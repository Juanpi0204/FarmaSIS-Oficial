import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/prediction_model.dart';

class ApiService {
  /// Detección automática del host según plataforma (192.168.1.9 en red Wi-Fi local para Android físico)
  static String get defaultHost {
    if (kIsWeb) return 'http://localhost';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.9';
    }
    return 'http://localhost';
  }

  static String springBootBaseUrl = '$defaultHost:8092';

  static bool useProductionBackend = true;

  static String get baseUrl => springBootBaseUrl;

  static String get fallbackBaseUrl =>
      defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8092'
          : springBootBaseUrl;

  /// Permite apuntar en caliente a AWS o IP local
  static void setCustomServerUrl(String url) {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isNotEmpty) {
      springBootBaseUrl = clean;
      useProductionBackend = true;
    }
  }

  /// Sin datos ficticios: siempre se usa la base real en MongoDB Atlas
  static List<Map<String, String>> getProductos() {
    return const [];
  }

  /// Obtiene el catálogo activo desde la API (/api/v1/productos)
  static Future<List<Map<String, String>>> getProductosRemotos() async {
    for (final candidateBase in [baseUrl, fallbackBaseUrl]) {
      final url = Uri.parse('$candidateBase/api/v1/productos');
      try {
        final response = await http
            .get(url, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          if (candidateBase != baseUrl) {
            useProductionBackend = (candidateBase == springBootBaseUrl);
          }
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final lista = (data['productos'] as List<dynamic>?) ?? [];
          return lista
              .map<Map<String, String>>((p) => {
                    'id': '${p['id']}',
                    'nombre': '${p['nombre']}',
                    'categoria': '${p['categoria'] ?? 'General'}',
                  })
              .toList();
        }
      } catch (e) {
        debugPrint('Aviso al cargar productos de $url: $e');
      }
    }
    return [];
  }

  /// Autenticación vía HTTP POST (/api/v1/auth/login)
  static Future<UserModel> login(String username, String password) async {
    final cleanUser = username.trim();
    final cleanPass = password.trim();

    if (cleanUser.isEmpty || cleanPass.isEmpty) {
      throw Exception('Por favor ingresa tu usuario y contraseña.');
    }

    for (final candidateBase in [baseUrl, fallbackBaseUrl]) {
      final url = Uri.parse('$candidateBase/api/v1/auth/login');
      try {
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': cleanUser,
                'password': cleanPass,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (candidateBase != baseUrl) {
            useProductionBackend = (candidateBase == springBootBaseUrl);
          }
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['status'] == 'success' && data['usuario'] != null) {
            return UserModel.fromJson(data['usuario']);
          }
        } else if (response.statusCode == 400 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          throw Exception(
              errorData['message'] ?? 'Usuario o contraseña incorrectos.');
        }
      } catch (e) {
        final errStr = e.toString();
        final isNetworkError = errStr.contains('SocketException') ||
            errStr.contains('TimeoutException') ||
            errStr.contains('ClientException') ||
            errStr.contains('Failed host lookup') ||
            errStr.contains('XMLHttpRequest');
        if (!isNetworkError) {
          rethrow;
        }
      }
    }

    throw Exception(
        'No se pudo conectar con el servidor de FarmaSIS. Verifica tu conexión.');
  }

  /// Consulta la predicción de demanda (/api/v1/prediccion/ventas)
  static Future<ContratoPrediccionResponse> getPrediccion({
    String productoId = '0846',
    String temporalidad = 'MENSUAL',
  }) async {
    for (final candidateBase in [baseUrl, fallbackBaseUrl]) {
      final url = Uri.parse(
          '$candidateBase/api/v1/prediccion/ventas?productoId=$productoId&temporalidad=$temporalidad');

      try {
        final response = await http
            .get(url, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (candidateBase != baseUrl) {
            useProductionBackend = (candidateBase == springBootBaseUrl);
          }
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return ContratoPrediccionResponse.fromJson(data);
        } else if (response.statusCode == 404) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          throw Exception(
              data['mensaje'] ?? 'Producto no encontrado en el catálogo.');
        }
      } catch (e) {
        final errStr = e.toString();
        final isNetworkError = errStr.contains('SocketException') ||
            errStr.contains('TimeoutException') ||
            errStr.contains('ClientException') ||
            errStr.contains('Failed host lookup') ||
            errStr.contains('XMLHttpRequest');
        if (!isNetworkError) {
          rethrow;
        }
      }
    }

    throw Exception(
        'No se pudo obtener la información de predicción del servidor.');
  }

  // =========================================================================
  // MICRO-DOMINIO 1: DASHBOARD EJECUTIVO Y KPIs
  // =========================================================================
  static Future<Map<String, dynamic>> getDashboardResumen({
    String? username,
    String? rol,
  }) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/dashboard/resumen')
        .replace(queryParameters: {
      'username': ?username,
      'rol': ?rol,
    });
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al consultar el resumen del sistema (${res.statusCode})');
  }

  // =========================================================================
  // MICRO-DOMINIO 2: INVENTARIO / PRODUCTOS (CRUD + DESCUENTOS + ARCHIVO)
  // =========================================================================
  static Future<Map<String, dynamic>> getInventario({
    int page = 0,
    int size = 60,
    String? search,
    String? categoria,
    bool? stockBajo,
    bool? enOferta,
    bool archivados = false,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      'archivados': '$archivados',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (categoria != null &&
        categoria.trim().isNotEmpty &&
        categoria != 'Todas') {
      params['categoria'] = categoria.trim();
    }
    if (stockBajo == true) params['stockBajo'] = 'true';
    if (enOferta == true) params['enOferta'] = 'true';

    final uri = Uri.parse('$springBootBaseUrl/api/v1/inventario')
        .replace(queryParameters: params);
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al consultar inventario (${res.statusCode})');
  }

  static Future<Map<String, dynamic>> crearProducto(
      Map<String, dynamic> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/inventario');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Error al guardar el producto');
  }

  static Future<Map<String, dynamic>> actualizarProducto(
      String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/inventario/$id');
    final res = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Error al actualizar el producto');
  }

  static Future<void> archivarProducto(String id) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/inventario/$id/archivar');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al archivar producto');
    }
  }

  static Future<void> restaurarProducto(String id) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/inventario/$id/restaurar');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al restaurar producto');
    }
  }

  static Future<void> aplicarDescuentoProducto(
      String id, double porcentaje) async {
    final uri = Uri.parse(
        '$springBootBaseUrl/api/v1/inventario/$id/descuento?porcentaje=$porcentaje');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al aplicar descuento');
    }
  }

  static Future<void> revertirDescuentoProducto(String id) async {
    final uri = Uri.parse(
        '$springBootBaseUrl/api/v1/inventario/$id/revertir-descuento');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al revertir descuento');
    }
  }

  // =========================================================================
  // MICRO-DOMINIO 3: PUNTO DE VENTA (POS) Y FACTURACIÓN
  // =========================================================================
  static Future<Map<String, dynamic>> getVentas({
    int page = 0,
    int size = 30,
    String? fechaDesde,
    String? fechaHasta,
    String? metodoPago,
    String? factura,
    String? vendedor,
    String? username,
    String? rol,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
    };
    if (fechaDesde != null && fechaDesde.isNotEmpty) {
      params['fechaDesde'] = fechaDesde;
    }
    if (fechaHasta != null && fechaHasta.isNotEmpty) {
      params['fechaHasta'] = fechaHasta;
    }
    if (metodoPago != null && metodoPago.isNotEmpty && metodoPago != 'TODOS') {
      params['metodoPago'] = metodoPago;
    }
    if (factura != null && factura.isNotEmpty) params['factura'] = factura;
    if (vendedor != null && vendedor.isNotEmpty) params['vendedor'] = vendedor;
    if (username != null && username.isNotEmpty) params['username'] = username;
    if (rol != null && rol.isNotEmpty) params['rol'] = rol;

    final uri = Uri.parse('$springBootBaseUrl/api/v1/ventas')
        .replace(queryParameters: params);
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al consultar historial de ventas');
  }

  static Future<Map<String, dynamic>> crearVenta({
    required String clienteCC,
    required String metodoPago,
    required String observaciones,
    required List<Map<String, dynamic>> detalles,
    required String vendedorEmail,
    String? vendedorNombre,
    String? vendedorRol,
  }) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/ventas')
        .replace(queryParameters: {'vendedorEmail': vendedorEmail});
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'clienteCC': clienteCC,
            'metodoPago': metodoPago,
            'observaciones': observaciones,
            'origenVenta': 'APP MÓVIL',
            'vendedorNombre': vendedorNombre,
            'vendedorRol': vendedorRol,
            'detalles': detalles,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'No se pudo procesar la venta');
  }

  // =========================================================================
  // MICRO-DOMINIO 4: PROVEEDORES
  // =========================================================================
  static Future<Map<String, dynamic>> getProveedores({
    String? search,
    String estado = 'ACTIVOS',
    String? categoria,
  }) async {
    final params = <String, String>{
      'estado': estado,
      'size': '100',
    };
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (categoria != null &&
        categoria.trim().isNotEmpty &&
        categoria != 'Todas') {
      params['categoria'] = categoria.trim();
    }
    final uri = Uri.parse('$springBootBaseUrl/api/v1/proveedores')
        .replace(queryParameters: params);
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al cargar proveedores');
  }

  static Future<void> crearProveedor(
      Map<String, dynamic> body, String creadoPor) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/proveedores')
        .replace(queryParameters: {'creadoPor': creadoPor});
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al crear proveedor');
    }
  }

  static Future<void> actualizarProveedor(
      String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/proveedores/$id');
    final res = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al actualizar proveedor');
    }
  }

  static Future<void> cambiarEstadoProveedor(String id, bool activar) async {
    final action = activar ? 'reactivar' : 'desactivar';
    final uri = Uri.parse('$springBootBaseUrl/api/v1/proveedores/$id/$action');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al cambiar estado del proveedor');
    }
  }

  // =========================================================================
  // MICRO-DOMINIO 5: GESTIÓN DE USUARIOS / EMPLEADOS (OWNER)
  // =========================================================================
  static Future<Map<String, dynamic>> getUsuarios({String? filtro}) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/usuarios').replace(
      queryParameters: {
        if (filtro != null && filtro.isNotEmpty) 'filtro': filtro,
      },
    );
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al consultar usuarios');
  }

  static Future<void> crearUsuario(Map<String, String> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/usuarios');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al crear usuario');
    }
  }

  static Future<void> cambiarRolUsuario(String id, String nuevoRol) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/usuarios/$id/rol')
        .replace(queryParameters: {'nuevoRol': nuevoRol});
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al cambiar rol');
    }
  }

  static Future<void> cambiarEstadoUsuario(String id, bool activar) async {
    final action = activar ? 'activar' : 'desactivar';
    final uri = Uri.parse('$springBootBaseUrl/api/v1/usuarios/$id/$action');
    final res = await http.post(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al cambiar estado del usuario');
    }
  }

  // =========================================================================
  // MICRO-DOMINIO 6: OPTIMIZACIÓN IA CON TIMEFOLD SOLVER (OWNER)
  // =========================================================================
  static Future<Map<String, dynamic>> getUltimaOptimizacion() async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/optimizacion/ultimo');
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al consultar optimización');
  }

  static Future<Map<String, dynamic>> ejecutarOptimizacion() async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/optimizacion/ejecutar');
    final res = await http
        .post(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 45));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al ejecutar Timefold Solver');
  }

  // =========================================================================
  // MICRO-DOMINIO 7: CONFIGURACIÓN DEL SISTEMA Y PERFIL
  // =========================================================================
  static Future<Map<String, dynamic>> getConfiguracion(
      {String? username}) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/configuracion').replace(
      queryParameters: {
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('Error al cargar configuración');
  }

  static Future<void> guardarConfiguracionSistema(
      Map<String, dynamic> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/configuracion/sistema');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al guardar configuración');
    }
  }

  static Future<void> actualizarPerfil(Map<String, dynamic> body) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/configuracion/perfil');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'Error al actualizar perfil');
    }
  }

  // =========================================================================
  // MICRO-DOMINIO 8: CHATBOT IA FARMACÉUTICO (GROQ + SPRING AI)
  // =========================================================================
  static Future<String> askChatbot({
    required String chatId,
    required String message,
    required String rol,
  }) async {
    final uri = Uri.parse('$springBootBaseUrl/api/v1/chat/ask');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chatId': chatId,
            'message': message,
            'rol': rol,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return '${data['reply'] ?? 'Sin respuesta del asistente.'}';
    }
    throw Exception('El asistente IA no está disponible en este momento.');
  }
}
