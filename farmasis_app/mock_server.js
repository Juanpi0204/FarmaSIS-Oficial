/**
 * =====================================================================
 *  FARMASIS - MOCK SERVER OFICIAL (Node.js)
 *  Taller Proyecto de Aula Digital: Mock Server y Contrato de API
 * =====================================================================
 *  Este servidor simula el servicio de predicción de ventas y demanda
 *  farmacéutica de FarmaSIS para que la aplicación móvil en Flutter
 *  consuma el contrato de datos mediante peticiones HTTP REST reales.
 * 
 *  Puerto por defecto: 3000
 *  Ejecución: node mock_server.js
 * =====================================================================
 */

const http = require('http');
const url = require('url');

const PORT = 3000;

// Catálogo de medicamentos del contrato (10 fármacos)
const PRODUCTOS_CATALOGO = [
  { id: 'MED-104', nombre: 'Acetaminofén 500mg (MED-104)', categoria: 'ANALGESICOS', stockActual: 32, stockMinimo: 30, baseSemanal: 380, tendencia: 'CRECIENTE', riesgoQuiebre: 'ALTO', semanaCritica: 'Semana 43', diaCritico: 'Viernes', mesCritico: 'Diciembre', sugerenciaReorden: 130 },
  { id: 'MED-202', nombre: 'Ibuprofeno 400mg (MED-202)', categoria: 'ANTIINFLAMATORIOS', stockActual: 95, stockMinimo: 40, baseSemanal: 210, tendencia: 'ESTABLE', riesgoQuiebre: 'BAJO', semanaCritica: 'Semana 44', diaCritico: 'Domingo', mesCritico: 'Diciembre', sugerenciaReorden: 0 },
  { id: 'MED-305', nombre: 'Amoxicilina 500mg (MED-305)', categoria: 'ANTIBIOTICOS', stockActual: 18, stockMinimo: 35, baseSemanal: 165, tendencia: 'CRECIENTE', riesgoQuiebre: 'ALTO', semanaCritica: 'Semana 42', diaCritico: 'Jueves', mesCritico: 'Noviembre', sugerenciaReorden: 95 },
  { id: 'MED-410', nombre: 'Losartán 50mg (MED-410)', categoria: 'ANTIHIPERTENSIVOS', stockActual: 55, stockMinimo: 35, baseSemanal: 240, tendencia: 'ESTABLE', riesgoQuiebre: 'MEDIO', semanaCritica: 'Semana 43', diaCritico: 'Viernes', mesCritico: 'Diciembre', sugerenciaReorden: 65 },
  { id: 'MED-512', nombre: 'Omeprazol 20mg (MED-512)', categoria: 'GASTROINTESTINALES', stockActual: 140, stockMinimo: 50, baseSemanal: 310, tendencia: 'ESTABLE', riesgoQuiebre: 'BAJO', semanaCritica: 'Semana 44', diaCritico: 'Sábado', mesCritico: 'Noviembre', sugerenciaReorden: 0 },
  { id: 'MED-618', nombre: 'Loratadina 10mg (MED-618)', categoria: 'ANTIHISTAMINICOS', stockActual: 22, stockMinimo: 30, baseSemanal: 195, tendencia: 'CRECIENTE', riesgoQuiebre: 'ALTO', semanaCritica: 'Semana 43', diaCritico: 'Viernes', mesCritico: 'Diciembre', sugerenciaReorden: 85 },
  { id: 'MED-725', nombre: 'Metformina 850mg (MED-725)', categoria: 'ANTIDIABETICOS', stockActual: 70, stockMinimo: 45, baseSemanal: 285, tendencia: 'ESTABLE', riesgoQuiebre: 'MEDIO', semanaCritica: 'Semana 44', diaCritico: 'Sábado', mesCritico: 'Noviembre', sugerenciaReorden: 55 },
  { id: 'MED-830', nombre: 'Azitromicina 500mg (MED-830)', categoria: 'ANTIBIOTICOS', stockActual: 14, stockMinimo: 25, baseSemanal: 145, tendencia: 'CRECIENTE', riesgoQuiebre: 'ALTO', semanaCritica: 'Semana 42', diaCritico: 'Miércoles', mesCritico: 'Octubre', sugerenciaReorden: 80 },
  { id: 'MED-942', nombre: 'Salbutamol Inhalador 100mcg (MED-942)', categoria: 'RESPIRATORIOS', stockActual: 40, stockMinimo: 25, baseSemanal: 180, tendencia: 'CRECIENTE', riesgoQuiebre: 'MEDIO', semanaCritica: 'Semana 43', diaCritico: 'Jueves', mesCritico: 'Diciembre', sugerenciaReorden: 50 },
  { id: 'MED-105', nombre: 'Diclofenaco Sódico 50mg (MED-105)', categoria: 'ANTIINFLAMATORIOS', stockActual: 110, stockMinimo: 35, baseSemanal: 175, tendencia: 'ESTABLE', riesgoQuiebre: 'BAJO', semanaCritica: 'Semana 44', diaCritico: 'Domingo', mesCritico: 'Noviembre', sugerenciaReorden: 0 }
];

