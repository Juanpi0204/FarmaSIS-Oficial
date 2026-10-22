/**
 * Libro Excel "Plantilla Dataset" con: Ficha técnica, Dataset, Variables,
 * Diccionario de Datos, Calidad de Datos, Líneas base y Modelo E-R.
 */
const ExcelJS = require('exceljs');
const { ENTIDADES, RELACIONES } = require('./schema');
const { VARIABLES } = require('./variables');

const AZUL = 'FF102A43';
const COLOR_ROL = {
  Identificador: 'FF607D8B',
  Predictora: 'FF1E5AA8',
  Objetivo: 'FFC62828',
  'Línea base': 'FF6A1B9A',
  Control: 'FFD9730D',
};
const borde = { style: 'thin', color: { argb: 'FFD0D7DE' } };
const bordes = { top: borde, left: borde, bottom: borde, right: borde };

function encabezado(fila, color = AZUL) {
  fila.eachCell((c) => {
    c.font = { bold: true, color: { argb: 'FFFFFFFF' }, name: 'Calibri', size: 11 };
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: color } };
    c.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
    c.border = bordes;
  });
  fila.height = 32;
}

function titulo(ws, texto, sub, columnas) {
  ws.mergeCells(1, 1, 1, columnas);
  ws.getCell(1, 1).value = texto;
  ws.getCell(1, 1).font = { bold: true, size: 16, color: { argb: AZUL } };
  ws.getRow(1).height = 26;
  if (sub) {
    ws.mergeCells(2, 1, 2, columnas);
    ws.getCell(2, 1).value = sub;
    ws.getCell(2, 1).font = { italic: true, size: 10, color: { argb: 'FF52606D' } };
    ws.getCell(2, 1).alignment = { wrapText: true, vertical: 'top' };
    ws.getRow(2).height = 30;
  }
}

