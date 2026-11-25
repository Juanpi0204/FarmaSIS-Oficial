package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.DTO.FacturaRequestDTO;
import com.admin.adminlfarma_mini.entity.*;
import com.admin.adminlfarma_mini.repository.FacturaRepository;
import com.admin.adminlfarma_mini.repository.ProductoRepository;
import com.admin.adminlfarma_mini.service.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Controlador REST unificado para la aplicación móvil Flutter (FarmaSIS).
 * Expone todos los micro-dominios del sistema (Dashboard BI, POS/Facturación,
 * Inventario/Productos, Proveedores, Gestión de Usuarios, Optimización Timefold,
 * Configuración y Chatbot IA) respetando los roles OWNER, ADMIN y EMPLEADO.
 */
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*", allowedHeaders = "*")
public class MobileFullRestController {

    private final ProductoService productoService;
    private final ProductoRepository productoRepository;
    private final ProveedorService proveedorService;
    private final FacturaService facturaService;
    private final FacturaRepository facturaRepository;
    private final ClienteService clienteService;
    private final UsuarioService usuarioService;
    private final ConfiguracionService configuracionService;
    private final OptimizacionService optimizacionService;
    private final ChatbotService chatbotService;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;
    private final ContabilidadService contabilidadService;

    // =========================================================================
    // 1. DASHBOARD EJECUTIVO Y KPIs (OWNER / ADMIN / EMPLEADO)
    // =========================================================================
    @GetMapping("/dashboard/resumen")
    public ResponseEntity<Map<String, Object>> obtenerResumenDashboard(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String rol) {

        Map<String, Object> res = new LinkedHashMap<>();

        LocalDateTime inicioHoy = LocalDate.now().atStartOfDay();
        LocalDateTime finHoy = LocalDate.now().atTime(LocalTime.MAX);
        LocalDateTime inicioAyer = LocalDate.now().minusDays(1).atStartOfDay();
        LocalDateTime finAyer = LocalDate.now().minusDays(1).atTime(LocalTime.MAX);
        LocalDateTime inicioSemana = LocalDate.now().minusDays(7).atStartOfDay();
        LocalDateTime inicioMes = LocalDate.now().withDayOfMonth(1).atStartOfDay();

        List<Factura> facturasHoy = facturaRepository.findByFechaBetween(inicioHoy, finHoy);
        List<Factura> facturasAyer = facturaRepository.findByFechaBetween(inicioAyer, finAyer);
        List<Factura> facturasSemana = facturaRepository.findByFechaBetween(inicioSemana, finHoy);
        List<Factura> facturasMes = facturaRepository.findByFechaBetween(inicioMes, finHoy);

        Map<String, Object> periodos = new LinkedHashMap<>();
        periodos.put("HOY", buildMetricasPeriodo(facturasHoy, "Hoy"));
        periodos.put("AYER", buildMetricasPeriodo(facturasAyer, "Ayer"));
        periodos.put("SEMANA", buildMetricasPeriodo(facturasSemana, "Últimos 7 días"));
        periodos.put("MES", buildMetricasPeriodo(facturasMes, "Este Mes"));

        res.put("status", "OK");
        res.put("periodos", periodos);
        res.put("totalProductos", productoService.contarProductos());
        res.put("productosCriticos", productoRepository.countBajoStock());
        res.put("totalProveedores", proveedorService.contarProveedores());
        res.put("usuariosActivos", usuarioService.contarActivos());
        res.put("usuariosInactivos", usuarioService.contarInactivos());
        res.put("ventasDelDia", facturaService.getVentasDelDia());
        res.put("cantidadVentasDelDia", facturaService.getCantidadVentasDelDia());

        List<Factura> ultimasFacturas = facturaRepository.findAll(
                PageRequest.of(0, 10, Sort.by(Sort.Direction.DESC, "fecha"))
        ).getContent();
        res.put("ultimasFacturas", ultimasFacturas);

        List<Producto> productosBajoStock = productoService.getProductosBajoStock()
                .stream().limit(10).collect(Collectors.toList());
        res.put("listaBajoStock", productosBajoStock);

        res.put("configuracion", configuracionService.getConfiguracion());
        return ResponseEntity.ok(res);
    }

