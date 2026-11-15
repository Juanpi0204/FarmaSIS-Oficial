import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';

class ProveedoresScreen extends StatefulWidget {
  final UserModel user;

  const ProveedoresScreen({super.key, required this.user});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  List<dynamic> _proveedores = [];
  String _search = '';
  String _estado = 'ACTIVOS';
  bool _loading = true;

  bool get _isOwner => widget.user.rol.toUpperCase().contains('OWNER');

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  Future<void> _cargarProveedores() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getProveedores(
        search: _search,
        estado: _estado,
      );
      if (!mounted) return;
      setState(() {
        _proveedores = (data['proveedores'] as List<dynamic>? ?? []);
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
    String? hint,
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
        hintText: hint,
        labelStyle: const TextStyle(
          color: FarmasisPalette.textSilver,
          fontSize: 11.5,
        ),
        hintStyle: const TextStyle(
          color: FarmasisPalette.textMuted,
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

  Future<void> _mostrarFormularioProveedor(
      {Map<String, dynamic>? prov}) async {
    final isEdit = prov != null;
    final nombreCtrl = TextEditingController(text: '${prov?['nombre'] ?? ''}');
    final empresaCtrl =
        TextEditingController(text: '${prov?['empresa'] ?? ''}');
    final telCtrl = TextEditingController(text: '${prov?['telefono'] ?? ''}');
    final emailCtrl = TextEditingController(text: '${prov?['email'] ?? ''}');
    final dirCtrl = TextEditingController(text: '${prov?['direccion'] ?? ''}');
    final tipoCtrl = TextEditingController(
        text: '${prov?['tipoProductos'] ?? 'Medicamentos'}');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text(
                    isEdit ? 'Editar Proveedor' : 'Nuevo Proveedor',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FarmasisPalette.textSilverBright,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _darkField(nombreCtrl, 'Nombre del Contacto (solo letras)'),
                  const SizedBox(height: 10),
                  _darkField(empresaCtrl, 'Empresa / Laboratorio'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _darkField(
                          telCtrl,
                          'Celular (10 díg, inicia en 3)',
                          hint: '3001234567',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _darkField(tipoCtrl, 'Línea / Categoría'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _darkField(
                    emailCtrl,
                    'Correo Electrónico',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _darkField(dirCtrl, 'Dirección Comercial'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final body = {
                          'nombre': nombreCtrl.text.trim(),
                          'empresa': empresaCtrl.text.trim(),
                          'telefono': telCtrl.text.trim(),
                          'email': emailCtrl.text.trim(),
                          'direccion': dirCtrl.text.trim(),
                          'tipoProductos': tipoCtrl.text.trim(),
                        };
                        if (isEdit) {
                          await ApiService.actualizarProveedor(
                              '${prov['id']}', body);
                        } else {
                          await ApiService.crearProveedor(
                              body, widget.user.username);
                        }
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
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                        isEdit ? 'Guardar Cambios' : 'Registrar Proveedor'),
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
    );

    if (ok == true) {
      _cargarProveedores();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioProveedor(),
        backgroundColor: FarmasisPalette.emeraldBright,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded, size: 18),
        label: const Text(
          'Nuevo Proveedor',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          children: [
            // PILL SELECTOR: PROVEEDORES ACTIVOS vs ARCHIVADOS
            Container(
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: FarmasisPalette.pillTrackSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FarmasisPalette.borderChromeBright,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _estado = 'ACTIVOS');
                        _cargarProveedores();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: _estado == 'ACTIVOS'
                              ? FarmasisPalette.headerForestTop
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Proveedores Activos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _estado == 'ACTIVOS'
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _estado == 'ACTIVOS'
                                ? Colors.white
                                : FarmasisPalette.textSilver,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _estado = 'ARCHIVADOS');
                        _cargarProveedores();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: _estado == 'ARCHIVADOS'
                              ? FarmasisPalette.goldWarm
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Archivados',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _estado == 'ARCHIVADOS'
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _estado == 'ARCHIVADOS'
                                ? Colors.white
                                : FarmasisPalette.goldText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 36,
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _cargarProveedores();
                },
                style: const TextStyle(
                  fontSize: 12.5,
                  color: FarmasisPalette.textSilverBright,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar proveedor o laboratorio...',
                  hintStyle: const TextStyle(
                    fontSize: 11.5,
                    color: FarmasisPalette.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: FarmasisPalette.textSteel,
                  ),
                  filled: true,
                  fillColor: FarmasisPalette.inputSurface,
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
                      onRefresh: _cargarProveedores,
                      child: _proveedores.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay proveedores en esta vista',
                                style: TextStyle(
                                  color: FarmasisPalette.textSteel,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 72),
                              itemCount: _proveedores.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, idx) {
                                final p =
                                    _proveedores[idx] as Map<String, dynamic>;
                                final activo = p['activo'] != false;
                                return MetallicGlassCard(
                                  padding: const EdgeInsets.all(11),
                                  isGoldVariant: !activo,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  FarmasisPalette.inputSurface,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                color: FarmasisPalette
                                                    .borderChromeSubtle,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.local_shipping_outlined,
                                              color:
                                                  FarmasisPalette.emeraldNeon,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${p['empresa'] ?? p['nombre'] ?? ''}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: FarmasisPalette
                                                        .textSilverBright,
                                                  ),
                                                ),
                                                Text(
                                                  'Contacto: ${p['nombre'] ?? ''} · ${p['tipoProductos'] ?? 'General'}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: FarmasisPalette
                                                        .textSteel,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        '📞 ${p['telefono'] ?? '—'}   ✉️ ${p['email'] ?? '—'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: FarmasisPalette.textSilver,
                                        ),
                                      ),
                                      Divider(
                                        height: 12,
                                        color: FarmasisPalette
                                            .borderChromeSubtle
                                            .withValues(alpha: 0.45),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                            onTap: () =>
                                                _mostrarFormularioProveedor(
                                                    prov: p),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 14,
                                                    color: FarmasisPalette
                                                        .textSilverBright,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Editar',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: FarmasisPalette
                                                          .textSilverBright,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_isOwner) ...[
                                            const SizedBox(width: 10),
                                            InkWell(
                                              onTap: () async {
                                                await ApiService
                                                    .cambiarEstadoProveedor(
                                                        '${p['id']}', !activo);
                                                _cargarProveedores();
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      activo
                                                          ? Icons
                                                              .archive_outlined
                                                          : Icons
                                                              .restore_rounded,
                                                      size: 14,
                                                      color: activo
                                                          ? FarmasisPalette
                                                              .dangerCoral
                                                          : FarmasisPalette
                                                              .emeraldNeon,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      activo
                                                          ? 'Archivar'
                                                          : 'Reactivar',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
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
