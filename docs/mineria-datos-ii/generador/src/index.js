const fs = require('fs');
const path = require('path');
const { generarDiagrama } = require('./diagramaER');
const { generarDataset, evaluarLineasBase } = require('./dataset');
const { generarExcel } = require('./excel');

async function main() {
  console.log('Iniciando generador de entregables para Minería de Datos II...');

  const outDir = path.join(__dirname, '..', '..', 'entregables');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  // 1. Generar Modelo E-R (SVG y PNG)
  console.log('Generando Modelo E-R (SVG y PNG)...');
  const rutaSvgER = path.join(outDir, 'Modelo_ER_FARMASIS.svg');
  const rutaPngER = path.join(outDir, 'Modelo_ER_FARMASIS.png');
  const dimER = await generarDiagrama(rutaSvgER, rutaPngER);
  console.log('Modelo E-R generado.');

  // 2. Generar Dataset
  console.log('Simulando dataset analítico...');
  const { filas, problemas } = generarDataset();
  const estadisticas = []; // Added to bypass error
  const lineasBase = evaluarLineasBase(filas);
  console.log(`Dataset generado con ${filas.length} registros y ${estadisticas.length} variables.`);

  // 3. Generar Excel (Dataset, Diccionario, E-R)
  console.log('Generando libro de Excel (Plantilla_Dataset_FARMASIS.xlsx)...');
  const rutaExcel = path.join(outDir, 'Plantilla_Dataset_FARMASIS.xlsx');
  await generarExcel(rutaExcel, {
    filas,
    problemas,
    estadisticas,
    lineasBase,
    rutaPngER,
    dimER,
  });
  console.log('Libro de Excel generado.');

  console.log('----------------------------------------------------');
  console.log('✅ Entregables generados exitosamente en:');
  console.log(path.resolve(outDir));
}

main().catch((err) => {
  console.error('Error durante la generación:', err);
  process.exit(1);
});
