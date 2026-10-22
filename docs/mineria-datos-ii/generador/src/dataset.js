/**
 * Generación del dataset analítico de demanda semanal por producto.
 *
 * Granularidad: 1 fila = 1 producto × 1 semana (lunes a domingo).
 * Periodo: 2024-01-01 a 2025-12-28 (104 semanas) × 40 productos = 4.160 registros.
 *
 * El dataset es SIMULADO de forma controlada a partir del esquema real de FARMASIS
 * (PRODUCTOS, FACTURA.detalles, proveedores) porque el histórico transaccional del
 * sistema en producción aún no tiene la profundidad temporal (≥ 1 año) que exige un
 * modelo de pronóstico con estacionalidad. El proceso generador incorpora efectos
 * documentados en el retail farmacéutico: tendencia, estacionalidad climática,
 * pago de quincena, festivos, elasticidad precio-descuento, vencimiento de lotes,
 * quiebres de stock (demanda censurada) y ruido sobredisperso (Poisson-Gamma).
 * Se inyectan además problemas de calidad de datos realistas para ejercitar la fase
 * de preprocesamiento.
 */

const SEMILLA = 2026;

// ---------------------------------------------------------------- PRNG reproducible
function mulberry32(a) {
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(SEMILLA);
const uniforme = (a, b) => a + (b - a) * rand();
function normal() {
  let u = 0;
  while (u === 0) u = rand();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * rand());
}
// Marsaglia-Tsang (k >= 1)
function gamma(k, theta) {
  const d = k - 1 / 3;
  const c = 1 / Math.sqrt(9 * d);
  for (;;) {
    let x, v;
    do {
      x = normal();
      v = 1 + c * x;
    } while (v <= 0);
    v = v * v * v;
    const u = rand();
    if (u < 1 - 0.0331 * x ** 4) return d * v * theta;
    if (Math.log(u) < 0.5 * x * x + d * (1 - v + Math.log(v))) return d * v * theta;
  }
}
function poisson(lambda) {
  if (lambda < 30) {
    const L = Math.exp(-lambda);
    let k = 0;
    let p = 1;
    do {
      k++;
      p *= rand();
    } while (p > L);
    return k - 1;
  }
  return Math.max(0, Math.round(lambda + Math.sqrt(lambda) * normal()));
}
// Binomial negativa como mezcla Poisson-Gamma (sobredispersión)
const binomialNegativa = (mu, k = 8) => poisson(mu * gamma(k, 1 / k));

// ---------------------------------------------------------------- Catálogo
const PROVEEDORES = [
  { id: 'PRV-01', empresa: 'Distribuidora Caribe Pharma S.A.S.' },
  { id: 'PRV-02', empresa: 'Droguería Mayorista Bolívar S.A.' },
  { id: 'PRV-03', empresa: 'Medisur Distribuciones S.A.S.' },
  { id: 'PRV-04', empresa: 'Farmadistri del Norte Ltda.' },
  { id: 'PRV-05', empresa: 'Biopharma Andina S.A.S.' },
];

// Factores estacionales por categoría
const CATEGORIAS = {
  'Analgésicos': { lluvia: 1.15, diciembre: 1.1, quincena: 1.05, enero: 1.0, seca: 1.0 },
  'Antigripales': { lluvia: 1.6, diciembre: 1.05, quincena: 1.03, enero: 1.0, seca: 0.9 },
  'Antialérgicos': { lluvia: 1.3, diciembre: 1.0, quincena: 1.03, enero: 1.0, seca: 1.0 },
  'Antibióticos': { lluvia: 1.2, diciembre: 1.0, quincena: 1.02, enero: 1.0, seca: 1.0 },
  'Gastrointestinales': { lluvia: 1.05, diciembre: 1.3, quincena: 1.05, enero: 1.1, seca: 1.0 },
  'Pediátricos': { lluvia: 1.25, diciembre: 1.0, quincena: 1.05, enero: 1.0, seca: 1.0 },
  'Cardiometabólicos': { lluvia: 1.0, diciembre: 1.0, quincena: 1.18, enero: 1.0, seca: 1.0 },
  'Vitaminas': { lluvia: 1.1, diciembre: 0.95, quincena: 1.08, enero: 1.25, seca: 1.0 },
  'Dermatológicos': { lluvia: 0.95, diciembre: 1.15, quincena: 1.05, enero: 1.1, seca: 1.2 },
  'Cuidado personal': { lluvia: 1.0, diciembre: 1.2, quincena: 1.1, enero: 1.0, seca: 1.05 },
};

