import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado del intento de autenticación biométrica en el dispositivo.
enum BiometricAuthStatus {
  /// Autenticado exitosamente por el lector biométrico nativo del SO.
  authenticatedNative,

  /// Cancelado voluntariamente por el usuario en el diálogo del sistema.
  cancelledByUser,

  /// El dispositivo no soporta biometría nativa (ej. Web) o no tiene huellas registradas en Ajustes;
  /// permite usar el lector biométrico interactivo de demostración.
  fallbackToInteractiveSensor,
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyUsername = 'farmasis_bio_v2_username';
  static const String _keyPassword = 'farmasis_bio_v2_password';
  static const String _keyDisplayName = 'farmasis_bio_v2_display_name';
  static const String _keyEnabled = 'farmasis_bio_v2_enabled';

  /// Verifica si el dispositivo cuenta con hardware biométrico nativo disponible.
  static Future<bool> hasNativeBiometricHardware() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('BiometricService.hasNativeBiometricHardware aviso: $e');
      return false;
    }
  }

  /// Ejecuta la validación de huella digital nativa con `local_auth`.
  /// Si el entorno es Web o el emulador no tiene huellas enroladas en el SO,
  /// retorna [BiometricAuthStatus.fallbackToInteractiveSensor] para mostrar el sensor táctil.
  static Future<BiometricAuthStatus> authenticateWithFingerprint() async {
    if (kIsWeb) {
      return BiometricAuthStatus.fallbackToInteractiveSensor;
    }

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        return BiometricAuthStatus.fallbackToInteractiveSensor;
      }

      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty && !isSupported) {
        return BiometricAuthStatus.fallbackToInteractiveSensor;
      }

      final authenticated = await _auth.authenticate(
        localizedReason:
            'Coloca tu huella digital en el sensor para ingresar a FarmaSIS',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        return BiometricAuthStatus.authenticatedNative;
      }
      return BiometricAuthStatus.cancelledByUser;
    } on LocalAuthException catch (e) {
      debugPrint('LocalAuthException (${e.code}): ${e.description}');
      if (e.code == LocalAuthExceptionCode.userCanceled ||
          e.code == LocalAuthExceptionCode.systemCanceled) {
        return BiometricAuthStatus.cancelledByUser;
      }
      // Si no hay huellas enroladas en el emulador/PC o el hardware no está configurado
      return BiometricAuthStatus.fallbackToInteractiveSensor;
    } catch (e) {
      debugPrint('Error en authenticateWithFingerprint: $e');
      return BiometricAuthStatus.fallbackToInteractiveSensor;
    }
  }

  /// Guarda las credenciales del usuario autenticado para futuros ingresos con huella.
  static Future<void> saveBiometricCredentials({
    required String username,
    required String password,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username.trim());
    await prefs.setString(_keyPassword, password.trim());
    await prefs.setString(_keyDisplayName, displayName.trim());
    await prefs.setBool(_keyEnabled, true);
  }

  /// Obtiene las credenciales vinculadas a la huella en el dispositivo.
  static Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    final password = prefs.getString(_keyPassword);
    final displayName = prefs.getString(_keyDisplayName);

    if (username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      return {
        'username': username,
        'password': password,
        'displayName': displayName ?? username,
      };
    }
    return null;
  }
}

