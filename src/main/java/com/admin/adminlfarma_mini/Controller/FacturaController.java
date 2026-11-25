package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.DTO.FacturaRequestDTO;
import com.admin.adminlfarma_mini.entity.Factura;
import com.admin.adminlfarma_mini.entity.Producto;
import com.admin.adminlfarma_mini.service.ClienteService;
import com.admin.adminlfarma_mini.service.ConfiguracionService;
import com.admin.adminlfarma_mini.service.ContabilidadService;
import com.admin.adminlfarma_mini.service.FacturaService;
import com.admin.adminlfarma_mini.service.ProductoService;
import com.admin.adminlfarma_mini.service.UsuarioService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.streaming.SXSSFWorkbook;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import jakarta.servlet.http.HttpServletRequest;

@Controller
@RequestMapping("/ventas")
@RequiredArgsConstructor
public class FacturaController {

    private final FacturaService facturaService;
    private final ProductoService productoService;
    private final ClienteService clienteService;
    private final ConfiguracionService configuracionService;
    private final UsuarioService usuarioService;
    private final ContabilidadService contabilidadService;

    @GetMapping
    public String listarVentas(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "15") int size,
            @RequestParam(required = false) String fechaDesde,
            @RequestParam(required = false) String fechaHasta,
            @RequestParam(required = false) String metodoPago,
            @RequestParam(required = false) String factura,
            @RequestParam(required = false) String vendedor,
            Model model,
            java.security.Principal principal) {

        String username = principal != null ? principal.getName() : null;
        com.admin.adminlfarma_mini.entity.Usuario logueado =
                username != null ? usuarioService.buscarPorUsername(username).orElse(null) : null;
        String rol = logueado != null ? logueado.getRol() : null;

        // Dueño y administrador ven todo + contabilidad; el empleado solo sus ventas y sin ganancias
        boolean accesoContable = ContabilidadService.tieneAccesoContable(rol);
        List<String> vendedores = contabilidadService.resolverVendedoresPermitidos(rol, username, vendedor);

        int tamano = Math.min(Math.max(size, 5), 100);
        int pagina = Math.max(page, 0);
        Page<Factura> ventasPage = facturaService.buscarFacturas(
                fechaDesde, fechaHasta, metodoPago, factura, vendedores,
                PageRequest.of(pagina, tamano, Sort.by("fecha").descending()));

        // Si piden una página que ya no existe (p. ej. cambió el filtro), se muestra la última
        if (ventasPage.getTotalPages() > 0 && pagina >= ventasPage.getTotalPages()) {
            pagina = ventasPage.getTotalPages() - 1;
            ventasPage = facturaService.buscarFacturas(
                    fechaDesde, fechaHasta, metodoPago, factura, vendedores,
                    PageRequest.of(pagina, tamano, Sort.by("fecha").descending()));
        }
        contabilidadService.enriquecer(ventasPage.getContent(), accesoContable);

        // Totales calculados en la base de datos: "Todo" siempre suma todo el historial
        ContabilidadService.ResumenContable periodo =
                contabilidadService.calcularResumen(fechaDesde, fechaHasta, metodoPago, factura, vendedores);
        ContabilidadService.ResumenContable hoy = contabilidadService.calcularResumenHoy(vendedores);

        model.addAttribute("accesoContable", accesoContable);
        model.addAttribute("ventas", ventasPage.getContent());
        model.addAttribute("currentPage", pagina);
        model.addAttribute("totalPages", ventasPage.getTotalPages());
        model.addAttribute("totalItems", ventasPage.getTotalElements());
        model.addAttribute("pageSize", tamano);
        model.addAttribute("ventasDelDia", hoy.getVentas());
        model.addAttribute("gananciaDelDia", hoy.getGanancia());
        model.addAttribute("cantidadVentasDelDia", hoy.getFacturas());
        model.addAttribute("unidadesVendidasHoy", hoy.getUnidades());
        model.addAttribute("ventasPeriodoTotal", periodo.getVentas());
        model.addAttribute("costoPeriodoTotal", periodo.getCosto());
        model.addAttribute("gananciaPeriodoTotal", periodo.getGanancia());
        model.addAttribute("unidadesPeriodoTotal", periodo.getUnidades());
        model.addAttribute("margenPeriodoPorcentaje", periodo.getMargenPorcentaje());
        model.addAttribute("resumenProductosContable", periodo.getProductos());
        model.addAttribute("fechaDesde", fechaDesde);
        model.addAttribute("fechaHasta", fechaHasta);
        model.addAttribute("metodoPago", metodoPago);
        model.addAttribute("factura", factura);
        model.addAttribute("vendedor", vendedor);

        return "ventas";
    }

    @GetMapping("/exportar")
    public Object exportarExcel(
            @RequestParam(required = false) String fechaDesde,
            @RequestParam(required = false) String fechaHasta,
            @RequestParam(required = false) String metodoPago,
            @RequestParam(required = false) String factura,
            @RequestParam(required = false) String vendedor,
            RedirectAttributes redirectAttributes,
            java.security.Principal principal) throws IOException {

        if (fechaDesde == null || fechaDesde.trim().isEmpty() || fechaHasta == null || fechaHasta.trim().isEmpty()) {
            redirectAttributes.addFlashAttribute("error", "Los parámetros de fecha (Desde / Hasta) son obligatorios para exportar.");
            if (fechaDesde != null) redirectAttributes.addAttribute("fechaDesde", fechaDesde);
            if (fechaHasta != null) redirectAttributes.addAttribute("fechaHasta", fechaHasta);
            if (metodoPago != null) redirectAttributes.addAttribute("metodoPago", metodoPago);
            if (factura != null) redirectAttributes.addAttribute("factura", factura);
            if (vendedor != null) redirectAttributes.addAttribute("vendedor", vendedor);
            return "redirect:/ventas";
        }

        java.time.LocalDate desde;
        java.time.LocalDate hasta;
        try {
            desde = java.time.LocalDate.parse(fechaDesde.trim());
            hasta = java.time.LocalDate.parse(fechaHasta.trim());
        } catch (java.time.format.DateTimeParseException e) {
            redirectAttributes.addFlashAttribute("error", "El formato de las fechas no es válido. Use el selector de fechas.");
            redirectAttributes.addAttribute("fechaDesde", fechaDesde);
            redirectAttributes.addAttribute("fechaHasta", fechaHasta);
            if (metodoPago != null) redirectAttributes.addAttribute("metodoPago", metodoPago);
            if (factura != null) redirectAttributes.addAttribute("factura", factura);
            if (vendedor != null) redirectAttributes.addAttribute("vendedor", vendedor);
            return "redirect:/ventas";
        }

        if (desde.isAfter(hasta)) {
            redirectAttributes.addFlashAttribute("error", "La fecha de inicio (Desde) no puede ser posterior a la fecha de fin (Hasta).");
            redirectAttributes.addAttribute("fechaDesde", fechaDesde);
            redirectAttributes.addAttribute("fechaHasta", fechaHasta);
            if (metodoPago != null) redirectAttributes.addAttribute("metodoPago", metodoPago);
            if (factura != null) redirectAttributes.addAttribute("factura", factura);
            if (vendedor != null) redirectAttributes.addAttribute("vendedor", vendedor);
            return "redirect:/ventas";
        }

        if (java.time.temporal.ChronoUnit.MONTHS.between(desde, hasta) > 6 || (java.time.temporal.ChronoUnit.MONTHS.between(desde, hasta) == 6 && desde.plusMonths(6).isBefore(hasta))) {
            redirectAttributes.addFlashAttribute("error", "El rango de fechas no puede ser superior a 6 meses para proteger el rendimiento del sistema.");
            redirectAttributes.addAttribute("fechaDesde", fechaDesde);
            redirectAttributes.addAttribute("fechaHasta", fechaHasta);
            if (metodoPago != null) redirectAttributes.addAttribute("metodoPago", metodoPago);
            if (factura != null) redirectAttributes.addAttribute("factura", factura);
            if (vendedor != null) redirectAttributes.addAttribute("vendedor", vendedor);
            return "redirect:/ventas";
        }

        com.admin.adminlfarma_mini.entity.Usuario logueado = principal != null
                ? usuarioService.buscarPorUsername(principal.getName()).orElse(null) : null;
        List<String> allowedVendedores = contabilidadService.resolverVendedoresPermitidos(
                logueado != null ? logueado.getRol() : null,
                principal != null ? principal.getName() : null,
                vendedor);
        List<Factura> facturas = facturaService.exportarFacturas(fechaDesde, fechaHasta, metodoPago, factura, allowedVendedores);
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

        try (SXSSFWorkbook wb = new SXSSFWorkbook(100); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Sheet sheet = wb.createSheet("Ventas");

            // Estilo de encabezado: verde oscuro con texto blanco
            CellStyle headerStyle = wb.createCellStyle();
            Font headerFont = wb.createFont();
            headerFont.setBold(true);
            headerFont.setColor(IndexedColors.WHITE.getIndex());
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.DARK_GREEN.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            // Encabezados
            Row header = sheet.createRow(0);
            String[] cols = {"Factura", "Fecha", "Cliente", "Subtotal", "IVA", "Total", "Método de Pago", "Observaciones", "Vendedor"};
            for (int i = 0; i < cols.length; i++) {
                Cell cell = header.createCell(i);
                cell.setCellValue(cols[i]);
                cell.setCellStyle(headerStyle);
                sheet.setColumnWidth(i, 5000);
            }

            // Datos
            int rowNum = 1;
            for (Factura f : facturas) {
                Row row = sheet.createRow(rowNum++);
                row.createCell(0).setCellValue(f.getNumeroFactura() != null ? f.getNumeroFactura() : "");
                row.createCell(1).setCellValue(f.getFecha() != null ? f.getFecha().format(fmt) : "");
                row.createCell(2).setCellValue(f.getClienteNombre() != null ? f.getClienteNombre() : "");
                row.createCell(3).setCellValue(f.getSubtotal() != null ? f.getSubtotal() : 0.0);
                row.createCell(4).setCellValue(f.getIva() != null ? f.getIva() : 0.0);
                row.createCell(5).setCellValue(f.getTotal() != null ? f.getTotal() : 0.0);
                row.createCell(6).setCellValue(f.getMetodoPago() != null ? f.getMetodoPago() : "");
                row.createCell(7).setCellValue(f.getObservaciones() != null ? f.getObservaciones() : "");
                row.createCell(8).setCellValue(f.getVendedorEmail() != null ? f.getVendedorEmail() : "—");
            }

            wb.write(out);
            wb.dispose();

            // Nombre dinámico del archivo
            String fDesde = (fechaDesde != null && !fechaDesde.trim().isEmpty()) ? fechaDesde.trim() : "Inicio";
            String fHasta = (fechaHasta != null && !fechaHasta.trim().isEmpty()) ? fechaHasta.trim() : "Fin";
            String mPago = (metodoPago != null && !metodoPago.trim().isEmpty()) ? metodoPago.trim() : "Todos";
            String filename = String.format("Ventas_%s_%s_%s.xlsx", fDesde, fHasta, mPago);

            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                    .body(out.toByteArray());
        }
    }

    @GetMapping("/nueva")
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN', 'EMPLEADO')")
    public String nuevaVenta(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "24") int size,
            @RequestParam(required = false) String categoria,
            @RequestParam(required = false) String search,
            Model model,
            HttpServletRequest request,
            java.security.Principal principal) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("nombre").ascending());
        Page<Producto> productosPage;

        if (search != null && !search.isEmpty()) {
            if (categoria != null && !categoria.isEmpty()) {
                productosPage = productoService.getProductosParaPOSConBusquedaYCategoria(search, categoria, pageable);
            } else {
                productosPage = productoService.getProductosParaPOSConBusqueda(search, pageable);
            }
        } else {
            if (categoria != null && !categoria.isEmpty()) {
                productosPage = productoService.getProductosParaPOSPorCategoria(categoria, pageable);
            } else {
                productosPage = productoService.getProductosParaPOS(pageable);
            }
        }

        model.addAttribute("productos", productosPage.getContent());
        model.addAttribute("currentPage", page);
        model.addAttribute("totalPages", productosPage.getTotalPages());
        model.addAttribute("totalItems", productosPage.getTotalElements());
        model.addAttribute("pageSize", size);
        model.addAttribute("categoriaActual", categoria);
        model.addAttribute("search", search);
        model.addAttribute("clientes", clienteService.listarTodos());
        model.addAttribute("consumidorFinal", clienteService.getConsumidorFinal());

        List<String> categorias = productoService.obtenerCategorias();
        model.addAttribute("categorias", categorias);

        if ("XMLHttpRequest".equalsIgnoreCase(request.getHeader("X-Requested-With"))) {
            return "crear-venta :: #productosContainer";
        }

        // Cargar facturas del día e historial reciente para la sección inferior del POS
        com.admin.adminlfarma_mini.entity.Usuario logueadoPos = principal != null
                ? usuarioService.buscarPorUsername(principal.getName()).orElse(null) : null;
        List<String> vendedoresScope = contabilidadService.resolverVendedoresPermitidos(
                logueadoPos != null ? logueadoPos.getRol() : null,
                principal != null ? principal.getName() : null,
                null);

        List<Factura> facturasHoyPos = facturaService.getFacturasDelDiaPorVendedores(vendedoresScope);
        double totalVendidoHoyPos = facturasHoyPos.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
        int unidadesVendidasHoyPos = facturaService.calcularUnidadesVendidas(facturasHoyPos);

        Pageable topRecent = PageRequest.of(0, 15, Sort.by("fecha").descending());
        List<Factura> ventasRecientesPos = facturaService.buscarFacturas(
                null, null, null, null, vendedoresScope, topRecent).getContent();

        model.addAttribute("facturasHoyPos", facturasHoyPos);
        model.addAttribute("ventasRecientesPos", ventasRecientesPos);
        model.addAttribute("totalVendidoHoyPos", totalVendidoHoyPos);
        model.addAttribute("cantidadFacturasHoyPos", facturasHoyPos.size());
        model.addAttribute("unidadesVendidasHoyPos", unidadesVendidasHoyPos);

        return "crear-venta";
    }

    @PostMapping("/guardar")
    @ResponseBody
    public ResponseEntity<Map<String, Object>> guardarVenta(
            @RequestBody FacturaRequestDTO request,
            java.security.Principal principal) {
        Map<String, Object> response = new HashMap<>();
        try {
            String vendedorEmail = (principal != null) ? principal.getName() : "Consumidor Final";
            Factura factura = facturaService.crearFactura(request, vendedorEmail);
            response.put("success", true);
            response.put("message", "Venta registrada exitosamente");
            response.put("facturaId", factura.getId());
            response.put("numeroFactura", factura.getNumeroFactura());
            response.put("total", factura.getTotal());
            response.put("cliente", factura.getClienteNombre());
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}/factura")
    public String verFactura(@PathVariable String id, Model model) {
        Factura factura = facturaService.obtenerPorId(id)
                .orElseThrow(() -> new RuntimeException("Factura no encontrada"));
        model.addAttribute("factura", factura);
        model.addAttribute("config", configuracionService.getConfiguracion());
        return "factura-ticket";
    }

    @GetMapping("/{id}")
    @ResponseBody
    public ResponseEntity<Factura> obtenerFactura(@PathVariable String id) {
        return facturaService.obtenerPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}