function buscarProducto(id) {
  return PRODUCTOS_CATALOGO.find(p => p.id === id) || PRODUCTOS_CATALOGO[0];
}

// Generador de Contrato JSON según Producto y Temporalidad
function generarRespuestaContrato(productoId, temporalidad) {
  const p = buscarProducto(productoId);
  const temp = (temporalidad || 'SEMANAL').toUpperCase();

  if (temp === 'DIARIO') {
    const d = Math.round(p.baseSemanal / 6);
    return {
      status: 'OK',
      producto: {
        codigo: p.id,
        nombre: p.nombre,
        categoria: p.categoria,
        stock_actual: p.stockActual,
        stock_minimo: p.stockMinimo
      },
      temporalidad: 'DIARIO',
      resumen: {
        total_predicho: Math.round(d * 5.8),
        tendencia: p.tendencia,
        riesgo_quiebre: p.riesgoQuiebre,
        dia_critico: p.diaCritico,
        sugerencia_reorden_unidades: Math.round(p.sugerenciaReorden / 3)
      },
      serie_datos: [
        { periodo: 'Lun', ventas_reales: Math.round(d * 0.7), ventas_predichas: Math.round(d * 0.8), limite_inferior: Math.round(d * 0.5), limite_superior: Math.round(d * 1.0) },
        { periodo: 'Mar', ventas_reales: Math.round(d * 0.9), ventas_predichas: Math.round(d * 0.9), limite_inferior: Math.round(d * 0.6), limite_superior: Math.round(d * 1.1) },
        { periodo: 'Mie', ventas_reales: Math.round(d * 0.8), ventas_predichas: Math.round(d * 0.9), limite_inferior: Math.round(d * 0.6), limite_superior: Math.round(d * 1.1) },
        { periodo: 'Jue', ventas_reales: Math.round(d * 1.1), ventas_predichas: Math.round(d * 1.0), limite_inferior: Math.round(d * 0.8), limite_superior: Math.round(d * 1.3) },
        { periodo: 'Vie', ventas_reales: null, ventas_predichas: Math.round(d * 1.5), limite_inferior: Math.round(d * 1.2), limite_superior: Math.round(d * 1.8) },
        { periodo: 'Sab', ventas_reales: null, ventas_predichas: Math.round(d * 1.3), limite_inferior: Math.round(d * 0.9), limite_superior: Math.round(d * 1.6) },
        { periodo: 'Dom', ventas_reales: null, ventas_predichas: Math.round(d * 0.6), limite_inferior: Math.round(d * 0.3), limite_superior: Math.round(d * 0.9) }
      ]
    };
  }

  if (temp === 'MENSUAL') {
    const m = Math.round(p.baseSemanal * 3.6);
    return {
      status: 'OK',
      producto: {
        codigo: p.id,
        nombre: p.nombre,
        categoria: p.categoria,
        stock_actual: p.stockActual,
        stock_minimo: p.stockMinimo
      },
      temporalidad: 'MENSUAL',
      resumen: {
        total_predicho: m,
        tendencia: p.tendencia,
        riesgo_quiebre: p.riesgoQuiebre,
        mes_critico: p.mesCritico,
        sugerencia_reorden_unidades: Math.round(p.sugerenciaReorden * 3.5)
      },
      serie_datos: [
        { periodo: 'Jul', ventas_reales: Math.round(m * 0.20), ventas_predichas: Math.round(m * 0.19), limite_inferior: Math.round(m * 0.17), limite_superior: Math.round(m * 0.22) },
        { periodo: 'Ago', ventas_reales: Math.round(m * 0.22), ventas_predichas: Math.round(m * 0.21), limite_inferior: Math.round(m * 0.19), limite_superior: Math.round(m * 0.24) },
        { periodo: 'Sep', ventas_reales: Math.round(m * 0.25), ventas_predichas: Math.round(m * 0.24), limite_inferior: Math.round(m * 0.21), limite_superior: Math.round(m * 0.26) },
        { periodo: 'Oct', ventas_reales: null, ventas_predichas: Math.round(m * 0.26), limite_inferior: Math.round(m * 0.23), limite_superior: Math.round(m * 0.29) },
        { periodo: 'Nov', ventas_reales: null, ventas_predichas: Math.round(m * 0.28), limite_inferior: Math.round(m * 0.25), limite_superior: Math.round(m * 0.31) },
        { periodo: 'Dic', ventas_reales: null, ventas_predichas: Math.round(m * 0.30), limite_inferior: Math.round(m * 0.27), limite_superior: Math.round(m * 0.33) }
      ]
    };
  }

  // SEMANAL (Por defecto)
  const b = p.baseSemanal / 4;
  const p1 = Math.round(b * 0.85);
  const p2 = Math.round(b * 0.95);
  const p3 = Math.round(b * 1.02);
  const p4 = Math.round(b * 1.10);
  const p5 = Math.round(b * 1.28);
  const p6 = Math.round(b * 1.20);

  return {
    status: 'OK',
    producto: {
      codigo: p.id,
      nombre: p.nombre,
      categoria: p.categoria,
      stock_actual: p.stockActual,
      stock_minimo: p.stockMinimo
    },
    temporalidad: 'SEMANAL',
    resumen: {
      total_predicho: p.baseSemanal,
      tendencia: p.tendencia,
      riesgo_quiebre: p.riesgoQuiebre,
      semana_critica: p.semanaCritica,
      sugerencia_reorden_unidades: p.sugerenciaReorden
    },
    serie_datos: [
      { periodo: 'Sem 39', ventas_reales: p1, ventas_predichas: Math.round(p1 * 0.98), limite_inferior: Math.round(p1 * 0.85), limite_superior: Math.round(p1 * 1.12) },
      { periodo: 'Sem 40', ventas_reales: p2, ventas_predichas: Math.round(p2 * 0.97), limite_inferior: Math.round(p2 * 0.86), limite_superior: Math.round(p2 * 1.10) },
      { periodo: 'Sem 41', ventas_reales: p3, ventas_predichas: Math.round(p3 * 0.98), limite_inferior: Math.round(p3 * 0.88), limite_superior: Math.round(p3 * 1.11) },
      { periodo: 'Sem 42', ventas_reales: p4, ventas_predichas: Math.round(p4 * 0.98), limite_inferior: Math.round(p4 * 0.89), limite_superior: Math.round(p4 * 1.10) },
      { periodo: 'Sem 43', ventas_reales: null, ventas_predichas: p5, limite_inferior: Math.round(p5 * 0.90), limite_superior: Math.round(p5 * 1.12) },
      { periodo: 'Sem 44', ventas_reales: null, ventas_predichas: p6, limite_inferior: Math.round(p6 * 0.88), limite_superior: Math.round(p6 * 1.11) }
    ]
  };
}