// [codigo, nombre, categoria, presentacion, concentracion, principio activo, demanda base semanal, precio COP, costo COP, proveedor]
const PRODUCTOS = [
  ['0001', 'Acetaminofén 500 mg x 10 tab', 'Analgésicos', 'Tableta', '500 mg', 'Acetaminofén', 90, 3500, 1900, 'PRV-01'],
  ['0002', 'Ibuprofeno 400 mg x 10 tab', 'Analgésicos', 'Tableta', '400 mg', 'Ibuprofeno', 70, 4800, 2600, 'PRV-02'],
  ['0003', 'Naproxeno 250 mg x 10 tab', 'Analgésicos', 'Tableta', '250 mg', 'Naproxeno sódico', 35, 6200, 3400, 'PRV-03'],
  ['0004', 'Diclofenaco 50 mg x 10 tab', 'Analgésicos', 'Tableta', '50 mg', 'Diclofenaco sódico', 30, 4200, 2100, 'PRV-01'],
  ['0005', 'Acetaminofén + Cafeína x 8 tab', 'Analgésicos', 'Tableta', '500 mg / 65 mg', 'Acetaminofén, Cafeína', 45, 9800, 6100, 'PRV-04'],
  ['0006', 'Acetaminofén jarabe 150 mg/5 mL x 60 mL', 'Pediátricos', 'Jarabe', '150 mg/5 mL', 'Acetaminofén', 25, 7500, 4000, 'PRV-04'],
  ['0007', 'Ibuprofeno suspensión 100 mg/5 mL x 120 mL', 'Pediátricos', 'Suspensión', '100 mg/5 mL', 'Ibuprofeno', 18, 11500, 6300, 'PRV-05'],
  ['0008', 'Sales de rehidratación oral x sobre', 'Gastrointestinales', 'Sobre', '27,9 g', 'Glucosa, Cloruro de sodio, Citrato', 30, 2500, 1200, 'PRV-04'],
  ['0009', 'Loratadina 10 mg x 10 tab', 'Antialérgicos', 'Tableta', '10 mg', 'Loratadina', 40, 3900, 1800, 'PRV-01'],
  ['0010', 'Cetirizina 10 mg x 10 tab', 'Antialérgicos', 'Tableta', '10 mg', 'Cetirizina', 28, 4500, 2200, 'PRV-02'],
  ['0011', 'Desloratadina jarabe 2,5 mg/5 mL x 60 mL', 'Antialérgicos', 'Jarabe', '2,5 mg/5 mL', 'Desloratadina', 10, 18500, 10200, 'PRV-05'],
  ['0012', 'Antigripal día x 12 cáps', 'Antigripales', 'Cápsula', '500 mg / 10 mg', 'Acetaminofén, Fenilefrina', 50, 8900, 5000, 'PRV-04'],
  ['0013', 'Antigripal noche x sobre', 'Antigripales', 'Sobre', '500 mg / 10 mg / 4 mg', 'Acetaminofén, Fenilefrina, Clorfeniramina', 40, 2800, 1400, 'PRV-03'],
  ['0014', 'Ambroxol jarabe 30 mg/5 mL x 120 mL', 'Antigripales', 'Jarabe', '30 mg/5 mL', 'Ambroxol', 22, 9500, 5100, 'PRV-01'],
  ['0015', 'Dextrometorfano jarabe 15 mg/5 mL x 120 mL', 'Antigripales', 'Jarabe', '15 mg/5 mL', 'Dextrometorfano', 18, 12000, 6800, 'PRV-05'],
  ['0016', 'Amoxicilina 500 mg x 21 cáps', 'Antibióticos', 'Cápsula', '500 mg', 'Amoxicilina', 20, 12500, 6900, 'PRV-01'],
  ['0017', 'Azitromicina 500 mg x 3 tab', 'Antibióticos', 'Tableta', '500 mg', 'Azitromicina', 15, 9800, 5200, 'PRV-02'],
  ['0018', 'Cefalexina 500 mg x 10 cáps', 'Antibióticos', 'Cápsula', '500 mg', 'Cefalexina', 10, 14500, 8100, 'PRV-03'],
  ['0019', 'Ciprofloxacino 500 mg x 10 tab', 'Antibióticos', 'Tableta', '500 mg', 'Ciprofloxacino', 9, 8700, 4600, 'PRV-01'],
  ['0020', 'Amoxicilina suspensión 250 mg/5 mL x 100 mL', 'Antibióticos', 'Suspensión', '250 mg/5 mL', 'Amoxicilina', 12, 10500, 5800, 'PRV-04'],
  ['0021', 'Omeprazol 20 mg x 14 cáps', 'Gastrointestinales', 'Cápsula', '20 mg', 'Omeprazol', 55, 5200, 2500, 'PRV-01'],
  ['0022', 'Loperamida 2 mg x 6 tab', 'Gastrointestinales', 'Tableta', '2 mg', 'Loperamida', 20, 3800, 1900, 'PRV-02'],
  ['0023', 'Hidróxido de Al + Mg suspensión x 360 mL', 'Gastrointestinales', 'Suspensión', '6 g / 4 g', 'Hidróxido de aluminio, Hidróxido de magnesio', 18, 13500, 7600, 'PRV-04'],
  ['0024', 'Esomeprazol 40 mg x 14 tab', 'Gastrointestinales', 'Tableta', '40 mg', 'Esomeprazol', 15, 22000, 12500, 'PRV-05'],
  ['0025', 'Metoclopramida 10 mg x 10 tab', 'Gastrointestinales', 'Tableta', '10 mg', 'Metoclopramida', 8, 3500, 1700, 'PRV-03'],
  ['0026', 'Losartán 50 mg x 30 tab', 'Cardiometabólicos', 'Tableta', '50 mg', 'Losartán potásico', 45, 7800, 3600, 'PRV-01'],
  ['0027', 'Amlodipino 5 mg x 30 tab', 'Cardiometabólicos', 'Tableta', '5 mg', 'Amlodipino', 30, 6900, 3200, 'PRV-02'],
  ['0028', 'Atorvastatina 20 mg x 30 tab', 'Cardiometabólicos', 'Tableta', '20 mg', 'Atorvastatina', 25, 14500, 7800, 'PRV-03'],
  ['0029', 'Metformina 850 mg x 30 tab', 'Cardiometabólicos', 'Tableta', '850 mg', 'Metformina', 40, 6500, 3000, 'PRV-01'],
  ['0030', 'Ácido acetilsalicílico 100 mg x 30 tab', 'Cardiometabólicos', 'Tableta', '100 mg', 'Ácido acetilsalicílico', 22, 5500, 2600, 'PRV-04'],
  ['0031', 'Vitamina C 500 mg x 100 tab', 'Vitaminas', 'Tableta', '500 mg', 'Ácido ascórbico', 20, 16500, 9200, 'PRV-05'],
  ['0032', 'Complejo B x 30 tab', 'Vitaminas', 'Tableta', 'B1/B6/B12', 'Tiamina, Piridoxina, Cianocobalamina', 12, 9800, 5100, 'PRV-03'],
  ['0033', 'Multivitamínico x 30 tab', 'Vitaminas', 'Tableta', 'Multicomponente', 'Vitaminas y minerales', 9, 32000, 19000, 'PRV-05'],
  ['0034', 'Calcio + Vitamina D x 30 tab', 'Vitaminas', 'Tableta', '600 mg / 400 UI', 'Carbonato de calcio, Colecalciferol', 8, 24500, 14100, 'PRV-02'],
  ['0035', 'Clotrimazol crema 1 % x 20 g', 'Dermatológicos', 'Crema', '1 %', 'Clotrimazol', 14, 7200, 3700, 'PRV-01'],
  ['0036', 'Betametasona crema 0,05 % x 40 g', 'Dermatológicos', 'Crema', '0,05 %', 'Betametasona', 9, 9500, 5000, 'PRV-02'],
  ['0037', 'Protector solar FPS 50 x 120 mL', 'Dermatológicos', 'Crema', 'FPS 50', 'Filtros UVA/UVB', 10, 45000, 27000, 'PRV-05'],
  ['0038', 'Alcohol antiséptico 70 % x 350 mL', 'Cuidado personal', 'Solución', '70 %', 'Etanol', 35, 6500, 3500, 'PRV-04'],
  ['0039', 'Gel antibacterial x 500 mL', 'Cuidado personal', 'Gel', '70 %', 'Etanol', 20, 11000, 6000, 'PRV-03'],
  ['0040', 'Suero fisiológico 0,9 % x 500 mL', 'Cuidado personal', 'Solución', '0,9 %', 'Cloruro de sodio', 15, 6800, 3500, 'PRV-05'],
].map(([codigo, nombre, categoria, presentacion, concentracion, principio, base, precio, costo, proveedorId]) => ({
  codigo, nombre, categoria, presentacion, concentracion, principio, base, precio, costo, proveedorId,
}));

