package com.admin.adminlfarma_mini.service; // Paquete de los servicios (lógica de negocio) de FARMASIS.

import com.admin.adminlfarma_mini.entity.DetalleFactura; // Una línea de factura (producto, cantidad, precio).
import com.admin.adminlfarma_mini.entity.Factura; // Documento FACTURA de MongoDB (contiene la lista de detalles).
import com.admin.adminlfarma_mini.entity.Producto; // Documento PRODUCTOS de MongoDB (stock, stock mínimo, nombre...).
import com.admin.adminlfarma_mini.repository.FacturaRepository; // Acceso a la colección FACTURA.
import com.admin.adminlfarma_mini.repository.ProductoRepository; // Acceso a la colección PRODUCTOS.
import lombok.RequiredArgsConstructor; // Lombok: genera el constructor con los campos 'final' (inyección de dependencias).
import lombok.extern.slf4j.Slf4j; // Lombok: crea el objeto 'log' para escribir en la consola.
import org.springframework.stereotype.Service; // Marca la clase como servicio administrado por Spring.

import java.time.DayOfWeek; // Día de la semana (lunes..domingo).
import java.time.LocalDate; // Fecha sin hora.
import java.time.temporal.ChronoUnit; // Para contar días/semanas/meses entre dos fechas.
import java.time.temporal.IsoFields; // Para obtener el número de semana ISO (1-53).
import java.time.temporal.TemporalAdjusters; // Para ubicar el lunes de una semana.
import java.util.*; // List, Map, Optional, Arrays, etc.

/**
 * PREDICCIÓN DE DEMANDA Y RIESGO DE QUIEBRE DE STOCK (100 % con datos reales).
 *
 * MODELO USADO: Suavizado exponencial doble con tendencia AMORTIGUADA (Holt amortiguado,
 * Gardner & McKenzie, 1985), más un componente estacional ADITIVO por día de la semana
 * únicamente cuando la escala es DIARIA.
 *
 * FLUJO:
 *  1) Se leen de MongoDB las facturas del producto en la ventana histórica.
 *  2) Se suman las unidades vendidas por periodo (día, semana ISO o mes). Un periodo sin ventas cuenta como 0.
 *  3) Si no hay historial suficiente, NO se predice nada (se responde SIN_DATOS).
 *  4) Se ajusta el modelo (se eligen alfa y beta que minimizan el error cuadrático de un paso adelante).
 *  5) Se proyectan los siguientes periodos con intervalo de confianza del 95 %.
 *  6) Se simula el inventario para estimar riesgo de quiebre, periodo crítico y reorden sugerida.
 */
@Service // Spring crea una única instancia de esta clase y la deja disponible para inyectar.
@RequiredArgsConstructor // Constructor con los dos repositorios de abajo.
@Slf4j // Habilita 'log'.
public class PrediccionService {

    private final ProductoRepository productoRepository; // Para leer stock, stock mínimo, nombre y categoría reales.
    private final FacturaRepository facturaRepository; // Para leer las ventas reales (facturas).

    /** Factor de amortiguación de la tendencia: 0.90 hace que la tendencia se "apague" gradualmente en el futuro. */
    private static final double PHI = 0.90;
    /** Valor crítico de la normal para un intervalo de confianza del 95 %. */
    private static final double Z95 = 1.96;
    /** Rejilla de valores candidatos para alfa (nivel) y beta (tendencia). Se prueban todas las combinaciones. */
    private static final double[] REJILLA = {0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9};
    /** Umbral de cambio relativo (8 %) para clasificar la tendencia como CRECIENTE o DECRECIENTE. */
    private static final double UMBRAL_TENDENCIA = 0.08;
    /** Nombres cortos de los días (índice 0 = lunes). */
    private static final String[] DIAS = {"Lun", "Mar", "Mie", "Jue", "Vie", "Sab", "Dom"};
    /** Nombres cortos de los meses (índice 0 = enero). */
    private static final String[] MESES = {"Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"};

