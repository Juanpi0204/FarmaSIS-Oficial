package com.admin.adminlfarma_mini.service; // Mismo paquete que los demás servicios.

import com.admin.adminlfarma_mini.entity.DetalleFactura; // Línea de factura.
import com.admin.adminlfarma_mini.entity.Factura; // Documento FACTURA.
import com.admin.adminlfarma_mini.entity.Producto; // Documento PRODUCTOS.
import com.admin.adminlfarma_mini.repository.FacturaRepository; // Colección FACTURA.
import com.admin.adminlfarma_mini.repository.ProductoRepository; // Colección PRODUCTOS.
import lombok.RequiredArgsConstructor; // Lombok: constructor con campos 'final'.
import lombok.extern.slf4j.Slf4j; // Lombok: 'log'.
import org.springframework.beans.factory.annotation.Value; // Lee valores de application.properties.
import org.springframework.boot.CommandLineRunner; // Se ejecuta una vez al arrancar la aplicación.
import org.springframework.stereotype.Component; // Bean administrado por Spring.

import java.time.DayOfWeek; // Día de la semana.
import java.time.LocalDate; // Fecha.
import java.time.LocalDateTime; // Fecha y hora.
import java.time.format.DateTimeFormatter; // Para armar el número de factura.
import java.util.*; // List, Random, Collections...

/**
 * SEMBRADOR DE VENTAS HISTÓRICAS DE PRUEBA para alimentar el módulo de predicción.
 *
 * Inserta FACTURAS reales en MongoDB (misma estructura que crea el POS) con fechas pasadas.
 * Todas llevan observaciones = "SEMILLA_PREDICCION" para poder identificarlas y borrarlas.
 * NO modifica el stock de los productos (es historia, no ventas de hoy).
 *
 * Se controla con la propiedad  farmasis.seed.prediccion  en application.properties:
 *   false     -> no hace nada (valor por defecto)
 *   true      -> siembra solo si todavía no hay facturas sembradas
 *   reiniciar -> borra las facturas sembradas y las vuelve a generar hasta ayer
 *   eliminar  -> borra las facturas sembradas y termina
 * La demanda de cada producto es aleatoria pero REPRODUCIBLE (semilla fija) y tiene tendencia,
 * efecto de día de la semana (más venta viernes y sábado) y efecto de quincena.
 */
@Component // Spring lo crea al arrancar y, como es CommandLineRunner, ejecuta run().
@RequiredArgsConstructor // Constructor con los repositorios.
@Slf4j // 'log'.
public class SembradorVentasPrediccion implements CommandLineRunner {

    /** Marca que identifica las facturas sembradas (campo 'observaciones'). */
    public static final String MARCA = "SEMILLA_PREDICCION";

    /** Multiplicador de demanda por día de la semana (índice 0 = lunes). Viernes y sábado venden más. */
    private static final double[] FACTOR_DIA = {0.90, 0.95, 0.95, 1.00, 1.25, 1.35, 0.60};

    private final ProductoRepository productoRepository; // Para leer los productos reales a los que se les siembran ventas.
    private final FacturaRepository facturaRepository; // Para guardar/borrar las facturas sembradas.

    @Value("${farmasis.seed.prediccion:false}") // Modo de operación; si no existe la propiedad, 'false'.
    private String modo;

    @Value("${farmasis.seed.prediccion.dias:180}") // Cuántos días hacia atrás se siembran (por defecto 180).
    private int dias;

    @Override
    public void run(String... args) { // Spring lo llama al terminar de arrancar.
        String m = modo == null ? "false" : modo.trim().toLowerCase(); // Normaliza el valor.
        switch (m) {
            case "eliminar" -> eliminar(); // Solo borra lo sembrado.
            case "reiniciar" -> { // Borra y vuelve a sembrar (deja la historia al día hasta ayer).
                eliminar();
                sembrar();
            }
            case "true" -> { // Siembra solo si aún no hay datos sembrados.
                long existentes = facturaRepository.countByObservaciones(MARCA);
                if (existentes > 0) {
                    log.info("[SEMILLA] Ya existen {} facturas sembradas. No se vuelve a sembrar (usa 'reiniciar' para regenerar).", existentes);
                } else {
                    sembrar();
                }
            }
            default -> { // 'false' u otro valor: no se hace nada.
            }
        }
    }

    /** Borra todas las facturas sembradas (solo las que tienen la marca; las ventas reales no se tocan). */
    private void eliminar() {
        long borradas = facturaRepository.deleteByObservaciones(MARCA);
        log.info("[SEMILLA] Facturas sembradas eliminadas: {}", borradas);
    }