// Servidor HTTP con CORS y enrutamiento
const server = http.createServer((req, res) => {
  // Encabezados CORS universales para Flutter (Web, Android y Desktop)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Accept, Authorization');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const query = parsedUrl.query;

  const timestamp = new Date().toLocaleTimeString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);

  // ENDPOINT 1: Predicción de Ventas (CONTRATO OFICIAL)
  // GET /api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL
  if (req.method === 'GET' && pathname === '/api/v1/prediccion/ventas') {
    const productoId = query.productoId || 'MED-104';
    const temporalidad = query.temporalidad || 'SEMANAL';

    const data = generarRespuestaContrato(productoId, temporalidad);
    res.writeHead(200);
    res.end(JSON.stringify(data, null, 2));
    return;
  }

  // ENDPOINT 2: Catálogo de Productos
  // GET /api/v1/productos
  if (req.method === 'GET' && pathname === '/api/v1/productos') {
    const lista = PRODUCTOS_CATALOGO.map(p => ({ id: p.id, nombre: p.nombre, categoria: p.categoria }));
    res.writeHead(200);
    res.end(JSON.stringify({ status: 'success', count: lista.length, productos: lista }, null, 2));
    return;
  }

  // ENDPOINT 3: Autenticación en Mock Server (Login)
  // POST /api/v1/auth/login
  if (req.method === 'POST' && pathname === '/api/v1/auth/login') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      let username = 'admin';
      if (body && body.trim().length > 0) {
        try {
          const credentials = JSON.parse(body);
          if (credentials.username) username = credentials.username.trim();
        } catch (e) {
          console.log('[MockServer] Aviso: Body recibido no es JSON estricto, usando usuario por defecto');
        }
      }

      res.writeHead(200);
      res.end(JSON.stringify({
        status: 'success',
        message: 'Autenticación exitosa en Mock Server FarmaSIS',
        usuario: {
          id: 'mock-usr-001',
          username: username,
          nombre: username.toLowerCase() === 'admin' ? 'Juan' : username,
          apellido: username.toLowerCase() === 'admin' ? 'Garces' : 'FarmaSIS',
          email: username.includes('@') ? username : 'juan.garces028@gmail.com',
          rol: 'ADMIN',
          activo: true
        }
      }, null, 2));
    });
    return;
  }

  // RUTA RAÍZ O STATUS
  if (pathname === '/' || pathname === '/status') {
    res.writeHead(200);
    res.end(JSON.stringify({
      server: 'FARMASIS Mock Server',
      status: 'ONLINE',
      puerto: PORT,
      endpoints: [
        'GET  /api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL',
        'GET  /api/v1/productos',
        'POST /api/v1/auth/login'
      ]
    }, null, 2));
    return;
  }

  // Ruta no encontrada
  res.writeHead(404);
  res.end(JSON.stringify({ status: 'error', message: `Ruta no encontrada: ${pathname}` }));
});

server.listen(PORT, () => {
  console.log('=============================================================');
  console.log(`  🚀 FARMASIS MOCK SERVER CORRIENDO EN: http://localhost:${PORT}`);
  console.log('=============================================================');
  console.log(`  • Endpoints disponibles:`);
  console.log(`    - GET  http://localhost:${PORT}/api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL`);
  console.log(`    - GET  http://localhost:${PORT}/api/v1/productos`);
  console.log(`    - POST http://localhost:${PORT}/api/v1/auth/login`);
  console.log('=============================================================');
  console.log('  Listo para recibir peticiones HTTP desde Flutter / Postman...\n');
});