    /**
     * Configuración de cada escala temporal.
     * ventana  = cuántos periodos completos hacia atrás se leen de la base de datos.
     * horizonte = cuántos periodos hacia adelante se predicen.
     * minimo   = periodos con historial (desde la primera venta) exigidos para poder predecir.
     * mostrar  = cuántos periodos históricos se devuelven para graficar.
     * estacional = si se aplica estacionalidad por día de la semana (solo tiene sentido en la escala diaria).
     */
    private enum Escala {
        DIARIO(28, 7, 14, 14, true, "días"), // 4 semanas de historia, 7 días de pronóstico, mínimo 2 semanas.
        SEMANAL(12, 4, 8, 12, false, "semanas"), // 12 semanas de historia, 4 de pronóstico, mínimo 8.
        MENSUAL(6, 3, 4, 6, false, "meses"); // 6 meses de historia, 3 de pronóstico, mínimo 4.

        final int ventana; // Periodos históricos que se consultan.
        final int horizonte; // Periodos futuros que se predicen.
        final int minimo; // Mínimo de periodos con historial.
        final int mostrar; // Periodos históricos que se devuelven al cliente.
        final boolean estacional; // ¿Usa componente estacional semanal?
        final String unidad; // Texto para los mensajes ("días", "semanas", "meses").

        Escala(int ventana, int horizonte, int minimo, int mostrar, boolean estacional, String unidad) {
            this.ventana = ventana; // Guarda la ventana.
            this.horizonte = horizonte; // Guarda el horizonte.
            this.minimo = minimo; // Guarda el mínimo.
            this.mostrar = mostrar; // Guarda cuántos mostrar.
            this.estacional = estacional; // Guarda si es estacional.
            this.unidad = unidad; // Guarda la unidad de texto.
        }
    }

    /** Resultado del ajuste del modelo (todo en la escala "desestacionalizada"). */
    private record ModeloHolt(double alfa, double beta, double nivel, double tendencia, double sse, double[] ajustados) {
    }

    // =====================================================================================
    //  MÉTODO PRINCIPAL: usado por GET /api/v1/prediccion/ventas
    // =====================================================================================

