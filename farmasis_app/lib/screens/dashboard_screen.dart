import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/user_model.dart';
import '../models/prediction_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserModel user;
  final bool showHeader;

  const DashboardScreen({
    super.key,
    required this.user,
    this.showHeader = true,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Navegación inferior: 0 = Control, 1 = Predicción, 2 = Punto (POS), 3 = Inventario
  int _currentTabIndex = 0;

  // Filtro de rango de tiempo en "Control": HOY | AYER | SEMANA | MES
  String _selectedControlRange = 'SEMANA';

  // Estado del módulo de Predicción IA
  String _selectedProducto = '0846';
  String _selectedTemporalidad = 'MENSUAL';
  bool _showConfidenceBand = true;
  double? _simulatedOrderUnits;

  // Estado del módulo Punto de Venta (POS)
  final Map<String, int> _posCart = {'0846': 2, '0545': 1};
  String _posPaymentMethod = 'EFECTIVO';
  String _posSearchQuery = '';
  int _extraFacturasSession = 0;
  double _extraVentasSession = 0.0;

  // Estado del módulo Inventario
  String _inventorySearchQuery = '';
  final String _inventoryCategory = 'Todas';
  bool _onlyCriticalStock = false;

  late Future<ContratoPrediccionResponse> _futurePrediccion;
  late TooltipBehavior _tooltipBehavior;

  List<Map<String, String>> _productos = [];

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(
      enable: true,
      canShowMarker: true,
      header: '',
      builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
          int seriesIndex) {
        if (data is PuntoPrediccion) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: FarmasisPalette.headerForestTop.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF74C69D),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Intervalo Confianza 95%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.periodo,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF95D5B2),
                  ),
                ),
                Text(
                  '○ High : ${data.limiteSuperior}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFFD8F3DC),
                  ),
                ),
                Text(
                  '○ Low  : ${data.limiteInferior}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFFD8F3DC),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
    _futurePrediccion = _cargarConProductos();
  }

  Future<ContratoPrediccionResponse> _cargarConProductos() async {
    var lista = await ApiService.getProductosRemotos();
    if (lista.isEmpty) {
      lista = ApiService.getProductos();
    }
    _productos = lista;
    if (_productos.isNotEmpty &&
        !_productos.any((p) => p['id'] == _selectedProducto)) {
      _selectedProducto = _productos.first['id']!;
    }
    final res = await ApiService.getPrediccion(
      productoId: _selectedProducto,
      temporalidad: _selectedTemporalidad,
    );
    _simulatedOrderUnits = res.resumen.sugerenciaReordenUnidades.toDouble();
    return res;
  }

  void _inicializar() {
    setState(() {
      _futurePrediccion = _cargarConProductos();
    });
  }

  void _cargarDatos() {
    setState(() {
      _futurePrediccion = ApiService.getPrediccion(
        productoId: _selectedProducto,
        temporalidad: _selectedTemporalidad,
      ).then((res) {
        _simulatedOrderUnits = res.resumen.sugerenciaReordenUnidades.toDouble();
        return res;
      });
    });
  }

  /// Métricas dinámicas del tablero BI según el filtro (HOY, AYER, SEMANA, MES)
  Map<String, String> _getBiMetrics() {
    double baseVentas;
    int baseFacturas;
    String labelPeriodo;

    switch (_selectedControlRange) {
      case 'HOY':
        baseVentas = 71894;
        baseFacturas = 1;
        labelPeriodo = 'Hoy';
        break;
      case 'AYER':
        baseVentas = 71894;
        baseFacturas = 1;
        labelPeriodo = 'Ayer';
        break;
      case 'MES':
        baseVentas = 648920;
        baseFacturas = 9;
        labelPeriodo = 'Este mes';
        break;
      case 'SEMANA':
      default:
        baseVentas = 143788;
        baseFacturas = 2;
        labelPeriodo = 'Últimos 7 días';
        break;
    }

    final totalVentas = baseVentas + _extraVentasSession;
    final totalFacturas = baseFacturas + _extraFacturasSession;
    final utilidad = totalVentas * 0.35;
    final ticketProm = totalFacturas > 0 ? totalVentas / totalFacturas : 0.0;

    return {
      'periodo': labelPeriodo,
      'facturacion': '\$${_formatCurrency(totalVentas.round())}',
      'facturas': '$totalFacturas facturas emitidas',
      'utilidad': '\$${_formatCurrency(utilidad.round())}',
      'ticketProm': 'Ticket prom: \$${_formatCurrency(ticketProm.round())}',
      'catalogo': '${_productos.length > 100 ? 1004 : _productos.length} ítems',
      'proveedores': '1 proveedores activos',
      'criticos': '20 críticos',
      'reposicion': 'Requieren reposición',
    };
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Precio unitario determinístico y realista por código de producto para el POS
  int _getProductPrice(String id) {
    final codeNum = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 104;
    return 8500 + ((codeNum * 37) % 420) * 100;
  }

  /// Stock simulado/real determinístico para la vista general del inventario
  int _getProductStock(String id, int index) {
    if (index < 20) {
      // Los primeros 20 productos se marcan con stock crítico (< stock mínimo)
      return (index % 4) + 1;
    }
    final codeNum = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 100;
    return 24 + (codeNum % 145);
  }

  Future<void> _openQuickProductSearch() async {
    if (_productos.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MetallicProductSearchModal(
        productos: _productos,
        currentId: _selectedProducto,
      ),
    );
    if (selected != null && selected != _selectedProducto) {
      setState(() {
        _selectedProducto = selected;
      });
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentBuilder = FutureBuilder<ContratoPrediccionResponse>(
      future: _futurePrediccion,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: FarmasisPalette.emeraldNeon,
                    strokeWidth: 2.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Sincronizando datos BI...',
                  style: TextStyle(
                    fontSize: 12,
                    color: FarmasisPalette.textSteel,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: MetallicGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 40,
                      color: FarmasisPalette.goldWarm,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${snapshot.error}'.replaceAll('Exception:', '').trim(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FarmasisPalette.textSilverBright,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _inicializar,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reintentar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmasisPalette.emeraldBright,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        if (!widget.showHeader) {
          return _buildPrediccionModule(data);
        }
        switch (_currentTabIndex) {
          case 0:
            return _buildControlModule(data);
          case 1:
            return _buildPrediccionModule(data);
          case 2:
            return _buildPosModule();
          case 3:
            return _buildInventarioModule();
          default:
            return _buildControlModule(data);
        }
      },
    );

    if (!widget.showHeader) {
      return contentBuilder;
    }

    return Scaffold(
      backgroundColor: FarmasisPalette.bgObsidian,
      bottomNavigationBar: _buildMetallicBottomNav(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FarmasisPalette.bgGunmetalTop,
              FarmasisPalette.bgGunmetalMid,
              FarmasisPalette.bgGunmetalBottom,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // HEADER DE CROMO Y ESMERALDA COMPACTO
              _buildMetallicHeader(widget.user),

              // CONTENIDO DEL MÓDULO ACTIVO
              Expanded(child: contentBuilder),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  //  HEADER Y BRANDING (ARRIBA) — EXACTO A LA REFERENCIA
  // ===========================================================================
  Widget _buildMetallicHeader(UserModel user) {
    final emailText = user.email.isNotEmpty
        ? user.email
        : 'juan.garces028@gmail.com';
    final roleText = user.rol.isNotEmpty
        ? user.rol.replaceAll('ROLE_', '').toUpperCase()
        : 'OWNER';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        children: [
          // Fila principal: Cruz 3D + FarmaSIS / Control Total & BI + Icono Salida
          Row(
            children: [
              const SizedBox(width: 28), // Equilibrio visual centrando el logo
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MetallicCrossLogo(size: 46),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Farma',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE2E8F0),
                                  letterSpacing: -0.3,
                                  height: 1.05,
                                ),
                              ),
                              TextSpan(
                                text: 'SIS',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: FarmasisPalette.emeraldNeon,
                                  letterSpacing: -0.3,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Control Total & BI',
                          style: TextStyle(
                            fontSize: 12,
                            color: FarmasisPalette.textSilver,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.logout_rounded,
                    color: FarmasisPalette.textSilver,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Franja fina con líneas metálicas y correo · ROL
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color:
                      FarmasisPalette.borderChromeBright.withValues(alpha: 0.28),
                  width: 0.8,
                ),
                bottom: BorderSide(
                  color:
                      FarmasisPalette.borderChromeBright.withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_rounded,
                  size: 16,
                  color: FarmasisPalette.textSilver,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$emailText · $roleText',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: FarmasisPalette.textSilver,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  MÓDULO 1: CONTROL TOTAL & BI (VISTA PRINCIPAL DE REFERENCIA)
  // ===========================================================================
  Widget _buildControlModule(ContratoPrediccionResponse data) {
    final bi = _getBiMetrics();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. PILL SELECTOR METÁLICO (HOY | AYER | SEMANA | MES)
          _buildTimeRangePillSelector(),
          const SizedBox(height: 10),

          // 2. GRID 2x2 DE TARJETAS DE DATOS (KPIs)
          Row(
            children: [
              // KPI 1: Facturación
              Expanded(
                child: MetallicGlassCard(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Facturación ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: FarmasisPalette.textSilver,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '(${bi['periodo']})',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: FarmasisPalette.textSteel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: FarmasisPalette.emeraldBright
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: FarmasisPalette.emeraldNeon
                                    .withValues(alpha: 0.6),
                                width: 0.8,
                              ),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 15,
                              color: FarmasisPalette.emeraldNeon,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bi['facturacion']!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE2F8F0),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bi['facturas']!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: FarmasisPalette.textSteel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // KPI 2: Utilidad Estimada (35%)
              Expanded(
                child: MetallicGlassCard(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Utilidad Estimada (35%)',
                              style: TextStyle(
                                fontSize: 11,
                                color: FarmasisPalette.textSilver,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 17,
                            color: FarmasisPalette.chromeBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bi['utilidad']!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: FarmasisPalette.textSilverBright,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bi['ticketProm']!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: FarmasisPalette.textSteel,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          Row(
            children: [
              // KPI 3: Catálogo Total
              Expanded(
                child: MetallicGlassCard(
                  padding: const EdgeInsets.all(11),
                  onTap: () {
                    setState(() {
                      _onlyCriticalStock = false;
                      _currentTabIndex = 3;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Catálogo Total',
                              style: TextStyle(
                                fontSize: 11,
                                color: FarmasisPalette.textSilver,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: FarmasisPalette.textSilver
                                .withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bi['catalogo']!,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: FarmasisPalette.textSilverBright,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bi['proveedores']!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: FarmasisPalette.textSteel,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // KPI 4: Alertas Stock Bajo (Variante Oro/Bronce Metálico)
              Expanded(
                child: MetallicGlassCard(
                  padding: const EdgeInsets.all(11),
                  isGoldVariant: true,
                  onTap: () {
                    setState(() {
                      _onlyCriticalStock = true;
                      _currentTabIndex = 3;
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Alertas Stock Bajo',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE5D5B5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 17,
                            color: FarmasisPalette.goldWarm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bi['criticos']!,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: FarmasisPalette.goldText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bi['reposicion']!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFC7B28B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),

          // 3. SECCIÓN: MÓDULOS DEL SISTEMA FARMASIS
          const Text(
            'Módulos del Sistema FarmaSIS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: FarmasisPalette.textSilverBright,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              // Botón 1: Nueva Venta POS
              Expanded(
                child: MetallicGlassCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                  onTap: () {
                    setState(() {
                      _currentTabIndex = 2;
                    });
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetallicModuleIcon(
                        icon: Icons.point_of_sale_rounded,
                        isAiVariant: false,
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Nueva Venta POS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // Botón 2: Predicción IA
              Expanded(
                child: MetallicGlassCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                  onTap: () {
                    setState(() {
                      _currentTabIndex = 1;
                    });
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetallicModuleIcon(
                        icon: Icons.auto_graph_rounded,
                        isAiVariant: true,
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Predicción IA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),

          // 4. GRÁFICO DE PREDEMANDA E IA COMPACTO
          _buildCompactMetallicChartCard(data),
        ],
      ),
    );
  }

  /// Selector de rango de tiempo ("HOY | AYER | SEMANA | MES") en acero oscuro y relieve esmeralda
  Widget _buildTimeRangePillSelector() {
    final ranges = ['HOY', 'AYER', 'SEMANA', 'MES'];
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF111E27),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: FarmasisPalette.borderChromeBright.withValues(alpha: 0.55),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(ranges.length, (index) {
          final item = ranges[index];
          final isSelected = _selectedControlRange == item;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedControlRange = item;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isSelected
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF14B8A6),
                            Color(0xFF0D9488),
                            Color(0xFF065F46),
                          ],
                        )
                      : null,
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFF5EEAD4).withValues(alpha: 0.8),
                          width: 1,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: FarmasisPalette.emeraldBright
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : FarmasisPalette.textSteel,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Tarjeta del gráfico de barras esmeralda con gradiente y línea azul cromo
  Widget _buildCompactMetallicChartCard(ContratoPrediccionResponse data) {
    return MetallicGlassCard(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evolución y Pronóstico de Demanda',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: FarmasisPalette.textSilverBright,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Comparativa entre ventas facturadas y proyección estadística',
                      style: TextStyle(
                        fontSize: 9.8,
                        color: FarmasisPalette.textSteel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Botón compacto "✓ Banda 95%"
              InkWell(
                onTap: () {
                  setState(() {
                    _showConfidenceBand = !_showConfidenceBand;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showConfidenceBand
                        ? FarmasisPalette.inputSurface
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showConfidenceBand
                          ? FarmasisPalette.chromeBlue
                          : FarmasisPalette.borderChromeSubtle,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showConfidenceBand
                            ? Icons.check_rounded
                            : Icons.visibility_off_outlined,
                        size: 12,
                        color: FarmasisPalette.chromeBlue,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Banda 95%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            height: 175,
            child: SfCartesianChart(
              margin: const EdgeInsets.only(top: 6, right: 6, left: 0, bottom: 0),
              tooltipBehavior: _tooltipBehavior,
              plotAreaBorderWidth: 0,
              primaryXAxis: const CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(color: Color(0xFF2B4454)),
                majorTickLines: MajorTickLines(size: 0),
                labelStyle: TextStyle(
                  fontSize: 9.5,
                  color: FarmasisPalette.textSilver,
                  fontWeight: FontWeight.w500,
                ),
              ),
              primaryYAxis: const NumericAxis(
                majorGridLines: MajorGridLines(
                  color: Color(0xFF1B303E),
                  width: 0.8,
                ),
                axisLine: AxisLine(width: 0),
                majorTickLines: MajorTickLines(size: 0),
                labelStyle: TextStyle(
                  fontSize: 9.5,
                  color: FarmasisPalette.textSteel,
                ),
              ),
              series: <CartesianSeries<PuntoPrediccion, String>>[
                if (_showConfidenceBand)
                  RangeAreaSeries<PuntoPrediccion, String>(
                    name: 'Intervalo Confianza 95%',
                    dataSource: data.serieDatos,
                    xValueMapper: (PuntoPrediccion p, _) => p.periodo,
                    lowValueMapper: (PuntoPrediccion p, _) => p.limiteInferior,
                    highValueMapper: (PuntoPrediccion p, _) => p.limiteSuperior,
                    color: FarmasisPalette.chromeIndigo.withValues(alpha: 0.22),
                    borderColor:
                        FarmasisPalette.chromeBlue.withValues(alpha: 0.55),
                    borderWidth: 1.1,
                  ),
                ColumnSeries<PuntoPrediccion, String>(
                  name: 'Ventas Reales',
                  dataSource: data.serieDatos,
                  xValueMapper: (PuntoPrediccion p, _) => p.periodo,
                  yValueMapper: (PuntoPrediccion p, _) => p.ventasReales,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF34D399),
                      Color(0xFF0D9488),
                      Color(0xFF064E3B),
                    ],
                  ),
                  borderColor: const Color(0xFF6EE7B7),
                  borderWidth: 0.8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  width: 0.52,
                ),
                SplineSeries<PuntoPrediccion, String>(
                  name: 'Pronóstico',
                  dataSource: data.serieDatos,
                  xValueMapper: (PuntoPrediccion p, _) => p.periodo,
                  yValueMapper: (PuntoPrediccion p, _) => p.ventasPredichas,
                  color: FarmasisPalette.chromeBlue,
                  width: 2.4,
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    shape: DataMarkerType.circle,
                    width: 5.5,
                    height: 5.5,
                    color: Colors.white,
                    borderColor: FarmasisPalette.chromeBlue,
                    borderWidth: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Leyenda compacta inferior
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                      color: const Color(0xFF6EE7B7), width: 0.8),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Ventas Reales',
                style: TextStyle(
                  fontSize: 10.5,
                  color: FarmasisPalette.textSilver,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 14,
                height: 2.5,
                decoration: BoxDecoration(
                  color: FarmasisPalette.chromeBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Pronóstico',
                style: TextStyle(
                  fontSize: 10.5,
                  color: FarmasisPalette.textSilver,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                data.producto.nombre,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: FarmasisPalette.textSteel,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  MÓDULO 2: PREDICCIÓN IA (COMPACTO, METÁLICO Y SIN DESCUADRES)
  // ===========================================================================
  Widget _buildPrediccionModule(ContratoPrediccionResponse data) {
    final producto = data.producto;
    final resumen = data.resumen;
    final modelo = data.modelo;
    final bool isHighRisk = resumen.riesgoQuiebre != 'BAJO';

    final maxSlider =
        (resumen.totalPredicho * 2 + 100).clamp(100, 1500).toDouble();
    final currentOrder =
        (_simulatedOrderUnits ?? resumen.sugerenciaReordenUnidades.toDouble())
            .clamp(0.0, maxSlider);
    final int orderInt = currentOrder.round();
    final int projectedStock = producto.stockActual + orderInt;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. SELECTOR DE MEDICAMENTO Y ESCALA TEMPORAL
          MetallicGlassCard(
            padding: const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'MEDICAMENTO ANALIZADO POR IA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FarmasisPalette.textSteel,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FarmasisPalette.chromeIndigo
                            .withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: FarmasisPalette.chromeBlue
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        producto.categoria,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.chromeBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Selector táctil de producto
                InkWell(
                  onTap: _openQuickProductSearch,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(
                      color: FarmasisPalette.inputSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FarmasisPalette.borderChromeBright,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medication_rounded,
                          color: FarmasisPalette.emeraldNeon,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            producto.nombre.isNotEmpty
                                ? '${producto.nombre} (${producto.codigo})'
                                : _selectedProducto,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: FarmasisPalette.textSilverBright,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.search_rounded,
                          size: 17,
                          color: FarmasisPalette.emeraldNeon,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),

                // Selector DIARIO | SEMANAL | MENSUAL
                Container(
                  height: 32,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: FarmasisPalette.pillTrackSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: FarmasisPalette.borderChromeBright),
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
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF14B8A6),
                                        Color(0xFF065F46),
                                      ],
                                    )
                                  : null,
                            ),
                            child: Text(
                              temp,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : FarmasisPalette.textSteel,
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
          ),
          const SizedBox(height: 9),

          if (data.status != 'OK') ...[
            MetallicGlassCard(
              isGoldVariant: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: FarmasisPalette.goldWarm, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    data.mensaje.isEmpty
                        ? 'Selecciona la escala MENSUAL o SEMANAL para ver la serie histórica completa.'
                        : data.mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: FarmasisPalette.textSilverBright,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // 2. TARJETAS KPI DE PREDICCIÓN (2x2 COMPACTO)
            Row(
              children: [
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Demanda Estimada',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: FarmasisPalette.textSilver,
                              ),
                            ),
                            Icon(Icons.auto_graph_rounded,
                                size: 15, color: FarmasisPalette.emeraldNeon),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${resumen.totalPredicho} uds',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                        ),
                        Text(
                          'Tendencia: ${resumen.tendencia}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: FarmasisPalette.textSteel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(11),
                    isGoldVariant: isHighRisk,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Riesgo Quiebre',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: FarmasisPalette.textSilver,
                              ),
                            ),
                            Icon(
                              isHighRisk
                                  ? Icons.warning_amber_rounded
                                  : Icons.verified_outlined,
                              size: 15,
                              color: isHighRisk
                                  ? FarmasisPalette.goldWarm
                                  : FarmasisPalette.emeraldNeon,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resumen.riesgoQuiebre,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isHighRisk
                                ? FarmasisPalette.goldText
                                : FarmasisPalette.emeraldNeon,
                          ),
                        ),
                        Text(
                          'Crítico: ${resumen.periodoCritico}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: FarmasisPalette.textSteel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),

            Row(
              children: [
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stock en Almacén',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: FarmasisPalette.textSilver,
                              ),
                            ),
                            Icon(Icons.inventory_2_outlined,
                                size: 15, color: FarmasisPalette.chromeBlue),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${producto.stockActual} uds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FarmasisPalette.textSilverBright,
                          ),
                        ),
                        Text(
                          'Stock mínimo: ${producto.stockMinimo} uds',
                          style: const TextStyle(
                            fontSize: 10,
                            color: FarmasisPalette.textSteel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sugerencia Reorden',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: FarmasisPalette.textSilver,
                              ),
                            ),
                            Icon(Icons.local_shipping_outlined,
                                size: 15, color: FarmasisPalette.goldWarm),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${resumen.sugerenciaReordenUnidades} uds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FarmasisPalette.goldText,
                          ),
                        ),
                        Text(
                          'Confianza: ${(modelo.nivelConfianza * 100).toInt()}% (Holt)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: FarmasisPalette.textSteel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),

            // 3. GRÁFICO DE PREDICCIÓN
            _buildCompactMetallicChartCard(data),
            const SizedBox(height: 9),

            // 4. SIMULADOR DE REABASTECIMIENTO EN ACERO OSCURO
            MetallicGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Simulador de Orden de Compra',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                      Text(
                        'Pedir: $orderInt uds → Stock: $projectedStock uds',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.emeraldNeon,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14),
                    ),
                    child: Slider(
                      value: currentOrder,
                      min: 0,
                      max: maxSlider,
                      activeColor: FarmasisPalette.emeraldNeon,
                      inactiveColor: FarmasisPalette.pillTrackSurface,
                      onChanged: (val) {
                        setState(() {
                          _simulatedOrderUnits = val;
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'α=${modelo.alfa} · β=${modelo.beta} · RMSE=${modelo.rmse}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: FarmasisPalette.textSteel,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text:
                                'FarmaSIS Reorden: ${producto.nombre} (${producto.codigo}) - Solicitar $orderInt uds.',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Orden copiada al portapapeles'),
                              backgroundColor: FarmasisPalette.emeraldDeep,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: FarmasisPalette.emeraldBright
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: FarmasisPalette.emeraldNeon),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 12,
                                  color: FarmasisPalette.emeraldNeon),
                              SizedBox(width: 4),
                              Text(
                                'Copiar Orden',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: FarmasisPalette.textSilverBright,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  //  MÓDULO 3: PUNTO DE VENTA MÓVIL (POS COMPACTO Y ORGANIZADO)
  // ===========================================================================
  Widget _buildPosModule() {
    final catalog = _productos.isEmpty ? ApiService.getProductos() : _productos;
    final filteredPos = catalog.where((p) {
      final q = _posSearchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (p['nombre'] ?? '').toLowerCase().contains(q) ||
          (p['id'] ?? '').toLowerCase().contains(q);
    }).toList();

    int subtotal = 0;
    _posCart.forEach((id, qty) {
      subtotal += _getProductPrice(id) * qty;
    });
    final int iva = (subtotal * 0.19).round();
    final int total = subtotal + iva;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. BUSCADOR COMPACTO Y MÉTODO DE PAGO
          MetallicGlassCard(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.point_of_sale_rounded,
                        size: 18, color: FarmasisPalette.emeraldNeon),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Terminal Punto de Venta POS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                    ),
                    ...['EFECTIVO', 'TARJETA', 'NEQUI'].map((metodo) {
                      final active = _posPaymentMethod == metodo;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _posPaymentMethod = metodo;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: active
                                  ? FarmasisPalette.emeraldBright
                                      .withValues(alpha: 0.25)
                                  : const Color(0xFF0B161E),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: active
                                    ? FarmasisPalette.emeraldNeon
                                    : FarmasisPalette.borderChromeSubtle,
                              ),
                            ),
                            child: Text(
                              metodo,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? FarmasisPalette.emeraldNeon
                                    : FarmasisPalette.textSteel,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: TextField(
                    onChanged: (val) => setState(() => _posSearchQuery = val),
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: FarmasisPalette.textSilverBright),
                    decoration: InputDecoration(
                      hintText: 'Buscar medicamento por código o nombre...',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: FarmasisPalette.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 18, color: FarmasisPalette.textSteel),
                      filled: true,
                      fillColor: const Color(0xFF0B161E),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. CATÁLOGO RÁPIDO PARA AGREGAR AL CARRITO
          Expanded(
            child: MetallicGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: ListView.separated(
                itemCount: filteredPos.length > 35 ? 35 : filteredPos.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: FarmasisPalette.borderChromeSubtle
                      .withValues(alpha: 0.5),
                ),
                itemBuilder: (context, idx) {
                  final item = filteredPos[idx];
                  final id = item['id']!;
                  final price = _getProductPrice(id);
                  final inCartQty = _posCart[id] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B161E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: FarmasisPalette.borderChromeSubtle),
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            size: 17,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['nombre'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: FarmasisPalette.textSilverBright,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '\$${_formatCurrency(price)} · Cód: $id',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: FarmasisPalette.emeraldNeon,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (inCartQty > 0) ...[
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (inCartQty <= 1) {
                                  _posCart.remove(id);
                                } else {
                                  _posCart[id] = inCartQty - 1;
                                }
                              });
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B161E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: FarmasisPalette.borderChromeBright),
                              ),
                              child: const Icon(Icons.remove_rounded,
                                  size: 15, color: Colors.white),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$inCartQty',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _posCart[id] = inCartQty + 1;
                            });
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF14B8A6), Color(0xFF065F46)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFF5EEAD4), width: 0.8),
                            ),
                            child: const Icon(Icons.add_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. PANEL DE LIQUIDACIÓN Y FACTURACIÓN POS
          MetallicGlassCard(
            padding: const EdgeInsets.all(11),
            isHighlighted: true,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ítems: ${_posCart.values.fold(0, (a, b) => a + b)}  |  IVA (19%): \$${_formatCurrency(iva)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FarmasisPalette.textSilver,
                      ),
                    ),
                    Text(
                      'Total: \$${_formatCurrency(total)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FarmasisPalette.emeraldNeon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _posCart.isEmpty
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _extraFacturasSession += 1;
                              _extraVentasSession += total;
                              _posCart.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Factura POS emitida por \$${_formatCurrency(total)} ($_posPaymentMethod)',
                                ),
                                backgroundColor: FarmasisPalette.emeraldDeep,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmasisPalette.emeraldBright,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 17),
                    label: const Text(
                      'Emitir Factura POS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  MÓDULO 4: INVENTARIO Y CONTROL DE ALERTAS DE STOCK BAJO
  // ===========================================================================
  Widget _buildInventarioModule() {
    final catalog = _productos.isEmpty ? ApiService.getProductos() : _productos;

    final filtered = <Map<String, dynamic>>[];
    for (int i = 0; i < catalog.length; i++) {
      final p = catalog[i];
      final stock = _getProductStock(p['id']!, i);
      final isCritical = stock <= 5;
      if (_onlyCriticalStock && !isCritical) continue;
      if (_inventoryCategory != 'Todas' &&
          (p['categoria'] ?? '').toLowerCase() !=
              _inventoryCategory.toLowerCase()) {
        continue;
      }
      final q = _inventorySearchQuery.trim().toLowerCase();
      if (q.isNotEmpty &&
          !(p['nombre'] ?? '').toLowerCase().contains(q) &&
          !(p['id'] ?? '').toLowerCase().contains(q)) {
        continue;
      }
      filtered.add({
        'id': p['id']!,
        'nombre': p['nombre']!,
        'categoria': p['categoria'] ?? 'General',
        'stock': stock,
        'minimo': 5,
        'critico': isCritical,
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. PILL SELECTOR: TODOS LOS ÍTEMS vs 20 CRÍTICOS
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF111E27),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    FarmasisPalette.borderChromeBright.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _onlyCriticalStock = false),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: !_onlyCriticalStock
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF14B8A6),
                                  Color(0xFF065F46),
                                ],
                              )
                            : null,
                      ),
                      child: const Text(
                        'CATÁLOGO TOTAL (1004)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _onlyCriticalStock = true),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _onlyCriticalStock
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFB45309),
                                  Color(0xFF78350F),
                                ],
                              )
                            : null,
                      ),
                      child: const Text(
                        'STOCK CRÍTICO (20)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.goldText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. BUSCADOR COMPACTO DE INVENTARIO
          SizedBox(
            height: 36,
            child: TextField(
              onChanged: (val) =>
                  setState(() => _inventorySearchQuery = val),
              style: const TextStyle(
                  fontSize: 12.5, color: FarmasisPalette.textSilverBright),
              decoration: InputDecoration(
                hintText: 'Filtrar inventario por código o medicamento...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: FarmasisPalette.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: FarmasisPalette.textSteel),
                filled: true,
                fillColor: const Color(0xFF101E27),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: FarmasisPalette.borderChromeSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: FarmasisPalette.borderChromeSubtle),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. LISTA COMPACTA DE TARJETAS DE INVENTARIO
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length > 40 ? 40 : filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                final bool critico = item['critico'] as bool;
                final int stock = item['stock'] as int;

                return MetallicGlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  isGoldVariant: critico,
                  onTap: () {
                    setState(() {
                      _selectedProducto = item['id'] as String;
                      _currentTabIndex = 1;
                    });
                    _cargarDatos();
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: critico
                                ? FarmasisPalette.borderGold
                                : FarmasisPalette.borderChromeSubtle,
                          ),
                        ),
                        child: Icon(
                          critico
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          size: 17,
                          color: critico
                              ? FarmasisPalette.goldWarm
                              : FarmasisPalette.emeraldNeon,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['nombre']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FarmasisPalette.textSilverBright,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cód: ${item['id']} · ${item['categoria']}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: FarmasisPalette.textSteel,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$stock uds',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: critico
                                  ? FarmasisPalette.goldText
                                  : FarmasisPalette.emeraldNeon,
                            ),
                          ),
                          Text(
                            critico ? 'Reposición' : 'Disponible',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: critico
                                  ? const Color(0xFFC7B28B)
                                  : FarmasisPalette.textSteel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: FarmasisPalette.textSteel,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  //  BARRA DE NAVEGACIÓN INFERIOR METÁLICA (Control, Predicción, Punto, Inventario)
  // ===========================================================================
  Widget _buildMetallicBottomNav() {
    final items = [
      {'icon': Icons.dashboard_rounded, 'label': 'Control'},
      {'icon': Icons.timeline_rounded, 'label': 'Predicción'},
      {'icon': Icons.point_of_sale_rounded, 'label': 'Punto'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Inventario'},
    ];

    return Container(
      height: 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF142530),
            Color(0xFF0A1319),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: FarmasisPalette.borderChromeBright.withValues(alpha: 0.55),
            width: 1.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = _currentTabIndex == index;
          final icon = items[index]['icon'] as IconData;
          final label = items[index]['label'] as String;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentTabIndex = index;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 14 : 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                FarmasisPalette.emeraldBright
                                    .withValues(alpha: 0.45),
                                FarmasisPalette.emeraldDeep
                                    .withValues(alpha: 0.65),
                              ],
                            )
                          : null,
                      border: isSelected
                          ? Border.all(
                              color: FarmasisPalette.emeraldNeon
                                  .withValues(alpha: 0.7),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: isSelected
                          ? Colors.white
                          : FarmasisPalette.textSilver,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : FarmasisPalette.textSteel,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Buscador modal metálico de medicamentos
class _MetallicProductSearchModal extends StatefulWidget {
  final List<Map<String, String>> productos;
  final String currentId;

  const _MetallicProductSearchModal({
    required this.productos,
    required this.currentId,
  });

  @override
  State<_MetallicProductSearchModal> createState() =>
      _MetallicProductSearchModalState();
}

class _MetallicProductSearchModalState
    extends State<_MetallicProductSearchModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = widget.productos.where((p) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (p['nombre'] ?? '').toLowerCase().contains(q) ||
          (p['id'] ?? '').toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FarmasisPalette.cardSteelLight,
            FarmasisPalette.bgObsidian,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
              color: FarmasisPalette.borderChromeBright, width: 1.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: FarmasisPalette.borderChromeBright,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seleccionar Medicamento',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FarmasisPalette.textSilverBright,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: TextField(
              autofocus: true,
              onChanged: (val) => setState(() => _query = val),
              style: const TextStyle(
                  fontSize: 13, color: FarmasisPalette.textSilverBright),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código (ej. 0846)...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: FarmasisPalette.textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: FarmasisPalette.emeraldNeon),
                filled: true,
                fillColor: FarmasisPalette.inputSurface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: FarmasisPalette.borderChromeSubtle),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color:
                    FarmasisPalette.borderChromeSubtle.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final item = results[index];
                final selected = item['id'] == widget.currentId;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  title: Text(
                    item['nombre'] ?? '',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? FarmasisPalette.emeraldNeon
                          : FarmasisPalette.textSilverBright,
                    ),
                  ),
                  subtitle: Text(
                    'Código: ${item['id']} · ${item['categoria'] ?? 'General'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: FarmasisPalette.textSteel,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded,
                          size: 18, color: FarmasisPalette.emeraldNeon)
                      : null,
                  onTap: () => Navigator.of(context).pop(item['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
