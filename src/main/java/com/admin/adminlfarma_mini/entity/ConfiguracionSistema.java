package com.admin.adminlfarma_mini.entity;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import lombok.Data;

@Document(collection = "configuracion_sistema")
@Data
public class ConfiguracionSistema {

    @Id
    private String id;

    @Field("nombre_farmacia")
    private String nombreFarmacia = "FARMASIS";

    private String nit = "123456789-0";
    private String direccion = "Calle Principal #123";
    private String telefono = "300 000 0000";

    @Field("umbral_stock_bajo")
    private Integer umbralStockBajo = 5;

    public ConfiguracionSistema() {
    }
}
