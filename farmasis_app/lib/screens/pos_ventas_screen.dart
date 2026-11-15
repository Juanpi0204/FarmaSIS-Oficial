import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../widgets/metallic_widgets.dart';

class PosVentasScreen extends StatefulWidget {
  final UserModel user;

  const PosVentasScreen({super.key, required this.user});

  @override
  State<PosVentasScreen> createState() => _PosVentasScreenState();
}

class _PosVentasScreenState extends State<PosVentasScreen> {
  int _activeSubTab = 0; // 0 = Punto de Venta (POS), 1 = Historial Facturas

  // Estado del POS
  List<dynamic> _productos = [];
  List<String> _categorias = ['Todas'];
  String _selectedCat = 'Todas';
  String _searchPos = '';
  bool _loadingPos = true;

  // Carrito: productoId -> {producto, cantidad}
  final Map<String, Map<String, dynamic>> _carrito = {};
  final TextEditingController _clienteCcCtrl =
      TextEditingController(text: '222222222222');
  final TextEditingController _obsCtrl = TextEditingController();
  String _metodoPago = 'EFECTIVO';
  bool _procesandoVenta = false;

  // Estado del Historial de Facturas
  List<dynamic> _ventas = [];
  double _ventasDelDia = 0;
  int _cantidadVentasDelDia = 0;
  String _filtroMetodo = 'TODOS';
  String _searchFactura = '';
  bool _loadingVentas = true;

  @override
  void initState() {
    super.initState();
    _cargarCatalogoPos();
    _cargarHistorialVentas();
  }

  @override
  void dispose() {
    _clienteCcCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
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

  Future<void> _cargarCatalogoPos() async {
    setState(() => _loadingPos = true);
    try {
      final data = await ApiService.getInventario(size: 200);
      if (!mounted) return;
      final cats = <String>{'Todas'};
      for (final c in (data['categorias'] as List<dynamic>? ?? [])) {
        final clean = '$c'.replaceAll(RegExp(r'^[,.\s]+'), '').trim();
        if (clean.isNotEmpty) cats.add(clean);
      }
      setState(() {
        _productos = (data['productos'] as List<dynamic>? ?? []);
        _categorias = cats.toList();
        _loadingPos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPos = false);
    }
  }

  Future<void> _cargarHistorialVentas() async {
    setState(() => _loadingVentas = true);
    try {
      final data = await ApiService.getVentas(
        metodoPago: _filtroMetodo,
        factura: _searchFactura.trim(),
        username: widget.user.username,
        rol: widget.user.rol,
      );
      if (!mounted) return;
      setState(() {
        _ventas = (data['ventas'] as List<dynamic>? ?? []);
        _ventasDelDia = ((data['ventasDelDia'] ?? 0) as num).toDouble();
        _cantidadVentasDelDia =
            ((data['cantidadVentasDelDia'] ?? 0) as num).toInt();
        _loadingVentas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingVentas = false);
    }
  }

  List<dynamic> get _productosFiltrados {
    return _productos.where((p) {
      final cat = '${p['categoria'] ?? ''}'
          .replaceAll(RegExp(r'^[,.\s]+'), '')
          .trim();
      final matchCat = _selectedCat == 'Todas' ||
          cat.toLowerCase() == _selectedCat.toLowerCase();
      final q = _searchPos.trim().toLowerCase();
      final matchSearch = q.isEmpty ||
          '${p['nombre'] ?? ''}'.toLowerCase().contains(q) ||
          '${p['codigo'] ?? ''}'.toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();
  }

  double get _totalCarrito {
    double sum = 0;
    for (final item in _carrito.values) {
      final prod = item['producto'] as Map<String, dynamic>;
      final cant = item['cantidad'] as int;
      final precio = ((prod['precio'] ?? 0) as num).toDouble();
      sum += precio * cant;
    }
    return sum;
  }

  int get _unidadesCarrito {
    int sum = 0;
    for (final item in _carrito.values) {
      sum += item['cantidad'] as int;
    }
    return sum;
  }

  void _agregarAlCarrito(Map<String, dynamic> prod) {
    final id = '${prod['id']}';
    final stock = ((prod['cantidad'] ?? 0) as num).toInt();
    if (stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF3B121D),
          content: Text('Producto agotado en inventario'),
        ),
      );
      return;
    }
    final actual = _carrito[id]?['cantidad'] as int? ?? 0;
    if (actual + 1 > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3B121D),
          content: Text('Stock máximo disponible: $stock unidades'),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _carrito[id] = {
        'producto': prod,
        'cantidad': actual + 1,
      };
    });
  }

