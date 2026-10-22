package com.admin.adminlfarma_mini.repository;

import com.admin.adminlfarma_mini.entity.ConfiguracionSistema;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ConfiguracionRepository extends MongoRepository<ConfiguracionSistema, String> {
}
