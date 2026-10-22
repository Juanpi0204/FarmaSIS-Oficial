package com.admin.adminlfarma_mini.repository;

import com.admin.adminlfarma_mini.entity.Usuario;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UsuarioRepository extends MongoRepository<Usuario, String> {
    
    Optional<Usuario> findByUsername(String username);
    
    Optional<Usuario> findFirstByUsername(String username);
    
    Optional<Usuario> findByEmail(String email);
    
    boolean existsByUsername(String username);
    
    boolean existsByEmail(String email);
    
    @Query(value = "{ 'rol': ?0 }", count = true)
    long countByRol(String rol);
    
    @Query(value = "{ 'activo': true }", count = true)
    long countActivos();
    
    List<Usuario> findByRol(String rol);
    
    @Query(value = "{ 'id': ?0 }", fields = "{ 'rol': 1 }")
    String findRolById(String id);
    
    List<Usuario> findByActivoTrue();
    
    List<Usuario> findByRolAndActivoTrue(String rol);
    
    @Query("{ 'rol': { $regex: ?0, $options: 'i' } }")
    List<Usuario> findUsuariosByRolContaining(String search);
    
    long countByRolNotAndActivoTrue(String rol);
    
    // Métodos para manejar Clientes unificados
    Optional<Usuario> findByCodigo(String codigo);

    Optional<Usuario> findByIdentificacion(String identificacion);

    Optional<Usuario> findFirstByEsConsumidorFinalTrue();

    boolean existsByCodigo(String codigo);

    @Query(value = "{ 'rol': 'ROLE_CLIENTE' }", sort = "{ 'nombre': 1 }")
    List<Usuario> findAllClientesOrderByNombreAsc();
    
    @Query(value = "{ 'rol': 'ROLE_CLIENTE' }")
    Page<Usuario> findAllClientes(Pageable pageable);

    @Query("{ 'rol': 'ROLE_CLIENTE', $or: [ { 'nombre': { $regex: ?0, $options: 'i' } }, { 'codigo': { $regex: ?1, $options: 'i' } } ] }")
    Page<Usuario> findClientesByNombreOrCodigo(String nombre, String codigo, Pageable pageable);
}