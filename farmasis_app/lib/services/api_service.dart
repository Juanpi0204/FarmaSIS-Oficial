import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/prediction_model.dart';

class ApiService {
  /// Detección automática del host según plataforma (localhost para Web/PC y 10.0.2.2 para emulador Android)
  static String get defaultHost {
    if (kIsWeb) return 'http://localhost';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2';
    }
    return 'http://localhost';
  }

  // Puerto del Mock Server de Node.js (3000) - Utilizado por defecto para el taller de aula
  static String mockServerBaseUrl = '$defaultHost:3000';

  // Puerto de Spring Boot (8092) - Para conexión con el backend de producción y MongoDB Atlas
  static String springBootBaseUrl = '$defaultHost:8092';

  /// Conmutador de Entorno:
  /// - 'false': Consume el Mock Server (puerto 3000) para el taller y pruebas del profesor.
  /// - 'true': Consume el backend de Spring Boot (puerto 8092) conectado a MongoDB Atlas.
  static bool useProductionBackend = false;

  static String get baseUrl =>
      useProductionBackend ? springBootBaseUrl : mockServerBaseUrl;

  /// Catálogo de medicamentos (10 fármacos) para el selector de la interfaz
  static List<Map<String, String>> getProductos() {
    return const [
      {'id': 'MED-104', 'nombre': 'Acetaminofén 500mg (MED-104)'},
      {'id': 'MED-202', 'nombre': 'Ibuprofeno 400mg (MED-202)'},
      {'id': 'MED-305', 'nombre': 'Amoxicilina 500mg (MED-305)'},
      {'id': 'MED-410', 'nombre': 'Losartán 50mg (MED-410)'},
      {'id': 'MED-512', 'nombre': 'Omeprazol 20mg (MED-512)'},
      {'id': 'MED-618', 'nombre': 'Loratadina 10mg (MED-618)'},
      {'id': 'MED-725', 'nombre': 'Metformina 850mg (MED-725)'},
      {'id': 'MED-830', 'nombre': 'Azitromicina 500mg (MED-830)'},
      {'id': 'MED-942', 'nombre': 'Salbutamol Inhalador 100mcg (MED-942)'},
      {'id': 'MED-105', 'nombre': 'Diclofenaco Sódico 50mg (MED-105)'},
    ];
  }

  /// Productos del servidor activo (GET /api/v1/productos). Con Spring Boot son los productos reales de MongoDB.
  /// Devuelve una lista vacía si el servidor no responde.
  static Future<List<Map<String, String>>> getProductosRemotos() async {
    final url = Uri.parse('$baseUrl/api/v1/productos');
    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final lista = (data['productos'] as List<dynamic>?) ?? [];
        return lista
            .map<Map<String, String>>(
                (p) => {'id': '${p['id']}', 'nombre': '${p['nombre']}'})
            .toList();
      }
    } catch (e) {
      debugPrint('Error al cargar productos de $url: $e');
    }
    return [];
  }

  /// Autenticación vía HTTP POST (consume /api/v1/auth/login en el Mock Server o Spring Boot)
  static Future<UserModel> login(String username, String password) async {
    final cleanUser = username.trim();
    final cleanPass = password.trim();

    if (cleanUser.isEmpty || cleanPass.isEmpty) {
      throw Exception('Por favor ingrese su usuario y contraseña.');
    }

    final url = Uri.parse('$baseUrl/api/v1/auth/login');

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
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success' && data['usuario'] != null) {
          return UserModel.fromJson(data['usuario']);
        }
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['message'] ?? 'Credenciales incorrectas.');
      }
    } catch (e) {
      debugPrint('Aviso de conexión de login a $url: $e');
      if (e is Exception &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      throw Exception(
          'No se pudo conectar con el servidor en $url. Inicie "node mock_server.js".');
    }

    throw Exception('Error al validar credenciales en el servidor.');
  }

  /// Consumo del Contrato de Predicción vía HTTP GET (consume /api/v1/prediccion/ventas)
  static Future<ContratoPrediccionResponse> getPrediccion({
    String productoId = 'MED-104',
    String temporalidad = 'SEMANAL',
  }) async {
    final url = Uri.parse(
        '$baseUrl/api/v1/prediccion/ventas?productoId=$productoId&temporalidad=$temporalidad');

    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return ContratoPrediccionResponse.fromJson(data);
      } else {
        throw Exception('El servidor respondió con código ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al consultar $url: $e');
      final serverName = useProductionBackend
          ? 'el Backend Spring Boot (8092)'
          : 'el Mock Server Node.js (3000)';
      throw Exception(
          'Error al conectar con $serverName en $url. Verifique que el servicio esté corriendo.');
    }
  }
}
