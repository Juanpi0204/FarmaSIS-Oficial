/**
 * Descripción de las variables del dataset analítico.
 * rol: Identificador | Predictora | Objetivo | Línea base | Control
 */
const VARIABLES = [
  ['id_registro', 'Identificador', 'Entero', 'Consecutivo único del registro.', 'Generado', 'Se excluye del modelo.'],
  ['semana_inicio', 'Identificador', 'Fecha (AAAA-MM-DD)', 'Lunes de la semana observada. Índice temporal.', 'FACTURA.fecha (agrupada por semana)', 'Usada para ordenar y particionar train/test; no entra al modelo.'],
  ['anio', 'Predictora', 'Numérica discreta', 'Año ISO de la semana.', 'Derivada de semana_inicio', 'Captura tendencia; se usa como numérica.'],
  ['semana_iso', 'Predictora', 'Numérica discreta (1-53)', 'Número de semana ISO 8601.', 'Derivada de semana_inicio', 'Codificación cíclica seno/coseno.'],
  ['mes', 'Predictora', 'Numérica discreta (1-12)', 'Mes de la semana (según el jueves ISO).', 'Derivada de semana_inicio', 'Codificación cíclica seno/coseno.'],
  ['trimestre', 'Predictora', 'Categórica ordinal (1-4)', 'Trimestre del año.', 'Derivada de semana_inicio', 'One-hot o se descarta si se usa mes cíclico.'],
  ['producto_codigo', 'Identificador', 'Categórica nominal (40)', 'Código de 4 dígitos del producto.', 'PRODUCTOS.codigo', 'Clave del panel; opcionalmente target encoding.'],
  ['producto_nombre', 'Identificador', 'Texto', 'Nombre del producto.', 'PRODUCTOS.nombre', 'Solo descriptiva; se excluye.'],
  ['categoria', 'Predictora', 'Categórica nominal (10)', 'Categoría terapéutica/comercial.', 'PRODUCTOS.categoria', 'Estandarizar texto (tildes/mayúsculas) y one-hot.'],
  ['presentacion', 'Predictora', 'Categórica nominal (8)', 'Forma farmacéutica.', 'PRODUCTOS.presentacion', 'One-hot.'],
  ['proveedor_id', 'Predictora', 'Categórica nominal (5)', 'Proveedor que abastece el producto.', 'PRODUCTOS.proveedorId', 'One-hot.'],
  ['precio_original', 'Predictora', 'Numérica continua (COP)', 'Precio de lista sin descuento.', 'PRODUCTOS.precioOriginal', 'Escalado (StandardScaler) / log.'],
  ['precio_venta_promedio', 'Predictora', 'Numérica continua (COP)', 'Precio unitario promedio cobrado en la semana.', 'FACTURA.detalles.precioUnitario', 'Detección de atípicos (errores de digitación) y escalado.'],
  ['descuento_pct', 'Predictora', 'Numérica continua (0-1)', 'Descuento aplicado = 1 − precio_venta/precio_original.', 'Derivada (PRODUCTOS.precio, precioOriginal)', 'Sin transformación.'],
  ['costo_compra', 'Predictora', 'Numérica continua (COP)', 'Costo unitario de compra.', 'PRODUCTOS.costoCompra', 'Imputar nulos con mediana por producto.'],
  ['margen_pct', 'Predictora', 'Numérica continua', 'Margen bruto = (precio_venta − costo)/precio_venta.', 'Derivada', 'Recalcular tras imputar costo.'],
  ['stock_inicio_semana', 'Predictora', 'Numérica discreta (unid.)', 'Unidades disponibles al iniciar la semana.', 'PRODUCTOS.cantidad (snapshot semanal)', 'Escalado; limita la venta observable.'],
  ['stock_minimo', 'Predictora', 'Numérica discreta (unid.)', 'Punto de reorden del producto.', 'PRODUCTOS.stockMinimo', 'Escalado.'],
  ['dias_para_vencer', 'Predictora', 'Numérica discreta (días)', 'Días entre el inicio de la semana y el vencimiento del lote vigente.', 'PRODUCTOS.fechaVencimiento', 'Imputar nulos con valor previo del mismo lote; recorte (clip) a 730.'],
  ['lote', 'Identificador', 'Texto', 'Código del lote vigente en la semana.', 'PRODUCTOS.lote', 'Solo trazabilidad; se excluye.'],
  ['festivos_semana', 'Predictora', 'Numérica discreta (0-3)', 'Cantidad de días festivos en Colombia dentro de la semana.', 'Externa: calendario oficial de festivos', 'Sin transformación.'],
  ['es_quincena', 'Predictora', 'Binaria (0/1)', '1 si la semana incluye el día 15 o el último día del mes (pago de nómina).', 'Externa: calendario', 'Sin transformación.'],
  ['temporada_lluvias', 'Predictora', 'Binaria (0/1)', '1 si el mes pertenece a la temporada de lluvias de la región Caribe.', 'Externa: régimen climático regional (supuesto)', 'Sin transformación.'],
  ['ventas_lag_1', 'Predictora', 'Numérica discreta (unid.)', 'Unidades vendidas la semana anterior.', 'Derivada de FACTURA.detalles.cantidad', 'Eliminar primeras semanas sin historia o imputar.'],
  ['ventas_lag_2', 'Predictora', 'Numérica discreta (unid.)', 'Unidades vendidas hace 2 semanas.', 'Derivada de FACTURA.detalles.cantidad', 'Igual que lag 1.'],
  ['ventas_lag_4', 'Predictora', 'Numérica discreta (unid.)', 'Unidades vendidas hace 4 semanas.', 'Derivada de FACTURA.detalles.cantidad', 'Igual que lag 1.'],
  ['media_movil_4', 'Predictora', 'Numérica continua (unid.)', 'Promedio de ventas de las 4 semanas previas.', 'Derivada', 'Igual que lag 1.'],
  ['desv_movil_4', 'Predictora', 'Numérica continua (unid.)', 'Desviación estándar de ventas de las 4 semanas previas (volatilidad).', 'Derivada', 'Igual que lag 1.'],
  ['ventas_lag_52', 'Predictora', 'Numérica discreta (unid.)', 'Unidades vendidas en la misma semana del año anterior (estacionalidad anual).', 'Derivada', '50 % nulo por construcción (año 1): usar solo en modelos que toleran nulos (XGBoost) o crear indicador.'],
  ['num_facturas_lag_1', 'Predictora', 'Numérica discreta', 'Número de facturas que incluyeron el producto la semana anterior.', 'Derivada de FACTURA', 'Escalado.'],
  ['quiebre_stock_lag_1', 'Predictora', 'Binaria (0/1)', '1 si la semana anterior se agotó el producto (venta censurada).', 'Derivada', 'Sin transformación.'],
  ['demanda_heuristica_actual', 'Línea base', 'Numérica discreta (unid.)', 'Demanda estimada por la regla vigente max(10, ⌊1,5 × stock⌋) de OptimizacionService.', 'Backend FARMASIS', 'NO es predictora: se usa solo para comparar desempeño.'],
  ['unidades_vendidas', 'Objetivo', 'Numérica discreta (unid.)', 'Unidades vendidas del producto en la semana (variable a predecir, y).', 'Σ FACTURA.detalles.cantidad por producto y semana', 'Posible transformación log1p para reducir asimetría.'],
  ['quiebre_stock', 'Control', 'Binaria (0/1)', '1 si en la semana la demanda superó el stock (y está censurada).', 'Derivada', 'NO es predictora (fuga de información). Se usa para filtrar/ponderar el entrenamiento.'],
];

module.exports = { VARIABLES };