    /**
     * Calcula la predicción de un producto para la temporalidad indicada usando SOLO datos reales.
     */
    public Map<String, Object> obtenerPrediccion(String productoId, String temporalidad) {
        Escala escala = parsearEscala(temporalidad); // Convierte el texto recibido en DIARIO/SEMANAL/MENSUAL (por defecto SEMANAL).

        Optional<Producto> opt = buscarProducto(productoId); // Busca el producto en MongoDB por código o por id.
        if (opt.isEmpty()) { // Si el producto no existe en la base de datos...
            Map<String, Object> noExiste = new LinkedHashMap<>(); // ...se arma una respuesta de error explícita.
            noExiste.put("status", "PRODUCTO_NO_ENCONTRADO"); // El controlador la convierte en HTTP 404.
            noExiste.put("mensaje", "No existe un producto con código o id '" + productoId + "' en la base de datos.");
            return noExiste; // No se inventa ningún producto.
        }
        Producto producto = opt.get(); // Producto real.

        // ---------- 1) Definir la ventana de tiempo (solo periodos COMPLETOS, el periodo en curso se excluye) ----------
        LocalDate hoy = LocalDate.now(); // Fecha actual del servidor.
        LocalDate inicioActual = inicioPeriodoActual(escala, hoy); // Primer día del periodo en curso (hoy / lunes / día 1).
        LocalDate inicioHistoria = desplazar(escala, inicioActual, -escala.ventana); // Primer día de la ventana histórica.

        // ---------- 2) Leer de MongoDB las facturas reales del producto dentro de la ventana ----------
        List<Factura> facturas = facturaRepository.findVentasPorProducto(
                inicioHistoria.atStartOfDay(), // Desde las 00:00 del primer día de la ventana (incluido).
                inicioActual.atStartOfDay(), // Hasta las 00:00 del periodo en curso (excluido).
                Objects.toString(producto.getCodigo(), "__sin_codigo__"), // Si no hay código, un texto que nunca coincide (evita traer facturas de más).
                Objects.toString(producto.getId(), "__sin_id__")); // Id interno de MongoDB del producto.

        // ---------- 3) Sumar unidades vendidas por periodo ----------
        double[] ventas = new double[escala.ventana]; // Un acumulador por periodo; inicia en 0 (sin ventas = 0 unidades).
        for (Factura f : facturas) { // Recorre cada factura encontrada.
            if (f.getFecha() == null || f.getDetalles() == null) continue; // Ignora facturas sin fecha o sin líneas.
            long idx = indicePeriodo(escala, inicioHistoria, f.getFecha().toLocalDate()); // En qué periodo cae la factura.
            if (idx < 0 || idx >= escala.ventana) continue; // Fuera de la ventana: se ignora.
            for (DetalleFactura d : f.getDetalles()) { // Recorre las líneas de la factura.
                if (coincide(producto, d)) { // Solo cuenta las líneas de ESTE producto (una factura puede traer varios).
                    ventas[(int) idx] += (d.getCantidad() != null ? d.getCantidad() : 0); // Suma las unidades vendidas.
                }
            }
        }

        // ---------- 4) Recortar los periodos previos a la primera venta (no son "demanda cero", son "producto aún sin vender") ----------
        int primero = -1; // Posición del primer periodo con ventas.
        for (int i = 0; i < ventas.length; i++) { // Busca desde el más antiguo...
            if (ventas[i] > 0) { primero = i; break; } // ...el primero con ventas.
        }
        if (primero < 0) { // Si nunca se vendió en toda la ventana...
            return sinDatos(producto, escala, 0, "Este producto no tiene ventas registradas en los últimos "
                    + escala.ventana + " " + escala.unidad + ". Registra ventas para activar la predicción.");
        }
        int n = escala.ventana - primero; // Cantidad de periodos con historial real.
        if (n < escala.minimo) { // Si el historial es demasiado corto para ajustar el modelo...
            return sinDatos(producto, escala, n, "Historial insuficiente: hay " + n + " " + escala.unidad
                    + " con ventas y se requieren al menos " + escala.minimo + " para predecir.");
        }
        double[] y = Arrays.copyOfRange(ventas, primero, escala.ventana); // Serie histórica real (unidades por periodo).
        LocalDate[] inicios = new LocalDate[n]; // Fecha de inicio de cada periodo de la serie.
        for (int t = 0; t < n; t++) inicios[t] = desplazar(escala, inicioHistoria, primero + t);

        // ---------- 5) Componente estacional aditivo por día de la semana (solo escala DIARIA) ----------
        double[] estac = escala.estacional ? estacionalidadAditiva(y, inicios) : new double[7]; // Ceros si no aplica.

        // ---------- 6) Quitar la estacionalidad: z = y - s(día) ----------
        double[] z = new double[n]; // Serie desestacionalizada, la que ve el modelo de Holt.
        for (int t = 0; t < n; t++) z[t] = y[t] - estac[idxEstacional(escala, inicios[t])];

        // ---------- 7) Ajustar Holt amortiguado eligiendo los mejores alfa y beta ----------
        ModeloHolt modelo = ajustar(z);

        // ---------- 8) Medir la calidad del ajuste ----------
        double sigma = Math.sqrt(modelo.sse() / Math.max(1, n - 1)); // RMSE de los errores de un paso adelante.
        double sumaErrAbs = 0; // Suma de |real - ajustado| (escala original).
        double sumaReal = 0; // Suma de ventas reales.
        for (int t = 1; t < n; t++) { // Desde t=1: en t=0 no hay predicción de un paso (es el valor inicial).
            double ajustado = Math.max(0, modelo.ajustados()[t] + estac[idxEstacional(escala, inicios[t])]); // Ajuste en unidades reales.
            sumaErrAbs += Math.abs(y[t] - ajustado); // Error absoluto de ese periodo.
            sumaReal += y[t]; // Ventas reales de ese periodo.
        }
        double wape = sumaReal > 0 ? sumaErrAbs / sumaReal : 0; // WAPE = error absoluto ponderado (menor es mejor).

        // ---------- 9) Serie histórica para graficar (real + ajuste del modelo + intervalo) ----------
        List<Map<String, Object>> serie = new ArrayList<>(); // Lista final de puntos del contrato JSON.
        int desde = Math.max(0, n - escala.mostrar); // Solo se devuelven los últimos 'mostrar' periodos históricos.
        for (int t = desde; t < n; t++) {
            double ajustado = Math.max(0, modelo.ajustados()[t] + estac[idxEstacional(escala, inicios[t])]); // Valor ajustado por el modelo.
            serie.add(crearPunto(etiqueta(escala, inicios[t]), // Etiqueta del eje X.
                    (int) Math.round(y[t]), // Ventas reales (hecho histórico).
                    (int) Math.round(ajustado), // Lo que el modelo "habría predicho" un paso antes.
                    (int) Math.round(Math.max(0, ajustado - Z95 * sigma)), // Límite inferior 95 %.
                    (int) Math.round(ajustado + Z95 * sigma))); // Límite superior 95 %.
        }

        // ---------- 10) Proyección hacia adelante ----------
        int h = escala.horizonte; // Número de periodos futuros.
        int[] pred = new int[h]; // Predicción redondeada de cada periodo futuro.
        String[] etiquetasFuturas = new String[h]; // Etiqueta de cada periodo futuro.
        double acumPhi = 0; // Suma phi + phi^2 + ... + phi^k (efecto acumulado de la tendencia amortiguada).
        double potPhi = 1; // phi^k, se va multiplicando en cada paso.
        for (int k = 1; k <= h; k++) {
            potPhi *= PHI; // phi^k.
            acumPhi += potPhi; // phi + ... + phi^k.
            LocalDate inicioFuturo = desplazar(escala, inicioActual, k - 1); // Primer día del periodo futuro k.
            double zHat = modelo.nivel() + acumPhi * modelo.tendencia(); // Pronóstico desestacionalizado: nivel + tendencia amortiguada.
            double yHat = Math.max(0, zHat + estac[idxEstacional(escala, inicioFuturo)]); // Se vuelve a sumar la estacionalidad; las ventas no pueden ser negativas.
            double sigmaH = sigma * Math.sqrt(k); // La incertidumbre crece con el horizonte (aprox. raíz de k).
            pred[k - 1] = (int) Math.round(yHat); // Pronóstico en unidades enteras.
            etiquetasFuturas[k - 1] = etiqueta(escala, inicioFuturo); // Etiqueta del eje X.
            serie.add(crearPunto(etiquetasFuturas[k - 1],
                    null, // ventas_reales = null: aún no ocurren.
                    pred[k - 1],
                    (int) Math.round(Math.max(0, yHat - Z95 * sigmaH)), // Límite inferior 95 %.
                    (int) Math.round(yHat + Z95 * sigmaH))); // Límite superior 95 %.
        }

        // ---------- 11) Resumen ejecutivo: total, tendencia, riesgo de quiebre y reorden ----------
        int stockActual = producto.getCantidad() != null ? producto.getCantidad() : 0; // Stock real hoy.
        int stockMinimo = producto.getStockMinimo(); // Stock mínimo real del producto.

        int totalPredicho = 0; // Demanda total esperada en el horizonte.
        for (int p : pred) totalPredicho += p;

        // Tendencia: compara el promedio pronosticado con el promedio de los últimos (hasta 4) periodos reales.
        int ult = Math.min(4, n); // Cuántos periodos reales recientes se usan como referencia.
        double mediaReciente = 0; // Promedio de las ventas reales recientes.
        for (int t = n - ult; t < n; t++) mediaReciente += y[t];
        mediaReciente /= ult;
        double mediaFutura = (double) totalPredicho / h; // Promedio de lo pronosticado.
        String tendencia = "ESTABLE"; // Por defecto.
        if (mediaReciente > 0) {
            double cambio = (mediaFutura - mediaReciente) / mediaReciente; // Cambio relativo.
            if (cambio > UMBRAL_TENDENCIA) tendencia = "CRECIENTE"; // Sube más de 8 %.
            else if (cambio < -UMBRAL_TENDENCIA) tendencia = "DECRECIENTE"; // Baja más de 8 %.
        } else if (mediaFutura > 0) {
            tendencia = "CRECIENTE"; // Antes no vendía y ahora se espera que venda.
        }

        // Simulación de inventario: se resta la demanda pronosticada periodo a periodo.
        double saldo = stockActual; // Inventario simulado.
        int idxCritico = -1; // Número (1..h) del primer periodo en que el saldo llega al stock mínimo.
        if (saldo <= stockMinimo) idxCritico = 1; // Si ya está en o bajo el mínimo, el problema es inmediato.
        for (int k = 1; k <= h && idxCritico < 0; k++) {
            saldo -= pred[k - 1]; // Se consume la demanda del periodo k.
            if (saldo <= stockMinimo) idxCritico = k; // Primer periodo en que se viola el stock mínimo.
        }
        String riesgo = "BAJO"; // Sin quiebre previsto dentro del horizonte.
        if (idxCritico >= 1 && idxCritico <= 2) riesgo = "ALTO"; // El mínimo se rompe en los 2 primeros periodos.
        else if (idxCritico > 2) riesgo = "MEDIO"; // Se rompe más adelante dentro del horizonte.
        String periodoCritico = idxCritico > 0 ? etiquetasFuturas[idxCritico - 1] : "Sin quiebre previsto";

        // Reorden sugerida = demanda futura + stock de seguridad (mínimo) - stock disponible, nunca negativa.
        int reorden = Math.max(0, totalPredicho + stockMinimo - stockActual);

        Map<String, Object> resumen = new LinkedHashMap<>();
        resumen.put("total_predicho", totalPredicho);
        resumen.put("tendencia", tendencia);
        resumen.put("riesgo_quiebre", riesgo);
        // El contrato usa una clave distinta según la temporalidad (la app Flutter acepta las tres).
        resumen.put(escala == Escala.DIARIO ? "dia_critico" : escala == Escala.SEMANAL ? "semana_critica" : "mes_critico", periodoCritico);
        resumen.put("sugerencia_reorden_unidades", reorden);

        // ---------- 12) Metadatos del modelo (para poder sustentar y auditar el resultado) ----------
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("modelo", escala.estacional
                ? "Holt amortiguado + estacionalidad aditiva por día de la semana"
                : "Holt amortiguado (suavizado exponencial doble con tendencia amortiguada)");
        info.put("alfa", r4(modelo.alfa())); // Peso del dato nuevo en el nivel.
        info.put("beta", r4(modelo.beta())); // Peso del dato nuevo en la tendencia.
        info.put("phi", PHI); // Amortiguación de la tendencia.
        info.put("rmse", r4(sigma)); // Error típico (unidades).
        info.put("wape", r4(wape)); // Error porcentual ponderado.
        info.put("periodos_usados", n); // Cuántos periodos reales alimentaron el modelo.
        info.put("nivel_confianza", 0.95);
        info.put("fuente", "Facturas reales de MongoDB (colección FACTURA)");

        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", "OK");
        response.put("producto", infoProducto(producto));
        response.put("temporalidad", escala.name());
        response.put("resumen", resumen);
        response.put("serie_datos", serie);
        response.put("modelo", info);
        log.info("Predicción {} del producto {}: n={}, alfa={}, beta={}, rmse={}", escala, producto.getCodigo(), n,
                modelo.alfa(), modelo.beta(), r4(sigma));
        return response;
    }

