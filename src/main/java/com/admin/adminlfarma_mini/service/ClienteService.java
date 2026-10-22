package com.admin.adminlfarma_mini.service;

import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.repository.UsuarioRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class ClienteService {

    private final UsuarioRepository usuarioRepository;

    @PostConstruct
    public void init() {
        crearConsumidorFinalSiNoExiste();
    }

    private void crearConsumidorFinalSiNoExiste() {
        if (usuarioRepository.findFirstByEsConsumidorFinalTrue().isEmpty()) {
            Usuario consumidorFinal = new Usuario();
            consumidorFinal.setRol("ROLE_CLIENTE");
            consumidorFinal.setCodigo("CF-0001");
            consumidorFinal.setNombre("Consumidor Final");
            consumidorFinal.setIdentificacion("9999999999");
            consumidorFinal.setEsConsumidorFinal(true);
            usuarioRepository.save(consumidorFinal);
            System.out.println("✅ Cliente 'Consumidor Final' creado unificado con Usuario en MongoDB");
        }
    }

    public Usuario getConsumidorFinal() {
        return usuarioRepository.findFirstByEsConsumidorFinalTrue()
                .orElseThrow(() -> new RuntimeException("No se encontró el cliente Consumidor Final"));
    }

    public List<Usuario> listarTodos() {
        return usuarioRepository.findAllClientesOrderByNombreAsc();
    }

    public Page<Usuario> listarClientes(Pageable pageable) {
        return usuarioRepository.findAllClientes(pageable);
    }

    public Page<Usuario> buscarClientes(String search, Pageable pageable) {
        if (search == null || search.trim().isEmpty()) {
            return listarClientes(pageable);
        }
        return usuarioRepository.findClientesByNombreOrCodigo(search, search, pageable);
    }

    public Optional<Usuario> obtenerPorId(String id) {
        return usuarioRepository.findById(id);
    }

    public Optional<Usuario> obtenerPorIdentificacion(String identificacion) {
        return usuarioRepository.findByIdentificacion(identificacion);
    }

    public Optional<Usuario> obtenerPorCodigo(String codigo) {
        return usuarioRepository.findByCodigo(codigo);
    }

    public Usuario guardar(Usuario cliente) {
        if (cliente.getRol() == null) {
            cliente.setRol("ROLE_CLIENTE");
        }
        return usuarioRepository.save(cliente);
    }

    public void eliminar(String id) {
        usuarioRepository.deleteById(id);
    }
}