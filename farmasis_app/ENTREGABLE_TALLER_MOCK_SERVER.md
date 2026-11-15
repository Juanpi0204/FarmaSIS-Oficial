# INFORME TÉCNICO: MOCK SERVER, CONTRATO DE API Y PANTALLAS DIGITALES
## Proyecto de Aula: FarmaSIS — Sistema Inteligente de Gestión y Predicción Farmacéutica
**Institución:** Tecnológico Comfenalco  
**Asignatura:** Proyecto de Aula Digital  
**Fecha de Entrega:** 9 de Octubre de 2026  
**Estudiante / Equipo:** Juan Garcés  

---

## 1. INTRODUCCIÓN Y PROBLEMA DE LA FUNCIÓN SELECCIONADA

### 1.1. Contexto de FarmaSIS
**FarmaSIS** es un sistema integral de gestión para droguerías y farmacias. Uno de los mayores problemas operativos del sector farmacéutico es el **desabastecimiento de medicamentos esenciales (quiebre de stock)** y el **sobrecosto por sobreinventario** de productos de baja rotación o vencimiento cercano.

### 1.2. Función del Proyecto Seleccionada
Para el desarrollo de la aplicación móvil y el contrato de API, se seleccionó la función de mayor valor analítico del proyecto:
> **"Módulo de Predicción de Demanda de Ventas y Alerta Temprana de Quiebre de Stock con IA"**

Esta función permite a los administradores y regentes de farmacia visualizar la curva de ventas proyectada por medicamento, estimar la demanda en unidades y recibir sugerencias automáticas de reorden antes de alcanzar el periodo crítico.

---

## 2. ESPECIFICACIÓN DEL CONTRATO DE DATOS (API CONTRACT)

Siguiendo el enfoque **API-First (Contract-First)**, se diseñó la especificación formal del contrato HTTP REST que intercambian la aplicación móvil Flutter (cliente) y el servicio de predicción (servidor).

### 2.1. Definición del Endpoint

* **Ruta:** `/api/v1/prediccion/ventas`
* **Método HTTP:** `GET`
* **Headers requeridos:**
  * `Accept: application/json`
  * `Content-Type: application/json`

### 2.2. Parámetros de Consulta (Query Parameters)

| Parámetro | Tipo | Obligatorio | Valores Permitidos | Descripción |
| :--- | :---: | :---: | :--- | :--- |
| `productoId` | `String` | Sí | `MED-104`, `MED-202`, `MED-305`, `MED-410`, etc. | Identificador único del fármaco en catálogo. |
| `temporalidad` | `String` | No (Default: `SEMANAL`) | `DIARIO`, `SEMANAL`, `MENSUAL` | Ventana temporal de agrupación de la serie. |

### 2.3. Estructura del JSON de Respuesta (Contrato 200 OK)

```json
{
  "status": "OK",
  "producto": {
    "codigo": "MED-104",
    "nombre": "Acetaminofén 500mg (MED-104)",
    "categoria": "ANALGESICOS",
    "stock_actual": 32,
    "stock_minimo": 30
  },
  "temporalidad": "SEMANAL",
  "resumen": {
    "total_predicho": 380,
    "tendencia": "CRECIENTE",
    "riesgo_quiebre": "ALTO",
    "semana_critica": "Semana 43",
    "sugerencia_reorden_unidades": 130
  },
  "serie_datos": [
    {
      "periodo": "Sem 39",
      "ventas_reales": 81,
      "ventas_predichas": 79,
      "limite_inferior": 69,
      "limite_superior": 91
    },
    {
      "periodo": "Sem 40",
      "ventas_reales": 90,
      "ventas_predichas": 87,
      "limite_inferior": 77,
      "limite_superior": 99
    },
    {
      "periodo": "Sem 41",
      "ventas_reales": 97,
      "ventas_predichas": 95,
      "limite_inferior": 85,
      "limite_superior": 108
    },
    {
      "periodo": "Sem 42",
      "ventas_reales": 105,
      "ventas_predichas": 103,
      "limite_inferior": 93,
      "limite_superior": 116
    },
    {
      "periodo": "Sem 43",
      "ventas_reales": null,
      "ventas_predichas": 122,
      "limite_inferior": 110,
      "limite_superior": 137
    },
    {
      "periodo": "Sem 44",
      "ventas_reales": null,
      "ventas_predichas": 114,
      "limite_inferior": 100,
      "limite_superior": 127
    }
  ]
}
```