    // =====================================================================================
    //  LISTA DE PRODUCTOS (para el selector de la app): GET /api/v1/productos
    // =====================================================================================

    /** Devuelve los productos activos reales de MongoDB, ordenados por nombre. */
    public List<Map<String, String>> listarProductos() {
        List<Map<String, String>> lista = new ArrayList<>();
        for (Producto p : productoRepository.findProductosActivos()) { // Solo productos activos.
            String id = p.getCodigo() != null ? p.getCodigo() : p.getId(); // Se prefiere el código de 4 dígitos.
            if (id == null) continue; // Sin identificador no se puede consultar.
            Map<String, String> item = new LinkedHashMap<>();
            item.put("id", id);
            item.put("nombre", (p.getNombre() != null ? p.getNombre() : id) + (p.getCodigo() != null ? " (" + p.getCodigo() + ")" : ""));
            item.put("categoria", p.getCategoria() != null ? p.getCategoria() : "GENERAL");
            lista.add(item);
        }
        lista.sort(Comparator.comparing(m -> m.get("nombre").toLowerCase())); // Orden alfabético.
        return lista;
    }

    /** Explicación metodológica del modelo, útil para sustentar ante el profesor. */
    public Map<String, Object> obtenerExplicacionMetodologica() {
        Map<String, Object> e = new LinkedHashMap<>();
        e.put("modelo", "Holt amortiguado (suavizado exponencial doble con tendencia amortiguada)");
        e.put("ecuacion_pronostico", "yhat(t+h) = nivel + (phi + phi^2 + ... + phi^h) * tendencia");
        e.put("ecuacion_nivel", "nivel(t) = alfa*y(t) + (1-alfa)*(nivel(t-1) + phi*tendencia(t-1))");
        e.put("ecuacion_tendencia", "tendencia(t) = beta*(nivel(t)-nivel(t-1)) + (1-beta)*phi*tendencia(t-1)");
        e.put("parametros", "alfa y beta se eligen probando una rejilla 0.1..0.9 y quedándose con la combinación de menor error cuadrático de un paso adelante; phi = " + PHI);
        e.put("estacionalidad", "Solo en escala DIARIA: componente aditivo por día de la semana (promedio del día menos promedio global)");
        e.put("intervalo_95", "yhat ± 1.96 * RMSE * raiz(h)");
        e.put("riesgo_quiebre", "Se resta la demanda pronosticada al stock real; ALTO si llega al stock mínimo en los 2 primeros periodos, MEDIO si ocurre después dentro del horizonte, BAJO si no ocurre");
        e.put("reorden", "max(0, demanda_pronosticada + stock_minimo - stock_actual)");
        e.put("sin_datos", "Si el producto no tiene el historial mínimo, no se predice (status SIN_DATOS)");
        e.put("fuente_datos", "Colección FACTURA (ventas reales) y PRODUCTOS (stock) de MongoDB");
        return e;
    }

