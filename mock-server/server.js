/**
 * FARMASIS - Mockup Server para Contrato de Predicción de Ventas
 * Ejecución: node server.js
 * Puerto: 3000
 */
const http = require('http');
const url = require('url');

const PORT = 3000;

const mockData = {
  'MED-104': {
    nombre: 'Acetaminofén 500mg - Caja x 20',
    categoria: 'ANALGESICOS',
    stock_actual: 32,
    stock_minimo: 30,
    semanal: {
      total_predicho: 380,
      tendencia: 'CRECIENTE',
      riesgo_quiebre: 'ALTO',
      semana_critica: 'Semana 43',
      sugerencia_reorden_unidades: 130,
      serie_datos: [
        { periodo: 'Sem 39', ventas_reales: 65, ventas_predichas: 63, limite_inferior: 55, limite_superior: 72 },
        { periodo: 'Sem 40', ventas_reales: 72, ventas_predichas: 70, limite_inferior: 62, limite_superior: 78 },
        { periodo: 'Sem 41', ventas_reales: 78, ventas_predichas: 76, limite_inferior: 68, limite_superior: 85 },
        { periodo: 'Sem 42', ventas_reales: 84, ventas_predichas: 82, limite_inferior: 74, limite_superior: 90 },
        { periodo: 'Sem 43', ventas_reales: null, ventas_predichas: 98, limite_inferior: 88, limite_superior: 108 },
        { periodo: 'Sem 44', ventas_reales: null, ventas_predichas: 92, limite_inferior: 82, limite_superior: 102 }
      ]
    },
    mensual: {
      total_predicho: 1320,
      tendencia: 'CRECIENTE',
      riesgo_quiebre: 'ALTO',
      mes_critico: 'Diciembre',
      sugerencia_reorden_unidades: 450,
      serie_datos: [
        { periodo: 'Jul', ventas_reales: 280, ventas_predichas: 275, limite_inferior: 250, limite_superior: 300 },
        { periodo: 'Ago', ventas_reales: 310, ventas_predichas: 305, limite_inferior: 280, limite_superior: 330 },
        { periodo: 'Sep', ventas_reales: 345, ventas_predichas: 330, limite_inferior: 300, limite_superior: 360 },
        { periodo: 'Oct', ventas_reales: null, ventas_predichas: 360, limite_inferior: 320, limite_superior: 400 },
        { periodo: 'Nov', ventas_reales: null, ventas_predichas: 390, limite_inferior: 350, limite_superior: 430 },
        { periodo: 'Dic', ventas_reales: null, ventas_predichas: 420, limite_inferior: 380, limite_superior: 460 }
      ]
    },
    diario: {
      total_predicho: 64,
      tendencia: 'ESTABLE',
      riesgo_quiebre: 'MEDIO',
      dia_critico: 'Viernes',
      sugerencia_reorden_unidades: 40,
      serie_datos: [
        { periodo: 'Lun', ventas_reales: 8, ventas_predichas: 9, limite_inferior: 6, limite_superior: 12 },
        { periodo: 'Mar', ventas_reales: 11, ventas_predichas: 10, limite_inferior: 7, limite_superior: 13 },
        { periodo: 'Mie', ventas_reales: 9, ventas_predichas: 10, limite_inferior: 7, limite_superior: 13 },
        { periodo: 'Jue', ventas_reales: 14, ventas_predichas: 12, limite_inferior: 9, limite_superior: 15 },
        { periodo: 'Vie', ventas_reales: null, ventas_predichas: 18, limite_inferior: 14, limite_superior: 22 },
        { periodo: 'Sab', ventas_reales: null, ventas_predichas: 15, limite_inferior: 11, limite_superior: 19 },
        { periodo: 'Dom', ventas_reales: null, ventas_predichas: 6, limite_inferior: 3, limite_superior: 9 }
      ]
    }
  },
  'MED-202': {
    nombre: 'Ibuprofeno 400mg - Caja x 30',
    categoria: 'ANALGESICOS / ANTIINFLAMATORIOS',
    stock_actual: 85,
    stock_minimo: 25,
    semanal: {
      total_predicho: 190,
      tendencia: 'ESTABLE',
      riesgo_quiebre: 'BAJO',
      semana_critica: 'Ninguna',
      sugerencia_reorden_unidades: 0,
      serie_datos: [
        { periodo: 'Sem 39', ventas_reales: 35, ventas_predichas: 34, limite_inferior: 30, limite_superior: 38 },
        { periodo: 'Sem 40', ventas_reales: 38, ventas_predichas: 36, limite_inferior: 32, limite_superior: 40 },
        { periodo: 'Sem 41', ventas_reales: 32, ventas_predichas: 35, limite_inferior: 30, limite_superior: 39 },
        { periodo: 'Sem 42', ventas_reales: 36, ventas_predichas: 37, limite_inferior: 33, limite_superior: 41 },
        { periodo: 'Sem 43', ventas_reales: null, ventas_predichas: 38, limite_inferior: 34, limite_superior: 42 },
        { periodo: 'Sem 44', ventas_reales: null, ventas_predichas: 36, limite_inferior: 31, limite_superior: 41 }
      ]
    }
  }
};

const server = http.createServer((req, res) => {
  // CORS Headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const query = parsedUrl.query;

  // Endpoint: POST /api/v1/auth/login
  if (req.method === 'POST' && pathname === '/api/v1/auth/login') {
    let body = '';
    req.on('data', chunk => { body += chunk.toString(); });
    req.on('end', () => {
      try {
        const payload = JSON.parse(body || '{}');
        const username = payload.username || 'admin';
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
          status: 'success',
          message: 'Inicio de sesión exitoso (Mock Server)',
          usuario: {
            id: 'mock-user-id',
            username: username,
            nombre: 'Juan',
            apellido: 'Garces',
            email: 'juan.garces028@gmail.com',
            rol: 'ADMIN',
            activo: true
          }
        }, null, 2));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'error', message: 'JSON inválido' }));
      }
    });
    return;
  }

  // Endpoint: GET /api/v1/prediccion/ventas
  if (req.method === 'GET' && pathname === '/api/v1/prediccion/ventas') {
    const prodId = query.productoId || 'MED-104';
    const temporalidad = (query.temporalidad || 'SEMANAL').toLowerCase();

    const prod = mockData[prodId] || mockData['MED-104'];
    const dataTemp = prod[temporalidad] || prod.semanal;

    const response = {
      status: 'OK',
      producto: {
        codigo: prodId,
        nombre: prod.nombre,
        categoria: prod.categoria,
        stock_actual: prod.stock_actual,
        stock_minimo: prod.stock_minimo
      },
      temporalidad: temporalidad.toUpperCase(),
      resumen: {
        total_predicho: dataTemp.total_predicho,
        tendencia: dataTemp.tendencia,
        riesgo_quiebre: dataTemp.riesgo_quiebre,
        semana_critica: dataTemp.semana_critica || dataTemp.dia_critico || dataTemp.mes_critico,
        sugerencia_reorden_unidades: dataTemp.sugerencia_reorden_unidades
      },
      serie_datos: dataTemp.serie_datos
    };

    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(response, null, 2));
    return;
  }

  // 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Endpoint no encontrado en el Mock Server' }));
});

server.listen(PORT, () => {
  console.log(`Mockup Server corriendo en http://localhost:${PORT}`);
  console.log(`Endpoint de prueba: http://localhost:${PORT}/api/v1/prediccion/ventas?productoId=MED-104&temporalidad=SEMANAL`);
});
