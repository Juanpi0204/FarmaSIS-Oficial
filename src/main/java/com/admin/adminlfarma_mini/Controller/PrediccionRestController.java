package com.admin.adminlfarma_mini.Controller; // Paquete de los controladores web/REST.

import com.admin.adminlfarma_mini.service.PrediccionService; // Servicio que contiene el modelo de predicción.
import lombok.RequiredArgsConstructor; // Lombok: constructor con los campos 'final'.
import lombok.extern.slf4j.Slf4j; // Lombok: habilita 'log'.
import org.springframework.http.HttpStatus; // Códigos HTTP (404...).
import org.springframework.http.ResponseEntity; // Respuesta HTTP con cuerpo y código.
import org.springframework.web.bind.annotation.*; // Anotaciones REST (@GetMapping, @RequestParam...).

import java.util.LinkedHashMap; // Mapa que conserva el orden de inserción.
import java.util.List; // Listas.
import java.util.Map; // Mapas.

/**
 * API REST del módulo de predicción. Consumida por la app móvil Flutter.
 *
 *  GET /api/v1/prediccion/ventas?productoId={codigo}&temporalidad={DIARIO|SEMANAL|MENSUAL}
 *  GET /api/v1/productos              -> productos reales para el selector de la app
 *  GET /api/v1/prediccion/explicacion -> descripción del modelo
 */
@RestController // Cada método devuelve JSON directamente (no vistas HTML).
@RequestMapping("/api/v1") // Prefijo común de todas las rutas de esta clase.
@RequiredArgsConstructor // Inyecta PrediccionService por constructor.
@Slf4j // Habilita 'log'.
@CrossOrigin(origins = "*", allowedHeaders = "*") // Permite llamadas desde la app web/emulador (CORS).
public class PrediccionRestController {

    private final PrediccionService prediccionService; // Servicio con la lógica del modelo.

    /** Predicción de ventas y riesgo de quiebre de un producto real. */
    @GetMapping("/prediccion/ventas") // GET /api/v1/prediccion/ventas
    public ResponseEntity<?> obtenerPrediccionVentas(
            @RequestParam(required = false) String productoId, // Código (4 dígitos) o id del producto.
            @RequestParam(required = false) String codigo,     // Alias alternativo de productoId.
            @RequestParam(defaultValue = "SEMANAL") String temporalidad, // DIARIO, SEMANAL o MENSUAL.
            @RequestParam(required = false) String horizonte) {          // Alias alternativo de temporalidad.

        String idFinal = (productoId != null && !productoId.isBlank()) ? productoId : codigo;
        if (idFinal == null || idFinal.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "ERROR",
                    "mensaje", "Debe proporcionar el parámetro 'productoId' o 'codigo' con el código de 4 dígitos del producto."
            ));
        }

        String tempFinal = (horizonte != null && !horizonte.isBlank()) ? horizonte : temporalidad;

        log.info("GET /api/v1/prediccion/ventas producto={} temporalidad={}", idFinal, tempFinal);
        Map<String, Object> respuesta = prediccionService.obtenerPrediccion(idFinal, tempFinal); // Calcula con datos reales.

        if ("PRODUCTO_NO_ENCONTRADO".equals(respuesta.get("status"))) { // El producto no existe en la base de datos.
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(respuesta); // HTTP 404.
        }
        return ResponseEntity.ok(respuesta); // HTTP 200 (status OK o SIN_DATOS).
    }

    /** Lista de productos activos reales para el selector de la app. */
    @GetMapping("/productos") // GET /api/v1/productos
    public ResponseEntity<?> listarProductos() {
        List<Map<String, String>> productos = prediccionService.listarProductos(); // Lee PRODUCTOS de MongoDB.
        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("status", "success");
        respuesta.put("count", productos.size());
        respuesta.put("productos", productos);
        return ResponseEntity.ok(respuesta);
    }

    /** Explicación del modelo (para sustentación). */
    @GetMapping("/prediccion/explicacion") // GET /api/v1/prediccion/explicacion
    public ResponseEntity<?> obtenerExplicacion() {
        return ResponseEntity.ok(prediccionService.obtenerExplicacionMetodologica());
    }
}
