package com.admin.adminlfarma_mini.Controller;

import com.admin.adminlfarma_mini.DTO.LoginRequestDTO;
import com.admin.adminlfarma_mini.DTO.LoginResponseDTO;
import com.admin.adminlfarma_mini.entity.Usuario;
import com.admin.adminlfarma_mini.repository.UsuarioRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*", allowedHeaders = "*")
public class AuthRestController {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;

    @PostMapping("/login")
    public ResponseEntity<LoginResponseDTO> login(@Valid @RequestBody LoginRequestDTO request) {
        log.info("Intento de login móvil para usuario: {}", request.getUsername());

        // Buscar por username o por email
        Optional<Usuario> usuarioOpt = usuarioRepository.findFirstByUsername(request.getUsername());
        if (usuarioOpt.isEmpty()) {
            usuarioOpt = usuarioRepository.findByEmail(request.getUsername());
        }

        if (usuarioOpt.isEmpty()) {
            log.warn("Login fallido: usuario {} no encontrado en MongoDB", request.getUsername());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                    LoginResponseDTO.builder()
                            .status("error")
                            .message("Credenciales inválidas: usuario no encontrado en la base de datos")
                            .build()
            );
        }

        Usuario usuario = usuarioOpt.get();

        // Verificar si la cuenta está activa
        if (usuario.getActivo() != null && !usuario.getActivo()) {
            log.warn("Login fallido: usuario {} inactivo", request.getUsername());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(
                    LoginResponseDTO.builder()
                            .status("error")
                            .message("La cuenta se encuentra inactiva")
                            .build()
            );
        }

        // Verificar contraseña con BCrypt
        if (!passwordEncoder.matches(request.getPassword(), usuario.getPassword())) {
            log.warn("Login fallido: contraseña incorrecta para {}", request.getUsername());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(
                    LoginResponseDTO.builder()
                            .status("error")
                            .message("Credenciales inválidas: contraseña incorrecta")
                            .build()
            );
        }

        log.info("Login exitoso para usuario: {} con rol: {}", usuario.getUsername(), usuario.getRol());

        LoginResponseDTO.UsuarioDTO usuarioDTO = LoginResponseDTO.UsuarioDTO.builder()
                .id(usuario.getId())
                .username(usuario.getUsername())
                .nombre(usuario.getNombre())
                .apellido(usuario.getApellido())
                .email(usuario.getEmail())
                .rol(usuario.getRol())
                .fotoPerfil(usuario.getFotoPerfil())
                .activo(usuario.getActivo())
                .build();

        return ResponseEntity.ok(
                LoginResponseDTO.builder()
                        .status("success")
                        .message("Inicio de sesión exitoso")
                        .usuario(usuarioDTO)
                        .build()
        );
    }
}
