package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.service.ProveedorService;
import com.admin.adminlfarma_mini.service.UsuarioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Arrays;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.admin.adminlfarma_mini.repository.FacturaRepository;
import com.admin.adminlfarma_mini.repository.ProductoRepository;
import com.admin.adminlfarma_mini.entity.Factura;
import com.admin.adminlfarma_mini.entity.Producto;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.stream.Collectors;
import java.text.NumberFormat;
import java.util.Locale;

@Controller
@RequestMapping("/owner")
@PreAuthorize("hasRole('OWNER')")
public class OwnerController {

    @Autowired
    private UsuarioService usuarioService;

    @Autowired
    private ProveedorService proveedorService;

    @Autowired
    private FacturaRepository facturaRepository;
    
    @Autowired
    private ProductoRepository productoRepository;

    @GetMapping("/dashboard")
    public String dashboard(Model model) {
        model.addAttribute("titulo", "Panel de Owner - Control Total");
        
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
        
        try {
            Map<String, Object> datasets = new HashMap<>();
            datasets.put("hoy", buildDatasetInfo(facturasHoy, "Hoy"));
            datasets.put("ayer", buildDatasetInfo(facturasAyer, "Ayer"));
            datasets.put("semana", buildDatasetInfo(facturasSemana, "Últimos 7 días"));
            datasets.put("mes", buildDatasetInfo(facturasMes, "Este Mes"));
            
            ObjectMapper mapper = new ObjectMapper();
            model.addAttribute("datasetsJson", mapper.writeValueAsString(datasets));
        } catch (Exception e) {
            model.addAttribute("datasetsJson", "{}");
        }
        
        List<Factura> ultimasFacturas = facturasHoy.stream()
            .filter(f -> f.getFecha() != null)
            .sorted((f1, f2) -> f2.getFecha().compareTo(f1.getFecha()))
            .limit(10)
            .collect(Collectors.toList());
            
        model.addAttribute("ultimasFacturas", ultimasFacturas);
        
        long productosCriticosCount = productoRepository.countBajoStock();
        model.addAttribute("productosCriticos", productosCriticosCount);
        
        org.springframework.data.domain.Page<Producto> topProdPage = productoRepository.findAll(
            org.springframework.data.domain.PageRequest.of(0, 4, org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "cantidad"))
        );
        model.addAttribute("topProductos", topProdPage.getContent());
        
