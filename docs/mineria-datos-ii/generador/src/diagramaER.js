/**
 * Dibuja el Modelo Entidad-Relación de FARMASIS en SVG (notación pata de gallo / Crow's Foot)
 * y lo rasteriza a PNG con sharp.
 */
const sharp = require('sharp');
const { ENTIDADES, RELACIONES } = require('./schema');

const W = 320;
const HEADER = 48;
const FILA = 20;
const COL = [40, 470, 900, 1330, 1760, 2190];
const ANCHO = 2550;
const ALTO = 1250;
const FUENTE = 'Arial, Helvetica, sans-serif';

const COLORES = {
  MySQL: { cab: '#1e5aa8', borde: '#1e5aa8' },
  MongoDB: { cab: '#2e7d32', borde: '#2e7d32' },
  'MongoDB (embebido)': { cab: '#00897b', borde: '#00897b' },
  propuesta: { cab: '#d9730d', borde: '#d9730d' },
};

// Posición (columna, y) de cada entidad
const POS = {
  PROVEEDOR: [0, 120],
  CONFIGURACION_SISTEMA: [0, 480],
  PRODUCTO: [1, 120],
  RESULTADO_OPTIMIZACION: [1, 640],
  DETALLE_FACTURA: [2, 200],
  PREDICCION_DEMANDA: [2, 560],
  MODELO_ML: [2, 880],
  FACTURA: [3, 120],
  CLIENTE: [3, 520],
  USUARIO: [4, 120],
  ASISTENCIA: [5, 120],
  NOVEDAD: [5, 360],
  AUDITORIA: [5, 690],
};

// Trazado de cada relación: lista de puntos desde el lado ORIGEN hasta el lado DESTINO
const RUTAS = {
  R1: [[360, 250], [470, 250]],
  R2: [[790, 290], [900, 290]],
  R3: [[1330, 290], [1220, 290]],
  R4: [[1490, 520], [1490, 414]],
  R5: [[1760, 300], [1650, 300]],
  R6: [[2080, 200], [2190, 200]],
  R7: [[2080, 420], [2190, 420]],
  R8: [[2080, 480], [2190, 480]],
  R9: [[2020, 514], [2020, 790], [2190, 790]],
  R10: [[1920, 120], [1920, 92], [200, 92], [200, 120]],
  R11: [[630, 554], [630, 640]],
  R12: [[790, 530], [845, 530], [845, 660], [900, 660]],
  R13: [[1060, 880], [1060, 794]],
};

// Etiquetas con posición manual (x, y, rotación) cuando el segmento es demasiado corto
const ETIQUETAS = {
  R12: [838, 595, -90],
};

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const tipoCorto = (tipo, long) => (long && /VARCHAR/.test(tipo) ? `${tipo}(${long})` : tipo);
const etiquetaClave = (k) => ({ PK: 'PK', FK: 'FK', UK: 'UK', 'FK lógica': 'FK*' }[k] || '');

function dibujarEntidad(e) {
  const [col, y] = POS[e.id];
  const x = COL[col];
  const h = HEADER + e.campos.length * FILA + 8;
  const c = e.estado === 'Propuesta MD II' ? COLORES.propuesta : COLORES[e.motor];
  const discontinuo = e.debil ? ' stroke-dasharray="8 4"' : '';
  const sub = `${e.motor === 'MongoDB (embebido)' ? 'Subdocumento' : e.motor} · ${e.nombreFisico}${e.estado === 'Propuesta MD II' ? ' · PROPUESTA' : ''}`;
  let s = `<g>
  <rect x="${x + 4}" y="${y + 4}" width="${W}" height="${h}" rx="8" fill="#00000022"/>
  <rect x="${x}" y="${y}" width="${W}" height="${h}" rx="8" fill="#ffffff" stroke="${c.borde}" stroke-width="${e.debil ? 2.5 : 2}"${discontinuo}/>
  <path d="M${x} ${y + 8} a8 8 0 0 1 8 -8 h${W - 16} a8 8 0 0 1 8 8 v${HEADER - 8} h${-W} z" fill="${c.cab}"/>
  <text x="${x + W / 2}" y="${y + 21}" font-family="${FUENTE}" font-size="15" font-weight="bold" fill="#fff" text-anchor="middle">${esc(e.id)}</text>
  <text x="${x + W / 2}" y="${y + 39}" font-family="${FUENTE}" font-size="11" fill="#ffffffdd" text-anchor="middle">${esc(sub)}</text>`;
  e.campos.forEach(([nombre, tipo, long, , clave], i) => {
    const fy = y + HEADER + i * FILA;
    if (i % 2 === 1) s += `\n  <rect x="${x + 1}" y="${fy}" width="${W - 2}" height="${FILA}" fill="#f2f5f9"/>`;
    const k = etiquetaClave(clave);
    const colorK = { PK: '#b8860b', FK: '#1e5aa8', UK: '#6a1b9a', 'FK*': '#c62828' }[k];
    if (k) s += `\n  <text x="${x + 10}" y="${fy + 14}" font-family="${FUENTE}" font-size="10" font-weight="bold" fill="${colorK}">${k}</text>`;
    const negrita = clave === 'PK' ? ' font-weight="bold"' : '';
    const sub2 = clave === 'PK' ? ' text-decoration="underline"' : '';
    s += `\n  <text x="${x + 42}" y="${fy + 14}" font-family="${FUENTE}" font-size="12" fill="#1f2933"${negrita}${sub2}>${esc(nombre)}</text>`;
    s += `\n  <text x="${x + W - 10}" y="${fy + 14}" font-family="${FUENTE}" font-size="11" fill="#6b7785" text-anchor="end">${esc(tipoCorto(tipo, long))}</text>`;
  });
  return s + '\n</g>';
}

