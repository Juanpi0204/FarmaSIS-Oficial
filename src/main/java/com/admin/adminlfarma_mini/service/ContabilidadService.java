package com.admin.adminlfarma_mini.service;

import com.admin.adminlfarma_mini.entity.DetalleFactura;
import com.admin.adminlfarma_mini.entity.Factura;
import com.admin.adminlfarma_mini.entity.Producto;
import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.repository.ProductoRepository;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.bson.Document;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.AggregationOperation;
import org.springframework.data.mongodb.core.aggregation.AggregationOptions;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Única fuente de verdad de la contabilidad (ventas, costo y ganancia neta).
 * La usan la Web, la API móvil (APK) y los filtros, así todas muestran exactamente las mismas cifras.
 *
 * Los totales se calculan DENTRO de MongoDB (agregación): se pueden sumar las 65.000+ facturas
 * sin cargarlas en la memoria del servidor.
 */
@Service
@RequiredArgsConstructor
public class ContabilidadService {

    /** Marcador que no coincide con ningún vendedor (el usuario no tiene permiso o el filtro no encontró a nadie). */
    private static final String SIN_COINCIDENCIA = "__sin_coincidencia__";

    /**
     * Si un producto no tiene costoCompra válido se estima el costo en 70% del precio
     * (30% de margen, que es el margen real del catálogo).
     */
    private static final double COSTO_ESTIMADO_SOBRE_PRECIO = 0.70;

    private final MongoTemplate mongoTemplate;
    private final ProductoRepository productoRepository;
    private final UsuarioService usuarioService;
    private final FacturaService facturaService;

    // ------------------------------------------------------------------ permisos

    /**
     * Roles que ven TODAS las ventas y la contabilidad (ganancia neta): OWNER y ADMIN.
     * El EMPLEADO solo ve sus propias ventas y nunca las ganancias.
     * Para restringir la ganancia únicamente al dueño basta con quitar "ADMIN" de este método.
     */
    public static boolean tieneAccesoContable(String rol) {
        if (rol == null) {
            return false;
        }
        String r = rol.toUpperCase();
        return r.contains("OWNER") || r.contains("ADMIN");
    }

    /**
     * Lista de correos/usuarios cuyas ventas puede ver quien consulta.
     * Lista vacía = sin restricción (dueño/admin sin filtro de vendedor).
     */
    public List<String> resolverVendedoresPermitidos(String rol, String username, String filtroVendedor) {
        List<String> permitidos = new ArrayList<>();

        if (!tieneAccesoContable(rol)) {
            if (hayTexto(username)) {
                permitidos.add(username.trim());
                usuarioService.buscarPorUsername(username.trim())
                        .map(Usuario::getEmail)
                        .filter(ContabilidadService::hayTexto)
                        .ifPresent(permitidos::add);
            }
        } else if (hayTexto(filtroVendedor)) {
            String buscado = filtroVendedor.toLowerCase().trim();
            for (Usuario u : usuarioService.listarTodosIncluyendoInactivos()) {
                if (contiene(u.getNombre(), buscado) || contiene(u.getApellido(), buscado)
                        || contiene(u.getUsername(), buscado) || contiene(u.getEmail(), buscado)) {
                    if (u.getUsername() != null) permitidos.add(u.getUsername());
                    if (u.getEmail() != null) permitidos.add(u.getEmail());
                }
            }
        } else {
            return permitidos;
        }

        if (permitidos.isEmpty()) {
            permitidos.add(SIN_COINCIDENCIA);
        }
        return permitidos;
    }

    // ------------------------------------------------------------------ resumen contable

    @Getter
    @AllArgsConstructor
    public static class ResumenContable {
        private final double ventas;
        private final double costo;
        private final double ganancia;
        private final double margenPorcentaje;
        private final long facturas;
        private final int unidades;
        /** Una fila por producto: codigo, nombre, unidades, precioUnitario, costoUnitario, ventaTotal, costoTotal, gananciaTotal. */
        private final List<Map<String, Object>> productos;
    }