    private Map<String, Object> buildMetricasPeriodo(List<Factura> facturas, String label) {
        double ventas = facturas.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
        double ganancias = Math.round(ventas * 0.35 * 100.0) / 100.0;
        int tickets = facturas.size();
        double ticketProm = tickets > 0 ? Math.round((ventas / tickets) * 100.0) / 100.0 : 0.0;

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("titulo", label);
        m.put("ventas", Math.round(ventas * 100.0) / 100.0);
        m.put("ganancias", ganancias);
        m.put("tickets", tickets);
        m.put("ticketPromedio", ticketProm);
        return m;
    }

    // =========================================================================
    // 2. MÓDULO DE INVENTARIO / PRODUCTOS (CRUD + DESCUENTOS + ARCHIVADOS)
    // =========================================================================
    @GetMapping("/inventario")
    public ResponseEntity<Map<String, Object>> listarInventario(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String categoria,
            @RequestParam(required = false) Boolean stockBajo,
            @RequestParam(required = false) Boolean enOferta,
            @RequestParam(defaultValue = "false") boolean archivados) {

        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.ASC, "codigo"));
        Page<Producto> productosPage;
        if (archivados) {
            productosPage = productoService.buscarProductosInactivos(search, pageable);
        } else {
            productosPage = productoService.buscarProductos(search, categoria, stockBajo, enOferta, pageable);
        }

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("productos", productosPage.getContent());
        res.put("currentPage", page);
        res.put("totalPages", productosPage.getTotalPages());
        res.put("totalItems", productosPage.getTotalElements());
        res.put("stockBajoCount", productoService.getProductosBajoStock().size());
        res.put("categorias", productoService.obtenerCategorias());
        res.put("proveedores", proveedorService.listarTodos());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/inventario")
    public ResponseEntity<Map<String, Object>> crearProducto(@RequestBody Producto producto) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            if (producto.getId() != null && producto.getId().trim().isEmpty()) {
                producto.setId(null);
            }
            if (producto.getCodigo() == null || producto.getCodigo().trim().isEmpty()) {
                res.put("success", false);
                res.put("message", "El código del producto es requerido (4 dígitos)");
                return ResponseEntity.badRequest().body(res);
            }
            if (producto.getNombre() == null || producto.getNombre().trim().isEmpty()) {
                res.put("success", false);
                res.put("message", "El nombre del producto es requerido");
                return ResponseEntity.badRequest().body(res);
            }
            if (producto.getPrecio() == null || producto.getPrecio() <= 0) {
                res.put("success", false);
                res.put("message", "El precio debe ser mayor a 0");
                return ResponseEntity.badRequest().body(res);
            }
            String codigoFormateado = producto.getCodigo().trim();
            try {
                codigoFormateado = String.format("%04d", Integer.parseInt(codigoFormateado));
                producto.setCodigo(codigoFormateado);
            } catch (NumberFormatException ignored) {
            }
            if (producto.getId() == null && productoService.existeCodigo(producto.getCodigo())) {
                res.put("success", false);
                res.put("message", "Ya existe un producto registrado con el código " + producto.getCodigo());
                return ResponseEntity.badRequest().body(res);
            }
            if (producto.getFechaIngreso() == null) {
                producto.setFechaIngreso(LocalDate.now());
            }
            Producto guardado = productoService.guardar(producto);
            res.put("success", true);
            res.put("message", "Producto guardado correctamente");
            res.put("producto", guardado);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PutMapping("/inventario/{id}")
    public ResponseEntity<Map<String, Object>> actualizarProducto(
            @PathVariable String id,
            @RequestBody Producto producto) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            productoService.obtenerPorId(id).ifPresent(pExistente -> {
                if (producto.getImagenUrl() == null || producto.getImagenUrl().isEmpty()) {
                    producto.setImagenUrl(pExistente.getImagenUrl());
                }
                if (producto.getFechaIngreso() == null) {
                    producto.setFechaIngreso(pExistente.getFechaIngreso());
                }
            });
            Producto actualizado = productoService.actualizar(id, producto);
            res.put("success", true);
            res.put("message", "Producto actualizado correctamente");
            res.put("producto", actualizado);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/inventario/{id}/archivar")
    public ResponseEntity<Map<String, Object>> archivarProducto(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            productoService.eliminar(id);
            res.put("success", true);
            res.put("message", "Producto archivado correctamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/inventario/{id}/restaurar")
    public ResponseEntity<Map<String, Object>> restaurarProducto(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            productoService.restaurar(id);
            res.put("success", true);
            res.put("message", "Producto restaurado correctamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/inventario/{id}/descuento")
    public ResponseEntity<Map<String, Object>> aplicarDescuentoProducto(
            @PathVariable String id,
            @RequestParam Double porcentaje) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            Optional<Producto> opt = productoService.obtenerPorId(id);
            if (opt.isEmpty()) {
                res.put("success", false);
                res.put("message", "Producto no encontrado");
                return ResponseEntity.badRequest().body(res);
            }
            Producto p = opt.get();
            if (p.getPrecioOriginal() == null) {
                p.setPrecioOriginal(p.getPrecio());
            }
            double nuevoPrecio = p.getPrecioOriginal() * (1.0 - (porcentaje / 100.0));
            nuevoPrecio = Math.round(nuevoPrecio * 100.0) / 100.0;
            p.setPrecio(nuevoPrecio);
            productoService.actualizar(id, p);
            res.put("success", true);
            res.put("nuevoPrecio", nuevoPrecio);
            res.put("message", "Descuento del " + porcentaje + "% aplicado");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/inventario/{id}/revertir-descuento")
    public ResponseEntity<Map<String, Object>> revertirDescuentoProducto(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            Optional<Producto> opt = productoService.obtenerPorId(id);
            if (opt.isEmpty()) {
                res.put("success", false);
                res.put("message", "Producto no encontrado");
                return ResponseEntity.badRequest().body(res);
            }
            Producto p = opt.get();
            if (p.getPrecioOriginal() != null) {
                p.setPrecio(p.getPrecioOriginal());
                p.setPrecioOriginal(null);
                productoService.actualizar(id, p);
            }
            res.put("success", true);
            res.put("message", "Precio original restaurado");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    // =========================================================================
    // 3. MÓDULO DE PUNTO DE VENTA (POS) Y FACTURACIÓN
    // =========================================================================
    @GetMapping("/ventas")
    public ResponseEntity<Map<String, Object>> listarVentas(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size,
            @RequestParam(required = false) String fechaDesde,
            @RequestParam(required = false) String fechaHasta,
            @RequestParam(required = false) String metodoPago,
            @RequestParam(required = false) String factura,
            @RequestParam(required = false) String vendedor,
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String rol) {

        // Dueño y administrador ven todo + contabilidad; el empleado solo sus ventas y sin ganancias
        boolean accesoContable = ContabilidadService.tieneAccesoContable(rol);
        List<String> vendedores = contabilidadService.resolverVendedoresPermitidos(rol, username, vendedor);

        int tamano = Math.min(Math.max(size, 5), 100);
        int pagina = Math.max(page, 0);
        Page<Factura> ventasPage = facturaService.buscarFacturas(
                fechaDesde, fechaHasta, metodoPago, factura, vendedores,
                PageRequest.of(pagina, tamano, Sort.by("fecha").descending()));

        // Si piden una página que ya no existe (p. ej. cambió el filtro), se devuelve la última
        if (ventasPage.getTotalPages() > 0 && pagina >= ventasPage.getTotalPages()) {
            pagina = ventasPage.getTotalPages() - 1;
            ventasPage = facturaService.buscarFacturas(
                    fechaDesde, fechaHasta, metodoPago, factura, vendedores,
                    PageRequest.of(pagina, tamano, Sort.by("fecha").descending()));
        }
        contabilidadService.enriquecer(ventasPage.getContent(), accesoContable);

        // Totales calculados en la base de datos: sin filtro de fechas suma TODO el historial
        ContabilidadService.ResumenContable periodo =
                contabilidadService.calcularResumen(fechaDesde, fechaHasta, metodoPago, factura, vendedores);
        ContabilidadService.ResumenContable hoy = contabilidadService.calcularResumenHoy(vendedores);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("ventas", ventasPage.getContent());
        res.put("currentPage", pagina);
        res.put("totalPages", ventasPage.getTotalPages());
        res.put("totalItems", ventasPage.getTotalElements());
        res.put("pageSize", tamano);
        res.put("ventasDelDia", hoy.getVentas());
        res.put("cantidadVentasDelDia", hoy.getFacturas());
        res.put("ventasPeriodoTotal", periodo.getVentas());
        res.put("facturasPeriodoTotal", periodo.getFacturas());
        res.put("unidadesPeriodoTotal", periodo.getUnidades());
        if (accesoContable) {
            res.put("gananciaDelDia", hoy.getGanancia());
            res.put("costoPeriodoTotal", periodo.getCosto());
            res.put("gananciaPeriodoTotal", periodo.getGanancia());
            res.put("margenPeriodoPorcentaje", periodo.getMargenPorcentaje());
            res.put("resumenProductosContable", periodo.getProductos());
        }
        res.put("configuracion", configuracionService.getConfiguracion());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/ventas")
    public ResponseEntity<Map<String, Object>> crearVenta(
            @RequestBody FacturaRequestDTO request,
            @RequestParam(required = false) String vendedorEmail) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            String vendedor = (vendedorEmail != null && !vendedorEmail.isBlank())
                    ? vendedorEmail.trim()
                    : "admin@farmasis.com";
            request.setOrigenVenta("APP MÓVIL");
            Factura factura = facturaService.crearFactura(request, vendedor);
            res.put("success", true);
            res.put("message", "Venta móvil registrada exitosamente");
            res.put("factura", factura);
            res.put("configuracion", configuracionService.getConfiguracion());
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @GetMapping("/ventas/clientes")
    public ResponseEntity<Map<String, Object>> listarClientesPOS() {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("consumidorFinal", clienteService.getConsumidorFinal());
        res.put("clientes", clienteService.listarTodos());
        return ResponseEntity.ok(res);
    }

    // =========================================================================
    // 4. MÓDULO DE PROVEEDORES
    // =========================================================================
    @GetMapping("/proveedores")
    public ResponseEntity<Map<String, Object>> listarProveedores(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size,
            @RequestParam(required = false) String search,
            @RequestParam(defaultValue = "ACTIVOS") String estado,
            @RequestParam(required = false) String categoria) {

        Pageable pageable = PageRequest.of(page, size, Sort.by("nombre").ascending());
        Page<Proveedor> proveedoresPage = proveedorService.listarProveedores(search, estado, categoria, pageable);

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("proveedores", proveedoresPage.getContent());
        res.put("totalItems", proveedoresPage.getTotalElements());
        res.put("categorias", proveedorService.obtenerCategorias());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/proveedores")
    public ResponseEntity<Map<String, Object>> crearProveedor(
            @RequestBody Proveedor proveedor,
            @RequestParam(required = false) String creadoPor) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            String autor = (creadoPor != null && !creadoPor.isBlank()) ? creadoPor : "admin";
            Proveedor guardado = proveedorService.crearProveedor(proveedor, autor);
            try {
                if (guardado.getEmail() != null && !guardado.getEmail().isBlank()) {
                    emailService.enviarCorreoBienvenidaProveedor(
                            guardado.getEmail(), guardado.getNombre(), guardado.getEmpresa());
                }
            } catch (Exception ignored) {
            }
            res.put("success", true);
            res.put("message", "Proveedor creado exitosamente");
            res.put("proveedor", guardado);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PutMapping("/proveedores/{id}")
    public ResponseEntity<Map<String, Object>> actualizarProveedor(
            @PathVariable String id,
            @RequestBody Proveedor proveedor) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            Proveedor actualizado = proveedorService.actualizarProveedor(id, proveedor);
            res.put("success", true);
            res.put("message", "Proveedor actualizado exitosamente");
            res.put("proveedor", actualizado);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/proveedores/{id}/desactivar")
    public ResponseEntity<Map<String, Object>> desactivarProveedor(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            proveedorService.desactivarProveedor(id);
            res.put("success", true);
            res.put("message", "Proveedor archivado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/proveedores/{id}/reactivar")
    public ResponseEntity<Map<String, Object>> reactivarProveedor(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            proveedorService.reactivarProveedor(id);
            res.put("success", true);
            res.put("message", "Proveedor reactivado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    // =========================================================================
    // 5. MÓDULO DE GESTIÓN DE USUARIOS / EMPLEADOS (OWNER)
    // =========================================================================
    @GetMapping("/usuarios")
    public ResponseEntity<Map<String, Object>> listarUsuarios(
            @RequestParam(required = false) String filtro) {

        List<Usuario> usuarios;
        if (filtro == null || filtro.isEmpty() || "TODOS".equalsIgnoreCase(filtro)) {
            usuarios = usuarioService.listarTodosIncluyendoInactivos();
        } else if ("ACTIVOS".equalsIgnoreCase(filtro)) {
            usuarios = usuarioService.listarTodosActivos();
        } else if ("INACTIVOS".equalsIgnoreCase(filtro)) {
            usuarios = usuarioService.listarTodosIncluyendoInactivos().stream()
                    .filter(u -> !Boolean.TRUE.equals(u.getActivo()))
                    .toList();
        } else {
            String rolTarget = filtro.startsWith("ROLE_") ? filtro : "ROLE_" + filtro;
            usuarios = usuarioService.listarTodosIncluyendoInactivos().stream()
                    .filter(u -> rolTarget.equalsIgnoreCase(u.getRol()) || filtro.equalsIgnoreCase(u.getRol()))
                    .toList();
        }

        // Igual que en OwnerController: excluir al OWNER y al Consumidor Final
        List<Map<String, Object>> listaPersonal = usuarios.stream()
                .filter(u -> !"ROLE_OWNER".equalsIgnoreCase(u.getRol()) &&
                        !Boolean.TRUE.equals(u.getEsConsumidorFinal()))
                .map(u -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", u.getId());
                    m.put("username", u.getUsername());
                    m.put("nombre", u.getNombre() != null ? u.getNombre() : "");
                    m.put("apellido", u.getApellido() != null ? u.getApellido() : "");
                    m.put("email", u.getEmail() != null ? u.getEmail() : "");
                    m.put("telefono", u.getTelefono() != null ? u.getTelefono() : "");
                    m.put("rol", u.getRol() != null ? u.getRol().replace("ROLE_", "") : "EMPLEADO");
                    m.put("activo", Boolean.TRUE.equals(u.getActivo()));
                    m.put("fechaCreacion", u.getFechaCreacion() != null ? u.getFechaCreacion().toString() : null);
                    return m;
                })
                .toList();

        long totalActivos = listaPersonal.stream().filter(u -> Boolean.TRUE.equals(u.get("activo"))).count();
        long totalInactivos = listaPersonal.size() - totalActivos;

        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("usuarios", listaPersonal);
        res.put("totalActivos", totalActivos);
        res.put("totalInactivos", totalInactivos);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/usuarios")
    public ResponseEntity<Map<String, Object>> crearUsuario(@RequestBody Map<String, String> body) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            String username = body.getOrDefault("username", "").trim();
            String email = body.getOrDefault("email", username).trim();
            if (username.isEmpty()) {
                username = email;
            }
            String password = body.getOrDefault("password", "").trim();
            String nombre = body.getOrDefault("nombre", "").trim();
            String apellido = body.getOrDefault("apellido", "").trim();
            String telefono = body.getOrDefault("telefono", "").trim();
            String rol = body.getOrDefault("rol", "ROLE_EMPLEADO").trim();

            if (usuarioService.existeUsuario(username)) {
                res.put("success", false);
                res.put("message", "El nombre de usuario o correo ya está registrado");
                return ResponseEntity.badRequest().body(res);
            }

            Usuario nuevo = new Usuario();
            nuevo.setUsername(username);
            nuevo.setEmail(email);
            nuevo.setPassword(password);
            nuevo.setNombre(nombre);
            nuevo.setApellido(apellido);
            nuevo.setTelefono(telefono);
            nuevo.setRol(rol.startsWith("ROLE_") ? rol : "ROLE_" + rol);

            Usuario guardado = usuarioService.registrar(nuevo);
            try {
                emailService.enviarCorreoBienvenida(email, (nombre + " " + apellido).trim(), username, password, nuevo.getRol());
            } catch (Exception ignored) {
            }

            res.put("success", true);
            res.put("message", "Usuario creado exitosamente");
            res.put("id", guardado.getId());
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/usuarios/{id}/rol")
    public ResponseEntity<Map<String, Object>> cambiarRolUsuario(
            @PathVariable String id,
            @RequestParam String nuevoRol) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            usuarioService.actualizarRol(id, nuevoRol);
            res.put("success", true);
            res.put("message", "Rol actualizado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/usuarios/{id}/desactivar")
    public ResponseEntity<Map<String, Object>> desactivarUsuario(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            Usuario u = usuarioService.desactivarUsuario(id);
            try {
                if (u.getEmail() != null && !u.getEmail().isBlank()) {
                    String nombre = ((u.getNombre() != null ? u.getNombre() : "") + " " +
                            (u.getApellido() != null ? u.getApellido() : "")).trim();
                    emailService.enviarCorreoSuspension(u.getEmail(), nombre.isEmpty() ? u.getUsername() : nombre);
                }
            } catch (Exception ignored) {
            }
            res.put("success", true);
            res.put("message", "Usuario desactivado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/usuarios/{id}/activar")
    public ResponseEntity<Map<String, Object>> activarUsuario(@PathVariable String id) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            Usuario u = usuarioService.activarUsuario(id);
            try {
                if (u.getEmail() != null && !u.getEmail().isBlank()) {
                    String nombre = ((u.getNombre() != null ? u.getNombre() : "") + " " +
                            (u.getApellido() != null ? u.getApellido() : "")).trim();
                    emailService.enviarCorreoReactivacion(u.getEmail(), nombre.isEmpty() ? u.getUsername() : nombre);
                }
            } catch (Exception ignored) {
            }
            res.put("success", true);
            res.put("message", "Usuario activado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    // =========================================================================
    // 6. MÓDULO DE OPTIMIZACIÓN IA CON TIMEFOLD SOLVER (OWNER)
    // =========================================================================
    @GetMapping("/optimizacion/ultimo")
    public ResponseEntity<Map<String, Object>> obtenerUltimaOptimizacion() {
        Optional<ResultadoOptimizacion> resultado = optimizacionService.obtenerUltimoResultado();
        Map<String, Object> response = new LinkedHashMap<>();
        if (resultado.isPresent()) {
            ResultadoOptimizacion r = resultado.get();
            List<Map<String, Object>> propuestasFiltradas = r.getPropuestas().stream()
                    .filter(map -> {
                        Object cant = map.get("cantidadAPedir");
                        Object desc = map.get("descuentoProximidad");
                        int c = cant instanceof Number ? ((Number) cant).intValue() : 0;
                        double d = desc instanceof Number ? ((Number) desc).doubleValue() : 0.0;
                        return c > 0 || d > 0.0;
                    })
                    .collect(Collectors.toList());
            response.put("status", "OK");
            response.put("score", r.getScore());
            response.put("hardScore", r.getHardScore());
            response.put("softScore", r.getSoftScore());
            response.put("propuestas", propuestasFiltradas);
            response.put("resumen", r.getResumen());
            response.put("fechaCalculo", r.getFechaCalculo() != null ? r.getFechaCalculo().toString() : "");
            return ResponseEntity.ok(response);
        }
        response.put("status", "EMPTY");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/optimizacion/ejecutar")
    public ResponseEntity<Map<String, Object>> ejecutarOptimizacion() {
        Map<String, Object> response = new LinkedHashMap<>();
        try {
            PlanOptimizacion solucion = optimizacionService.optimizar();
            response.put("status", "OK");
            response.put("score", solucion.getScore() != null ? solucion.getScore().toString() : "N/A");
            response.put("hardScore", solucion.getScore() != null ? solucion.getScore().hardScore() : 0);
            response.put("softScore", solucion.getScore() != null ? solucion.getScore().softScore() : 0);

            List<Map<String, Object>> propuestasJson = solucion.getPropuestas().stream()
                    .filter(p -> p.getCantidadAPedir() != null && (p.getCantidadAPedir() > 0 || p.getDescuentoAplicable() > 0.0))
                    .map(this::mapearPropuesta)
                    .collect(Collectors.toList());
            response.put("propuestas", propuestasJson);

            Map<String, Object> resumen = calcularResumenOptimizacion(solucion.getPropuestas());
            response.put("resumen", resumen);
            response.put("fechaCalculo", LocalDateTime.now().toString());

            optimizacionService.guardarResultado(
                    response.get("score").toString(),
                    (Integer) response.get("hardScore"),
                    (Integer) response.get("softScore"),
                    propuestasJson, resumen);

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Error ejecutando optimización móvil: {}", e.getMessage());
            response.put("status", "ERROR");
            response.put("mensaje", "Error al ejecutar la optimización: " + e.getMessage());
            return ResponseEntity.internalServerError().body(response);
        }
    }

    private Map<String, Object> mapearPropuesta(PropuestaPedido p) {
        Map<String, Object> propuesta = new LinkedHashMap<>();
        propuesta.put("productoNombre", p.getNombreProducto());
        propuesta.put("productoId", p.getProducto() != null ? p.getProducto().getId() : null);
        propuesta.put("productoCodigo", p.getProducto() != null ? p.getProducto().getCodigo() : "N/A");
        propuesta.put("productoCategoria", p.getProducto() != null ? p.getProducto().getCategoria() : "Otros");
        propuesta.put("precioBase", p.getPrecioBase());
        propuesta.put("costoCompra", p.getCostoCompraProducto());
        propuesta.put("cantidadActual", p.getCantidadActual());
        propuesta.put("demandaEstimada", p.getDemandaEstimada());
        propuesta.put("cantidadAPedir", p.getCantidadAPedir());
        propuesta.put("descuentoProximidad", p.getDescuentoAplicable());
        propuesta.put("descuentoPorcentaje", String.format("%.0f%%", p.getDescuentoAplicable() * 100));
        propuesta.put("utilidadEstimada", Math.round(p.calcularUtilidad() * 100.0) / 100.0);
        propuesta.put("costoTotalPedido", Math.round(p.getCostoCompraProducto() * p.getCantidadAPedir() * 100.0) / 100.0);
        propuesta.put("stockResultante", p.getCantidadActual() + p.getCantidadAPedir());
        return propuesta;
    }

    private Map<String, Object> calcularResumenOptimizacion(List<PropuestaPedido> propuestas) {
        Map<String, Object> resumen = new LinkedHashMap<>();
        double utilidadTotal = propuestas.stream().mapToDouble(PropuestaPedido::calcularUtilidad).sum();
        double costoTotalPedidos = propuestas.stream()
                .mapToDouble(p -> p.getCostoCompraProducto() * p.getCantidadAPedir()).sum();
        double espacioTotalUsado = propuestas.stream()
                .mapToDouble(p -> p.getEspacioUnidad() * (p.getCantidadActual() + p.getCantidadAPedir())).sum();
        double horasTotalesRequeridas = propuestas.stream()
                .mapToDouble(p -> 0.1 * Math.min(p.getDemandaEstimada(), p.getCantidadActual() + p.getCantidadAPedir())).sum();
        int totalUnidadesAPedir = propuestas.stream().mapToInt(PropuestaPedido::getCantidadAPedir).sum();

        resumen.put("utilidadTotalEstimada", Math.round(utilidadTotal * 100.0) / 100.0);
        resumen.put("costoTotalPedidos", Math.round(costoTotalPedidos * 100.0) / 100.0);
        resumen.put("presupuestoMaximo", 1_500_000);
        resumen.put("presupuestoUsadoPorcentaje", String.format("%.1f%%", (costoTotalPedidos / 1_500_000) * 100));
        resumen.put("espacioTotalUsado", Math.round(espacioTotalUsado * 100.0) / 100.0);
        resumen.put("capacidadAlmacen", 5_000);
        resumen.put("horasTotalesRequeridas", Math.round(horasTotalesRequeridas * 100.0) / 100.0);
        resumen.put("horasDisponibles", 160);
        resumen.put("totalUnidadesAPedir", totalUnidadesAPedir);
        return resumen;
    }

    // =========================================================================
    // 7. MÓDULO DE CONFIGURACIÓN DEL SISTEMA Y PERFIL DE USUARIO
    // =========================================================================
    @GetMapping("/configuracion")
    public ResponseEntity<Map<String, Object>> obtenerConfiguracion(
            @RequestParam(required = false) String username) {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("status", "OK");
        res.put("sistema", configuracionService.getConfiguracion());
        if (username != null && !username.isBlank()) {
            usuarioService.buscarPorUsername(username.trim()).ifPresent(u -> {
                Map<String, Object> perfil = new LinkedHashMap<>();
                perfil.put("id", u.getId());
                perfil.put("username", u.getUsername());
                perfil.put("nombre", u.getNombre());
                perfil.put("apellido", u.getApellido());
                perfil.put("email", u.getEmail());
                perfil.put("telefono", u.getTelefono());
                perfil.put("rol", u.getRol());
                perfil.put("requiere2FA", Boolean.TRUE.equals(u.getRequiere2FA()));
                perfil.put("fotoPerfil", u.getFotoPerfil());
                res.put("perfil", perfil);
            });
        }
        return ResponseEntity.ok(res);
    }

    @PostMapping("/configuracion/sistema")
    public ResponseEntity<Map<String, Object>> guardarConfiguracionSistema(
            @RequestBody ConfiguracionSistema config) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            ConfiguracionSistema guardada = configuracionService.guardarConfiguracion(config);
            res.put("success", true);
            res.put("message", "Configuración de la farmacia actualizada correctamente");
            res.put("sistema", guardada);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    @PostMapping("/configuracion/perfil")
    public ResponseEntity<Map<String, Object>> actualizarPerfilMovil(@RequestBody Map<String, Object> body) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            String username = String.valueOf(body.getOrDefault("username", "")).trim();
            String email = String.valueOf(body.getOrDefault("email", "")).trim();
            String passwordActual = String.valueOf(body.getOrDefault("passwordActual", "")).trim();
            String nuevaPassword = String.valueOf(body.getOrDefault("nuevaPassword", "")).trim();
            Boolean requiere2FA = Boolean.TRUE.equals(body.get("requiere2FA"));

            Usuario usuario = usuarioService.buscarPorUsername(username)
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

            if ((!nuevaPassword.isEmpty()) || (!email.isEmpty() && !email.equalsIgnoreCase(usuario.getEmail()))) {
                if (passwordActual.isEmpty()) {
                    throw new RuntimeException("Debes ingresar tu contraseña actual para modificar correo o contraseña");
                }
                if (!passwordEncoder.matches(passwordActual, usuario.getPassword())) {
                    throw new RuntimeException("La contraseña actual es incorrecta");
                }
            }

            usuarioService.actualizarPerfil(
                    usuario.getId(),
                    email.isEmpty() ? usuario.getEmail() : email,
                    nuevaPassword.isEmpty() ? null : nuevaPassword,
                    usuario.getFotoPerfil(),
                    requiere2FA);

            res.put("success", true);
            res.put("message", "Perfil actualizado exitosamente");
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("success", false);
            res.put("message", e.getMessage());
            return ResponseEntity.badRequest().body(res);
        }
    }

    // =========================================================================
    // 8. MÓDULO CHATBOT IA FARMACÉUTICO CON CONCIENCIA DE ROL
    // =========================================================================
    @PostMapping("/chat/ask")
    public ResponseEntity<Map<String, Object>> askChatbot(@RequestBody Map<String, String> body) {
        Map<String, Object> res = new LinkedHashMap<>();
        try {
            String chatId = body.getOrDefault("chatId", "mobile-session");
            String message = body.getOrDefault("message", "");
            String rolRaw = body.getOrDefault("rol", "EMPLEADO").toUpperCase();
            String userRole = "EMPLEADO";
            if (rolRaw.contains("OWNER")) {
                userRole = "OWNER";
            } else if (rolRaw.contains("ADMIN")) {
                userRole = "ADMIN";
            }
            String reply = chatbotService.chat(chatId, message, userRole);
            res.put("status", "OK");
            res.put("reply", reply);
            return ResponseEntity.ok(res);
        } catch (Exception e) {
            res.put("status", "ERROR");
            res.put("reply", "⚠️ El asistente IA está temporalmente ocupado. Intenta nuevamente en unos segundos.");
            return ResponseEntity.ok(res);
        }
    }
}
