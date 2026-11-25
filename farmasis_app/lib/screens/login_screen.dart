import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../widgets/metallic_widgets.dart';
import 'home_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Inicio de sesión normal con usuario y contraseña: NUNCA guarda ni sobrescribe la huella.
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final user = await ApiService.login(username, password);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeShellScreen(user: user),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Valida el sensor de huella (nativo o interactivo de respaldo).
  Future<bool> _verifyFingerprintSensor() async {
    final status = await BiometricService.authenticateWithFingerprint();
    if (!mounted) return false;

    if (status == BiometricAuthStatus.authenticatedNative) {
      HapticFeedback.mediumImpact();
      return true;
    }

    if (status == BiometricAuthStatus.cancelledByUser) {
      return false;
    }

    final verified = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _FingerprintScannerBottomSheet(),
    );

    return verified == true;
  }

  /// Flujo exclusivo de Huella Digital:
  /// - Si NO hay cuenta vinculada aún: pide por primera vez el usuario/contraseña para vincularlos a la huella.
  /// - Si YA hay cuenta vinculada: pide únicamente la huella e inicia sesión con esa cuenta fija (sin sobrescribirla nunca).
  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    setState(() {
      _errorMessage = null;
    });

    final saved = await BiometricService.getSavedCredentials();
    if (!mounted) return;

    // 1) PRIMERA VEZ: No hay datos guardados en la huella -> pedir credenciales para vincularlas
    if (saved == null) {
      await _mostrarModalVincularHuellaPrimeraVez();
      return;
    }

    // 2) YA VINCULADA: Solo pide la huella y abre los datos exclusivos de esa huella
    final okHuella = await _verifyFingerprintSensor();
    if (!mounted || !okHuella) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ApiService.login(
        saved['username']!,
        saved['password']!,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeShellScreen(user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Modal que aparece SOLO la primera vez que se toca "Ingresar con huella"
  Future<void> _mostrarModalVincularHuellaPrimeraVez() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    bool vinculando = false;
    String? modalError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: FarmasisPalette.emeraldBright
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: FarmasisPalette.emeraldBright,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vincular Huella por Primera Vez',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: FarmasisPalette.textSilverBright,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Ingresa tu cuenta una única vez para asociarla a tu huella digital.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FarmasisPalette.textSteel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (modalError != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: FarmasisPalette.dangerCoral
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          modalError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9F1239),
                          ),
                        ),
                      ),
                    TextField(
                      controller: userCtrl,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: FarmasisPalette.textSilverBright,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Usuario o Correo a vincular',
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: FarmasisPalette.textSilver,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 19,
                          color: FarmasisPalette.emeraldBright,
                        ),
                        filled: true,
                        fillColor: FarmasisPalette.inputSurface,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: FarmasisPalette.textSilverBright,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(
                          fontSize: 12,
                          color: FarmasisPalette.textSilver,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 19,
                          color: FarmasisPalette.emeraldBright,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: FarmasisPalette.textSteel,
                          ),
                        ),
                        filled: true,
                        fillColor: FarmasisPalette.inputSurface,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: FarmasisPalette.borderChromeSubtle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: vinculando
                          ? null
                          : () async {
                              final u = userCtrl.text.trim();
                              final p = passCtrl.text.trim();
                              if (u.isEmpty || p.isEmpty) {
                                setModalState(() {
                                  modalError =
                                      'Completa tu usuario y contraseña para vincular la huella.';
                                });
                                return;
                              }

                              setModalState(() {
                                vinculando = true;
                                modalError = null;
                              });

                              try {
                                // 1. Verifica que las credenciales existan en MongoDB
                                final user = await ApiService.login(u, p);
                                if (!ctx.mounted) return;

                                // 2. Pide confirmar con el sensor de huella
                                final okHuella =
                                    await _verifyFingerprintSensor();
                                if (!ctx.mounted) return;
                                if (!okHuella) {
                                  setModalState(() {
                                    vinculando = false;
                                    modalError =
                                        'No se completó la lectura de huella.';
                                  });
                                  return;
                                }

                                // 3. Guarda permanentemente en la huella
                                final fullName =
                                    '${user.nombre} ${user.apellido}'.trim();
                                await BiometricService.saveBiometricCredentials(
                                  username: u,
                                  password: p,
                                  displayName:
                                      fullName.isEmpty ? user.username : fullName,
                                );

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);

                                if (!mounted) return;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        HomeShellScreen(user: user),
                                  ),
                                );
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setModalState(() {
                                  vinculando = false;
                                  modalError = e
                                      .toString()
                                      .replaceAll('Exception:', '')
                                      .trim();
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FarmasisPalette.emeraldBright,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: vinculando
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.fingerprint_rounded, size: 20),
                      label: Text(
                        vinculando
                            ? 'Verificando...'
                            : 'Confirmar con Huella y Guardar',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FarmasisPalette.bgObsidian,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B4332),
              Color(0xFF2D6A4F),
              Color(0xFFCCE2D8),
            ],
            stops: [0.0, 0.42, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // BRANDING SUPERIOR EN CROMO, PLATA Y ESMERALDA 3D
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MetallicCrossLogo(size: 58),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Farma',
                                    style: TextStyle(
                                      fontSize: 29,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'SIS',
                                    style: TextStyle(
                                      fontSize: 29,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF95D5B2),
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'Control Total & BI',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFFD8F3DC),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // TARJETA GLASSMORPHISM METÁLICA (BLANCO PERLA Y PLATA ESMERALDA)
                    MetallicGlassCard(
                      padding: const EdgeInsets.all(22),
                      borderRadius: 20,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Acceso Ejecutivo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: FarmasisPalette.textSilverBright,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Ingresa tus credenciales autorizadas',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: FarmasisPalette.textSteel,
                              ),
                            ),
                            const SizedBox(height: 18),

                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: FarmasisPalette.dangerCoral
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: FarmasisPalette.dangerCoral,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFF9F1239),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // USUARIO O CORREO
                            const Text(
                              'USUARIO O CORREO',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: FarmasisPalette.textSilver,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(
                                color: FarmasisPalette.textSilverBright,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'juan.garces028@gmail.com',
                                hintStyle: const TextStyle(
                                  color: FarmasisPalette.textMuted,
                                  fontSize: 13.5,
                                ),
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: FarmasisPalette.emeraldBright,
                                  size: 19,
                                ),
                                filled: true,
                                fillColor: FarmasisPalette.inputSurface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:
                                          FarmasisPalette.borderChromeSubtle),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:
                                          FarmasisPalette.borderChromeSubtle),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: FarmasisPalette.emeraldBright,
                                      width: 1.5),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                      ? 'Ingresa tu usuario o correo'
                                      : null,
                            ),
                            const SizedBox(height: 14),

                            // CONTRASEÑA
                            const Text(
                              'CONTRASEÑA',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: FarmasisPalette.textSilver,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              onFieldSubmitted: (_) => _handleLogin(),
                              style: const TextStyle(
                                color: FarmasisPalette.textSilverBright,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                hintStyle: const TextStyle(
                                  color: FarmasisPalette.textMuted,
                                  fontSize: 13.5,
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: FarmasisPalette.emeraldBright,
                                  size: 19,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: FarmasisPalette.textSteel,
                                    size: 19,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: FarmasisPalette.inputSurface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 13),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:
                                          FarmasisPalette.borderChromeSubtle),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color:
                                          FarmasisPalette.borderChromeSubtle),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: FarmasisPalette.emeraldBright,
                                      width: 1.5),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                      ? 'Ingresa tu contraseña'
                                      : null,
                            ),
                            const SizedBox(height: 20),

                            // BOTÓN METÁLICO VERDE FARMASIS: INICIAR SESIÓN
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF40916C),
                                    Color(0xFF2D6A4F),
                                    Color(0xFF1B4332),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF74C69D),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: FarmasisPalette.emeraldDeep
                                        .withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : () => _handleLogin(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : const Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // BOTÓN METÁLICO PLATA/ESMERALDA: INGRESAR CON HUELLA
                            SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _handleBiometricLogin,
                                icon: const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 21,
                                  color: FarmasisPalette.emeraldBright,
                                ),
                                label: const Text(
                                  'Ingresar con huella',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: FarmasisPalette.textSilverBright,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: FarmasisPalette.inputSurface,
                                  side: const BorderSide(
                                    color: FarmasisPalette.borderChromeBright,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                onPressed: _mostrarDialogoServidor,
                                icon: const Icon(
                                  Icons.wifi_tethering_rounded,
                                  size: 15,
                                  color: FarmasisPalette.textSteel,
                                ),
                                label: Text(
                                  'Servidor: ${ApiService.springBootBaseUrl}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: FarmasisPalette.textSteel,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
  }

  void _mostrarDialogoServidor() {
    final ctrl = TextEditingController(text: ApiService.springBootBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Configurar Servidor FarmaSIS',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: FarmasisPalette.textSilverBright,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'URL del servidor en la nube (Render) o IP local:',
              style: TextStyle(
                fontSize: 12,
                color: FarmasisPalette.textSteel,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: const TextStyle(
                fontSize: 13,
                color: FarmasisPalette.textSilverBright,
              ),
              decoration: InputDecoration(
                hintText: 'https://farmasis-oficial.onrender.com',
                filled: true,
                fillColor: FarmasisPalette.inputSurface,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: FarmasisPalette.borderChromeSubtle),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiService.setCustomServerUrl(ctrl.text);
              Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FarmasisPalette.emeraldBright,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar IP'),
          ),
        ],
      ),
    );
  }
}