async function generarExcel(ruta, { filas, problemas, estadisticas, lineasBase, rutaPngER, dimER }) {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Colectivo FARMASIS – Minería de Datos II';
  wb.created = new Date();

  // ---------------------------------------------------------------- 1. Ficha técnica
  const ft = wb.addWorksheet('1. Ficha técnica', { properties: { tabColor: { argb: AZUL } } });
  ft.columns = [{ width: 34 }, { width: 110 }];
  titulo(ft, 'Plantilla Dataset – FARMASIS · Minería de Datos II', 'Fundación Universitaria Tecnológico Comfenalco · Ingeniería de Sistemas · VIII semestre · 2026', 2);
  const ficha = [
    ['Proyecto', 'FARMASIS: Sistema de gestión de farmacias inteligente (ERP + POS + IA)'],
    ['Problema analítico', 'Pronóstico de la demanda semanal (unidades vendidas) por producto'],
    ['Tipo de problema', 'Aprendizaje supervisado – Regresión sobre datos de panel (series de tiempo de 40 productos)'],
    ['Variable objetivo (y)', 'unidades_vendidas'],
    ['Variables predictoras (X)', `${VARIABLES.filter((v) => v[1] === 'Predictora').length} variables (calendario, producto, precio, inventario, rezagos de ventas)`],
    ['Granularidad', '1 registro = 1 producto × 1 semana (lunes a domingo)'],
    ['Periodo', `${filas[0].semana_inicio} a ${filas[filas.length - 1].semana_inicio} (104 semanas)`],
    ['Registros × columnas', `${filas.length.toLocaleString('es-CO')} × ${Object.keys(filas[0]).length}`],
    ['Fuente de datos', 'Dataset SIMULADO de forma controlada a partir del esquema real de FARMASIS (colecciones PRODUCTOS, FACTURA.detalles, proveedores) + fuentes externas (calendario de festivos de Colombia, régimen de lluvias de la región Caribe).'],
    ['Motivo de la simulación', 'El histórico transaccional en producción aún no cubre ≥ 1 año, condición mínima para capturar estacionalidad anual. El script extraerMongo.js construye el mismo dataset con datos reales cuando exista suficiente historia.'],
    ['Reproducibilidad', 'Semilla aleatoria 2026 – generador: docs/mineria-datos-ii/generador (npm run generar)'],
    ['Partición sugerida', `Entrenamiento: semanas < ${lineasBase.fechaCorte} (${lineasBase.registrosEntrenamiento} reg.) · Prueba: semanas ≥ ${lineasBase.fechaCorte} (${filas.length - lineasBase.registrosEntrenamiento} reg.) · Validación cruzada temporal (TimeSeriesSplit)`],
    ['Problemas de calidad inyectados', `costo_compra nulo: ${problemas.costo_nulo} · dias_para_vencer nulo: ${problemas.vencimiento_nulo} · precio con error de digitación (×10): ${problemas.precio_digitacion} · categoría con escritura inconsistente: ${problemas.categoria_inconsistente}`],
    ['Archivo CSV equivalente', 'Dataset_Demanda_FARMASIS.csv (UTF-8, separador coma)'],
  ];
  ficha.forEach(([k, v], i) => {
    const r = ft.getRow(4 + i);
    r.values = [k, v];
    r.getCell(1).font = { bold: true, color: { argb: AZUL } };
    r.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8EEF5' } };
    r.getCell(2).alignment = { wrapText: true, vertical: 'top' };
    r.eachCell((c) => (c.border = bordes));
    r.height = v.length > 110 ? 32 : 18;
  });
  const leyR = 4 + ficha.length + 1;
  ft.getCell(leyR, 1).value = 'Código de color de columnas (hoja Dataset)';
  ft.getCell(leyR, 1).font = { bold: true };
  Object.entries(COLOR_ROL).forEach(([rol, color], i) => {
    const c = ft.getCell(leyR + 1 + i, 1);
    c.value = rol;
    c.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: color } };
  });

  // ---------------------------------------------------------------- 2. Dataset
  const ds = wb.addWorksheet('2. Dataset', { properties: { tabColor: { argb: 'FFC62828' } }, views: [{ state: 'frozen', ySplit: 1, xSplit: 2 }] });
  const claves = Object.keys(filas[0]);
  ds.columns = claves.map((k) => ({ header: k, key: k, width: Math.max(12, Math.min(38, k.length + 4)) }));
  ds.getColumn('producto_nombre').width = 40;
  filas.forEach((f) => ds.addRow(f));
  encabezado(ds.getRow(1));
  claves.forEach((k, i) => {
    const rol = (VARIABLES.find((v) => v[0] === k) || [])[1];
    ds.getRow(1).getCell(i + 1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: COLOR_ROL[rol] || AZUL } };
  });
  ds.autoFilter = { from: { row: 1, column: 1 }, to: { row: 1, column: claves.length } };
  ['precio_original', 'precio_venta_promedio', 'costo_compra'].forEach((k) => (ds.getColumn(k).numFmt = '"$"#,##0'));
  ['descuento_pct', 'margen_pct'].forEach((k) => (ds.getColumn(k).numFmt = '0.0%'));

  // ---------------------------------------------------------------- 3. Variables
  const vs = wb.addWorksheet('3. Variables', { properties: { tabColor: { argb: 'FF1E5AA8' } } });
  vs.columns = [{ width: 5 }, { width: 28 }, { width: 14 }, { width: 24 }, { width: 60 }, { width: 38 }, { width: 55 }];
  titulo(vs, 'Variables del dataset analítico', 'Rol de cada variable en el modelo de regresión y transformación prevista en la etapa de preprocesamiento.', 7);
  vs.getRow(4).values = ['#', 'Variable', 'Rol', 'Tipo', 'Descripción', 'Origen (FARMASIS / externa)', 'Preprocesamiento previsto'];
  encabezado(vs.getRow(4));
  VARIABLES.forEach((v, i) => {
    const r = vs.getRow(5 + i);
    r.values = [i + 1, ...v];
    r.eachCell((c) => {
      c.border = bordes;
      c.alignment = { wrapText: true, vertical: 'top' };
    });
    r.getCell(2).font = { bold: true, name: 'Consolas' };
    r.getCell(3).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    r.getCell(3).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: COLOR_ROL[v[1]] } };
  });

  // ---------------------------------------------------------------- 4. Diccionario de Datos
  const dd = wb.addWorksheet('4. Diccionario de Datos', { properties: { tabColor: { argb: 'FF2E7D32' } }, views: [{ state: 'frozen', ySplit: 4 }] });
  dd.columns = [{ width: 24 }, { width: 22 }, { width: 18 }, { width: 26 }, { width: 22 }, { width: 9 }, { width: 8 }, { width: 11 }, { width: 14 }, { width: 70 }];
  titulo(dd, 'Diccionario de Datos – FARMASIS', 'Construido a partir de las clases @Entity (MySQL) y @Document (MongoDB) del backend Spring Boot. FK lógica = referencia por valor no forzada por el motor.', 10);
  dd.getRow(4).values = ['Entidad', 'Tabla / Colección', 'Motor', 'Campo', 'Tipo de dato', 'Long.', 'Nulo', 'Clave', 'Por defecto', 'Descripción / Restricciones'];
  encabezado(dd.getRow(4));
  let fila = 5;
  ENTIDADES.forEach((e, ie) => {
    const colorEnt = e.estado === 'Propuesta MD II' ? 'FFFFF3E0' : e.motor === 'MySQL' ? 'FFE3EDF9' : 'FFE8F5E9';
    // fila de descripción de la entidad
    dd.mergeCells(fila, 1, fila, 10);
    const c = dd.getCell(fila, 1);
    c.value = `${e.id}  (${e.estado}) – ${e.descripcion}  [Clase: ${e.claseJava}]`;
    c.font = { bold: true, color: { argb: AZUL } };
    c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colorEnt } };
    c.alignment = { wrapText: true, vertical: 'middle' };
    dd.getRow(fila).height = 30;
    fila++;
    e.campos.forEach((campo) => {
      const r = dd.getRow(fila++);
      r.values = [e.id, e.nombreFisico, e.motor, ...campo];
      r.eachCell((cc) => {
        cc.border = bordes;
        cc.alignment = { wrapText: true, vertical: 'top' };
      });
      r.getCell(4).font = { name: 'Consolas', bold: campo[4] === 'PK' };
      if (campo[4]) r.getCell(8).font = { bold: true, color: { argb: { PK: 'FFB8860B', FK: 'FF1E5AA8', UK: 'FF6A1B9A' }[campo[4]] || 'FFC62828' } };
    });
    if (ie < ENTIDADES.length - 1) fila++;
  });
  // Relaciones
  fila += 2;
  dd.mergeCells(fila, 1, fila, 10);
  dd.getCell(fila, 1).value = 'Relaciones del Modelo E-R';
  dd.getCell(fila, 1).font = { bold: true, size: 14, color: { argb: AZUL } };
  fila++;
  const hr = dd.getRow(fila++);
  hr.values = ['Id', 'Entidad origen', 'Card. origen', 'Verbo', 'Entidad destino', 'Card. destino', '', 'Tipo', '', 'Implementación'];
  encabezado(hr);
  RELACIONES.forEach((r) => {
    const row = dd.getRow(fila++);
    row.values = [r.id, r.origen, `(${r.card[0]})`, r.verbo, r.destino, `(${r.card[1]})`, '', r.tipo, r.nueva ? 'Nueva' : '', r.via];
    row.eachCell((cc) => (cc.border = bordes));
  });

  // ---------------------------------------------------------------- 5. Calidad de Datos
  const cq = wb.addWorksheet('5. Calidad de Datos', { properties: { tabColor: { argb: 'FFD9730D' } } });
  cq.columns = [{ width: 28 }, { width: 14 }, { width: 10 }, { width: 10 }, { width: 10 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 10 }, { width: 26 }];
  titulo(cq, 'Perfil y calidad de los datos', 'Estadística descriptiva por variable, calculada sobre el dataset completo antes del preprocesamiento.', 14);
  cq.getRow(4).values = ['Variable', 'Tipo', 'N', 'Nulos', '% Nulos', 'Mínimo', 'P25', 'Mediana', 'P75', 'Máximo', 'Media', 'Desv. est.', 'Únicos', 'Moda / Observación'];
  encabezado(cq.getRow(4));
  estadisticas.forEach((s, i) => {
    const r = cq.getRow(5 + i);
    r.values = [s.variable, s.tipo, s.n, s.nulos, s.pctNulos, s.min, s.p25, s.mediana, s.p75, s.max, s.media, s.desv, s.unicos, s.moda];
    r.getCell(5).numFmt = '0.0%';
    for (let k = 6; k <= 12; k++) r.getCell(k).numFmt = '#,##0.00';
    r.eachCell((cc) => (cc.border = bordes));
    if (s.nulos > 0) r.getCell(4).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFE0B2' } };
  });

  // ---------------------------------------------------------------- 6. Líneas base
  const lb = wb.addWorksheet('6. Líneas base', { properties: { tabColor: { argb: 'FF6A1B9A' } } });
  lb.columns = [{ width: 56 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }, { width: 12 }];
  titulo(lb, 'Métricas de referencia (conjunto de prueba)', `Periodo de prueba: semanas ≥ ${lineasBase.fechaCorte}. El modelo de Minería de Datos II debe superar estas métricas.`, 6);
  lb.getRow(4).values = ['Método', 'n', 'MAE', 'RMSE', 'WAPE', 'R²'];
  encabezado(lb.getRow(4));
  lineasBase.resultados.forEach((m, i) => {
    const r = lb.getRow(5 + i);
    r.values = [m.metodo, m.n, m.mae, m.rmse, m.wape, m.r2];
    r.getCell(5).numFmt = '0.0%';
    r.getCell(6).numFmt = '0.000';
    r.eachCell((cc) => (cc.border = bordes));
  });

  // ---------------------------------------------------------------- 7. Modelo E-R
  const er = wb.addWorksheet('7. Modelo E-R', { properties: { tabColor: { argb: 'FF00897B' } } });
  titulo(er, 'Modelo Entidad-Relación – FARMASIS', 'Imagen en alta resolución: Modelo_ER_FARMASIS.png / .svg', 20);
  const img = wb.addImage({ filename: rutaPngER, extension: 'png' });
  const anchoImg = 1500;
  er.addImage(img, { tl: { col: 0, row: 3 }, ext: { width: anchoImg, height: Math.round((anchoImg * dimER.alto) / dimER.ancho) } });

  await wb.xlsx.writeFile(ruta);
}

module.exports = { generarExcel };