    /** Genera facturas históricas diarias para todos los productos activos. */
    private void sembrar() {
        List<Producto> productos = productoRepository.findProductosActivos(); // Productos reales activos.
        if (productos.isEmpty()) { // Sin productos no hay a qué sembrarle ventas.
            log.warn("[SEMILLA] No hay productos activos en la base de datos. No se sembró nada.");
            return;
        }
        Random rnd = new Random(2026); // Semilla fija: siempre genera los mismos datos (reproducible).
        LocalDate hoy = LocalDate.now(); // Hoy.
        List<Factura> buffer = new ArrayList<>(); // Facturas pendientes de guardar (se guardan por lotes).
        long totalFacturas = 0; // Contador para el log.

        // Perfil de demanda de cada producto, determinístico a partir de su código.
        double[] base = new double[productos.size()]; // Unidades promedio por día.
        double[] tendSemanal = new double[productos.size()]; // Crecimiento (o caída) por semana.
        for (int i = 0; i < productos.size(); i++) {
            Producto p = productos.get(i);
            int h = Math.abs(Objects.hash(p.getCodigo() != null ? p.getCodigo() : p.getId())); // Número estable por producto.
            base[i] = 1.0 + (h % 41) / 10.0; // Entre 1.0 y 5.0 unidades por día.
            tendSemanal[i] = -0.005 + ((h / 41) % 25) / 1000.0; // Entre -0.5 % y +1.9 % por semana.
        }

        for (int d = dias; d >= 1; d--) { // Desde hace 'dias' días hasta AYER (el día de hoy lo dejan las ventas reales).
            LocalDate dia = hoy.minusDays(d); // Día que se está generando.
            int dow = dia.getDayOfWeek().getValue() - 1; // 0 = lunes ... 6 = domingo.
            int diaMes = dia.getDayOfMonth();
            boolean quincena = diaMes == 1 || (diaMes >= 14 && diaMes <= 16) || diaMes >= 29; // Días de pago: se vende más.
            double semanas = (dias - d) / 7.0; // Semanas transcurridas desde el inicio (para aplicar la tendencia).

            List<Linea> lineas = new ArrayList<>(); // Ventas del día: (producto, unidades).
            for (int i = 0; i < productos.size(); i++) {
                double mu = base[i] * (1 + tendSemanal[i] * semanas) * FACTOR_DIA[dow] * (quincena ? 1.15 : 1.0); // Demanda esperada ese día.
                int unidades = poisson(rnd, Math.max(0.05, mu)); // Unidades realmente vendidas (aleatorio Poisson alrededor de mu).
                if (unidades > 0) lineas.add(new Linea(productos.get(i), unidades));
            }

            Collections.shuffle(lineas, rnd); // Se mezclan para repartirlas en facturas distintas.
            int pos = 0; // Posición actual en la lista de líneas.
            int consecutivo = 0; // Número de factura dentro del día.
            while (pos < lineas.size()) {
                int tam = 1 + rnd.nextInt(4); // Cada factura lleva entre 1 y 4 líneas.
                List<Linea> grupo = lineas.subList(pos, Math.min(lineas.size(), pos + tam));
                pos += tam;
                buffer.add(construirFactura(dia, ++consecutivo, grupo, rnd));
                totalFacturas++;
            }
            if (buffer.size() >= 500) { // Guarda por lotes para no saturar la memoria.
                facturaRepository.saveAll(buffer);
                buffer.clear();
            }
        }
        if (!buffer.isEmpty()) facturaRepository.saveAll(buffer); // Guarda lo que quedó pendiente.
        log.info("[SEMILLA] Sembradas {} facturas históricas ({} días, {} productos). Marca: {}", totalFacturas, dias, productos.size(), MARCA);
    }

    /** Arma una factura con la misma estructura que crea el POS. */
    private Factura construirFactura(LocalDate dia, int consecutivo, List<Linea> grupo, Random rnd) {
        Factura f = new Factura(); // Documento nuevo.
        f.setNumeroFactura(String.format("SEM-%s-%03d", dia.format(DateTimeFormatter.BASIC_ISO_DATE), consecutivo)); // Único: SEM-20261021-001.
        f.setFecha(LocalDateTime.of(dia, java.time.LocalTime.of(8 + rnd.nextInt(13), rnd.nextInt(60)))); // Hora aleatoria entre 8:00 y 20:59.
        f.setClienteNombre("Consumidor Final");
        f.setMetodoPago("EFECTIVO");
        f.setVendedorEmail("semilla@farmasis.local");
        f.setObservaciones(MARCA); // Marca para poder borrarlas luego.
        double subtotal = 0; // Total de la factura.
        List<DetalleFactura> detalles = new ArrayList<>();
        for (Linea l : grupo) {
            DetalleFactura det = new DetalleFactura();
            det.setProductoId(l.producto().getId()); // El POS guarda el id interno...
            det.setProductoCodigo(l.producto().getCodigo()); // ...y el código de 4 dígitos.
            det.setProductoNombre(l.producto().getNombre());
            det.setCantidad(l.unidades());
            double precio = l.producto().getPrecio() != null ? l.producto().getPrecio() : 0.0;
            det.setPrecioUnitario(precio);
            det.setSubtotal(precio * l.unidades());
            subtotal += det.getSubtotal();
            detalles.add(det);
        }
        f.setDetalles(detalles);
        f.setSubtotal(subtotal);
        f.setIva(0.0);
        f.setTotal(subtotal);
        return f;
    }

    /** Muestra aleatoria de una distribución de Poisson (algoritmo de Knuth), apropiada para conteos de ventas pequeños. */
    private int poisson(Random rnd, double lambda) {
        double limite = Math.exp(-lambda); // e^-lambda
        int k = 0; // Contador de eventos.
        double p = 1.0; // Producto acumulado de uniformes.
        do {
            k++;
            p *= rnd.nextDouble();
        } while (p > limite);
        return k - 1;
    }

    /** Venta de un producto en un día: producto y unidades. */
    private record Linea(Producto producto, int unidades) {
    }
}
