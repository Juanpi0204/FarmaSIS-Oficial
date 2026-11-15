package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.entity.DetalleFactura;
import com.admin.adminlfarma_mini.entity.Factura;
import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.service.FacturaService;
import com.admin.adminlfarma_mini.service.UsuarioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Controller
@RequestMapping("/empleado")
@PreAuthorize("hasRole('EMPLEADO')")
public class EmpleadoController {

    @Autowired
    private FacturaService facturaService;

    @Autowired
    private UsuarioService usuarioService;

    @GetMapping("/dashboard")
    public String dashboardEmpleado(Model model, Authentication auth) {
        String username = auth.getName();
        Usuario empleado = usuarioService.buscarPorUsername(username).orElse(null);

        List<String> misIdentificadores = new ArrayList<>();
        misIdentificadores.add(username);
        if (empleado != null && empleado.getEmail() != null && !empleado.getEmail().isBlank()) {
            misIdentificadores.add(empleado.getEmail());
        }

        // 1. Facturas del día del empleado
        List<Factura> facturasHoy = facturaService.getFacturasDelDiaPorVendedores(misIdentificadores);
        double ventasHoyMonto = facturasHoy.stream()
                .mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0)
                .sum();
        int cantidadFacturasHoy = facturasHoy.size();
        int productosVendidosHoy = facturaService.calcularUnidadesVendidas(facturasHoy);

        // 2. Historial total del empleado
        List<Factura> todasMisFacturas = facturaService.exportarFacturas(null, null, null, null, misIdentificadores);
        double totalHistoricoMonto = todasMisFacturas.stream()
                .mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0)
                .sum();
        int totalFacturasHistorico = todasMisFacturas.size();
        int totalProductosVendidosHistorico = facturaService.calcularUnidadesVendidas(todasMisFacturas);
        double ticketPromedio = totalFacturasHistorico > 0 ? (totalHistoricoMonto / totalFacturasHistorico) : 0.0;

        // 3. Top 5 productos más vendidos por este empleado
        Map<String, Map<String, Object>> conteoProductos = new LinkedHashMap<>();
        for (Factura f : todasMisFacturas) {
            if (f.getDetalles() == null) continue;
            for (DetalleFactura d : f.getDetalles()) {
                String nombreProd = d.getProductoNombre() != null ? d.getProductoNombre() : "Producto";
                Map<String, Object> item = conteoProductos.computeIfAbsent(nombreProd, k -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("nombre", k);
                    m.put("codigo", d.getProductoCodigo() != null ? d.getProductoCodigo() : "-");
                    m.put("unidades", 0);
                    m.put("recaudado", 0.0);
                    return m;
                });
                int uds = d.getCantidad() != null ? d.getCantidad() : 0;
                double sub = d.getSubtotal() != null ? d.getSubtotal() : 0.0;
                item.put("unidades", ((Integer) item.get("unidades")) + uds);
                item.put("recaudado", ((Double) item.get("recaudado")) + sub);
            }
        }
        List<Map<String, Object>> topMisProductos = conteoProductos.values().stream()
                .sorted((a, b) -> Integer.compare((Integer) b.get("unidades"), (Integer) a.get("unidades")))
                .limit(5)
                .toList();

        // 4. Datos de los últimos 7 días para la gráfica del empleado
        List<String> labels7Dias = new ArrayList<>();
        List<Double> montos7Dias = new ArrayList<>();
        List<Integer> unidades7Dias = new ArrayList<>();
        DateTimeFormatter fmtDia = DateTimeFormatter.ofPattern("dd/MM");
        LocalDate hoy = LocalDate.now();

        for (int i = 6; i >= 0; i--) {
            LocalDate dia = hoy.minusDays(i);
            labels7Dias.add(dia.format(fmtDia));
            List<Factura> delDia = todasMisFacturas.stream()
                    .filter(f -> f.getFecha() != null && f.getFecha().toLocalDate().isEqual(dia))
                    .toList();
            double montoDia = delDia.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
            int udsDia = facturaService.calcularUnidadesVendidas(delDia);
            montos7Dias.add(montoDia);
            unidades7Dias.add(udsDia);
        }

        String nombreMostrar = (empleado != null && empleado.getNombre() != null && !empleado.getNombre().isBlank())
                ? (empleado.getNombre() + " " + (empleado.getApellido() != null ? empleado.getApellido() : "")).trim()
                : username;

        model.addAttribute("titulo", "Mi Panel de Ventas - L-Farma");
        model.addAttribute("nombreEmpleado", nombreMostrar);
        model.addAttribute("ventasHoyMonto", ventasHoyMonto);
        model.addAttribute("cantidadFacturasHoy", cantidadFacturasHoy);
        model.addAttribute("productosVendidosHoy", productosVendidosHoy);
        model.addAttribute("totalHistoricoMonto", totalHistoricoMonto);
        model.addAttribute("totalFacturasHistorico", totalFacturasHistorico);
        model.addAttribute("totalProductosVendidosHistorico", totalProductosVendidosHistorico);
        model.addAttribute("ticketPromedio", ticketPromedio);
        model.addAttribute("facturasHoy", facturasHoy);
        model.addAttribute("ultimasFacturas", todasMisFacturas.stream().limit(10).toList());
        model.addAttribute("topMisProductos", topMisProductos);
        model.addAttribute("labels7Dias", labels7Dias);
        model.addAttribute("montos7Dias", montos7Dias);
        model.addAttribute("unidades7Dias", unidades7Dias);

        return "empleado/dashboard";
    }

    // Redirigir al POS unificado
    @GetMapping("/pos")
    public String puntoDeVenta() {
        return "redirect:/ventas/nueva";
    }
}