// ---------------------------------------------------------------- Calendario (Colombia, Cartagena)
// Festivos oficiales Colombia (Ley 51 de 1983 - Ley Emiliani) + 11 de noviembre (Independencia de Cartagena)
const FESTIVOS = new Set([
  '2024-01-01', '2024-01-08', '2024-03-25', '2024-03-28', '2024-03-29', '2024-05-01', '2024-05-13',
  '2024-06-03', '2024-06-10', '2024-07-01', '2024-07-20', '2024-08-07', '2024-08-19', '2024-10-14',
  '2024-11-04', '2024-11-11', '2024-12-08', '2024-12-25',
  '2025-01-01', '2025-01-06', '2025-03-24', '2025-04-17', '2025-04-18', '2025-05-01', '2025-06-02',
  '2025-06-23', '2025-06-30', '2025-07-20', '2025-08-07', '2025-08-18', '2025-10-13', '2025-11-03',
  '2025-11-17', '2025-12-08', '2025-12-25',
]);
// Supuesto: régimen de lluvias de la región Caribe (mayo-junio y agosto-noviembre; julio = "veranillo")
const MESES_LLUVIA = new Set([5, 6, 8, 9, 10, 11]);

const DIA_MS = 86400000;
const FECHA_INICIO = Date.UTC(2024, 0, 1); // lunes
const N_SEMANAS = 104;