  void _cambiarCantidadCarrito(String id, int delta) {
    if (!_carrito.containsKey(id)) return;
    final prod = _carrito[id]!['producto'] as Map<String, dynamic>;
    final stock = ((prod['cantidad'] ?? 0) as num).toInt();
    final nueva = (_carrito[id]!['cantidad'] as int) + delta;
    setState(() {
      if (nueva <= 0) {
        _carrito.remove(id);
      } else if (nueva <= stock) {
        _carrito[id]!['cantidad'] = nueva;
      }
    });
  }

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty || _procesandoVenta) return;
    setState(() => _procesandoVenta = true);
    try {
      final detalles = _carrito.values.map((item) {
        final p = item['producto'] as Map<String, dynamic>;
        return {
          'productoId': '${p['id']}',
          'cantidad': item['cantidad'] as int,
          'precioUnitario': ((p['precio'] ?? 0) as num).toDouble(),
        };
      }).toList();

      final fullName = '${widget.user.nombre} ${widget.user.apellido}'.trim();
      final res = await ApiService.crearVenta(
        clienteCC: _clienteCcCtrl.text.trim().isEmpty
            ? '222222222222'
            : _clienteCcCtrl.text.trim(),
        metodoPago: _metodoPago,
        observaciones: _obsCtrl.text.trim(),
        detalles: detalles,
        vendedorEmail: widget.user.email.isNotEmpty
            ? widget.user.email
            : widget.user.username,
        vendedorNombre: fullName.isEmpty ? widget.user.username : fullName,
        vendedorRol: widget.user.rol,
      );

      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _obsCtrl.clear();
        _procesandoVenta = false;
      });
      _cargarCatalogoPos();
      _cargarHistorialVentas();

      final factura = res['factura'] as Map<String, dynamic>?;
      if (factura != null) {
        _mostrarTicketFactura(factura);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoVenta = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF3B121D),
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
        ),
      );
    }
  }

  void _mostrarTicketFactura(Map<String, dynamic> factura) {
    final detalles = (factura['detalles'] as List<dynamic>? ?? []);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: FarmasisPalette.emeraldBright
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FarmasisPalette.emeraldNeon
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: FarmasisPalette.emeraldNeon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comprobante ${factura['numeroFactura'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: FarmasisPalette.textSilverBright,
                          ),
                        ),
                        Text(
                          'Cliente: ${factura['clienteNombre'] ?? 'Consumidor Final'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: FarmasisPalette.textSilver,
                          ),
                        ),
                        Text(
                          'Vendedor: ${factura['vendedorNombre'] ?? factura['vendedorEmail'] ?? '—'} · ${factura['origenVenta'] ?? 'APP'}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: FarmasisPalette.chromeIndigo
                          .withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FarmasisPalette.chromeBlue
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      '${factura['metodoPago'] ?? 'EFECTIVO'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FarmasisPalette.chromeBlue,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                height: 20,
                color:
                    FarmasisPalette.borderChromeSubtle.withValues(alpha: 0.6),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: detalles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, idx) {
                    final d = detalles[idx] as Map<String, dynamic>;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${d['cantidad']}x ${d['productoNombre'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: FarmasisPalette.textSilverBright,
                            ),
                          ),
                        ),
                        Text(
                          '\$${_formatCurrency((d['subtotal'] ?? 0) as num)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: FarmasisPalette.emeraldNeon,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Divider(
                height: 20,
                color:
                    FarmasisPalette.borderChromeSubtle.withValues(alpha: 0.6),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL PAGADO',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: FarmasisPalette.textSilver,
                    ),
                  ),
                  Text(
                    '\$${_formatCurrency((factura['total'] ?? 0) as num)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: FarmasisPalette.emeraldNeon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FarmasisPalette.emeraldBright,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Cerrar Ticket',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirCheckoutModal() {
    if (_carrito.isEmpty) return;
    showModalBottomSheet(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Confirmar Venta POS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FarmasisPalette.textSilverBright,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _carrito.clear());
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: FarmasisPalette.dangerCoral),
                        label: const Text(
                          'Vaciar',
                          style: TextStyle(
                              color: FarmasisPalette.dangerCoral, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 170),
                    child: ListView(
                      shrinkWrap: true,
                      children: _carrito.entries.map((e) {
                        final p = e.value['producto'] as Map<String, dynamic>;
                        final cant = e.value['cantidad'] as int;
                        final precio = ((p['precio'] ?? 0) as num).toDouble();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p['nombre']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: FarmasisPalette.textSilverBright,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '\$${_formatCurrency(precio)} c/u',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: FarmasisPalette.textSteel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _cambiarCantidadCarrito(e.key, -1);
                                  setModalState(() {});
                                  if (_carrito.isEmpty) Navigator.pop(ctx);
                                },
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 19,
                                  color: FarmasisPalette.textSilver,
                                ),
                              ),
                              Text(
                                '$cant',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: FarmasisPalette.textSilverBright,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _cambiarCantidadCarrito(e.key, 1);
                                  setModalState(() {});
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 19,
                                  color: FarmasisPalette.emeraldNeon,
                                ),
                              ),
                              SizedBox(
                                width: 68,
                                child: Text(
                                  '\$${_formatCurrency(precio * cant)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: FarmasisPalette.emeraldNeon,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(
                    height: 18,
                    color: FarmasisPalette.borderChromeSubtle
                        .withValues(alpha: 0.6),
                  ),
                  _darkInput(
                    controller: _clienteCcCtrl,
                    label: 'Cédula / NIT Cliente (222222222222 = Final)',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _metodoPago,
                    dropdownColor: FarmasisPalette.cardSteelDark,
                    style: const TextStyle(
                      color: FarmasisPalette.textSilverBright,
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Método de Pago',
                      labelStyle: const TextStyle(
                        color: FarmasisPalette.textSilver,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: FarmasisPalette.emeraldNeon,
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
                    items: const [
                      DropdownMenuItem(
                          value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'TARJETA',
                          child: Text('Tarjeta Débito/Crédito')),
                      DropdownMenuItem(
                          value: 'TRANSFERENCIA',
                          child: Text('Transferencia / Nequi / Daviplata')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _metodoPago = v);
                        setModalState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _darkInput(
                    controller: _obsCtrl,
                    label: 'Observaciones (opcional)',
                    icon: Icons.notes_rounded,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total ($_unidadesCarrito uds):',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: FarmasisPalette.textSilver,
                        ),
                      ),
                      Text(
                        '\$${_formatCurrency(_totalCarrito)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: FarmasisPalette.emeraldNeon,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _procesandoVenta
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _confirmarVenta();
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Facturar y Descontar Stock',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
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
  }

  Widget _darkInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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
        prefixIcon: Icon(icon, size: 18, color: FarmasisPalette.textSteel),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        children: [
          // PILL SELECTOR NEUTRO EJECUTIVO: TERMINAL POS vs HISTORIAL FACTURAS
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
                    onTap: () => setState(() => _activeSubTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: _activeSubTab == 0
                            ? FarmasisPalette.headerForestTop
                            : Colors.transparent,
                        boxShadow: _activeSubTab == 0
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.point_of_sale_rounded,
                            size: 15,
                            color: _activeSubTab == 0
                                ? Colors.white
                                : FarmasisPalette.textSilver,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Punto de Venta (POS)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeSubTab == 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _activeSubTab == 0
                                  ? Colors.white
                                  : FarmasisPalette.textSilver,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeSubTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: _activeSubTab == 1
                            ? FarmasisPalette.headerForestTop
                            : Colors.transparent,
                        boxShadow: _activeSubTab == 1
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 15,
                            color: _activeSubTab == 1
                                ? Colors.white
                                : FarmasisPalette.textSilver,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mis Ventas / Facturas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _activeSubTab == 1
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: _activeSubTab == 1
                                  ? Colors.white
                                  : FarmasisPalette.textSilver,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _activeSubTab == 0 ? _buildPosTab() : _buildHistorialTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildPosTab() {
    return Stack(
      children: [
        Column(
          children: [
            MetallicGlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchPos = v),
                      style: const TextStyle(
                        fontSize: 13,
                        color: FarmasisPalette.textSilverBright,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar medicamento por código o nombre...',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
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
                            horizontal: 12, vertical: 0),
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
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categorias.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, idx) {
                        final cat = _categorias[idx];
                        final selected = cat == _selectedCat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCat = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: selected
                                  ? FarmasisPalette.headerForestTop
                                  : FarmasisPalette.inputSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? FarmasisPalette.headerForestTop
                                    : FarmasisPalette.borderChromeSubtle,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : FarmasisPalette.textSilver,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loadingPos
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FarmasisPalette.emeraldBright,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: FarmasisPalette.emeraldBright,
                      backgroundColor: Colors.white,
                      onRefresh: _cargarCatalogoPos,
                      child: ListView.separated(
                        padding: EdgeInsets.only(
                            bottom: _carrito.isNotEmpty ? 76 : 12),
                        itemCount: _productosFiltrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 7),
                        itemBuilder: (_, idx) {
                          final p =
                              _productosFiltrados[idx] as Map<String, dynamic>;
                          final id = '${p['id']}';
                          final stock = ((p['cantidad'] ?? 0) as num).toInt();
                          final precio =
                              ((p['precio'] ?? 0) as num).toDouble();
                          final enCarrito =
                              _carrito[id]?['cantidad'] as int? ?? 0;

                          return MetallicGlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 10),
                            isHighlighted: enCarrito > 0,
                            isGoldVariant: stock <= 5 && enCarrito == 0,
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: FarmasisPalette.inputSurface,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: stock > 0
                                          ? FarmasisPalette.borderChromeSubtle
                                          : FarmasisPalette.dangerCoral,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.medication_outlined,
                                    size: 19,
                                    color: stock > 0
                                        ? FarmasisPalette.textSilver
                                        : FarmasisPalette.dangerCoral,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p['nombre'] ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                          color:
                                              FarmasisPalette.textSilverBright,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cód: ${p['codigo'] ?? 'N/A'} · Stock: $stock uds',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: stock <= 5
                                              ? FarmasisPalette.goldText
                                              : FarmasisPalette.textSteel,
                                          fontWeight: stock <= 5
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${_formatCurrency(precio)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: FarmasisPalette.textSilverBright,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    InkWell(
                                      onTap: stock > 0
                                          ? () => _agregarAlCarrito(p)
                                          : null,
                                      borderRadius: BorderRadius.circular(7),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: stock > 0
                                              ? FarmasisPalette.emeraldBright
                                              : FarmasisPalette.textMuted,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          enCarrito > 0
                                              ? '+ Carrito ($enCarrito)'
                                              : '+ Agregar',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
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
        if (_carrito.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: MetallicGlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isHighlighted: true,
              onTap: _abrirCheckoutModal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: FarmasisPalette.emeraldBright,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$_unidadesCarrito uds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ver Carrito y Cobrar',
                        style: TextStyle(
                          color: FarmasisPalette.textSilverBright,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '\$${_formatCurrency(_totalCarrito)} →',
                    style: const TextStyle(
                      color: FarmasisPalette.emeraldNeon,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebColorSummaryCard({
    required String label,
    required String value,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialTab() {
    int udsVendidas = 0;
    for (final v in _ventas) {
      final map = v as Map<String, dynamic>;
      final dets = (map['detalles'] as List<dynamic>? ?? []);
      for (final d in dets) {
        udsVendidas += (((d as Map<String, dynamic>)['cantidad'] ?? 0) as num).toInt();
      }
    }

    final c1 = _buildWebColorSummaryCard(
      label: 'Mis Ventas Hoy',
      value: '\$${_formatCurrency(_ventasDelDia)}',
      bgColor: const Color(0xFF198754),
    );
    final c2 = _buildWebColorSummaryCard(
      label: 'Mis Facturas Hoy',
      value: '$_cantidadVentasDelDia',
      bgColor: const Color(0xFF06B6D4),
    );
    final c3 = _buildWebColorSummaryCard(
      label: 'Productos Vendidos',
      value: '$udsVendidas uds',
      bgColor: const Color(0xFF64748B),
    );
    final c4 = _buildWebColorSummaryCard(
      label: 'Total Mis Ventas',
      value: '${_ventas.length}',
      bgColor: const Color(0xFF2563EB),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return Column(
          children: [
            if (isWide)
              Row(
                children: [
                  Expanded(child: c1),
                  const SizedBox(width: 8),
                  Expanded(child: c2),
                  const SizedBox(width: 8),
                  Expanded(child: c3),
                  const SizedBox(width: 8),
                  Expanded(child: c4),
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(child: c1),
                  const SizedBox(width: 8),
                  Expanded(child: c2),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: c3),
                  const SizedBox(width: 8),
                  Expanded(child: c4),
                ],
              ),
            ],
            const SizedBox(height: 10),
            MetallicGlassCard(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        onChanged: (v) {
                          _searchFactura = v;
                          _cargarHistorialVentas();
                        },
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: FarmasisPalette.textSilverBright,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar # Factura (ej. FAC-065793)...',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: FarmasisPalette.textMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 17,
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
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _filtroMetodo,
                    dropdownColor: Colors.white,
                    underline: const SizedBox(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FarmasisPalette.textSilverBright,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                      DropdownMenuItem(
                          value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(
                          value: 'TARJETA', child: Text('Tarjeta')),
                      DropdownMenuItem(
                          value: 'TRANSFERENCIA', child: Text('Transf.')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _filtroMetodo = v);
                        _cargarHistorialVentas();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loadingVentas
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FarmasisPalette.emeraldBright,
                        strokeWidth: 2.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: FarmasisPalette.emeraldBright,
                      backgroundColor: Colors.white,
                      onRefresh: _cargarHistorialVentas,
                      child: _ventas.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron facturas registradas',
                                style: TextStyle(
                                  color: FarmasisPalette.textSteel,
                                  fontSize: 12.5,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _ventas.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, idx) {
                                final f = _ventas[idx] as Map<String, dynamic>;
                                final total =
                                    ((f['total'] ?? 0) as num).toDouble();
                                final detalles =
                                    (f['detalles'] as List<dynamic>? ?? []);
                                final metodo =
                                    '${f['metodoPago'] ?? 'EFECTIVO'}';
                                return MetallicGlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  onTap: () => _mostrarTicketFactura(f),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF64748B),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${f['numeroFactura'] ?? 'FAC'}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${f['clienteNombre'] ?? 'Consumidor Final'}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: FarmasisPalette
                                                    .textSilverBright,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${detalles.length} ítems · Vendedor: ${f['vendedorNombre'] ?? 'Tú'}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color:
                                                    FarmasisPalette.textSteel,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        margin: const EdgeInsets.only(right: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF06B6D4),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          metodo,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '\$${_formatCurrency(total)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color:
                                              FarmasisPalette.textSilverBright,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