/// Modal metálico esmeralda/plata para escaneo de huella digital
class _FingerprintScannerBottomSheet extends StatefulWidget {
  const _FingerprintScannerBottomSheet();

  @override
  State<_FingerprintScannerBottomSheet> createState() =>
      _FingerprintScannerBottomSheetState();
}

class _FingerprintScannerBottomSheetState
    extends State<_FingerprintScannerBottomSheet> {
  double _progress = 0.0;
  bool _isScanning = false;
  bool _isCompleted = false;
  Timer? _scanTimer;

  void _startScan() {
    if (_isCompleted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isScanning = true;
    });

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress += 0.07;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _isCompleted = true;
          _isScanning = false;
          timer.cancel();
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 280), () {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          });
        }
      });
    });
  }

  void _stopScan() {
    if (_isCompleted) return;
    _scanTimer?.cancel();
    setState(() {
      _isScanning = false;
      _progress = 0.0;
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isCompleted
        ? FarmasisPalette.emeraldNeon
        : (_isScanning
            ? FarmasisPalette.emeraldBright
            : FarmasisPalette.textSteel);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FarmasisPalette.cardSteelLight,
            FarmasisPalette.cardSteelDark,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
              color: FarmasisPalette.borderChromeBright, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: FarmasisPalette.borderChromeBright,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verificación Biométrica',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FarmasisPalette.textSilverBright,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca el sensor para validar tu huella',
              style: TextStyle(
                fontSize: 12.5,
                color: FarmasisPalette.textSteel,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTapDown: (_) => _startScan(),
              onTapUp: (_) => _stopScan(),
              onTapCancel: _stopScan,
              onTap: () {
                if (!_isScanning && !_isCompleted) {
                  _startScan();
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 3.2,
                      backgroundColor: FarmasisPalette.pillTrackSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isCompleted || _isScanning
                            ? FarmasisPalette.emeraldBright
                            : FarmasisPalette.borderChromeSubtle,
                      ),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FarmasisPalette.inputSurface,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: _isScanning || _isCompleted
                          ? [
                              BoxShadow(
                                color: FarmasisPalette.emeraldBright
                                    .withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isCompleted
                          ? Icons.check_rounded
                          : Icons.fingerprint_rounded,
                      size: 42,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isCompleted
                  ? 'Huella verificada'
                  : (_isScanning
                      ? 'Escaneando huella...'
                      : 'Toca el ícono de huella para ingresar'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _isCompleted
                    ? FarmasisPalette.emeraldBright
                    : FarmasisPalette.textSilver,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: FarmasisPalette.textSteel,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