    /** Resumen contable de un período (o de todo el historial si no hay fechas), calculado en la base de datos. */
    public ResumenContable calcularResumen(String fechaDesde, String fechaHasta, String metodoPago,
                                           String numFactura, List<String> vendedores) {
        Criteria filtro = facturaService.construirFiltro(fechaDesde, fechaHasta, metodoPago, numFactura, vendedores);

        AggregationOptions options = AggregationOptions.builder().allowDiskUse(true).build();

        // 1) Total vendido y número de facturas
        List<AggregationOperation> opsTotales = new ArrayList<>();
        if (filtro != null) opsTotales.add(Aggregation.match(filtro));
        opsTotales.add(Aggregation.group().sum("total").as("ventas").count().as("facturas"));
        Document totales = mongoTemplate
                .aggregate(Aggregation.newAggregation(Factura.class, opsTotales).withOptions(options), Document.class)
                .getUniqueMappedResult();
        double ventas = totales != null ? numero(totales.get("ventas")) : 0.0;
        long facturas = totales != null ? (long) numero(totales.get("facturas")) : 0L;

        // 2) Unidades y venta por producto y precio
        List<AggregationOperation> opsItems = new ArrayList<>();
        if (filtro != null) opsItems.add(Aggregation.match(filtro));
        opsItems.add(Aggregation.unwind("detalles"));
        opsItems.add(Aggregation.project()
                .and("detalles.productoNombre").as("nombre")
                .and("detalles.productoId").as("productoId")
                .and("detalles.productoCodigo").as("codigo")
                .and("detalles.cantidad").as("cantidad")
                .and("detalles.precioUnitario").as("precio")
                .and("detalles.subtotal").as("subtotal"));
        opsItems.add(Aggregation.group("nombre", "precio")
                .first("productoId").as("productoId")
                .first("codigo").as("codigo")
                .sum("cantidad").as("unidades")
                .sum("subtotal").as("venta"));
        List<Document> grupos = mongoTemplate
                .aggregate(Aggregation.newAggregation(Factura.class, opsItems).withOptions(options), Document.class)
                .getMappedResults();

        // 3) Costos reales de solo los productos involucrados
        Set<String> ids = new HashSet<>();
        for (Document g : grupos) {
            Object id = g.get("productoId");
            if (id != null) ids.add(id.toString());
        }
        Map<String, Double> costos = cargarCostos(ids);

        // 4) Costo y ganancia, agrupados por producto
        Map<String, Map<String, Object>> porProducto = new LinkedHashMap<>();
        double costoTotal = 0.0;
        double ventaItems = 0.0;
        int unidadesTotal = 0;

        for (Document g : grupos) {
            Document clave = g.get("_id") instanceof Document ? (Document) g.get("_id") : g;
            String nombre = clave.get("nombre") != null ? clave.get("nombre").toString() : "Producto";
            double precio = numero(clave.get("precio"));
            int unidades = (int) numero(g.get("unidades"));
            double venta = numero(g.get("venta"));
            String productoId = g.get("productoId") != null ? g.get("productoId").toString() : null;

            double costoUnitario = costoUnitarioEfectivo(productoId != null ? costos.get(productoId) : null, precio);
            double costoGrupo = costoUnitario * unidades;

            costoTotal += costoGrupo;
            ventaItems += venta;
            unidadesTotal += unidades;

            Map<String, Object> fila = porProducto.computeIfAbsent(nombre, k -> {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("codigo", g.get("codigo") != null ? g.get("codigo").toString() : "—");
                m.put("nombre", nombre);
                m.put("unidades", 0);
                m.put("ventaTotal", 0.0);
                m.put("costoTotal", 0.0);
                return m;
            });
            fila.put("unidades", (int) fila.get("unidades") + unidades);
            fila.put("ventaTotal", (double) fila.get("ventaTotal") + venta);
            fila.put("costoTotal", (double) fila.get("costoTotal") + costoGrupo);
        }

        List<Map<String, Object>> productos = new ArrayList<>();
        for (Map<String, Object> fila : porProducto.values()) {
            int unidades = (int) fila.get("unidades");
            double venta = (double) fila.get("ventaTotal");
            double costo = (double) fila.get("costoTotal");
            fila.put("precioUnitario", unidades > 0 ? redondear(venta / unidades) : 0.0);
            fila.put("costoUnitario", unidades > 0 ? redondear(costo / unidades) : 0.0);
            fila.put("ventaTotal", redondear(venta));
            fila.put("costoTotal", redondear(costo));
            fila.put("gananciaTotal", redondear(venta - costo));
            productos.add(fila);
        }
        productos.sort((a, b) -> Double.compare((double) b.get("gananciaTotal"), (double) a.get("gananciaTotal")));

        double ganancia;
        if (ventaItems == 0.0 && ventas > 0.0) {
            costoTotal = redondear(ventas * COSTO_ESTIMADO_SOBRE_PRECIO);
            ganancia = ventas - costoTotal;
        } else {
            ganancia = ventaItems - costoTotal;
        }
        double margen = ventas > 0 ? Math.round((ganancia / ventas) * 1000.0) / 10.0 : 0.0;

        if (productos.size() > 250) {
            productos = new ArrayList<>(productos.subList(0, 250));
        }
        return new ResumenContable(redondear(ventas), redondear(costoTotal), redondear(ganancia),
                margen, facturas, unidadesTotal, productos);
    }