    // =====================================================================================
    //  MODELO DE HOLT AMORTIGUADO
    // =====================================================================================

    /** Prueba todas las combinaciones (alfa, beta) de la rejilla y devuelve la de menor error cuadrático. */
    private ModeloHolt ajustar(double[] z) {
        ModeloHolt mejor = null; // Mejor modelo encontrado hasta ahora.
        for (double alfa : REJILLA) { // Cada alfa candidato...
            for (double beta : REJILLA) { // ...con cada beta candidato.
                ModeloHolt m = simular(z, alfa, beta); // Se corre el modelo sobre toda la serie.
                if (mejor == null || m.sse() < mejor.sse()) mejor = m; // Se conserva el de menor SSE.
            }
        }
        return mejor;
    }

    /** Recorre la serie aplicando las ecuaciones de Holt amortiguado con alfa y beta dados. */
    private ModeloHolt simular(double[] z, double alfa, double beta) {
        int n = z.length; // Número de observaciones.
        double[] ajustados = new double[n]; // Predicción de un paso adelante para cada periodo.
        double nivel = z[0]; // Nivel inicial = primer dato.
        int k = Math.min(3, n - 1); // Cuántos pasos se usan para estimar la tendencia inicial.
        double tendencia = (z[k] - z[0]) / k; // Tendencia inicial = pendiente media de los primeros pasos.
        ajustados[0] = z[0]; // En t=0 no hay predicción previa: se usa el propio dato.
        double sse = 0; // Suma de errores al cuadrado.
        for (int t = 1; t < n; t++) {
            double pronostico = nivel + PHI * tendencia; // Predicción de un paso adelante para el periodo t.
            ajustados[t] = pronostico; // Se guarda para graficar.
            double error = z[t] - pronostico; // Error = real - pronosticado.
            sse += error * error; // Se acumula el error cuadrático.
            double nivelNuevo = alfa * z[t] + (1 - alfa) * pronostico; // Actualiza el nivel mezclando dato nuevo y pronóstico.
            tendencia = beta * (nivelNuevo - nivel) + (1 - beta) * PHI * tendencia; // Actualiza la tendencia (amortiguada).
            nivel = nivelNuevo; // El nivel nuevo pasa a ser el actual.
        }
        return new ModeloHolt(alfa, beta, nivel, tendencia, sse, ajustados);
    }

