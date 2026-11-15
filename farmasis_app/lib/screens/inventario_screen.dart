import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';

class InventarioScreen extends StatefulWidget {
  final UserModel user;

  const InventarioScreen({super.key, required this.user});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  List<dynamic> _productos = [];
  List<String> _categorias = ['Todas'];
  String _selectedCat = 'Todas';
  String _search = '';
  bool _soloStockBajo = false;
  bool _soloEnOferta = false;
  bool _verArchivados = false;
  int _stockBajoCount = 0;
  bool _loading = true;

  bool get _isOwner => widget.user.rol.toUpperCase().contains('OWNER');
  bool get _canEdit =>
      _isOwner || widget.user.rol.toUpperCase().contains('ADMIN');

  @override
  void initState() {
    super.initState();
    _cargarInventario();
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

  Future<void> _cargarInventario() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getInventario(
        size: 120,
        search: _search,
        categoria: _selectedCat,
        stockBajo: _soloStockBajo ? true : null,
        enOferta: _soloEnOferta ? true : null,
        archivados: _verArchivados,
      );
      if (!mounted) return;
      final cats = <String>{'Todas'};
      for (final c in (data['categorias'] as List<dynamic>? ?? [])) {
        final clean = '$c'.replaceAll(RegExp(r'^[,.\s]+'), '').trim();
        if (clean.isNotEmpty) cats.add(clean);
      }
      setState(() {
        _productos = (data['productos'] as List<dynamic>? ?? []);
        _categorias = cats.toList();
        _stockBajoCount = ((data['stockBajoCount'] ?? 0) as num).toInt();
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

  Future<void> _mostrarFormularioProducto({Map<String, dynamic>? prod}) async {
    final isEdit = prod != null;
    final codigoCtrl = TextEditingController(text: '${prod?['codigo'] ?? ''}');
    final nombreCtrl = TextEditingController(text: '${prod?['nombre'] ?? ''}');
    final catCtrl =
        TextEditingController(text: '${prod?['categoria'] ?? 'Analgésicos'}');
    final costoCtrl =
        TextEditingController(text: '${prod?['costoCompra'] ?? '2500'}');
    final precioCtrl =
        TextEditingController(text: '${prod?['precio'] ?? '4200'}');
    final cantCtrl = TextEditingController(text: '${prod?['cantidad'] ?? '30'}');
    final minCtrl =
        TextEditingController(text: '${prod?['stockMinimo'] ?? '5'}');
    final loteCtrl = TextEditingController(text: '${prod?['lote'] ?? 'L-2026'}');
    final presCtrl =
        TextEditingController(text: '${prod?['presentacion'] ?? 'Caja x 10'}');

    final guardado = await showModalBottomSheet<bool>(
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
                    isEdit ? 'Editar Producto' : 'Nuevo Producto Farmacéutico',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: FarmasisPalette.textSilverBright,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _darkField(codigoCtrl, 'Código (4 díg)',
                            hint: '0125'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _darkField(nombreCtrl, 'Nombre del medicamento'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _darkField(catCtrl, 'Categoría')),
                      const SizedBox(width: 8),
                      Expanded(child: _darkField(presCtrl, 'Presentación')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _darkField(
                          costoCtrl,
                          'Costo Compra (\$)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _darkField(
                          precioCtrl,
                          'Precio Venta (\$)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _darkField(
                          cantCtrl,
                          'Stock Actual',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _darkField(
                          minCtrl,
                          'Stock Mínimo',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _darkField(loteCtrl, 'Lote')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final body = {
                          'codigo': codigoCtrl.text.trim(),
                          'nombre': nombreCtrl.text.trim(),
                          'categoria': catCtrl.text.trim(),
                          'presentacion': presCtrl.text.trim(),
                          'costoCompra':
                              double.tryParse(costoCtrl.text.trim()) ?? 1000,
                          'precio':
                              double.tryParse(precioCtrl.text.trim()) ?? 2000,
                          'cantidad': int.tryParse(cantCtrl.text.trim()) ?? 0,
                          'stockMinimo': int.tryParse(minCtrl.text.trim()) ?? 5,
                          'lote': loteCtrl.text.trim(),
                          'activo': true,
                        };
                        if (isEdit) {
                          await ApiService.actualizarProducto(
                              '${prod['id']}', body);
                        } else {
                          await ApiService.crearProducto(body);
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
                    label:
                        Text(isEdit ? 'Guardar Cambios' : 'Registrar Producto'),
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

    if (guardado == true) {
      _cargarInventario();
    }
  }

  Future<void> _dialogoDescuento(Map<String, dynamic> prod) async {
    final pctCtrl = TextEditingController(text: '15');
    final tieneDescuento = prod['precioOriginal'] != null;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FarmasisPalette.cardSteelDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FarmasisPalette.borderChromeBright),
        ),
        title: Text(
          'Promoción · ${prod['nombre']}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: FarmasisPalette.textSilverBright,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _darkField(
              pctCtrl,
              'Porcentaje de descuento (%)',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          if (tieneDescuento)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ApiService.revertirDescuentoProducto('${prod['id']}');
                _cargarInventario();
              },
              child: const Text(
                'Quitar Oferta',
                style: TextStyle(color: FarmasisPalette.dangerCoral),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: FarmasisPalette.textSilver),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final pct = double.tryParse(pctCtrl.text.trim()) ?? 10;
              Navigator.pop(ctx);
              await ApiService.aplicarDescuentoProducto('${prod['id']}', pct);
              _cargarInventario();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmasisPalette.emeraldBright,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarFormularioProducto(),
              backgroundColor: FarmasisPalette.emeraldBright,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Nuevo Producto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          children: [
            // PILL SELECTOR: CATÁLOGO TOTAL vs STOCK CRÍTICO
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
                        setState(() {
                          _soloStockBajo = false;
                          _verArchivados = false;
                        });
                        _cargarInventario();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: !_soloStockBajo && !_verArchivados
                              ? FarmasisPalette.headerForestTop
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Catálogo Activo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: !_soloStockBajo && !_verArchivados
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: !_soloStockBajo && !_verArchivados
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
                        setState(() {
                          _soloStockBajo = true;
                          _verArchivados = false;
                        });
                        _cargarInventario();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: _soloStockBajo
                              ? FarmasisPalette.goldWarm
                              : Colors.transparent,
                        ),
                        child: Text(
                          'Stock Crítico (${_stockBajoCount > 0 ? _stockBajoCount : 20})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _soloStockBajo
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _soloStockBajo
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

            // BUSCADOR Y FILTROS COMPACTOS
            MetallicGlassCard(
              padding: const EdgeInsets.all(9),
              child: Column(
                children: [
                  SizedBox(
                    height: 35,
                    child: TextField(
                      onChanged: (v) {
                        _search = v;
                        _cargarInventario();
                      },
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: FarmasisPalette.textSilverBright,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Filtrar inventario por código o nombre...',
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
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                              color: FarmasisPalette.borderChromeSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                          borderSide: const BorderSide(
                              color: FarmasisPalette.borderChromeSubtle),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterPill(
                          label: 'En Oferta',
                          selected: _soloEnOferta,
                          onTap: () {
                            setState(() {
                              _soloEnOferta = !_soloEnOferta;
                              _verArchivados = false;
                            });
                            _cargarInventario();
                          },
                        ),
                        if (_isOwner) ...[
                          const SizedBox(width: 6),
                          _filterPill(
                            label: 'Archivados',
                            selected: _verArchivados,
                            onTap: () {
                              setState(() {
                                _verArchivados = !_verArchivados;
                                if (_verArchivados) {
                                  _soloStockBajo = false;
                                  _soloEnOferta = false;
                                }
                              });
                              _cargarInventario();
                            },
                          ),
                        ],
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _categorias.contains(_selectedCat)
                              ? _selectedCat
                              : 'Todas',
                          dropdownColor: FarmasisPalette.cardSteelDark,
                          underline: const SizedBox(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                          items: _categorias
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedCat = v);
                              _cargarInventario();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // LISTA COMPACTA DE INVENTARIO
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
                      onRefresh: _cargarInventario,
                      child: _productos.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay productos para este filtro',
                                style: TextStyle(
                                  color: FarmasisPalette.textSteel,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 72),
                              itemCount: _productos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, idx) {
                                final p =
                                    _productos[idx] as Map<String, dynamic>;
                                final stock =
                                    ((p['cantidad'] ?? 0) as num).toInt();
                                final minStock =
                                    ((p['stockMinimo'] ?? 5) as num).toInt();
                                final precio =
                                    ((p['precio'] ?? 0) as num).toDouble();
                                final precioOrig = p['precioOriginal'] != null
                                    ? ((p['precioOriginal']) as num).toDouble()
                                    : null;
                                final isLow = stock <= minStock;

                                return MetallicGlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 9),
                                  isGoldVariant: isLow,
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: FarmasisPalette.inputSurface,
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                              border: Border.all(
                                                color: isLow
                                                    ? FarmasisPalette.borderGold
                                                    : FarmasisPalette
                                                        .borderChromeSubtle,
                                              ),
                                            ),
                                            child: Text(
                                              '${p['codigo'] ?? '----'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10.5,
                                                color: isLow
                                                    ? FarmasisPalette.goldText
                                                    : FarmasisPalette
                                                        .emeraldNeon,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${p['nombre'] ?? ''}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: FarmasisPalette
                                                        .textSilverBright,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${p['categoria'] ?? 'General'} · Lote: ${p['lote'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    color: FarmasisPalette
                                                        .textSteel,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (precioOrig != null)
                                                Text(
                                                  '\$${_formatCurrency(precioOrig)}',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    color: FarmasisPalette
                                                        .textSteel,
                                                    decoration: TextDecoration
                                                        .lineThrough,
                                                  ),
                                                ),
                                              Text(
                                                '\$${_formatCurrency(precio)}',
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: FarmasisPalette
                                                      .emeraldNeon,
                                                ),
                                              ),
                                              Text(
                                                'Stock: $stock uds',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isLow
                                                      ? FarmasisPalette.goldText
                                                      : FarmasisPalette
                                                          .textSilver,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (_canEdit) ...[
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
                                            if (!_verArchivados)
                                              _actionLink(
                                                icon: Icons.edit_outlined,
                                                label: 'Editar',
                                                color: FarmasisPalette
                                                    .textSilverBright,
                                                onTap: () =>
                                                    _mostrarFormularioProducto(
                                                        prod: p),
                                              ),
                                            if (_isOwner && !_verArchivados) ...[
                                              const SizedBox(width: 12),
                                              _actionLink(
                                                icon:
                                                    Icons.local_offer_outlined,
                                                label: 'Oferta',
                                                color:
                                                    FarmasisPalette.chromeBlue,
                                                onTap: () =>
                                                    _dialogoDescuento(p),
                                              ),
                                            ],
                                            if (_isOwner) ...[
                                              const SizedBox(width: 12),
                                              _actionLink(
                                                icon: _verArchivados
                                                    ? Icons.restore_rounded
                                                    : Icons.archive_outlined,
                                                label: _verArchivados
                                                    ? 'Restaurar'
                                                    : 'Archivar',
                                                color: _verArchivados
                                                    ? FarmasisPalette
                                                        .emeraldNeon
                                                    : FarmasisPalette
                                                        .dangerCoral,
                                                onTap: () async {
                                                  if (_verArchivados) {
                                                    await ApiService
                                                        .restaurarProducto(
                                                            '${p['id']}');
                                                  } else {
                                                    await ApiService
                                                        .archivarProducto(
                                                            '${p['id']}');
                                                  }
                                                  _cargarInventario();
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
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

  Widget _filterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? FarmasisPalette.emeraldBright.withValues(alpha: 0.18)
              : FarmasisPalette.inputSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? FarmasisPalette.emeraldNeon
                : FarmasisPalette.borderChromeSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? FarmasisPalette.emeraldNeon
                : FarmasisPalette.textSilver,
          ),
        ),
      ),
    );
  }

  Widget _actionLink({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.5, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
