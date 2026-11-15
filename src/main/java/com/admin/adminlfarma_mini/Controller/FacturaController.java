package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.DTO.FacturaRequestDTO;
import com.admin.adminlfarma_mini.entity.Factura;
import com.admin.adminlfarma_mini.entity.Producto;
import com.admin.adminlfarma_mini.service.ClienteService;
import com.admin.adminlfarma_mini.service.ConfiguracionService;
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

        Pageable pageable = PageRequest.of(page, size, Sort.by("fecha").descending());

        List<String> allowedVendedores = new java.util.ArrayList<>();
        boolean isOwner = false;
        if (principal != null) {
            String loggedUserEmail = principal.getName();
            com.admin.adminlfarma_mini.entity.Usuario loggedUser = usuarioService.buscarPorUsername(loggedUserEmail).orElse(null);
            if (loggedUser != null) {
                if ("ROLE_OWNER".equals(loggedUser.getRol())) {
                    isOwner = true;
                    if (vendedor != null && !vendedor.trim().isEmpty()) {
                        List<com.admin.adminlfarma_mini.entity.Usuario> matchedUsers = usuarioService.listarTodosIncluyendoInactivos().stream()
                            .filter(u -> (u.getNombre() != null && u.getNombre().toLowerCase().contains(vendedor.toLowerCase().trim())) ||
                                         (u.getApellido() != null && u.getApellido().toLowerCase().contains(vendedor.toLowerCase().trim())) ||
                                         (u.getUsername() != null && u.getUsername().toLowerCase().contains(vendedor.toLowerCase().trim())))
                            .toList();
                        for (com.admin.adminlfarma_mini.entity.Usuario u : matchedUsers) {
                            if (u.getUsername() != null) allowedVendedores.add(u.getUsername());
                            if (u.getEmail() != null) allowedVendedores.add(u.getEmail());
                        }
                        if (allowedVendedores.isEmpty()) {
                            allowedVendedores.add("dummy_no_match");
                        }
                    }
                } else if ("ROLE_ADMIN".equals(loggedUser.getRol())) {
                    List<com.admin.adminlfarma_mini.entity.Usuario> allUsers = usuarioService.listarTodosIncluyendoInactivos();
                    for (com.admin.adminlfarma_mini.entity.Usuario u : allUsers) {
                        if (!"ROLE_OWNER".equals(u.getRol())) {
                            if (u.getUsername() != null) allowedVendedores.add(u.getUsername());
                            if (u.getEmail() != null) allowedVendedores.add(u.getEmail());
                        }
                    }
                } else {
                    allowedVendedores.add(loggedUserEmail);
                    if (loggedUser.getEmail() != null && !loggedUser.getEmail().isBlank()) {
                        allowedVendedores.add(loggedUser.getEmail());
                    }
                }
            }
        }

        if (!isOwner && allowedVendedores.isEmpty()) {
            allowedVendedores.add("dummy_no_match");
        }

        Page<Factura> ventasPage = facturaService.buscarFacturas(fechaDesde, fechaHasta, metodoPago, factura, allowedVendedores, pageable);

        List<Factura> facturasHoyScope = facturaService.getFacturasDelDiaPorVendedores(isOwner && allowedVendedores.isEmpty() ? null : allowedVendedores);
        double ventasDelDiaScope = facturasHoyScope.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
        long cantidadVentasDelDiaScope = facturasHoyScope.size();
        int unidadesVendidasHoyScope = facturaService.calcularUnidadesVendidas(facturasHoyScope);

        model.addAttribute("ventas", ventasPage.getContent());
        model.addAttribute("currentPage", page);
        model.addAttribute("totalPages", ventasPage.getTotalPages());
        model.addAttribute("totalItems", ventasPage.getTotalElements());
        model.addAttribute("pageSize", size);
        model.addAttribute("ventasDelDia", ventasDelDiaScope);
        model.addAttribute("cantidadVentasDelDia", cantidadVentasDelDiaScope);
        model.addAttribute("unidadesVendidasHoy", unidadesVendidasHoyScope);
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

        List<String> allowedVendedores = new java.util.ArrayList<>();
        boolean isOwner = false;
        if (principal != null) {
            String loggedUserEmail = principal.getName();
            com.admin.adminlfarma_mini.entity.Usuario loggedUser = usuarioService.buscarPorUsername(loggedUserEmail).orElse(null);
            if (loggedUser != null) {
                if ("ROLE_OWNER".equals(loggedUser.getRol())) {
                    isOwner = true;
                    if (vendedor != null && !vendedor.trim().isEmpty()) {
                        List<com.admin.adminlfarma_mini.entity.Usuario> matchedUsers = usuarioService.listarTodosIncluyendoInactivos().stream()
                            .filter(u -> (u.getNombre() != null && u.getNombre().toLowerCase().contains(vendedor.toLowerCase().trim())) ||
                                         (u.getApellido() != null && u.getApellido().toLowerCase().contains(vendedor.toLowerCase().trim())) ||
                                         (u.getUsername() != null && u.getUsername().toLowerCase().contains(vendedor.toLowerCase().trim())))
                            .toList();
                        for (com.admin.adminlfarma_mini.entity.Usuario u : matchedUsers) {
                            allowedVendedores.add(u.getUsername());
                        }
                        if (allowedVendedores.isEmpty()) {
                            allowedVendedores.add("dummy_no_match");
                        }
                    }
                } else if ("ROLE_ADMIN".equals(loggedUser.getRol())) {
                    List<com.admin.adminlfarma_mini.entity.Usuario> allUsers = usuarioService.listarTodosIncluyendoInactivos();
                    for (com.admin.adminlfarma_mini.entity.Usuario u : allUsers) {
                        if (!"ROLE_OWNER".equals(u.getRol())) {
                            allowedVendedores.add(u.getUsername());
                        }
                    }
                } else {
                    allowedVendedores.add(loggedUserEmail);
                }
            }
        }

        if (!isOwner && allowedVendedores.isEmpty()) {
            allowedVendedores.add("dummy_no_match");
        }

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
        List<String> vendedoresScope = new java.util.ArrayList<>();
        boolean isOwnerPos = false;
        if (principal != null) {
            String userPrincipal = principal.getName();
            com.admin.adminlfarma_mini.entity.Usuario logged = usuarioService.buscarPorUsername(userPrincipal).orElse(null);
            if (logged != null) {
                if ("ROLE_OWNER".equals(logged.getRol())) {
                    isOwnerPos = true;
                } else if ("ROLE_ADMIN".equals(logged.getRol())) {
                    for (com.admin.adminlfarma_mini.entity.Usuario u : usuarioService.listarTodosIncluyendoInactivos()) {
                        if (!"ROLE_OWNER".equals(u.getRol())) {
                            if (u.getUsername() != null) vendedoresScope.add(u.getUsername());
                            if (u.getEmail() != null) vendedoresScope.add(u.getEmail());
                        }
                    }
                } else {
                    vendedoresScope.add(userPrincipal);
                    if (logged.getEmail() != null && !logged.getEmail().isBlank()) {
                        vendedoresScope.add(logged.getEmail());
                    }
                }
            }
        }

        List<Factura> facturasHoyPos = facturaService.getFacturasDelDiaPorVendedores(isOwnerPos ? null : vendedoresScope);
        double totalVendidoHoyPos = facturasHoyPos.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
        int unidadesVendidasHoyPos = facturaService.calcularUnidadesVendidas(facturasHoyPos);

        Pageable topRecent = PageRequest.of(0, 15, Sort.by("fecha").descending());
        List<Factura> ventasRecientesPos = facturaService.buscarFacturas(
                null, null, null, null, isOwnerPos ? null : vendedoresScope, topRecent).getContent();

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