    /** Componente estacional aditivo por día de la semana: promedio de ese día menos promedio general, centrado en 0. */
    private double[] estacionalidadAditiva(double[] y, LocalDate[] inicios) {
        double[] suma = new double[7]; // Suma de ventas por día de la semana.
        int[] cuenta = new int[7]; // Cuántos días de cada tipo hay en la serie.
        double media = 0; // Promedio general.
        for (int t = 0; t < y.length; t++) {
            int d = inicios[t].getDayOfWeek().getValue() - 1; // 0 = lunes ... 6 = domingo.
            suma[d] += y[t];
            cuenta[d]++;
            media += y[t];
        }
        media /= y.length;
        double[] s = new double[7];
        double prom = 0; // Promedio de los componentes (para centrarlos en cero).
        for (int d = 0; d < 7; d++) {
            s[d] = cuenta[d] > 0 ? suma[d] / cuenta[d] - media : 0; // Efecto del día: cuánto se aparta del promedio.
            prom += s[d];
        }
        prom /= 7;
        for (int d = 0; d < 7; d++) s[d] -= prom; // Centrado: la suma de efectos queda en ~0.
        return s;
    }

    /** Índice del componente estacional que corresponde a un periodo (día de la semana; 0 si no hay estacionalidad). */
    private int idxEstacional(Escala escala, LocalDate inicio) {
        return escala.estacional ? inicio.getDayOfWeek().getValue() - 1 : 0;
    }