### 2.4. Diccionario de Datos del Contrato

1. **Objeto `producto`:**
   * `codigo`: Identificador alfanumérico estandarizado del medicamento.
   * `nombre`: Nombre comercial y concentración.
   * `categoria`: Familia terapéutica (Analgésicos, Antibióticos, etc.).
   * `stock_actual`: Cantidad disponible física en estantería.
   * `stock_minimo`: Umbral de seguridad predefinido por política de inventario.
2. **Objeto `resumen`:**
   * `total_predicho`: Total acumulado de unidades que demandarán los clientes en el horizonte evaluado.
   * `tendencia`: Dirección de la demanda (`CRECIENTE`, `ESTABLE`, `DECRECIENTE`).
   * `riesgo_quiebre`: Evaluación del riesgo de agotamiento (`ALTO`, `MEDIO`, `BAJO`).
   * `semana_critica` / `dia_critico` / `mes_critico`: Periodo exacto donde el inventario cae por debajo del stock mínimo.
   * `sugerencia_reorden_unidades`: Cantidad óptima de pedido recomendada al proveedor.
3. **Arreglo `serie_datos`:**
   * `periodo`: Etiqueta del eje X (días, semanas o meses).
   * `ventas_reales`: Ventas históricas registradas en caja (`null` para periodos futuros).
   * `ventas_predichas`: Valor estimado generado por el modelo de IA.
   * `limite_inferior` / `limite_superior`: Intervalo de confianza de la predicción (95%).

---

## 3. EL MOCK EMPLEADO (MOCK SERVER REST)

### 3.1. Justificación Tecnológica
Para cumplir con los requerimientos del taller y permitir el desacoplamiento entre el backend analítico y el cliente móvil, se desarrolló un **Mock Server en Node.js (`mock_server.js`)**:
* **Ligero y portátil:** Funciona nativamente con Node.js sin dependencias pesadas de terceros.
* **Soporte de CORS habilitado:** Permite conexiones cruzadas desde emuladores Android (`10.0.2.2`), navegadores web y clientes Postman.
* **Simulación multi-producto:** Contiene el catálogo completo de **10 medicamentos representativos** con variaciones realistas de stock y riesgo.

### 3.2. Arquitectura de Endpoints Expuestos

```
[Puerto 3000]
  ├── GET  /api/v1/prediccion/ventas?productoId={id}&temporalidad={temp}
  ├── GET  /api/v1/productos
  └── POST /api/v1/auth/login
```

### 3.3. Instrucciones de Ejecución del Mock Server

1. **Iniciar el servidor:**
   ```bash
   node mock_server.js
   ```
2. **Salida esperada en consola:**
   ```text
   =============================================================
     🚀 FARMASIS MOCK SERVER CORRIENDO EN: http://localhost:3000
   =============================================================
     • Endpoints disponibles:
       - GET  http://localhost:3000/api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL
       - GET  http://localhost:3000/api/v1/productos
       - POST http://localhost:3000/api/v1/auth/login
   =============================================================
   ```

### 3.4. Evidencia de Consumo vía HTTP (Pruebas REST en Mock Server)

**Prueba 1: Consulta del Contrato de Predicción (GET):**
* **Comando:**
  ```powershell
  Invoke-RestMethod -Uri 'http://localhost:3000/api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL'
  ```
* **Resultado:** Código HTTP `200 OK` retornando el JSON estructurado con series temporales en 10ms.

**Prueba 2: Autenticación de Usuario (POST):**
* **Comando:**
  ```powershell
  Invoke-RestMethod -Uri 'http://localhost:3000/api/v1/auth/login' -Method POST -ContentType 'application/json' -Body '{"username":"admin","password":"123"}'
  ```
* **Resultado:** Código HTTP `200 OK` retornando el objeto `usuario` (`Juan Garces · ADMIN`).

---

## 4. DISEÑO DE LAS PANTALLAS DE LA APP MÓVIL

La aplicación fue desarrollada en **Flutter** bajo un sistema de diseño institucional inspirado en interfaces médicas profesionales (Figma Pixel-Perfect).