/** Marcador pata de gallo en el punto P; u = vector unitario que apunta hacia la entidad. */
function marcador(P, u, card, color) {
  const [min, max] = card.split(',');
  const n = [-u[1], u[0]];
  const at = (d, o = 0) => [P[0] - u[0] * d + n[0] * o, P[1] - u[1] * d + n[1] * o];
  const linea = (a, b) => `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${color}" stroke-width="2"/>`;
  let s = '';
  if (max === 'N') {
    s += linea(at(16), at(0, 9)) + linea(at(16), at(0, 0)) + linea(at(16), at(0, -9));
  } else {
    s += linea(at(8, 8), at(8, -8));
  }
  if (min === '1') s += linea(at(max === 'N' ? 20 : 15, 8), at(max === 'N' ? 20 : 15, -8));
  else {
    const c = at(max === 'N' ? 25 : 21);
    s += `<circle cx="${c[0]}" cy="${c[1]}" r="5" fill="#fff" stroke="${color}" stroke-width="2"/>`;
  }
  return s;
}

function dibujarRelacion(r) {
  const pts = RUTAS[r.id];
  const color = r.nueva ? '#d9730d' : r.tipo === 'composición' ? '#00897b' : '#37474f';
  const guion = r.tipo === 'lógica' ? ' stroke-dasharray="7 5"' : '';
  const ancho = r.tipo === 'composición' ? 3 : 2;
  let s = `<polyline points="${pts.map((p) => p.join(',')).join(' ')}" fill="none" stroke="${color}" stroke-width="${ancho}"${guion}/>`;
  const unit = (a, b) => {
    const dx = b[0] - a[0];
    const dy = b[1] - a[1];
    const l = Math.hypot(dx, dy);
    return [dx / l, dy / l];
  };
  const ini = pts[0];
  const fin = pts[pts.length - 1];
  s += marcador(ini, unit(pts[1], ini), r.card[0], color);
  s += marcador(fin, unit(pts[pts.length - 2], fin), r.card[1], color);

  // Etiqueta del verbo sobre el segmento más largo
  let mejor = 0;
  let largo = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const l = Math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]);
    if (l > largo) { largo = l; mejor = i; }
  }
  const a = pts[mejor];
  const b = pts[mejor + 1];
  const mx = (a[0] + b[0]) / 2;
  const my = (a[1] + b[1]) / 2;
  const vertical = a[0] === b[0];
  const texto = `${r.id}: ${r.verbo}`;
  const tw = texto.length * 6.1 + 8;
  if (ETIQUETAS[r.id]) {
    const [ex, ey, rot] = ETIQUETAS[r.id];
    s += `<text x="${ex}" y="${ey}" transform="rotate(${rot} ${ex} ${ey})" font-family="${FUENTE}" font-size="11" font-style="italic" fill="${color}" text-anchor="middle">${esc(texto)}</text>`;
  } else if (vertical) {
    s += `<rect x="${mx + 6}" y="${my - 9}" width="${tw}" height="17" rx="3" fill="#ffffffee"/>`;
    s += `<text x="${mx + 10}" y="${my + 4}" font-family="${FUENTE}" font-size="11" font-style="italic" fill="${color}">${esc(texto)}</text>`;
  } else {
    s += `<rect x="${mx - tw / 2}" y="${my - 22}" width="${tw}" height="16" rx="3" fill="#ffffffee"/>`;
    s += `<text x="${mx}" y="${my - 10}" font-family="${FUENTE}" font-size="11" font-style="italic" fill="${color}" text-anchor="middle">${esc(texto)}</text>`;
  }
  // Cardinalidades (min,max) junto a cada extremo
  // Horizontal: debajo de la línea. Vertical: a la izquierda. (Los verbos van arriba / a la derecha.)
  const cardTxt = (P, u, txt) => {
    const estilo = `font-family="${FUENTE}" font-size="10" font-weight="bold" fill="${color}"`;
    if (u[1] === 0) {
      return `<text x="${P[0] - u[0] * 30}" y="${P[1] + 20}" ${estilo} text-anchor="middle">(${txt})</text>`;
    }
    return `<text x="${P[0] - 8}" y="${P[1] - u[1] * 34 + 4}" ${estilo} text-anchor="end">(${txt})</text>`;
  };
  s += cardTxt(ini, unit(pts[1], ini), r.card[0]);
  s += cardTxt(fin, unit(pts[pts.length - 2], fin), r.card[1]);
  return s;
}