    // =====================================================================================
    //  UTILIDADES DE PERIODOS Y CONSULTAS
    // =====================================================================================

    /** Convierte el texto de temporalidad en Escala; si es nulo o inválido usa SEMANAL. */
    private Escala parsearEscala(String t) {
        if (t == null) return Escala.SEMANAL;
        try {
            return Escala.valueOf(t.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            return Escala.SEMANAL;
        }
    }

    /** Primer día del periodo en curso: hoy (diario), lunes de esta semana (semanal) o día 1 del mes (mensual). */
    private LocalDate inicioPeriodoActual(Escala e, LocalDate hoy) {
        return switch (e) {
            case DIARIO -> hoy;
            case SEMANAL -> hoy.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
            case MENSUAL -> hoy.withDayOfMonth(1);
        };
    }

    /** Desplaza una fecha de inicio de periodo k periodos (k puede ser negativo). */
    private LocalDate desplazar(Escala e, LocalDate inicio, long k) {
        return switch (e) {
            case DIARIO -> inicio.plusDays(k);
            case SEMANAL -> inicio.plusWeeks(k);
            case MENSUAL -> inicio.plusMonths(k);
        };
    }

    /** Número de periodo (0 = primero de la ventana) al que pertenece una fecha. */
    private long indicePeriodo(Escala e, LocalDate base, LocalDate fecha) {
        return switch (e) {
            case DIARIO -> ChronoUnit.DAYS.between(base, fecha);
            case SEMANAL -> ChronoUnit.WEEKS.between(base, fecha);
            case MENSUAL -> ChronoUnit.MONTHS.between(base, fecha.withDayOfMonth(1));
        };
    }

    /** Etiqueta del eje X: "Lun 13" (día), "Sem 42" (semana ISO) o "Oct" (mes). */
    private String etiqueta(Escala e, LocalDate inicio) {
        return switch (e) {
            case DIARIO -> DIAS[inicio.getDayOfWeek().getValue() - 1] + " " + inicio.getDayOfMonth();
            case SEMANAL -> "Sem " + inicio.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR);
            case MENSUAL -> MESES[inicio.getMonthValue() - 1];
        };
    }

