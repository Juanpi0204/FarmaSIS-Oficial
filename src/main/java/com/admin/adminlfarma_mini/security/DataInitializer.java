package com.admin.adminlfarma_mini.security;

import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.repository.UsuarioRepository;
import com.admin.adminlfarma_mini.service.UsuarioService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class DataInitializer {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Autowired
    private UsuarioService usuarioService;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @Bean
    public CommandLineRunner initDatabase() {
        return args -> {
            // Actualizar OWNER existente o crear uno nuevo con el correo
            // juan.garces028@gmail.com
            java.util.List<Usuario> owners = usuarioRepository.findByRol("ROLE_OWNER");
            if (owners.isEmpty()) {
                log.info("👑 No se detectó ningún OWNER. Creando Superadministrador inicial...");
                usuarioService.crearOwner(
                        "juan.garces028@gmail.com", // username inicial
                        "Admin123!", // password inicial
                        "juan.garces028@gmail.com" // email inicial
                );
                log.info("✅ OWNER inicial creado: usuario='juan.garces028@gmail.com', contraseña='Admin123!'");
                log.info("⚠️ IMPORTANTE: Por favor cambie sus credenciales en el módulo de Configuración.");
            } else {
                for (Usuario owner : owners) {
                    if (!"juan.garces028@gmail.com".equalsIgnoreCase(owner.getEmail())) {
                        log.info("📧 Actualizando correo del OWNER existente a juan.garces028@gmail.com...");
                        owner.setEmail("juan.garces028@gmail.com");
                        owner.setUsername("juan.garces028@gmail.com");
                        usuarioRepository.save(owner);
                    }
                }
            }
        };
    }
}