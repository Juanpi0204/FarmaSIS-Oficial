package com.admin.adminlfarma_mini.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

        @Bean
        public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
                http
                                .cors(org.springframework.security.config.Customizer.withDefaults())
                                .csrf(csrf -> csrf
                                                .ignoringRequestMatchers("/api/chat/**", "/api/**", "/api/v1/**"))
                                .authorizeHttpRequests(auth -> auth
                                                .requestMatchers("/login", "/error", "/css/**", "/js/**", "/images/**",
                                                                "/webjars/**", "/favicon.ico",
                                                                "/api/v1/**", "/api/v1/auth/**", "/api/v1/prediccion/**", "/api/v1/productos",
                                                                "/api/chat/**")
                                                .permitAll()
                                                // Rutas protegidas estrictamente
                                                .requestMatchers("/owner/**").hasRole("OWNER")
                                                .requestMatchers("/admin/**").hasAnyRole("ADMIN", "OWNER")
                                                .requestMatchers("/empleado/**").hasRole("EMPLEADO")
                                                .requestMatchers("/configuracion/**").hasAnyRole("OWNER", "ADMIN")
                                                .requestMatchers("/api/optimizar").hasRole("OWNER")
                                                .requestMatchers("/api/optimizacion/**").hasRole("OWNER")
                                                // POS unificado: accesible por todos los roles
                                                .requestMatchers("/ventas/nueva", "/ventas/guardar").authenticated()
                                                .requestMatchers("/api/**").authenticated()
                                                .anyRequest().authenticated())
                                .headers(headers -> headers
                                                // Habilitamos protección contra caché para evitar que el botón 'Atrás' muestre datos sensibles
                                                .cacheControl(org.springframework.security.config.Customizer.withDefaults())
                                                .frameOptions(frame -> frame.sameOrigin()))
                                .formLogin(form -> form
                                                .loginPage("/login")
                                                .defaultSuccessUrl("/verificar-codigo", true)
                                                .permitAll())
                                .logout(logout -> logout
                                                .logoutUrl("/logout")
                                                .logoutSuccessUrl("/login?logout")
                                                .invalidateHttpSession(true)
                                                .clearAuthentication(true)
                                                .deleteCookies("JSESSIONID")
                                                .permitAll());

                return http.build();
        }

        @Bean
        public PasswordEncoder passwordEncoder() {
                return new BCryptPasswordEncoder();
        }

        @Bean
        public org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource() {
                org.springframework.web.cors.CorsConfiguration configuration = new org.springframework.web.cors.CorsConfiguration();
                configuration.setAllowedOriginPatterns(java.util.Collections.singletonList("*"));
                configuration.setAllowedMethods(java.util.Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
                configuration.setAllowedHeaders(java.util.Collections.singletonList("*"));
                configuration.setAllowCredentials(true);
                org.springframework.web.cors.UrlBasedCorsConfigurationSource source = new org.springframework.web.cors.UrlBasedCorsConfigurationSource();
                source.registerCorsConfiguration("/**", configuration);
                return source;
        }
}