const iso = (ms) => new Date(ms).toISOString().slice(0, 10);
function semanaIso(ms) {
  const d = new Date(ms);
  const dia = (d.getUTCDay() + 6) % 7;
  const jueves = new Date(ms + (3 - dia) * DIA_MS);
  const primerJueves = new Date(Date.UTC(jueves.getUTCFullYear(), 0, 4));
  return 1 + Math.round(((jueves - primerJueves) / DIA_MS - 3 + ((primerJueves.getUTCDay() + 6) % 7)) / 7);
}
function infoCalendario(lunesMs) {
  const jueves = new Date(lunesMs + 3 * DIA_MS); // mes/año de referencia = jueves (ISO)
  let festivos = 0;
  let quincena = 0;
  for (let i = 0; i < 7; i++) {
    const d = new Date(lunesMs + i * DIA_MS);
    if (FESTIVOS.has(iso(d.getTime()))) festivos++;
    const ultimoDia = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
    if (d.getUTCDate() === 15 || d.getUTCDate() === ultimoDia) quincena = 1;
  }
  const mes = jueves.getUTCMonth() + 1;
  return {
    anio: jueves.getUTCFullYear(),
    semana: semanaIso(lunesMs),
    mes,
    trimestre: Math.ceil(mes / 3),
    festivos,
    quincena,
    lluvia: MESES_LLUVIA.has(mes) ? 1 : 0,
  };
}

// ---------------------------------------------------------------- Utilidades
const redondear50 = (x) => Math.round(x / 50) * 50;
const r2 = (x) => Math.round(x * 100) / 100;
const r4 = (x) => Math.round(x * 10000) / 10000;
const media = (a) => a.reduce((s, x) => s + x, 0) / a.length;
const desv = (a) => {
  const m = media(a);
  return Math.sqrt(a.reduce((s, x) => s + (x - m) ** 2, 0) / (a.length - 1));
};
const UNIDADES_POR_LINEA = { Tableta: 1.6, Cápsula: 1.4, Jarabe: 1.1, Suspensión: 1.1, Sobre: 2.4, Crema: 1.05, Solución: 1.2, Gel: 1.1 };

/** Heurística vigente en OptimizacionService.calcularDemandaEstimada(): max(10, floor(stock × 1.5)) */
const heuristicaActual = (stock) => Math.max(10, Math.floor(stock * 1.5));

