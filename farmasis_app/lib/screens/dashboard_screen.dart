import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/user_model.dart';
import '../models/prediction_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedProducto = 'MED-104';
  String _selectedTemporalidad = 'SEMANAL';

  late Future<ContratoPrediccionResponse> _futurePrediccion;
  late TooltipBehavior _tooltipBehavior;

  // Productos del servidor activo (con Spring Boot son los productos reales de MongoDB).
  List<Map<String, String>> _productos = [];

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _futurePrediccion = _cargarConProductos();
  }

  /// Carga el catálogo del servidor activo y luego consulta la predicción del producto seleccionado.
  Future<ContratoPrediccionResponse> _cargarConProductos() async {
    var lista = await ApiService.getProductosRemotos();
    if (lista.isEmpty && !ApiService.useProductionBackend) {
      lista = ApiService.getProductos(); // El Mock Server siempre trae su catálogo de ejemplo.
    }
    if (lista.isEmpty) {
      throw Exception(
          'No se pudieron cargar productos del servidor. Verifique que el backend esté corriendo y que existan productos registrados.');
    }
    _productos = lista;
    if (!_productos.any((p) => p['id'] == _selectedProducto)) {
      _selectedProducto = _productos.first['id']!; // Si el producto elegido no existe en este servidor, usa el primero.
    }
    return ApiService.getPrediccion(
      productoId: _selectedProducto,
      temporalidad: _selectedTemporalidad,
    );
  }

  /// Recarga catálogo + predicción (al reintentar o cambiar de servidor).
  void _inicializar() {
    setState(() {
      _futurePrediccion = _cargarConProductos();
    });
  }

  /// Recarga solo la predicción (al cambiar de producto o de temporalidad).
  void _cargarDatos() {
    setState(() {
      _futurePrediccion = ApiService.getPrediccion(
        productoId: _selectedProducto,
        temporalidad: _selectedTemporalidad,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F3), // Fondo gris-menta idéntico a Figma
      body: FutureBuilder<ContratoPrediccionResponse>(
        future: _futurePrediccion,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFDC2626)),
                    const SizedBox(height: 14),
                    Text(
                      '${snapshot.error}'.replaceAll('Exception:', '').trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _inicializar,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(ApiService.useProductionBackend
                          ? 'Reintentar conexión a Spring Boot (8092)'
                          : 'Reintentar conexión al Mock Server (3000)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        ApiService.useProductionBackend = !ApiService.useProductionBackend;
                        _inicializar();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: Text(
                        ApiService.useProductionBackend
                            ? 'Cambiar a Mock Server Node.js (3000)'
                            : 'Cambiar a Spring Boot Backend (8092)',
                        style: const TextStyle(color: Color(0xFF0F766E), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final resumen = data.resumen;

          return Column(
            children: [
              // HEADER VERDE BOSQUE CON DEGRADADO
              _buildFigmaHeader(widget.user),

              // CONTENIDO SCROLLABLE
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // TARJETA 1: PRODUCTO FARMACÉUTICO Y SELECTOR DE PERÍODO
                      _buildSelectorCard(data.producto),
                      const SizedBox(height: 14),

                      if (data.status != 'OK') ...[
                        // SIN DATOS REALES SUFICIENTES: no se muestra ninguna cifra inventada
                        _buildSinDatosCard(data.mensaje),
                        const SizedBox(height: 16),
                      ] else ...[
                        // TARJETA 2: KPIS (DEMANDA ESTIMADA Y RIESGO QUIEBRE)
                        _buildKpiRow(resumen),
                        const SizedBox(height: 14),

                        // TARJETA 3: GRÁFICO SYNCFUSION
                        _buildSyncfusionChartCard(data),
                        const SizedBox(height: 14),

                        // TARJETA 4: REABASTECIMIENTO RECOMENDADO
                        _buildReabastecimientoCard(resumen),
                        const SizedBox(height: 16),
                      ],

                      // CÁPSULA INFERIOR: CONTRATO OFICIAL FARMASIS
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: Color(0xFF10B981),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Predicción FarmaSIS · Datos reales de ventas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF065F46),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tarjeta que se muestra cuando el producto no tiene historial real suficiente para predecir.
  Widget _buildSinDatosCard(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.query_stats_rounded, size: 48, color: Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          const Text(
            'Sin datos suficientes para predecir',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje.isEmpty ? 'Aún no hay ventas registradas para este producto.' : mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  /// Header superior verde con degradado (Exacto a Figma)
  Widget _buildFigmaHeader(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF134E2C), // Verde bosque superior
            Color(0xFF0F3D23),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Logo, Título, Campana y Avatar
          Row(
            children: [
              // Logo squircle blanco con símbolo oficial FarmaSIS
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/images/farmasis_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Center(
                      child: Icon(
                        Icons.local_pharmacy_rounded,
                        size: 26,
                        color: Color(0xFF134E2C),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Título y Subtítulo
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FarmaSIS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Predicción Farmacéutica',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA7D7B5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Botón Campana Notificación
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4E30).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2E6B45).withValues(alpha: 0.6),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFFA7D7B5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),

              // Avatar Verde Brillante "J"
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : 'J',
                      style: const TextStyle(
                        color: Color(0xFF092916),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Nombre de Usuario y Rol
          Text(
            '${user.nombre} ${user.apellido}'.trim().isEmpty ? 'Juan Garces' : '${user.nombre} ${user.apellido}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Rol: ${user.rol} · FARMASIS',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFA7D7B5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Chip conmutador de entorno interactivo (Spring Boot 8092 vs Mock Server 3000)
          InkWell(
            onTap: () {
              ApiService.useProductionBackend = !ApiService.useProductionBackend;
              _inicializar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ApiService.useProductionBackend
                      ? '🚀 Conectado a Spring Boot (Puerto 8092 - MongoDB Atlas)'
                      : '⚡ Conectado a Mock Server Node.js (Puerto 3000 - Contrato REST)'),
                  backgroundColor: ApiService.useProductionBackend
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0F766E),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ApiService.useProductionBackend
                    ? const Color(0xFF10B981).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ApiService.useProductionBackend
                      ? const Color(0xFF34D399)
                      : const Color(0xFFA7D7B5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ApiService.useProductionBackend
                        ? Icons.cloud_done_rounded
                        : Icons.alt_route_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ApiService.useProductionBackend
                        ? 'Servidor: Spring Boot (8092 - Mongo Atlas)'
                        : 'Servidor: Mock Server (Puerto 3000)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: Color(0xFFA7D7B5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta 1: Dropdown de medicamento y selector segmentado (Exacto a Figma)
  Widget _buildSelectorCard(ProductoInfo producto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRODUCTO FARMACÉUTICO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  producto.categoria,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Selector desplegable con borde redondeado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProducto,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F766E)),
                items: _productos.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'],
                    child: Text(
                      p['nombre']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedProducto = val;
                    });
                    _cargarDatos();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Chip con stock actual y stock mínimo
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: producto.stockActual <= producto.stockMinimo
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669),
              ),
              const SizedBox(width: 4),
              Text(
                'Stock en almacén: ${producto.stockActual} uds',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: producto.stockActual <= producto.stockMinimo
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF334155),
                ),
              ),
              const Spacer(),
              Text(
                'Mínimo: ${producto.stockMinimo} uds',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector Segmentado: DIARIO | SEMANAL | MENSUAL
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: ['DIARIO', 'SEMANAL', 'MENSUAL'].map((temp) {
                final isSelected = _selectedTemporalidad == temp;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTemporalidad = temp;
                      });
                      _cargarDatos();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        temp,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta 2: Fila de KPIs adaptativa (Demanda Estimada y Riesgo Quiebre)
  Widget _buildKpiRow(ResumenPrediccion resumen) {
    Color riskColor;
    Color riskBorder;
    IconData riskIcon;
    String riskLabel;

    switch (resumen.riesgoQuiebre) {
      case 'BAJO':
        riskColor = const Color(0xFF16A34A);
        riskBorder = const Color(0xFFBBF7D0);
        riskIcon = Icons.check_circle_outline_rounded;
        riskLabel = 'Stock seguro';
        break;
      case 'MEDIO':
        riskColor = const Color(0xFFD97706);
        riskBorder = const Color(0xFFFED7AA);
        riskIcon = Icons.info_outline_rounded;
        riskLabel = 'Atención requerida';
        break;
      case 'ALTO':
      default:
        riskColor = const Color(0xFFB91C1C);
        riskBorder = const Color(0xFFFECACA);
        riskIcon = Icons.warning_amber_rounded;
        riskLabel = 'Acción requerida';
        break;
    }

    return Row(
      children: [
        // KPI 1: Demanda Estimada
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demanda Estimada',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${resumen.totalPredicho} ',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F4D2A), // Verde oscuro profundo
                        ),
                      ),
                      const TextSpan(
                        text: 'uds',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F4D2A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // KPI 2: Riesgo Quiebre
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: riskBorder, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riesgo Quiebre',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resumen.riesgoQuiebre,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(riskIcon, color: riskColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      riskLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: riskColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Tarjeta 3: Gráfico Syncfusion con barras esmeralda y curva spline oscura (Exacto a Figma)
  Widget _buildSyncfusionChartCard(ContratoPrediccionResponse data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: Título y Tag "Syncfusion"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Curva de Predicción (${_selectedTemporalidad.toLowerCase().replaceFirst(
                      _selectedTemporalidad[0].toLowerCase(),
                      _selectedTemporalidad[0].toUpperCase(),
                    )})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Text(
                  'Syncfusion',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Gráfico Syncfusion
          SizedBox(
            height: 240,
            child: SfCartesianChart(
              tooltipBehavior: _tooltipBehavior,
              plotAreaBorderWidth: 0,
              primaryXAxis: const CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(color: Color(0xFFE2E8F0)),
                labelStyle: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              primaryYAxis: const NumericAxis(
                majorGridLines: MajorGridLines(
                  color: Color(0xFFF1F5F9),
                  width: 1,
                ),
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(size: 0),
                isVisible: false, // Ocultar eje Y numérico como en el Figma
              ),
              series: <CartesianSeries<PuntoPrediccion, String>>[
                // 1. Barras de Ventas Reales (Verde Esmeralda)
                ColumnSeries<PuntoPrediccion, String>(
                  name: 'Ventas Reales',
                  dataSource: data.serieDatos,
                  xValueMapper: (PuntoPrediccion p, _) => p.periodo,
                  yValueMapper: (PuntoPrediccion p, _) => p.ventasReales,
                  color: const Color(0xFF34D399), // Esmeralda de Figma
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  width: 0.5,
                ),

                // 2. Curva Spline de Predicción (Verde Bosque Oscuro)
                SplineSeries<PuntoPrediccion, String>(
                  name: 'Predicción (IA)',
                  dataSource: data.serieDatos,
                  xValueMapper: (PuntoPrediccion p, _) => p.periodo,
                  yValueMapper: (PuntoPrediccion p, _) => p.ventasPredichas,
                  color: const Color(0xFF14532D), // Verde bosque oscuro
                  width: 3.0,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    shape: DataMarkerType.circle,
                    width: 6,
                    height: 6,
                    color: Color(0xFF14532D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Leyenda personalizada idéntica al diseño de Figma
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ventas Reales (cuadrito verde)
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ventas Reales',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 20),

              // Predicción (línea verde oscura)
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF14532D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Predicción (IA)',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta 4: Reabastecimiento Recomendado (Adaptativo a nivel de inventario)
  Widget _buildReabastecimientoCard(ResumenPrediccion resumen) {
    final bool sinRiesgo = resumen.sugerenciaReordenUnidades == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sinRiesgo ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sinRiesgo ? const Color(0xFFBBF7D0) : const Color(0xFFFED7AA),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: sinRiesgo ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              sinRiesgo ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
              color: sinRiesgo ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sinRiesgo ? 'Inventario Óptimo' : 'Reabastecimiento Recomendado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: sinRiesgo ? const Color(0xFF166534) : const Color(0xFF9A3412),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sinRiesgo
                      ? 'Los niveles de stock actuales son suficientes para cubrir la demanda estimada. No es necesario reordenar.'
                      : 'Emitir orden de pedido por ${resumen.sugerenciaReordenUnidades} unidades antes de ${resumen.periodoCritico} para evitar desabastecimiento en mostradores.',
                  style: TextStyle(
                    fontSize: 12,
                    color: sinRiesgo ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
