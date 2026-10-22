package com.admin.adminlfarma_mini.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.index.Indexed;
import java.time.LocalDateTime;

@Document(collection = "usuarios")
public class Usuario {

    @Id
    private String id;

    @Indexed(unique = true)
    private String username;

    private String password;
    private String rol;
    private String email;
    private String telefono;
    private String nombre;
    private String apellido;
    
    @Field("email_verificado")
    private Boolean emailVerificado = false;
    
    private Boolean activo = true;
    
    @Field("fecha_creacion")
    private LocalDateTime fechaCreacion;
    
    @Field("fecha_ultimo_cambio_rol")
    private LocalDateTime fechaUltimoCambioRol;
    
    @Field("fecha_ultimo_cambio_estado")
    private LocalDateTime fechaUltimoCambioEstado;
    
    @Field("codigo_2fa")
    private String codigo2FA;
    
    @Field("codigo_expiracion")
    private LocalDateTime codigoExpiracion;
    
    @Field("codigo_verificado")
    private Boolean codigoVerificado = false;
    
    // Nueva opción para 2FA opcional, según lo solicitado
    @Field("requiere_2fa")
    private Boolean requiere2FA = false;
    
    @Field("foto_perfil")
    private String fotoPerfil;

    // Campos agregados para la unificación con Cliente
    @Indexed(unique = true, sparse = true)
    private String codigo;

    @Indexed(unique = true, sparse = true)
    private String identificacion;

    private String direccion;
    
    @Field("direccion_fisica")
    private String direccionFisica;
    
    @Field("es_consumidor_final")
    private Boolean esConsumidorFinal = false;

    public Usuario() {
        this.fechaCreacion = LocalDateTime.now();
        this.activo = true;
    }

    public Usuario(String username, String password, String rol) {
        this();
        this.username = username;
        this.password = password;
        this.rol = rol;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getUsername() { return username; }
    public void setUsername(String username) { this.username = username; }
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    public String getRol() { return rol; }
    public void setRol(String rol) { this.rol = rol; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getTelefono() { return telefono; }
    public void setTelefono(String telefono) { this.telefono = telefono; }
    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }
    public String getApellido() { return apellido; }
    public void setApellido(String apellido) { this.apellido = apellido; }
    public Boolean getEmailVerificado() { return emailVerificado; }
    public void setEmailVerificado(Boolean emailVerificado) { this.emailVerificado = emailVerificado; }
    public Boolean getActivo() { return activo; }
    public void setActivo(Boolean activo) { this.activo = activo; }
    public LocalDateTime getFechaCreacion() { return fechaCreacion; }
    public void setFechaCreacion(LocalDateTime fechaCreacion) { this.fechaCreacion = fechaCreacion; }
    public LocalDateTime getFechaUltimoCambioRol() { return fechaUltimoCambioRol; }
    public void setFechaUltimoCambioRol(LocalDateTime fechaUltimoCambioRol) { this.fechaUltimoCambioRol = fechaUltimoCambioRol; }
    public LocalDateTime getFechaUltimoCambioEstado() { return fechaUltimoCambioEstado; }
    public void setFechaUltimoCambioEstado(LocalDateTime fechaUltimoCambioEstado) { this.fechaUltimoCambioEstado = fechaUltimoCambioEstado; }
    public String getCodigo2FA() { return codigo2FA; }
    public void setCodigo2FA(String codigo2FA) { this.codigo2FA = codigo2FA; }
    public LocalDateTime getCodigoExpiracion() { return codigoExpiracion; }
    public void setCodigoExpiracion(LocalDateTime codigoExpiracion) { this.codigoExpiracion = codigoExpiracion; }
    public Boolean getCodigoVerificado() { return codigoVerificado; }
    public void setCodigoVerificado(Boolean codigoVerificado) { this.codigoVerificado = codigoVerificado; }
    public Boolean getRequiere2FA() { return requiere2FA; }
    public void setRequiere2FA(Boolean requiere2FA) { this.requiere2FA = requiere2FA; }
    public String getFotoPerfil() { return fotoPerfil; }
    public void setFotoPerfil(String fotoPerfil) { this.fotoPerfil = fotoPerfil; }
    
    // Getters y Setters de los campos de Cliente
    public String getCodigo() { return codigo; }
    public void setCodigo(String codigo) { this.codigo = codigo; }
    public String getIdentificacion() { return identificacion; }
    public void setIdentificacion(String identificacion) { this.identificacion = identificacion; }
    public String getDireccion() { return direccion; }
    public void setDireccion(String direccion) { this.direccion = direccion; }
    public String getDireccionFisica() { return direccionFisica; }
    public void setDireccionFisica(String direccionFisica) { this.direccionFisica = direccionFisica; }
    public Boolean getEsConsumidorFinal() { return esConsumidorFinal; }
    public void setEsConsumidorFinal(Boolean esConsumidorFinal) { this.esConsumidorFinal = esConsumidorFinal; }
}