// ---------------------------------------------------------------- Simulación
function generarDataset() {
  const filas = [];
  const calendario = Array.from({ length: N_SEMANAS }, (_, t) => {
    const ms = FECHA_INICIO + t * 7 * DIA_MS;
    return { ms, fecha: iso(ms), ...infoCalendario(ms) };
  });

  for (const p of PRODUCTOS) {
    const cat = CATEGORIAS[p.categoria];
    const crecimiento = uniforme(-0.05, 0.15); // tendencia anual
    const stockMinimo = Math.max(5, Math.round(p.base * 0.8));
    let stock = Math.round(p.base * uniforme(2.5, 4));
    let lote = 1;
    let vencimientoMs = FECHA_INICIO + Math.round(uniforme(200, 600)) * DIA_MS;
    let pedidoEnTransito = 0;
    let semanasParaLlegada = 0;
    const ventas = [];
    const facturas = [];
    const quiebres = [];

    calendario.forEach((c, t) => {
      // 1) Recepción de pedidos al inicio de la semana (se actualiza lote y vencimiento, como en PRODUCTOS)
      if (pedidoEnTransito > 0) {
        semanasParaLlegada--;
        if (semanasParaLlegada <= 0) {
          stock += pedidoEnTransito;
          pedidoEnTransito = 0;
          lote++;
          const corto = rand() < 0.15; // lotes de vida útil corta
          vencimientoMs = c.ms + Math.round(corto ? uniforme(60, 150) : uniforme(300, 720)) * DIA_MS;
        }
      }
      let diasParaVencer = Math.round((vencimientoMs - c.ms) / DIA_MS);
      if (diasParaVencer <= 0) {
        // lote vencido: se da de baja el inventario
        stock = 0;
        diasParaVencer = 0;
      }
      const stockInicio = stock;

      // 2) Precio y descuento (inflación anual en enero de 2025)
      const factorAnio = c.anio === 2025 ? 1.07 : 1.0;
      const precioOriginal = redondear50(p.precio * factorAnio);
      const costo = redondear50(p.costo * (c.anio === 2025 ? 1.06 : 1.0));
      let descuento = 0;
      if (diasParaVencer > 0 && diasParaVencer <= 45) descuento = 0.3;
      else if (diasParaVencer > 0 && diasParaVencer <= 90) descuento = 0.15;
      else if (rand() < 0.05) descuento = 0.1; // promoción puntual
      const precioVenta = redondear50(precioOriginal * (1 - descuento));

      // 3) Demanda latente
      let factorEstacional = c.lluvia ? cat.lluvia : cat.seca;
      if (c.mes === 12) factorEstacional *= 1.12 * cat.diciembre;
      if (c.mes === 1) factorEstacional *= cat.enero;
      if (c.mes === 1 && c.semana === 1) factorEstacional *= 0.85;
      const lambda =
        p.base *
        (1 + crecimiento * (t / 52)) *
        factorEstacional *
        (c.quincena ? cat.quincena : 1) *
        Math.pow(0.93, c.festivos) *
        Math.pow(1 - descuento, -1.2);
      let demanda = binomialNegativa(lambda);
      if (rand() < 0.004) demanda = Math.round(demanda * uniforme(3, 6)); // compra institucional atípica

      // 4) Venta observada = demanda censurada por el stock disponible
      const vendidas = Math.min(demanda, stockInicio);
      const quiebre = demanda > stockInicio ? 1 : 0;
      stock = stockInicio - vendidas;
      const nFacturas = vendidas === 0 ? 0 : Math.max(1, Math.round((vendidas / UNIDADES_POR_LINEA[p.presentacion]) * uniforme(0.9, 1.1)));

      // 5) Política de reorden simple (la que se busca mejorar con el pronóstico)
      if (stock <= stockMinimo * 1.5 && pedidoEnTransito === 0) {
        pedidoEnTransito = Math.round(p.base * uniforme(2.5, 4));
        semanasParaLlegada = rand() < 0.06 ? 2 : 1; // retraso ocasional del proveedor
      }

      // 6) Variables rezagadas (solo información disponible al inicio de la semana t)
      const lag = (k) => (t - k >= 0 ? ventas[t - k] : null);
      const ventana4 = t >= 4 ? ventas.slice(t - 4, t) : null;

      filas.push({
        id_registro: filas.length + 1,
        semana_inicio: c.fecha,
        anio: c.anio,
        semana_iso: c.semana,
        mes: c.mes,
        trimestre: c.trimestre,
        producto_codigo: p.codigo,
        producto_nombre: p.nombre,
        categoria: p.categoria,
        presentacion: p.presentacion,
        proveedor_id: p.proveedorId,
        precio_original: precioOriginal,
        precio_venta_promedio: precioVenta,
        descuento_pct: r4(descuento),
        costo_compra: costo,
        margen_pct: r4((precioVenta - costo) / precioVenta),
        stock_inicio_semana: stockInicio,
        stock_minimo: stockMinimo,
        dias_para_vencer: diasParaVencer,
        lote: `L${String(c.anio).slice(2)}${p.codigo}-${String(lote).padStart(2, '0')}`,
        festivos_semana: c.festivos,
        es_quincena: c.quincena,
        temporada_lluvias: c.lluvia,
        ventas_lag_1: lag(1),
        ventas_lag_2: lag(2),
        ventas_lag_4: lag(4),
        media_movil_4: ventana4 ? r2(media(ventana4)) : null,
        desv_movil_4: ventana4 ? r2(desv(ventana4)) : null,
        ventas_lag_52: lag(52),
        num_facturas_lag_1: t >= 1 ? facturas[t - 1] : null,
        quiebre_stock_lag_1: t >= 1 ? quiebres[t - 1] : null,
        demanda_heuristica_actual: heuristicaActual(stockInicio),
        unidades_vendidas: vendidas,
        quiebre_stock: quiebre,
      });
      ventas.push(vendidas);
      facturas.push(nFacturas);
      quiebres.push(quiebre);
    });
  }

  // ---------------------------------------------- Inyección controlada de problemas de calidad
  const problemas = { costo_nulo: 0, vencimiento_nulo: 0, precio_digitacion: 0, categoria_inconsistente: 0 };
  const variantes = {
    'Analgésicos': 'analgesicos', 'Antibióticos': 'ANTIBIOTICOS', 'Antialérgicos': 'Antialergicos',
    'Gastrointestinales': 'gastrointestinales ', 'Cardiometabólicos': 'Cardiometabolicos',
  };
  for (const f of filas) {
    if (rand() < 0.012) { f.costo_compra = null; f.margen_pct = null; problemas.costo_nulo++; }
    if (rand() < 0.008) { f.dias_para_vencer = null; problemas.vencimiento_nulo++; }
    if (rand() < 0.002) { f.precio_venta_promedio = f.precio_venta_promedio * 10; problemas.precio_digitacion++; }
    if (variantes[f.categoria] && rand() < 0.02) { f.categoria = variantes[f.categoria]; problemas.categoria_inconsistente++; }
  }

  return { filas, problemas, calendario };
}

