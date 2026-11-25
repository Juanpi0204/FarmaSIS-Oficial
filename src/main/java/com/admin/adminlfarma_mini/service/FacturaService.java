package com.admin.adminlfarma_mini.service;

import com.admin.adminlfarma_mini.DTO.FacturaRequestDTO;
import com.admin.adminlfarma_mini.entity.*;
import com.admin.adminlfarma_mini.repository.FacturaRepository;
import com.admin.adminlfarma_mini.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.support.PageableExecutionUtils;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class FacturaService {
    
    private final FacturaRepository facturaRepository;
    private final ProductoService productoService;
    private final ClienteService clienteService;
    private final UsuarioRepository usuarioRepository;
    private final MongoTemplate mongoTemplate;
    
    public Page<Factura> listarFacturas(Pageable pageable) {
        return facturaRepository.findAllByOrderByFechaDesc(pageable);
    }

    public Page<Factura> buscarFacturas(String fechaDesde, String fechaHasta,
                                         String metodoPago, String numFactura, List<String> vendedores, Pageable pageable) {
        Query query = new Query().with(pageable).with(Sort.by(Sort.Direction.DESC, "fecha"));
        List<Criteria> criterios = new ArrayList<>();

        if (fechaDesde != null && !fechaDesde.isEmpty()) {
            LocalDateTime desde = LocalDate.parse(fechaDesde).atStartOfDay();
            criterios.add(Criteria.where("fecha").gte(desde));
        }
        if (fechaHasta != null && !fechaHasta.isEmpty()) {
            LocalDateTime hasta = LocalDate.parse(fechaHasta).atTime(23, 59, 59);
            criterios.add(Criteria.where("fecha").lte(hasta));
        }
        if (metodoPago != null && !metodoPago.isEmpty()) {
            criterios.add(Criteria.where("metodoPago").is(metodoPago));
        }
        if (numFactura != null && !numFactura.isEmpty()) {
            criterios.add(Criteria.where("numeroFactura").regex(numFactura, "i"));
        }
        if (vendedores != null && !vendedores.isEmpty()) {
            criterios.add(Criteria.where("vendedorEmail").in(vendedores));
        }

        if (!criterios.isEmpty()) {
            query.addCriteria(new Criteria().andOperator(criterios.toArray(new Criteria[0])));
        }

        List<Factura> facturas = mongoTemplate.find(query, Factura.class);
        Query countQuery = Query.of(query).limit(-1).skip(-1);
        long total = mongoTemplate.count(countQuery, Factura.class);

        return PageableExecutionUtils.getPage(facturas, pageable, () -> total);
    }

    public List<Factura> exportarFacturas(String fechaDesde, String fechaHasta,
                                           String metodoPago, String numFactura, List<String> vendedores) {
        Query query = new Query().with(Sort.by(Sort.Direction.DESC, "fecha")).limit(1500);
        List<Criteria> criterios = new ArrayList<>();

        if (fechaDesde != null && !fechaDesde.isEmpty()) {
            criterios.add(Criteria.where("fecha").gte(LocalDate.parse(fechaDesde).atStartOfDay()));
        }
        if (fechaHasta != null && !fechaHasta.isEmpty()) {
            criterios.add(Criteria.where("fecha").lte(LocalDate.parse(fechaHasta).atTime(23, 59, 59)));
        }
        if (metodoPago != null && !metodoPago.isEmpty()) {
            criterios.add(Criteria.where("metodoPago").is(metodoPago));
        }
        if (numFactura != null && !numFactura.isEmpty()) {
            criterios.add(Criteria.where("numeroFactura").regex(numFactura, "i"));
        }
        if (vendedores != null && !vendedores.isEmpty()) {
            criterios.add(Criteria.where("vendedorEmail").in(vendedores));
        }
        if (!criterios.isEmpty()) {
            query.addCriteria(new Criteria().andOperator(criterios.toArray(new Criteria[0])));
        }
        List<Factura> facturas = mongoTemplate.find(query, Factura.class);
        if (facturas != null) {
            facturas.sort((f1, f2) -> {
                if (f1.getFecha() == null && f2.getFecha() == null) return 0;
                if (f1.getFecha() == null) return 1;
                if (f2.getFecha() == null) return -1;
                return f2.getFecha().compareTo(f1.getFecha());
            });
        }
        return facturas;
    }
    
    public Double getVentasDelDia() {
        LocalDateTime inicio = LocalDate.now().atStartOfDay();
        LocalDateTime fin = inicio.plusDays(1);
        List<Factura> ventas = facturaRepository.findVentasDelDia(inicio, fin);
        return ventas.stream().mapToDouble(f -> f.getTotal() != null ? f.getTotal() : 0.0).sum();
    }
    
    public Long getCantidadVentasDelDia() {
        LocalDateTime inicio = LocalDate.now().atStartOfDay();
        LocalDateTime fin = inicio.plusDays(1);
        return facturaRepository.countVentasDelDia(inicio, fin);
    }

    public List<Factura> getFacturasDelDiaPorVendedores(List<String> vendedores) {
        LocalDateTime inicio = LocalDate.now().atStartOfDay();
        LocalDateTime fin = inicio.plusDays(1);
        List<Factura> ventasHoy = facturaRepository.findVentasDelDia(inicio, fin);
        if (vendedores != null && !vendedores.isEmpty()) {
            ventasHoy = ventasHoy.stream()
                    .filter(f -> f.getVendedorEmail() != null &&
                            vendedores.stream().anyMatch(v -> v.equalsIgnoreCase(f.getVendedorEmail())))
                    .collect(java.util.stream.Collectors.toList());
        }
        ventasHoy.sort((f1, f2) -> {
            if (f1.getFecha() == null) return 1;
            if (f2.getFecha() == null) return -1;
            return f2.getFecha().compareTo(f1.getFecha());
        });
        return ventasHoy;
    }

    public int calcularUnidadesVendidas(List<Factura> facturas) {
        if (facturas == null) return 0;
        return facturas.stream()
                .filter(f -> f.getDetalles() != null)
                .flatMap(f -> f.getDetalles().stream())
                .mapToInt(d -> d.getCantidad() != null ? d.getCantidad() : 0)
                .sum();
    }
    
    public Factura crearFactura(FacturaRequestDTO request, String vendedorEmail) {
        Usuario cliente;
        String cc = request.getClienteCC();
        if (cc == null || cc.trim().isEmpty()) {
            cc = "222222222222";
        } else {
            cc = cc.trim();
        }
        
        Optional<Usuario> clienteOpt = clienteService.obtenerPorIdentificacion(cc);
        if (clienteOpt.isPresent()) {
            cliente = clienteOpt.get();
        } else {
            cliente = new Usuario();
            cliente.setRol("ROLE_CLIENTE");
            cliente.setIdentificacion(cc);
            if ("222222222222".equals(cc)) {
                cliente.setNombre("Consumidor Final");
                cliente.setEsConsumidorFinal(true);
            } else {
                cliente.setNombre("Cliente CC " + cc);
            }
            cliente.setCodigo("C-" + cc);
            cliente = clienteService.guardar(cliente);
        }
        
        Factura factura = new Factura();
        factura.setNumeroFactura(generarNumeroFactura());
        factura.setClienteId(cliente.getId());
        factura.setClienteNombre(cliente.getNombre());
        factura.setFecha(LocalDateTime.now());
        factura.setMetodoPago(request.getMetodoPago() != null ? request.getMetodoPago() : "EFECTIVO");
        factura.setObservaciones(request.getObservaciones());
        factura.setVendedorEmail(vendedorEmail);

        String origen = (request.getOrigenVenta() != null && !request.getOrigenVenta().trim().isEmpty())
                ? request.getOrigenVenta().trim()
                : "WEB";
        factura.setOrigenVenta(origen);

        String nombreVendedor = request.getVendedorNombre();
        String rolVendedor = request.getVendedorRol();
        if (vendedorEmail != null && !vendedorEmail.trim().isEmpty()) {
            Optional<Usuario> vendOpt = usuarioRepository.findFirstByUsername(vendedorEmail.trim());
            if (vendOpt.isEmpty()) {
                vendOpt = usuarioRepository.findByEmail(vendedorEmail.trim());
            }
            if (vendOpt.isPresent()) {
                Usuario v = vendOpt.get();
                factura.setVendedorEmail(v.getEmail() != null && !v.getEmail().isBlank() ? v.getEmail() : v.getUsername());
                String full = ((v.getNombre() != null ? v.getNombre() : "") + " " +
                        (v.getApellido() != null ? v.getApellido() : "")).trim();
                if (!full.isEmpty()) {
                    nombreVendedor = full;
                }
                if (v.getRol() != null && !v.getRol().isBlank()) {
                    rolVendedor = v.getRol().replace("ROLE_", "");
                }
            }
        }
        factura.setVendedorNombre(nombreVendedor != null && !nombreVendedor.isBlank() ? nombreVendedor : vendedorEmail);
        factura.setVendedorRol(rolVendedor != null && !rolVendedor.isBlank() ? rolVendedor.replace("ROLE_", "") : "EMPLEADO");
        
        double subtotal = 0.0;
        
        for (FacturaRequestDTO.DetalleDTO detalleDTO : request.getDetalles()) {
            Producto producto = productoService.obtenerPorId(detalleDTO.getProductoId())
                .orElseThrow(() -> new RuntimeException("Producto no encontrado"));
            
            if (producto.getCantidad() < detalleDTO.getCantidad()) {
                throw new RuntimeException("Stock insuficiente para: " + producto.getNombre());
            }
            
            DetalleFactura detalle = new DetalleFactura();
            detalle.setProductoId(producto.getId());
            detalle.setProductoNombre(producto.getNombre());
            detalle.setProductoCodigo(producto.getCodigo());
            detalle.setCantidad(detalleDTO.getCantidad());
            detalle.setPrecioUnitario(detalleDTO.getPrecioUnitario());
            detalle.setSubtotal(detalleDTO.getPrecioUnitario() * detalleDTO.getCantidad());
            
            factura.getDetalles().add(detalle);
            subtotal += detalle.getSubtotal();
            
            productoService.actualizarStock(producto.getId(), detalleDTO.getCantidad());
        }
        
        factura.setSubtotal(subtotal);
        factura.setIva(0.0);
        factura.setTotal(subtotal);
        
        return facturaRepository.save(factura);
    }
    
    private String generarNumeroFactura() {
        long count = facturaRepository.count() + 1;
        return String.format("FAC-%06d", count);
    }
    
    public List<Factura> listarTodasFacturas() {
        return facturaRepository.findAll();
    }

    public Optional<Factura> obtenerPorId(String id) {
        return facturaRepository.findById(id);
    }
}