function dibujarLeyenda() {
  const x = 40;
  const y = 900;
  let s = `<rect x="${x}" y="${y}" width="790" height="320" rx="10" fill="#fafbfc" stroke="#c5ced8"/>
<text x="${x + 20}" y="${y + 30}" font-family="${FUENTE}" font-size="15" font-weight="bold" fill="#1f2933">Convenciones</text>`;
  const cajas = [
    ['#1e5aa8', 'Tabla MySQL (JPA / Hibernate)', false],
    ['#2e7d32', 'Colección MongoDB Atlas', false],
    ['#00897b', 'Subdocumento embebido (entidad débil)', true],
    ['#d9730d', 'Colección propuesta – Minería de Datos II', false],
  ];
  cajas.forEach(([c, t, d], i) => {
    const yy = y + 50 + i * 30;
    s += `<rect x="${x + 20}" y="${yy}" width="34" height="20" rx="4" fill="${c}"${d ? ' stroke="#004d40" stroke-dasharray="4 2"' : ''}/>`;
    s += `<text x="${x + 64}" y="${yy + 15}" font-family="${FUENTE}" font-size="12" fill="#1f2933">${t}</text>`;
  });
  const lineas = [
    ['#37474f', '', 2, 'FK con integridad referencial (MySQL)'],
    ['#37474f', '7 5', 2, 'Referencia lógica por valor (MongoDB / entre motores)'],
    ['#00897b', '', 3, 'Composición (documento embebido)'],
    ['#d9730d', '7 5', 2, 'Relación nueva propuesta'],
  ];
  lineas.forEach(([c, g, w, t], i) => {
    const yy = y + 60 + (i + 4) * 30;
    s += `<line x1="${x + 20}" y1="${yy}" x2="${x + 54}" y2="${yy}" stroke="${c}" stroke-width="${w}"${g ? ` stroke-dasharray="${g}"` : ''}/>`;
    s += `<text x="${x + 64}" y="${yy + 4}" font-family="${FUENTE}" font-size="12" fill="#1f2933">${t}</text>`;
  });
  // Notación pata de gallo
  const nx = x + 440;
  s += `<text x="${nx}" y="${y + 62}" font-family="${FUENTE}" font-size="13" font-weight="bold" fill="#1f2933">Cardinalidad (min,max)</text>`;
  [['1,1', 'Uno y solo uno'], ['0,1', 'Cero o uno'], ['1,N', 'Uno o muchos'], ['0,N', 'Cero o muchos']].forEach(([c, t], i) => {
    const yy = y + 92 + i * 34;
    s += `<line x1="${nx}" y1="${yy}" x2="${nx + 60}" y2="${yy}" stroke="#37474f" stroke-width="2"/>`;
    s += marcador([nx + 60, yy], [1, 0], c, '#37474f');
    s += `<text x="${nx + 75}" y="${yy + 4}" font-family="${FUENTE}" font-size="12" fill="#1f2933">(${c}) ${t}</text>`;
  });
  s += `<text x="${nx}" y="${y + 240}" font-family="${FUENTE}" font-size="12" fill="#1f2933"><tspan font-weight="bold" fill="#b8860b">PK</tspan> clave primaria   <tspan font-weight="bold" fill="#6a1b9a">UK</tspan> única   <tspan font-weight="bold" fill="#1e5aa8">FK</tspan> foránea</text>`;
  s += `<text x="${nx}" y="${y + 262}" font-family="${FUENTE}" font-size="12" fill="#1f2933"><tspan font-weight="bold" fill="#c62828">FK*</tspan> foránea lógica (no forzada por el motor)</text>`;
  return s;
}

function generarSvg() {
  const ents = ENTIDADES.map(dibujarEntidad).join('\n');
  const rels = RELACIONES.map(dibujarRelacion).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${ANCHO}" height="${ALTO}" viewBox="0 0 ${ANCHO} ${ALTO}">
<rect width="100%" height="100%" fill="#ffffff"/>
<text x="40" y="44" font-family="${FUENTE}" font-size="26" font-weight="bold" fill="#102a43">Modelo Entidad-Relación – FARMASIS</text>
<text x="40" y="70" font-family="${FUENTE}" font-size="14" fill="#52606d">Persistencia híbrida MySQL + MongoDB Atlas · Extensión analítica para el pronóstico de demanda (Minería de Datos II)</text>
${rels}
${ents}
${dibujarLeyenda()}
</svg>`;
}

async function generarDiagrama(rutaSvg, rutaPng) {
  const fs = require('fs');
  const svg = generarSvg();
  fs.writeFileSync(rutaSvg, svg, 'utf8');
  await sharp(Buffer.from(svg), { density: 144 }).png().toFile(rutaPng);
  const meta = await sharp(rutaPng).metadata();
  return { ancho: meta.width, alto: meta.height };
}

module.exports = { generarDiagrama };