    /** ¿La línea de factura corresponde a este producto? (por código o por id interno). */
    private boolean coincide(Producto p, DetalleFactura d) {
        boolean porCodigo = p.getCodigo() != null && p.getCodigo().equals(d.getProductoCodigo());
        boolean porId = p.getId() != null && p.getId().equals(d.getProductoId());
        return porCodigo || porId;
    }

    /** Busca el producto en MongoDB: primero por código (4 dígitos) y si no, por id interno. */
    private Optional<Producto> buscarProducto(String idOCodigo) {
        if (idOCodigo == null || idOCodigo.isBlank()) return Optional.empty();
        String clave = idOCodigo.trim();
        Optional<Producto> porCodigo = productoRepository.findByCodigo(clave);
        return porCodigo.isPresent() ? porCodigo : productoRepository.findById(clave);
    }

    /** Ficha del producto con datos reales para el contrato JSON. */
    private Map<String, Object> infoProducto(Producto p) {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("codigo", p.getCodigo() != null ? p.getCodigo() : p.getId());
        info.put("nombre", p.getNombre());
        info.put("categoria", p.getCategoria() != null ? p.getCategoria().toUpperCase() : "GENERAL");
        info.put("stock_actual", p.getCantidad() != null ? p.getCantidad() : 0);
        info.put("stock_minimo", p.getStockMinimo());
        return info;
    }

    /** Respuesta cuando NO hay datos suficientes: se informa el motivo y NO se genera ninguna cifra. */
    private Map<String, Object> sinDatos(Producto p, Escala e, int periodosConHistorial, String mensaje) {
        Map<String, Object> requisitos = new LinkedHashMap<>();
        requisitos.put("periodos_con_historial", periodosConHistorial);
        requisitos.put("minimo_periodos", e.minimo);
        requisitos.put("unidad", e.unidad);
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("status", "SIN_DATOS");
        r.put("mensaje", mensaje);
        r.put("producto", infoProducto(p));
        r.put("temporalidad", e.name());
        r.put("resumen", new LinkedHashMap<String, Object>());
        r.put("serie_datos", new ArrayList<>());
        r.put("requisitos", requisitos);
        return r;
    }

    /** Un punto de la serie del contrato JSON. */
    private Map<String, Object> crearPunto(String periodo, Integer real, Integer predicho, Integer limInf, Integer limSup) {
        Map<String, Object> punto = new LinkedHashMap<>();
        punto.put("periodo", periodo);
        punto.put("ventas_reales", real);
        punto.put("ventas_predichas", predicho);
        punto.put("limite_inferior", limInf);
        punto.put("limite_superior", limSup);
        return punto;
    }

    /** Redondea a 4 decimales para mostrar métricas. */
    private double r4(double v) {
        return Math.round(v * 10000.0) / 10000.0;
    }
}
