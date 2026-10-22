package com.admin.adminlfarma_mini.DTO;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoginResponseDTO {
    private String status;
    private String message;
    private UsuarioDTO usuario;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class UsuarioDTO {
        private String id;
        private String username;
        private String nombre;
        private String apellido;
        private String email;
        private String rol;
        private String fotoPerfil;
        private Boolean activo;
    }
}