// ---------------------------------------------------------------- Métricas de línea base
function metricas(reales, predichos) {
  const n = reales.length;
  let ae = 0, se = 0, sumReal = 0;
  const m = media(reales);
  let sst = 0;
  for (let i = 0; i < n; i++) {
    const e = reales[i] - predichos[i];
    ae += Math.abs(e);
    se += e * e;
    sumReal += reales[i];
    sst += (reales[i] - m) ** 2;
  }
  return { n, mae: r2(ae / n), rmse: r2(Math.sqrt(se / n)), wape: r4(ae / sumReal), r2: r4(1 - se / sst) };
}

/** Evalúa en el periodo de prueba (jul-dic 2025) los métodos actuales/ingenuos que el modelo de ML debe superar. */
function evaluarLineasBase(filas, fechaCorte = '2025-07-01') {
  const prueba = filas.filter((f) => f.semana_inicio >= fechaCorte && f.media_movil_4 !== null);
  const y = prueba.map((f) => f.unidades_vendidas);
  return {
    fechaCorte,
    registrosEntrenamiento: filas.filter((f) => f.semana_inicio < fechaCorte).length,
    registrosPrueba: prueba.length,
    resultados: [
      { metodo: 'Heurística actual de FARMASIS: max(10, 1,5 × stock)', ...metricas(y, prueba.map((f) => f.demanda_heuristica_actual)) },
      { metodo: 'Ingenuo: ventas de la semana anterior (lag 1)', ...metricas(y, prueba.map((f) => f.ventas_lag_1)) },
      { metodo: 'Media móvil de 4 semanas', ...metricas(y, prueba.map((f) => f.media_movil_4)) },
    ],
  };
}

module.exports = { generarDataset, evaluarLineasBase, PRODUCTOS, PROVEEDORES, CATEGORIAS, SEMILLA, N_SEMANAS, heuristicaActual, media, desv, r2, r4 };