### 4.1. Paleta de Colores Institucional
* **Verde Bosque Oscuro (`#134E2C` a `#092916`):** Fondo principal, cabecera ejecutiva y solidez institucional.
* **Verde Esmeralda (`#10B981` / `#34D399`):** Barras de ventas reales y estados activos.
* **Rojo Alerta Quiebre (`#B91C1C` / `#FECACA`):** Alerta inmediata cuando el stock es inferior a la demanda.
* **Melocotón Advertencia (`#FEF2EE` / `#FED7AA`):** Tarjeta de reabastecimiento asistido.
* **Blanco / Gris Claro (`#FFFFFF` / `#F1F5F3`):** Tarjetas redondeadas de contenido (Squircle 22px).

### 4.2. Pantalla 1: Inicio de Sesión (Login y Biometría)
* **Objetivo:** Autenticación de usuarios administradores y empleados con acceso a la farmacia.
* **Componentes:**
  * Logotipo oficial squircle de FarmaSIS.
  * Formulario con validación de credenciales y botón para mostrar/ocultar contraseña.
  * **Herramienta Avanzada (Lector de Huella Digital - `local_auth`):** Permite el ingreso biométrico validando la huella del usuario en el sensor del dispositivo y autenticando las credenciales vinculadas directamente contra el endpoint `/api/v1/auth/login` de la API.
  * Conexión híbrida: Integra consumo real contra la base de datos de **MongoDB Atlas** (Spring Boot en puerto `8092`) con conmutación y contingencia automática hacia el Mock Server (`3000`).

### 4.3. Pantalla 2: Dashboard Predictivo (Consumo del Contrato)
* **Objetivo:** Presentación ejecutiva del análisis de demanda y decisiones de inventario.
* **Componentes implementados:**
  1. **Cabecera Institucional:** Datos del usuario autenticado (`Juan Garces · ADMIN`), avatar interactivo y campana de notificaciones.
  2. **Selector de Medicamento (10 Fármacos):** Menú desplegable para cambiar entre Acetaminofén, Ibuprofeno, Amoxicilina, Losartán, Omeprazol, etc., con chip informativo de categoría médica y niveles de stock vs stock mínimo.
  3. **Selector Segmentado de Temporalidad:** Pestañas para alternar entre **DIARIO**, **SEMANAL** y **MENSUAL**.
  4. **Tarjetas de KPI:**
     * *Demanda Estimada:* Cantidad proyectada en unidades (ej. `380 uds`).
     * *Riesgo de Quiebre:* Badge adaptativo con colorimetría semafórica (Rojo: ALTO, Ámbar: MEDIO, Verde: BAJO).
  5. **Gráfico Syncfusion (`SfCartesianChart`):** Visualización combinada de barras en verde esmeralda (ventas reales) con curva Spline verde bosque (predicción de IA con marcadores circulares).
  6. **Tarjeta de Reabastecimiento Recomendado:** Recomendación algorítmica calculada que indica cuántas unidades comprar y la fecha límite antes del agotamiento.

---

## 5. CONSUMO DE LA API EN FLUTTER (CÓDIGO DE INTEGRACIÓN)

El archivo `lib/services/api_service.dart` ejecuta la petición HTTP asíncrona hacia el Mock Server:

```dart
static Future<ContratoPrediccionResponse> getPrediccion({
  String productoId = 'MED-104',
  String temporalidad = 'SEMANAL',
}) async {
  final baseUrl = useRealPredictionApi ? springBootBaseUrl : mockServerBaseUrl;
  final url = Uri.parse(
      '$baseUrl/api/v1/prediccion/ventas?productoId=$productoId&temporalidad=$temporalidad');

  final response = await http
      .get(url, headers: {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 4));

  if (response.statusCode == 200) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return ContratoPrediccionResponse.fromJson(data);
  }
  
  throw Exception('Error al consultar el Mock Server');
}
```

---

## 6. CONCLUSIÓN

El taller permitió implementar con éxito la arquitectura **Contract-First**, demostrando cómo un **Mock Server** facilita el desarrollo ágil de aplicaciones móviles complejas antes de contar con el backend final desplegado. La app de FarmaSIS consume datos estructurados vía HTTP REST y ofrece una experiencia visual interactiva de alto nivel para la toma de decisiones farmacéuticas.
