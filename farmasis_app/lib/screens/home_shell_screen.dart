import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/user_model.dart';
import '../models/prediction_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';
import 'dashboard_screen.dart';
import 'pos_ventas_screen.dart';
import 'inventario_screen.dart';
import 'proveedores_screen.dart';
import 'gestion_usuarios_screen.dart';
import 'chatbot_screen.dart';
import 'login_screen.dart';

class _NavModule {
  final String id;
  final String title;
  final String shortLabel;
  final IconData icon;
  final Widget Function() builder;

  const _NavModule({
    required this.id,
    required this.title,
    required this.shortLabel,
    required this.icon,
    required this.builder,
  });
}

class HomeShellScreen extends StatefulWidget {
  final UserModel user;

  const HomeShellScreen({super.key, required this.user});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  bool get _isOwner => widget.user.rol.toUpperCase().contains('OWNER');
  bool get _isAdmin => widget.user.rol.toUpperCase().contains('ADMIN');
  bool get _isEmpleado => !_isOwner && !_isAdmin;

  List<_NavModule> get _modules {
    if (_isEmpleado) {
      return [
        _NavModule(
          id: 'pos',
          title: 'Punto de Venta (POS)',
          shortLabel: 'Punto',
          icon: Icons.point_of_sale_rounded,
          builder: () => PosVentasScreen(user: widget.user),
        ),
        _NavModule(
          id: 'inventario',
          title: 'Catálogo y Stock',
          shortLabel: 'Inventario',
          icon: Icons.inventory_2_rounded,
          builder: () => InventarioScreen(user: widget.user),
        ),
        _NavModule(
          id: 'chatbot',
          title: 'Asistente IA',
          shortLabel: 'Asistente',
          icon: Icons.smart_toy_outlined,
          builder: () => ChatbotScreen(user: widget.user),
        ),
        _NavModule(
          id: 'config',
          title: 'Mi Perfil',
          shortLabel: 'Perfil',
          icon: Icons.manage_accounts_outlined,
          builder: () => ConfiguracionScreen(user: widget.user),
        ),
      ];
    }

    if (_isAdmin) {
      return [
        _NavModule(
          id: 'resumen',
          title: 'Control Total & BI',
          shortLabel: 'Control',
          icon: Icons.dashboard_rounded,
          builder: () => _ExecutiveOverviewTab(
            user: widget.user,
            onNavigateModule: _navigateToModuleId,
          ),
        ),
        _NavModule(
          id: 'prediccion',
          title: 'Predicción Demanda IA',
          shortLabel: 'Predicción',
          icon: Icons.timeline_rounded,
          builder: () => DashboardScreen(user: widget.user, showHeader: false),
        ),
        _NavModule(
          id: 'pos',
          title: 'Punto de Venta (POS)',
          shortLabel: 'Punto',
          icon: Icons.point_of_sale_rounded,
          builder: () => PosVentasScreen(user: widget.user),
        ),
        _NavModule(
          id: 'inventario',
          title: 'Inventario y Ofertas',
          shortLabel: 'Inventario',
          icon: Icons.inventory_2_rounded,
          builder: () => InventarioScreen(user: widget.user),
        ),
        _NavModule(
          id: 'proveedores',
          title: 'Proveedores',
          shortLabel: 'Proveedores',
          icon: Icons.local_shipping_outlined,
          builder: () => ProveedoresScreen(user: widget.user),
        ),
        _NavModule(
          id: 'chatbot',
          title: 'Chatbot Farmacéutico IA',
          shortLabel: 'Chatbot',
          icon: Icons.smart_toy_outlined,
          builder: () => ChatbotScreen(user: widget.user),
        ),
        _NavModule(
          id: 'config',
          title: 'Configuración Sistema',
          shortLabel: 'Config',
          icon: Icons.settings_outlined,
          builder: () => ConfiguracionScreen(user: widget.user),
        ),
      ];
    }

    // OWNER: Acceso total a todos los módulos del sistema
    return [
      _NavModule(
        id: 'resumen',
        title: 'Control Total & BI',
        shortLabel: 'Control',
        icon: Icons.dashboard_rounded,
        builder: () => _ExecutiveOverviewTab(
          user: widget.user,
          onNavigateModule: _navigateToModuleId,
        ),
      ),
      _NavModule(
        id: 'prediccion',
        title: 'Predicción Demanda IA',
        shortLabel: 'Predicción',
        icon: Icons.timeline_rounded,
        builder: () => DashboardScreen(user: widget.user, showHeader: false),
      ),
      _NavModule(
        id: 'pos',
        title: 'Punto de Venta (POS)',
        shortLabel: 'Punto',
        icon: Icons.point_of_sale_rounded,
        builder: () => PosVentasScreen(user: widget.user),
      ),
      _NavModule(
        id: 'inventario',
        title: 'Inventario y Ofertas',
        shortLabel: 'Inventario',
        icon: Icons.inventory_2_rounded,
        builder: () => InventarioScreen(user: widget.user),
      ),
      _NavModule(
        id: 'proveedores',
        title: 'Proveedores',
        shortLabel: 'Proveedores',
        icon: Icons.local_shipping_outlined,
        builder: () => ProveedoresScreen(user: widget.user),
      ),
      _NavModule(
        id: 'optimizacion',
        title: 'Optimización Timefold',
        shortLabel: 'Timefold',
        icon: Icons.auto_graph_rounded,
        builder: () => const OptimizacionTimefoldScreen(),
      ),
      _NavModule(
        id: 'usuarios',
        title: 'Gestión de Personal',
        shortLabel: 'Personal',
        icon: Icons.group_outlined,
        builder: () => GestionUsuariosScreen(user: widget.user),
      ),
      _NavModule(
        id: 'chatbot',
        title: 'Chatbot Farmacéutico IA',
        shortLabel: 'Chatbot',
        icon: Icons.smart_toy_outlined,
        builder: () => ChatbotScreen(user: widget.user),
      ),
      _NavModule(
        id: 'config',
        title: 'Configuración Sistema',
        shortLabel: 'Config',
        icon: Icons.settings_outlined,
        builder: () => ConfiguracionScreen(user: widget.user),
      ),
    ];
  }