    /** Resumen de las ventas de hoy dentro del alcance (vendedores) indicado. */
    public ResumenContable calcularResumenHoy(List<String> vendedores) {
        String hoy = LocalDate.now().toString();
        return calcularResumen(hoy, hoy, null, null, vendedores);
    }

    // ------------------------------------------------------------------ enriquecer facturas de una página

    /**
     * Completa las facturas que se van a mostrar: nombre/rol real del vendedor y,
     * si el rol lo permite, costo y ganancia neta por ítem y por factura.
     */
    public void enriquecer(List<Factura> facturas, boolean incluirGanancia) {
        if (facturas == null || facturas.isEmpty()) {
            return;
        }

        Map<String, Usuario> usuarios = null;
        for (Factura f : facturas) {
            if (!hayTexto(f.getVendedorNombre()) && f.getVendedorEmail() != null) {
                if (usuarios == null) {
                    usuarios = indexarUsuarios();
                }
                completarVendedor(f, usuarios.get(f.getVendedorEmail().toLowerCase().trim()));
            }
        }

        if (!incluirGanancia) {
            return;
        }

        Set<String> ids = new HashSet<>();
        for (Factura f : facturas) {
            if (f.getDetalles() == null) continue;
            for (DetalleFactura d : f.getDetalles()) {
                if (d.getProductoId() != null) ids.add(d.getProductoId());
            }
        }
        Map<String, Double> costos = cargarCostos(ids);

        for (Factura f : facturas) {
            double costoFactura = 0.0;
            double gananciaFactura = 0.0;
            if (f.getDetalles() != null) {
                for (DetalleFactura d : f.getDetalles()) {
                    int cantidad = d.getCantidad() != null ? d.getCantidad() : 0;
                    double precio = d.getPrecioUnitario() != null ? d.getPrecioUnitario() : 0.0;
                    double subtotal = d.getSubtotal() != null ? d.getSubtotal() : precio * cantidad;
                    double costoUnitario = costoUnitarioEfectivo(
                            d.getProductoId() != null ? costos.get(d.getProductoId()) : null, precio);
                    d.setCostoUnitario(costoUnitario);
                    d.setGananciaItem(redondear(subtotal - costoUnitario * cantidad));
                    costoFactura += costoUnitario * cantidad;
                    gananciaFactura += subtotal - costoUnitario * cantidad;
                }
            }
            f.setCostoTotal(redondear(costoFactura));
            f.setGananciaNeta(redondear(gananciaFactura));
        }
    }

    // ------------------------------------------------------------------ utilidades

    /** Costo real del producto si es coherente (mayor que 0 y menor que el precio); si no, un costo estimado. */
    public static double costoUnitarioEfectivo(Double costoReal, double precioUnitario) {
        if (costoReal != null && costoReal > 0 && costoReal < precioUnitario) {
            return costoReal;
        }
        return redondear(precioUnitario * COSTO_ESTIMADO_SOBRE_PRECIO);
    }

    private Map<String, Double> cargarCostos(Set<String> productoIds) {
        Map<String, Double> costos = new HashMap<>();
        if (productoIds.isEmpty()) {
            return costos;
        }
        for (Producto p : productoRepository.findAllById(productoIds)) {
            if (p.getId() != null && p.getCostoCompra() != null && p.getCostoCompra() > 0) {
                costos.put(p.getId(), p.getCostoCompra());
            }
        }
        return costos;
    }

    private Map<String, Usuario> indexarUsuarios() {
        Map<String, Usuario> usuarios = new HashMap<>();
        for (Usuario u : usuarioService.listarTodosIncluyendoInactivos()) {
            if (u.getUsername() != null) usuarios.put(u.getUsername().toLowerCase(), u);
            if (u.getEmail() != null) usuarios.put(u.getEmail().toLowerCase(), u);
        }
        return usuarios;
    }

    private void completarVendedor(Factura f, Usuario u) {
        if (u == null) {
            f.setVendedorNombre(f.getVendedorEmail());
            return;
        }
        String completo = ((u.getNombre() != null ? u.getNombre() : "") + " "
                + (u.getApellido() != null ? u.getApellido() : "")).trim();
        f.setVendedorNombre(completo.isEmpty() ? u.getUsername() : completo);
        if (!hayTexto(f.getVendedorRol())) {
            f.setVendedorRol(u.getRol() != null ? u.getRol().replace("ROLE_", "") : "EMPLEADO");
        }
    }

    private static boolean contiene(String texto, String buscado) {
        return texto != null && texto.toLowerCase().contains(buscado);
    }

    private static boolean hayTexto(String valor) {
        return valor != null && !valor.trim().isEmpty();
    }

    private static double numero(Object valor) {
        return valor instanceof Number ? ((Number) valor).doubleValue() : 0.0;
    }

    private static double redondear(double valor) {
        return Math.round(valor * 100.0) / 100.0;
    }
}