        return "owner/dashboard";
    }
    
    private Map<String, Object> buildDatasetInfo(List<Factura> facturas, String titulo) {
        Map<String, Object> data = new HashMap<>();
        double ventas = facturas.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
        double ganancias = ventas * 0.35; 
        int tickets = facturas.size();
        double prom = tickets > 0 ? ventas / tickets : 0.0;
        
        NumberFormat fmt = NumberFormat.getCurrencyInstance(new Locale("es", "CO"));
        data.put("ventas", fmt.format(ventas));
        data.put("ganancias", fmt.format(ganancias));
        data.put("tickets", tickets + " facturas");
        data.put("ticketProm", fmt.format(prom));
        data.put("title", "Curva de Facturación - " + titulo);
        
        data.put("labels", Arrays.asList("08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00"));
        data.put("data", Arrays.asList(ventas*0.1, ventas*0.2, ventas*0.3, ventas*0.15, ventas*0.15, ventas*0.1, 0));
        
        return data;
    }

    @GetMapping({"/optimizacion-ia", "/prediccion-ia", "/prediccion"})
    public String mostrarOptimizacionIA(Model model) {
        model.addAttribute("titulo", "Predicción de Demanda e IA");
        return "owner/optimizacion-ia";
    }

    @GetMapping("/gestionar-usuarios")
    public String gestionarUsuarios(
            @RequestParam(value = "filtro", required = false) String filtro,
            Model model) {

        List<Usuario> usuarios;

        // Si no hay filtro o es vacío, mostrar TODOS los usuarios
        if (filtro == null || filtro.isEmpty()) {
            usuarios = usuarioService.listarTodosIncluyendoInactivos();
        } else if ("ACTIVOS".equals(filtro)) {
            usuarios = usuarioService.listarTodosActivos();
        } else if ("INACTIVOS".equals(filtro)) {
            usuarios = usuarioService.listarTodosIncluyendoInactivos().stream()
                    .filter(u -> !Boolean.TRUE.equals(u.getActivo()))
                    .toList();
        } else {
            // Filtrar por rol (mostrar tanto activos como inactivos del rol seleccionado)
            usuarios = usuarioService.listarTodosIncluyendoInactivos().stream()
                    .filter(u -> filtro.equals(u.getRol()))
                    .toList();
        }

        // Filtrar para que nunca se muestre al OWNER en la tabla
        usuarios = usuarios.stream()
                .filter(u -> !"ROLE_OWNER".equals(u.getRol()))
                .toList();

        long totalActivos = usuarioService.listarTodosActivos().stream()
                .filter(u -> !"ROLE_OWNER".equals(u.getRol()))
                .count();

        long totalInactivos = usuarioService.listarTodosIncluyendoInactivos().stream()
                .filter(u -> !Boolean.TRUE.equals(u.getActivo()) && !"ROLE_OWNER".equals(u.getRol()))
                .count();

        model.addAttribute("usuarios", usuarios);
        model.addAttribute("filtroActual", filtro);
        model.addAttribute("totalActivos", totalActivos);
        model.addAttribute("totalInactivos", totalInactivos);
        return "owner/gestionar-usuarios";
    }

    @Autowired
    private com.admin.adminlfarma_mini.service.EmailService emailService;

    @PostMapping("/crear-usuario")
    @ResponseBody
    public Map<String, Object> crearUsuario(@jakarta.validation.Valid @ModelAttribute com.admin.adminlfarma_mini.DTO.UsuarioRegistroDTO dto,
                                            org.springframework.validation.BindingResult result) {
        Map<String, Object> response = new HashMap<>();
        
        if (result.hasErrors()) {
            response.put("success", false);
            response.put("message", result.getAllErrors().get(0).getDefaultMessage());
            return response;
        }

        try {
            if (usuarioService.existeUsuario(dto.getUsername())) {
                response.put("success", false);
                response.put("message", "El nombre de usuario ya existe");
                return response;
            }

            Usuario nuevoUsuario = new Usuario();
            nuevoUsuario.setUsername(dto.getUsername());
            nuevoUsuario.setPassword(dto.getPassword());
            nuevoUsuario.setEmail(dto.getEmail());
            nuevoUsuario.setRol(dto.getRol());
            nuevoUsuario.setNombre(dto.getNombre());
            nuevoUsuario.setApellido(dto.getApellido());
            nuevoUsuario.setTelefono(dto.getTelefono());

            usuarioService.registrar(nuevoUsuario);
            
            // Send email asynchronously
            emailService.enviarCorreoBienvenida(dto.getEmail(), dto.getNombre() + " " + dto.getApellido(), dto.getUsername(), dto.getPassword(), dto.getRol());
            
            response.put("success", true);
            response.put("message", "Usuario creado exitosamente y correo de bienvenida enviado");
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Error al crear usuario: " + e.getMessage());
        }
        return response;
    }

    @PostMapping("/actualizar-usuario/{id}")
    @ResponseBody
    public Map<String, Object> actualizarUsuario(@PathVariable String id,
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String email,
            @RequestParam String rol) {
        Map<String, Object> response = new HashMap<>();
        try {
            Usuario usuario = usuarioService.buscarPorId(id)
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

            // No permitir modificar al OWNER
            if ("ROLE_OWNER".equals(usuario.getRol())) {
                response.put("success", false);
                response.put("message", "No se puede modificar al OWNER del sistema");
                return response;
            }

            // REGLA DE AUDITORÍA: Solo actualizar si el usuario está ACTIVO
            if (!Boolean.TRUE.equals(usuario.getActivo())) {
                response.put("success", false);
                response.put("message", "No se puede actualizar un usuario inactivo");
                return response;
            }

            // REGLA DE AUDITORÍA: Ignorar username y email enviados, mantener inmutabilidad
            String rolAnterior = usuario.getRol();
            String rolConPrefijo = rol.startsWith("ROLE_") ? rol : "ROLE_" + rol;
            usuario.setRol(rolConPrefijo);

            usuarioService.actualizar(usuario);

            // Enviar correo de notificación del cambio de rol DESPUÉS de guardar en la BD
            if (rolAnterior != null && !rolAnterior.equals(rolConPrefijo)) {
                usuarioService.enviarCorreoPorCambioRol(usuario, rolAnterior, rolConPrefijo);
            }
            response.put("success", true);
            response.put("message", "Rol actualizado exitosamente. Los datos de identidad (Username/Email) permanecen inmutables.");
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return response;
    }

    @PostMapping("/cambiar-rol/{id}")
    @ResponseBody
    public Map<String, Object> cambiarRol(@PathVariable String id, @RequestParam String nuevoRol) {
        Map<String, Object> response = new HashMap<>();
        try {
            Usuario usuarioActual = usuarioService.buscarPorId(id)
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));

            // REGLA DE AUDITORÍA: Solo permitir cambio de rol si el usuario está ACTIVO
            if (!Boolean.TRUE.equals(usuarioActual.getActivo())) {
                response.put("success", false);
                response.put("message", "No se puede cambiar el rol de un usuario inactivo");
                return response;
            }

            usuarioService.actualizarRol(id, nuevoRol);
            response.put("success", true);
            response.put("message", "Rol actualizado exitosamente");
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return response;
    }

    @PostMapping("/desactivar/{id}")
    @ResponseBody
    public Map<String, Object> desactivarUsuario(@PathVariable String id) {
        Map<String, Object> response = new HashMap<>();
        try {
            Usuario usuarioActualizado = usuarioService.desactivarUsuario(id);
            
            if (usuarioActualizado.getEmail() != null && !usuarioActualizado.getEmail().isEmpty()) {
                String nombreCompleto = (usuarioActualizado.getNombre() != null ? usuarioActualizado.getNombre() : "") + " " + (usuarioActualizado.getApellido() != null ? usuarioActualizado.getApellido() : "");
                nombreCompleto = nombreCompleto.trim();
                if (nombreCompleto.isEmpty()) {
                    nombreCompleto = usuarioActualizado.getUsername();
                }
                emailService.enviarCorreoSuspension(usuarioActualizado.getEmail(), nombreCompleto);
            }

            response.put("success", true);
            response.put("message", "Usuario desactivado exitosamente");
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return response;
    }

    @PostMapping("/activar/{id}")
    @ResponseBody
    public Map<String, Object> activarUsuario(@PathVariable String id) {
        Map<String, Object> response = new HashMap<>();
        try {
            Usuario usuarioActualizado = usuarioService.activarUsuario(id);

            if (usuarioActualizado.getEmail() != null && !usuarioActualizado.getEmail().isEmpty()) {
                String nombreCompleto = (usuarioActualizado.getNombre() != null ? usuarioActualizado.getNombre() : "") + " " + (usuarioActualizado.getApellido() != null ? usuarioActualizado.getApellido() : "");
                nombreCompleto = nombreCompleto.trim();
                if (nombreCompleto.isEmpty()) {
                    nombreCompleto = usuarioActualizado.getUsername();
                }
                emailService.enviarCorreoReactivacion(usuarioActualizado.getEmail(), nombreCompleto);
            }

            response.put("success", true);
            response.put("message", "Usuario activado exitosamente");
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return response;
    }

    @GetMapping("/usuario/{id}")
    @ResponseBody
    public Map<String, Object> obtenerUsuario(@PathVariable String id) {
        Map<String, Object> response = new HashMap<>();
        try {
            Usuario usuario = usuarioService.buscarPorId(id)
                    .orElseThrow(() -> new RuntimeException("Usuario no encontrado"));
            response.put("success", true);
            response.put("id", usuario.getId());
            response.put("username", usuario.getUsername());
            response.put("email", usuario.getEmail());
            response.put("telefono", usuario.getTelefono());
            response.put("rol", usuario.getRol().replace("ROLE_", ""));
            response.put("activo", usuario.getActivo());
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", e.getMessage());
        }
        return response;
    }
}