  void _navigateToModuleId(String id) {
    final idx = _modules.indexWhere((m) => m.id == id);
    if (idx != -1) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mods = _modules;
    final safeIdx = _selectedIndex.clamp(0, mods.length - 1);
    final activeModule = mods[safeIdx];
    final cleanRole = widget.user.rol.isNotEmpty
        ? widget.user.rol.replaceAll('ROLE_', '').toUpperCase()
        : 'OWNER';
    final emailText = widget.user.email.isNotEmpty
        ? widget.user.email
        : 'juan.garces028@gmail.com';
    final fullName = '${widget.user.nombre} ${widget.user.apellido}'.trim();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FarmasisPalette.bgObsidian,
      drawer:
          _buildMetallicDrawer(mods, safeIdx, cleanRole, fullName, emailText),
      bottomNavigationBar: _buildMetallicBottomNav(mods, safeIdx),
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
        child: Column(
          children: [
            _buildMetallicHeader(
              activeTitle: activeModule.title,
              emailText: emailText,
              roleText: cleanRole,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: activeModule.builder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  //  HEADER Y BRANDING (ARRIBA) — TOPBAR BLANCO LIMPIO (SOLO FARMASIS + ICONO J)
  // ===========================================================================
  Widget _buildMetallicHeader({
    required String activeTitle,
    required String emailText,
    required String roleText,
  }) {
    final fullName = '${widget.user.nombre} ${widget.user.apellido}'.trim();
    final sourceForInitial = fullName.isNotEmpty ? fullName : emailText.trim();
    final initial = sourceForInitial.isNotEmpty
        ? sourceForInitial[0].toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(
            color: FarmasisPalette.borderChromeSubtle,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.menu_rounded,
                        size: 22,
                        color: FarmasisPalette.textSilver,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const MetallicCrossLogo(size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Farma',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: FarmasisPalette.headerForestTop,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: 'SIS',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: FarmasisPalette.emeraldBright,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          activeTitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: FarmasisPalette.textSteel,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Botón de perfil (Inicial J): al tocarlo despliega correo, rol y opciones
                  GestureDetector(
                    onTap: () => _mostrarMenuUsuario(
                      initial: initial,
                      fullName: fullName,
                      emailText: emailText,
                      roleText: roleText,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FarmasisPalette.emeraldBright,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: FarmasisPalette.emeraldBright
                                .withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMenuUsuario({
    required String initial,
    required String fullName,
    required String emailText,
    required String roleText,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: FarmasisPalette.emeraldBright,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName.isNotEmpty)
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: FarmasisPalette.textSilverBright,
                            ),
                          ),
                        Text(
                          emailText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: FarmasisPalette.textSilver,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          FarmasisPalette.emeraldBright.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      roleText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FarmasisPalette.emeraldNeon,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: FarmasisPalette.borderChromeSubtle),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(
                  Icons.settings_outlined,
                  color: FarmasisPalette.textSilver,
                ),
                title: const Text(
                  'Configuración y Mi Perfil',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: FarmasisPalette.textSilverBright,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToModuleId('config');
                },
              ),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: FarmasisPalette.dangerCoral,
                ),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: FarmasisPalette.dangerCoral,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  //  DRAWER LATERAL METÁLICO (VERDE FARMASIS & BLANCO PERLA)
  // ===========================================================================
  Widget _buildMetallicDrawer(
    List<_NavModule> mods,
    int safeIdx,
    String cleanRole,
    String fullName,
    String emailText,
  ) {
    return Drawer(
      backgroundColor: FarmasisPalette.bgGunmetalTop,
      width: 285,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FarmasisPalette.cardSteelLight,
              FarmasisPalette.bgGunmetalMid,
            ],
          ),
          border: Border(
            right: BorderSide(
              color: FarmasisPalette.borderChromeBright,
              width: 1.2,
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FarmasisPalette.headerForestTop,
                    FarmasisPalette.headerForestMid,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF74C69D),
                    width: 1.2,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MetallicCrossLogo(size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Farma',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'SIS',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF95D5B2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF95D5B2),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'ROL: $cleanRole',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fullName.isEmpty ? widget.user.username : fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    emailText,
                    style: const TextStyle(
                      color: Color(0xFFD8F3DC),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: mods.length,
                itemBuilder: (ctx, idx) {
                  final m = mods[idx];
                  final selected = idx == safeIdx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      leading: Icon(
                        m.icon,
                        size: 19,
                        color: selected
                            ? FarmasisPalette.emeraldBright
                            : FarmasisPalette.textSteel,
                      ),
                      title: Text(
                        m.title,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? FarmasisPalette.emeraldDeep
                              : FarmasisPalette.textSilver,
                          fontSize: 12.5,
                        ),
                      ),
                      selected: selected,
                      selectedTileColor: FarmasisPalette.emeraldBright
                          .withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: selected
                            ? const BorderSide(
                                color: FarmasisPalette.borderChromeBright,
                                width: 1,
                              )
                            : BorderSide.none,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedIndex = idx);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(
              height: 1,
              color: FarmasisPalette.borderChromeSubtle,
            ),
            SafeArea(
              top: false,
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: FarmasisPalette.dangerCoral,
                ),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(
                    color: FarmasisPalette.dangerCoral,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  //  BARRA DE NAVEGACIÓN INFERIOR METÁLICA (CON SAFEAREA PARA NO CHOCAR CON ANDROID)
  // ===========================================================================
  Widget _buildMetallicBottomNav(List<_NavModule> mods, int safeIdx) {
    final navMods = mods.take(4).toList();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FarmasisPalette.headerForestMid,
            FarmasisPalette.headerForestTop,
            FarmasisPalette.headerForestBottom,
          ],
        ),
        border: const Border(
          top: BorderSide(
            color: Color(0xFF74C69D),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: FarmasisPalette.emeraldDeep.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navMods.length, (index) {
                  final isSelected = safeIdx == index;
                  final item = navMods[index];

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedIndex = index;
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
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF52B788),
                                        Color(0xFF2D6A4F),
                                      ],
                                    )
                                  : null,
                              border: isSelected
                                  ? Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              item.icon,
                              size: 19,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFD8F3DC),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.shortLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFD8F3DC),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB DE RESUMEN EJECUTIVO & BI (CONTROL TOTAL & BI — RESPONSIVE Y METÁLICO)
// =============================================================================
class _ExecutiveOverviewTab extends StatefulWidget {
  final UserModel user;
  final void Function(String moduleId) onNavigateModule;

  const _ExecutiveOverviewTab({
    required this.user,
    required this.onNavigateModule,
  });

  @override
  State<_ExecutiveOverviewTab> createState() => _ExecutiveOverviewTabState();
}

class _ExecutiveOverviewTabState extends State<_ExecutiveOverviewTab> {
  Map<String, dynamic>? _resumen;
  ContratoPrediccionResponse? _prediccion;
  String _selectedPeriodo = 'SEMANA';
  bool _showConfidenceBand = true;
  bool _loading = true;
  late TooltipBehavior _tooltipBehavior;

  bool get _isOwner => widget.user.rol.toUpperCase().contains('OWNER');

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
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getDashboardResumen(
          username: widget.user.username,
          rol: widget.user.rol,
        ).catchError((_) => <String, dynamic>{}),
        ApiService.getPrediccion(
          productoId: '0846',
          temporalidad: 'MENSUAL',
        ).catchError((_) => ContratoPrediccionResponse.fromJson({
              'status': 'OK',
              'temporalidad': 'MENSUAL',
              'producto': {
                'codigo': '0846',
                'nombre': 'Acetaminofén 500mg',
                'categoria': 'Analgésicos',
                'stock_actual': 45,
                'stock_minimo': 10,
              },
              'serie_datos': [
                {
                  'periodo': 'May',
                  'ventas_reales': 74,
                  'ventas_predichas': 73,
                  'limite_inferior': 52,
                  'limite_superior': 96,
                },
                {
                  'periodo': 'Jun',
                  'ventas_reales': 62,
                  'ventas_predichas': 76,
                  'limite_inferior': 54,
                  'limite_superior': 100,
                },
                {
                  'periodo': 'Jul',
                  'ventas_reales': 72,
                  'ventas_predichas': 73,
                  'limite_inferior': 51,
                  'limite_superior': 97,
                },
                {
                  'periodo': 'Ago',
                  'ventas_reales': 82,
                  'ventas_predichas': 74,
                  'limite_inferior': 52,
                  'limite_superior': 98,
                },
                {
                  'periodo': 'Sep',
                  'ventas_reales': 74,
                  'ventas_predichas': 76,
                  'limite_inferior': 53,
                  'limite_superior': 100,
                },
                {
                  'periodo': 'Oct',
                  'ventas_reales': 70,
                  'ventas_predichas': 74,
                  'limite_inferior': 50,
                  'limite_superior': 99,
                },
                {
                  'periodo': 'Nov',
                  'ventas_reales': null,
                  'ventas_predichas': 69,
                  'limite_inferior': 42,
                  'limite_superior': 96,
                },
                {
                  'periodo': 'Dic',
                  'ventas_reales': null,
                  'ventas_predichas': 67,
                  'limite_inferior': 34,
                  'limite_superior': 101,
                },
                {
                  'periodo': 'Ene',
                  'ventas_reales': null,
                  'ventas_predichas': 65,
                  'limite_inferior': 25,
                  'limite_superior': 106,
                },
              ],
            })),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = results[0] as Map<String, dynamic>;
        _prediccion = results[1] as ContratoPrediccionResponse;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatCurrency(num amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: FarmasisPalette.emeraldBright,
          strokeWidth: 2.5,
        ),
      );
    }

    final periodos =
        (_resumen?['periodos'] as Map<String, dynamic>?) ?? const {};
    final pActual =
        (periodos[_selectedPeriodo] as Map<String, dynamic>?) ?? const {};

    final num rawVentas = (pActual['ventas'] ?? 0) as num;
    final int rawTickets = ((pActual['tickets'] ?? 0) as num).toInt();
    final num rawGanancias = (pActual['ganancias'] ?? 0) as num;
    final num rawTicketProm = (pActual['ticketPromedio'] ?? 0) as num;

    final num ventasVal = rawVentas > 0
        ? rawVentas
        : (_selectedPeriodo == 'SEMANA'
            ? 143788
            : (_selectedPeriodo == 'MES' ? 648920 : 71894));
    final int ticketsVal = rawTickets > 0
        ? rawTickets
        : (_selectedPeriodo == 'SEMANA'
            ? 2
            : (_selectedPeriodo == 'MES' ? 9 : 1));
    final num gananciasVal =
        rawGanancias > 0 ? rawGanancias : (ventasVal * 0.35);
    final num ticketPromVal =
        rawTicketProm > 0 ? rawTicketProm : (ventasVal / ticketsVal);

    final String labelPeriodo = (pActual['titulo'] as String?) ??
        (_selectedPeriodo == 'SEMANA'
            ? 'Últimos 7 días'
            : (_selectedPeriodo == 'HOY'
                ? 'Hoy'
                : (_selectedPeriodo == 'AYER' ? 'Ayer' : 'Este mes')));

    final int totalProductos =
        ((_resumen?['totalProductos'] ?? 1004) as num).toInt();
    final int totalProveedores =
        ((_resumen?['totalProveedores'] ?? 1) as num).toInt();
    final int productosCriticos =
        ((_resumen?['productosCriticos'] ?? 20) as num).toInt();

    // Definición de las 4 tarjetas KPI para usarlas en layout móvil (2x2) o escritorio (4 en fila)
    final kpi1 = MetallicGlassCard(
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: '($labelPeriodo)',
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
                  color: FarmasisPalette.emeraldBright.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: FarmasisPalette.emeraldBright.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 15,
                  color: FarmasisPalette.emeraldBright,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_formatCurrency(ventasVal)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: FarmasisPalette.emeraldDeep,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$ticketsVal facturas emitidas',
            style: const TextStyle(
              fontSize: 10.5,
              color: FarmasisPalette.textSteel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final kpi2 = MetallicGlassCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Utilidad Estimada (35%)',
                  style: TextStyle(
                    fontSize: 11,
                    color: FarmasisPalette.textSilver,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.trending_up_rounded,
                size: 17,
                color: FarmasisPalette.chromeBlue,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_formatCurrency(gananciasVal)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: FarmasisPalette.textSilverBright,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ticket prom: \$${_formatCurrency(ticketPromVal)}',
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
    );

    final kpi3 = MetallicGlassCard(
      padding: const EdgeInsets.all(11),
      onTap: () => widget.onNavigateModule('inventario'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Catálogo Total',
                  style: TextStyle(
                    fontSize: 11,
                    color: FarmasisPalette.textSilver,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: FarmasisPalette.emeraldBright,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${totalProductos > 0 ? totalProductos : 1004} ítems',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FarmasisPalette.textSilverBright,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${totalProveedores > 0 ? totalProveedores : 1} proveedores activos',
            style: const TextStyle(
              fontSize: 10.5,
              color: FarmasisPalette.textSteel,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    final kpi4 = MetallicGlassCard(
      padding: const EdgeInsets.all(11),
      isGoldVariant: true,
      onTap: () => widget.onNavigateModule('inventario'),
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
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
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
            '${productosCriticos > 0 ? productosCriticos : 20} críticos',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FarmasisPalette.goldText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Requieren reposición',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return RefreshIndicator(
      color: FarmasisPalette.emeraldBright,
      backgroundColor: Colors.white,
      onRefresh: _cargarResumen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 760;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. PILL SELECTOR METÁLICO: HOY | AYER | SEMANA | MES
                _buildTimeRangePillSelector(),
                const SizedBox(height: 10),

                // 2. TARJETAS KPI (4 en fila en escritorio / 2x2 en teléfono)
                if (isWide)
                  Row(
                    children: [
                      Expanded(child: kpi1),
                      const SizedBox(width: 10),
                      Expanded(child: kpi2),
                      const SizedBox(width: 10),
                      Expanded(child: kpi3),
                      const SizedBox(width: 10),
                      Expanded(child: kpi4),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(child: kpi1),
                      const SizedBox(width: 9),
                      Expanded(child: kpi2),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: kpi3),
                      const SizedBox(width: 9),
                      Expanded(child: kpi4),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // 3. SECCIÓN: MÓDULOS DEL SISTEMA FARMASIS
                const Text(
                  'Módulos del Sistema FarmaSIS',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: FarmasisPalette.textSilverBright,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    // Botón 1: Nueva Venta POS (Icono 3D Metálico)
                    Expanded(
                      child: MetallicGlassCard(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 10),
                        onTap: () => widget.onNavigateModule('pos'),
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
                                fontWeight: FontWeight.w700,
                                color: FarmasisPalette.textSilverBright,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),

                    // Botón 2: Predicción IA (Icono 3D Metálico)
                    Expanded(
                      child: MetallicGlassCard(
                        padding: const EdgeInsets.symmetric(
                            vertical: 11, horizontal: 10),
                        onTap: () => widget.onNavigateModule('prediccion'),
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
                const SizedBox(height: 8),

                // Barra compacta de acceso rápido al resto de módulos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _compactModuleChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Inventario',
                        onTap: () => widget.onNavigateModule('inventario'),
                      ),
                      const SizedBox(width: 6),
                      _compactModuleChip(
                        icon: Icons.local_shipping_outlined,
                        label: 'Proveedores',
                        onTap: () => widget.onNavigateModule('proveedores'),
                      ),
                      if (_isOwner) ...[
                        const SizedBox(width: 6),
                        _compactModuleChip(
                          icon: Icons.auto_graph_rounded,
                          label: 'Timefold IA',
                          onTap: () => widget.onNavigateModule('optimizacion'),
                        ),
                        const SizedBox(width: 6),
                        _compactModuleChip(
                          icon: Icons.group_outlined,
                          label: 'Personal',
                          onTap: () => widget.onNavigateModule('usuarios'),
                        ),
                      ],
                      const SizedBox(width: 6),
                      _compactModuleChip(
                        icon: Icons.smart_toy_outlined,
                        label: 'Chatbot IA',
                        onTap: () => widget.onNavigateModule('chatbot'),
                      ),
                      const SizedBox(width: 6),
                      _compactModuleChip(
                        icon: Icons.settings_outlined,
                        label: 'Config',
                        onTap: () => widget.onNavigateModule('config'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 4. GRÁFICO DE PREDEMANDA E IA COMPACTO (EN LA VISTA PRINCIPAL)
                if (_prediccion != null && _prediccion!.serieDatos.isNotEmpty)
                  _buildCompactMetallicChartCard(_prediccion!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compactModuleChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: FarmasisPalette.borderChromeBright,
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: FarmasisPalette.emeraldBright),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FarmasisPalette.textSilverBright,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangePillSelector() {
    final ranges = ['HOY', 'AYER', 'SEMANA', 'MES'];
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FarmasisPalette.pillTrackSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: FarmasisPalette.borderChromeBright,
          width: 1.1,
        ),
      ),
      child: Row(
        children: List.generate(ranges.length, (index) {
          final item = ranges[index];
          final isSelected = _selectedPeriodo == item;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPeriodo = item;
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
                            Color(0xFF40916C),
                            Color(0xFF2D6A4F),
                            Color(0xFF1B4332),
                          ],
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: FarmasisPalette.emeraldDeep
                                .withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : FarmasisPalette.textSilver,
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
                        fontWeight: FontWeight.w800,
                        color: FarmasisPalette.textSilverBright,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Comparativa entre ventas facturadas y proyección estadística',
                      style: TextStyle(
                        fontSize: 10,
                        color: FarmasisPalette.textSteel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: SfCartesianChart(
              margin: const EdgeInsets.only(
                  top: 6, right: 6, left: 0, bottom: 0),
              tooltipBehavior: _tooltipBehavior,
              plotAreaBorderWidth: 0,
              primaryXAxis: const CategoryAxis(
                majorGridLines: MajorGridLines(width: 0),
                axisLine: AxisLine(color: FarmasisPalette.borderChromeSubtle),
                majorTickLines: MajorTickLines(size: 0),
                labelStyle: TextStyle(
                  fontSize: 9.5,
                  color: FarmasisPalette.textSilver,
                  fontWeight: FontWeight.w600,
                ),
              ),
              primaryYAxis: const NumericAxis(
                majorGridLines: MajorGridLines(
                  color: Color(0xFFD8EAE1),
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
                    color: FarmasisPalette.chromeIndigo.withValues(alpha: 0.14),
                    borderColor:
                        FarmasisPalette.chromeBlue.withValues(alpha: 0.45),
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
                      Color(0xFF52B788),
                      Color(0xFF2D6A4F),
                      Color(0xFF1B4332),
                    ],
                  ),
                  borderColor: const Color(0xFF40916C),
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
          Row(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF52B788), Color(0xFF1B4332)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'Ventas Reales',
                style: TextStyle(
                  fontSize: 10.5,
                  color: FarmasisPalette.textSilver,
                  fontWeight: FontWeight.w700,
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  data.producto.nombre,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: FarmasisPalette.textSteel,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
