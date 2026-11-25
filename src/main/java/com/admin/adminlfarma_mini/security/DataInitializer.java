package com.admin.adminlfarma_mini.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Inicializador de base de datos desactivado permanentemente.
 * La base de datos en MongoDB Atlas ya cuenta con los usuarios reales del
 * sistema
 * (Owner, Administradores, Empleados) y cualquier nuevo usuario se crea desde
 * la plataforma Web o Móvil.
 */
@Configuration
public class DataInitializer {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    @Bean
    @ConditionalOnProperty(name = "farmasis.database.seed.enabled", havingValue = "true", matchIfMissing = false)
    public CommandLineRunner initDatabase() {
        return args -> {
            log.info(
                    "🔒 La inicialización automática de semilla está desactivada para proteger las credenciales reales en MongoDB Atlas.");
        };
    }
}