import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';

class GestionUsuariosScreen extends StatefulWidget {
  final UserModel user;

  const GestionUsuariosScreen({super.key, required this.user});

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  List<dynamic> _usuarios = [];
  String _filtro = 'TODOS';
  int _activos = 0;
  int _inactivos = 0;
  bool _loading = true;

  bool get _isOwner => widget.user.rol.toUpperCase().contains('OWNER');

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getUsuarios(
        filtro: _filtro == 'TODOS' ? null : _filtro,
      );
      if (!mounted) return;
      setState(() {
        _usuarios = (data['usuarios'] as List<dynamic>? ?? []);
        _activos = ((data['totalActivos'] ?? 0) as num).toInt();
        _inactivos = ((data['totalInactivos'] ?? 0) as num).toInt();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _darkField(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: FarmasisPalette.textSilverBright,
        fontSize: 12.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: FarmasisPalette.textSilver,
          fontSize: 11.5,
        ),
        filled: true,
        fillColor: FarmasisPalette.inputSurface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FarmasisPalette.borderChromeSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FarmasisPalette.borderChromeSubtle),
        ),
      ),
    );
  }

  Future<void> _mostrarModalCrearUsuario() async {
    final nombreCtrl = TextEditingController();
    final apellidoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Farma2026!');
    String rolSel = 'ROLE_EMPLEADO';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(18),
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
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Registrar Nuevo Colaborador',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: FarmasisPalette.textSilverBright,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _darkField(nombreCtrl, 'Nombre')),
                        const SizedBox(width: 8),
                        Expanded(child: _darkField(apellidoCtrl, 'Apellido')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _darkField(
                      emailCtrl,
                      'Correo Electrónico (será su usuario)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _darkField(
                            telCtrl,
                            'Celular',
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: rolSel,
                            dropdownColor: FarmasisPalette.cardSteelDark,
                            style: const TextStyle(
                              color: FarmasisPalette.textSilverBright,
                              fontSize: 12.5,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Rol',
                              labelStyle: const TextStyle(
                                color: FarmasisPalette.textSilver,
                                fontSize: 11.5,
                              ),
                              filled: true,
                              fillColor: FarmasisPalette.inputSurface,
                              isDense: true,
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
                            items: [
                              const DropdownMenuItem(
                                  value: 'ROLE_EMPLEADO',
                                  child: Text('Empleado')),
                              if (_isOwner)
                                const DropdownMenuItem(
                                    value: 'ROLE_ADMIN',
                                    child: Text('Administrador')),
                            ],
                            onChanged: (v) {
                              if (v != null) setModalState(() => rolSel = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _darkField(
                      passCtrl,
                      'Contraseña inicial (Mínimo 8 caracteres)',
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await ApiService.crearUsuario({
                            'nombre': nombreCtrl.text.trim(),
                            'apellido': apellidoCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'username': emailCtrl.text.trim(),
                            'telefono': telCtrl.text.trim(),
                            'password': passCtrl.text.trim(),
                            'rol': rolSel,
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF3B121D),
                                content: Text(
                                    e.toString().replaceAll('Exception:', '')),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_1_rounded,
                          size: 18),
                      label: const Text('Crear Usuario y Enviar Correo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmasisPalette.emeraldBright,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (ok == true) {
      _cargarUsuarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarModalCrearUsuario,
        backgroundColor: FarmasisPalette.emeraldBright,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text(
          'Nuevo Usuario',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 17, color: FarmasisPalette.emeraldNeon),
                        const SizedBox(width: 7),
                        Text(
                          'Activos: $_activos',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MetallicGlassCard(
                    padding: const EdgeInsets.all(10),
                    isGoldVariant: _inactivos > 0,
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded,
                            size: 17, color: FarmasisPalette.goldWarm),
                        const SizedBox(width: 7),
                        Text(
                          'Inactivos: $_inactivos',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: FarmasisPalette.goldText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in [
                    'TODOS',
                    'ACTIVOS',
                    'INACTIVOS',
                    'ROLE_ADMIN',
                    'ROLE_EMPLEADO'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _filtro = f);
                          _cargarUsuarios();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _filtro == f
                                ? FarmasisPalette.emeraldBright
                                    .withValues(alpha: 0.22)
                                : FarmasisPalette.inputSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _filtro == f
                                  ? FarmasisPalette.emeraldNeon
                                  : FarmasisPalette.borderChromeSubtle,
                            ),
                          ),
                          child: Text(
                            f.replaceAll('ROLE_', ''),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _filtro == f
                                  ? FarmasisPalette.emeraldNeon
                                  : FarmasisPalette.textSilver,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FarmasisPalette.emeraldNeon,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: FarmasisPalette.emeraldNeon,
                      backgroundColor: FarmasisPalette.cardSteelDark,
                      onRefresh: _cargarUsuarios,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 72),
                        itemCount: _usuarios.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (_, idx) {
                          final u = _usuarios[idx] as Map<String, dynamic>;
                          final activo = u['activo'] == true;
                          final rol =
                              '${u['rol'] ?? 'EMPLEADO'}'.replaceAll('ROLE_', '');
                          final isAdmin = rol.contains('ADMIN');
                          return MetallicGlassCard(
                            padding: const EdgeInsets.all(11),
                            isGoldVariant: !activo,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: FarmasisPalette.inputSurface,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: isAdmin
                                              ? FarmasisPalette.chromeBlue
                                              : FarmasisPalette
                                                  .borderChromeSubtle,
                                        ),
                                      ),
                                      child: Icon(
                                        isAdmin
                                            ? Icons
                                                .admin_panel_settings_rounded
                                            : Icons.badge_outlined,
                                        size: 18,
                                        color: isAdmin
                                            ? FarmasisPalette.chromeBlue
                                            : FarmasisPalette.emeraldNeon,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${u['nombre']} ${u['apellido']}'
                                                    .trim()
                                                    .isEmpty
                                                ? '${u['username']}'
                                                : '${u['nombre']} ${u['apellido']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12.5,
                                              color: FarmasisPalette
                                                  .textSilverBright,
                                            ),
                                          ),
                                          Text(
                                            '${u['email'] ?? u['username']}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: FarmasisPalette.textSteel,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAdmin
                                            ? FarmasisPalette.chromeIndigo
                                                .withValues(alpha: 0.22)
                                            : FarmasisPalette.emeraldBright
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isAdmin
                                              ? FarmasisPalette.chromeBlue
                                              : FarmasisPalette.emeraldNeon,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        rol,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isAdmin
                                              ? FarmasisPalette.chromeBlue
                                              : FarmasisPalette.emeraldNeon,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  height: 12,
                                  color: FarmasisPalette.borderChromeSubtle
                                      .withValues(alpha: 0.45),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (activo && _isOwner)
                                      InkWell(
                                        onTap: () async {
                                          try {
                                            final nuevoRol = isAdmin
                                                ? 'ROLE_EMPLEADO'
                                                : 'ROLE_ADMIN';
                                            await ApiService.cambiarRolUsuario(
                                                '${u['id']}', nuevoRol);
                                            _cargarUsuarios();
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(e
                                                    .toString()
                                                    .replaceAll(
                                                        'Exception:', '')),
                                              ));
                                            }
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.swap_horiz_rounded,
                                                size: 14,
                                                color:
                                                    FarmasisPalette.chromeBlue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isAdmin
                                                    ? 'Pasar a Empleado'
                                                    : 'Ascender a Admin',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: FarmasisPalette
                                                      .chromeBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    if (_isOwner || !isAdmin)
                                      InkWell(
                                      onTap: () async {
                                        try {
                                          await ApiService.cambiarEstadoUsuario(
                                              '${u['id']}', !activo);
                                          _cargarUsuarios();
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(e
                                                  .toString()
                                                  .replaceAll(
                                                      'Exception:', '')),
                                            ));
                                          }
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              activo
                                                  ? Icons.block_rounded
                                                  : Icons.check_circle_outline,
                                              size: 14,
                                              color: activo
                                                  ? FarmasisPalette.dangerCoral
                                                  : FarmasisPalette.emeraldNeon,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              activo ? 'Suspender' : 'Activar',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: activo
                                                    ? FarmasisPalette
                                                        .dangerCoral
                                                    : FarmasisPalette
                                                        .emeraldNeon,
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
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE OPTIMIZACIÓN IA CON TIMEFOLD SOLVER (OWNER)
// =============================================================================
class OptimizacionTimefoldScreen extends StatefulWidget {
  const OptimizacionTimefoldScreen({super.key});

  @override
  State<OptimizacionTimefoldScreen> createState() =>
      _OptimizacionTimefoldScreenState();
}

class _OptimizacionTimefoldScreenState
    extends State<OptimizacionTimefoldScreen> {
  Map<String, dynamic>? _resultado;
  bool _loading = true;
  bool _ejecutando = false;

  @override
  void initState() {
    super.initState();
    _cargarUltimo();
  }

  Future<void> _cargarUltimo() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUltimaOptimizacion();
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _ejecutarSolver() async {
    if (_ejecutando) return;
    setState(() => _ejecutando = true);
    try {
      final res = await ApiService.ejecutarOptimizacion();
      if (!mounted) return;
      setState(() {
        _resultado = res;
        _ejecutando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _ejecutando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3B121D),
          content: Text(e.toString().replaceAll('Exception:', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final propuestas =
        (_resultado?['propuestas'] as List<dynamic>?) ?? const [];
    final resumen =
        (_resultado?['resumen'] as Map<String, dynamic>?) ?? const {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetallicGlassCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    MetallicModuleIcon(
                      icon: Icons.auto_graph_rounded,
                      isAiVariant: true,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motor Timefold Solver IA',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: FarmasisPalette.textSilverBright,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Optimización matemática de compras, presupuesto (\$1.5M), almacén y descuentos por vencimiento.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: FarmasisPalette.textSteel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _ejecutando ? null : _ejecutarSolver,
                    icon: _ejecutando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(
                      _ejecutando
                          ? 'Resolviendo restricciones (Timefold)...'
                          : 'Ejecutar Optimización Ahora',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmasisPalette.emeraldBright,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(
                child: CircularProgressIndicator(
                  color: FarmasisPalette.emeraldNeon,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else if (_resultado == null || _resultado!['status'] != 'OK')
            const MetallicGlassCard(
              padding: EdgeInsets.all(18),
              child: Text(
                'Aún no se ha ejecutado una corrida de optimización. Presiona el botón superior para generar el plan óptimo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FarmasisPalette.textSilver,
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _metricBox(
                    'Utilidad Estimada',
                    '\$${resumen['utilidadTotalEstimada'] ?? 0}',
                    'Score: ${_resultado!['score'] ?? ''}',
                    FarmasisPalette.emeraldNeon,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox(
                    'Inversión Pedido',
                    '\$${resumen['costoTotalPedidos'] ?? 0}',
                    'Uso: ${resumen['presupuestoUsadoPorcentaje'] ?? '0%'}',
                    FarmasisPalette.chromeBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _metricBox(
                    'Unidades a Pedir',
                    '${resumen['totalUnidadesAPedir'] ?? 0} uds',
                    'Espacio: ${resumen['espacioTotalUsado'] ?? 0} / 5000',
                    FarmasisPalette.textSilverBright,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricBox(
                    'Horas Operativas',
                    '${resumen['horasTotalesRequeridas'] ?? 0} h',
                    'Disponibles: ${resumen['horasDisponibles'] ?? 160} h',
                    FarmasisPalette.goldText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Propuestas Óptimas (${propuestas.length} medicamentos)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: FarmasisPalette.textSilverBright,
              ),
            ),
            const SizedBox(height: 7),
            ...propuestas.map((raw) {
              final p = raw as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: MetallicGlassCard(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['productoNombre']} (${p['productoCodigo']})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: FarmasisPalette.textSilverBright,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stock: ${p['cantidadActual']} · Demanda: ${p['demandaEstimada']} · Desc: ${p['descuentoPorcentaje']}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: FarmasisPalette.emeraldBright
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: FarmasisPalette.emeraldNeon,
                                  width: 0.8),
                            ),
                            child: Text(
                              'Pedir +${p['cantidadAPedir']} uds',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                color: FarmasisPalette.emeraldNeon,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Utilidad: \$${p['utilidadEstimada']}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: FarmasisPalette.textSilver,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _metricBox(String title, String val, String sub, Color accent) {
    return MetallicGlassCard(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: FarmasisPalette.textSilver,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10,
              color: FarmasisPalette.textSteel,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PANTALLA DE CONFIGURACIÓN DEL SISTEMA, PERFIL Y SERVIDOR AWS
// =============================================================================
class ConfiguracionScreen extends StatefulWidget {
  final UserModel user;

  const ConfiguracionScreen({super.key, required this.user});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _nombreFarmaciaCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _umbralCtrl = TextEditingController();
  String? _configId;

  final _emailCtrl = TextEditingController();
  final _passActualCtrl = TextEditingController();
  final _passNuevaCtrl = TextEditingController();
  bool _requiere2FA = false;

  late TextEditingController _serverUrlCtrl;
  bool _loading = true;

  bool get _canEditSistema =>
      widget.user.rol.toUpperCase().contains('OWNER') ||
      widget.user.rol.toUpperCase().contains('ADMIN');

  @override
  void initState() {
    super.initState();
    _serverUrlCtrl = TextEditingController(text: ApiService.springBootBaseUrl);
    _cargarConfig();
  }

  @override
  void dispose() {
    _nombreFarmaciaCtrl.dispose();
    _nitCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    _umbralCtrl.dispose();
    _emailCtrl.dispose();
    _passActualCtrl.dispose();
    _passNuevaCtrl.dispose();
    _serverUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    setState(() => _loading = true);
    try {
      final data =
          await ApiService.getConfiguracion(username: widget.user.username);
      if (!mounted) return;
      final sis = data['sistema'] as Map<String, dynamic>? ?? {};
      final perf = data['perfil'] as Map<String, dynamic>? ?? {};
      setState(() {
        _configId = sis['id']?.toString();
        _nombreFarmaciaCtrl.text = '${sis['nombreFarmacia'] ?? 'FARMASIS'}';
        _nitCtrl.text = '${sis['nit'] ?? ''}';
        _dirCtrl.text = '${sis['direccion'] ?? ''}';
        _telCtrl.text = '${sis['telefono'] ?? ''}';
        _umbralCtrl.text = '${sis['umbralStockBajo'] ?? 5}';
        _emailCtrl.text = '${perf['email'] ?? widget.user.email}';
        _requiere2FA = perf['requiere2FA'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Widget _darkField(
    TextEditingController ctrl,
    String label, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: FarmasisPalette.textSilverBright,
        fontSize: 12.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: FarmasisPalette.textSilver,
          fontSize: 11.5,
        ),
        filled: true,
        fillColor: FarmasisPalette.inputSurface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FarmasisPalette.borderChromeSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: FarmasisPalette.borderChromeSubtle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: FarmasisPalette.emeraldNeon,
          strokeWidth: 2.5,
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_canEditSistema) ...[
            MetallicGlassCard(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Datos Institucionales de la Farmacia',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: FarmasisPalette.textSilverBright,
                    ),
                  ),
                  const SizedBox(height: 11),
                  _darkField(_nombreFarmaciaCtrl, 'Nombre Comercial'),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(child: _darkField(_nitCtrl, 'NIT')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _darkField(
                          _umbralCtrl,
                          'Umbral Stock Bajo',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  _darkField(_dirCtrl, 'Dirección Principal'),
                  const SizedBox(height: 9),
                  _darkField(_telCtrl, 'Teléfono'),
                  const SizedBox(height: 11),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await ApiService.guardarConfiguracionSistema({
                          if (_configId != null) 'id': _configId,
                          'nombreFarmacia': _nombreFarmaciaCtrl.text.trim(),
                          'nit': _nitCtrl.text.trim(),
                          'direccion': _dirCtrl.text.trim(),
                          'telefono': _telCtrl.text.trim(),
                          'umbralStockBajo':
                              int.tryParse(_umbralCtrl.text.trim()) ?? 5,
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: FarmasisPalette.emeraldDeep,
                              content: Text(
                                  'Configuración del sistema actualizada'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Guardar Datos de Farmacia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FarmasisPalette.emeraldBright,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          MetallicGlassCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Seguridad y Perfil de Usuario',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FarmasisPalette.textSilverBright,
                  ),
                ),
                const SizedBox(height: 10),
                _darkField(_emailCtrl, 'Correo Electrónico'),
                const SizedBox(height: 9),
                _darkField(
                  _passActualCtrl,
                  'Contraseña Actual (para confirmar cambios)',
                  obscure: true,
                ),
                const SizedBox(height: 9),
                _darkField(
                  _passNuevaCtrl,
                  'Nueva Contraseña (opcional)',
                  obscure: true,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: FarmasisPalette.emeraldNeon,
                  title: const Text(
                    'Verificación en 2 pasos (2FA por correo)',
                    style: TextStyle(
                      fontSize: 12,
                      color: FarmasisPalette.textSilver,
                    ),
                  ),
                  value: _requiere2FA,
                  onChanged: (v) => setState(() => _requiere2FA = v),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await ApiService.actualizarPerfil({
                        'username': widget.user.username,
                        'email': _emailCtrl.text.trim(),
                        'passwordActual': _passActualCtrl.text.trim(),
                        'nuevaPassword': _passNuevaCtrl.text.trim(),
                        'requiere2FA': _requiere2FA,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: FarmasisPalette.emeraldDeep,
                            content: Text('Perfil actualizado con éxito'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                e.toString().replaceAll('Exception:', '')),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.lock_reset_rounded, size: 17),
                  label: const Text('Actualizar Mi Perfil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FarmasisPalette.emeraldDeep,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MetallicGlassCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Endpoint de Servidor / Nube AWS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FarmasisPalette.textSilverBright,
                  ),
                ),
                const SizedBox(height: 9),
                _darkField(
                  _serverUrlCtrl,
                  'URL Base del Backend (Local o AWS EC2)',
                ),
                const SizedBox(height: 9),
                OutlinedButton.icon(
                  onPressed: () {
                    ApiService.setCustomServerUrl(_serverUrlCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: FarmasisPalette.emeraldDeep,
                        content: Text(
                            'Servidor apuntando a: ${ApiService.springBootBaseUrl}'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FarmasisPalette.emeraldNeon,
                    side: const BorderSide(color: FarmasisPalette.emeraldNeon),
                  ),
                  icon: const Icon(Icons.cloud_done_outlined, size: 17),
                  label: const Text('Aplicar URL de Servidor'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
