import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'widgets/metallic_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Oculta los botones de navegación inferiores de Android (||| O <) dejando visible la barra de estado superior
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [SystemUiOverlay.top],
  );
  runApp(const FarmasisApp());
}

class FarmasisApp extends StatelessWidget {
  const FarmasisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmaSIS · Control Total & BI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: FarmasisPalette.bgObsidian,
        colorScheme: const ColorScheme.light(
          primary: FarmasisPalette.emeraldBright,
          secondary: FarmasisPalette.chromeIndigo,
          surface: FarmasisPalette.cardSteelLight,
        ),
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const [
          'Inter',
          '-apple-system',
          'BlinkMacSystemFont',
          'Roboto',
          'sans-serif',
        ],
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: FarmasisPalette.textSilverBright,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(
            color: FarmasisPalette.textSilverBright,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          bodyMedium: TextStyle(
            color: FarmasisPalette.textSilver,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            color: FarmasisPalette.textSteel,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
