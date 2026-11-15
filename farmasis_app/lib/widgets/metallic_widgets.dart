import 'package:flutter/material.dart';

/// Paleta Ejecutiva FarmaSIS (Armonizada con la Web: Fondo neutro #F4F7F6,
/// tarjetas blancas puras, bordes plata-pizarra y acentos esmeralda/azul/cian controlados)
class FarmasisPalette {
  // Fondos principales: Gris Perla Neutro idéntico a la Web (#F4F7F6 -> #EEF2F5)
  static const Color bgObsidian = Color(0xFFF4F7F6);
  static const Color bgGunmetalTop = Color(0xFFF8FAFC);
  static const Color bgGunmetalMid = Color(0xFFF4F7F6);
  static const Color bgGunmetalBottom = Color(0xFFEDF2F4);

  // Barra de Navegación / Sidebar Web: Verde Bosque Oscuro Institucional (#143325 -> #1B4332)
  static const Color headerForestTop = Color(0xFF143325);
  static const Color headerForestMid = Color(0xFF1B4332);
  static const Color headerForestBottom = Color(0xFF0F261C);

  // Superficies para inputs y selectores (Blanco y Gris Pizarra suave, sin verde invasivo)
  static const Color inputSurface = Color(0xFFF8FAFC);
  static const Color pillTrackSurface = Color(0xFFE2E8F0);

  // Superficies de tarjetas: Blanco Puro con sutil reflejo plata
  static const Color cardSteelLight = Color(0xFFFFFFFF);
  static const Color cardSteelDark = Color(0xFFFAFCFE);

  // Superficie ámbar suave para alertas críticas de stock
  static const Color cardGoldLight = Color(0xFFFFFBEB);
  static const Color cardGoldDark = Color(0xFFFEF3C7);

  // Bordes neutros de plata y pizarra (evita bordes verdes en todas las tarjetas)
  static const Color borderChromeBright = Color(0xFFCBD5E1);
  static const Color borderChromeSubtle = Color(0xFFE2E8F0);
  static const Color borderGold = Color(0xFFD97706);
  static const Color borderEmerald = Color(0xFF198754);

  // Acentos de la Web FarmaSIS (Esmeralda, Cian, Azul Rey, Pizarra y Ámbar)
  static const Color emeraldBright = Color(0xFF198754);
  static const Color emeraldNeon = Color(0xFF15803D);
  static const Color emeraldDeep = Color(0xFF1B4332);
  static const Color emeraldMint = Color(0xFF52B788);
  static const Color cyanGlow = Color(0xFF06B6D4);
  static const Color chromeBlue = Color(0xFF0284C7);
  static const Color chromeIndigo = Color(0xFF2563EB);
  static const Color slateAccent = Color(0xFF64748B);
  static const Color goldWarm = Color(0xFFD97706);
  static const Color goldText = Color(0xFFB45309);
  static const Color dangerCoral = Color(0xFFDC2626);

  // Tipografía nítida en Gris Pizarra / Carbón (igual a la Web para máxima legibilidad)
  static const Color textSilverBright = Color(0xFF0F172A);
  static const Color textSilver = Color(0xFF334155);
  static const Color textSteel = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
}

/// Tarjeta ejecutiva limpia (Blanco puro con borde plata-pizarra y sombra suave)
class MetallicGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isGoldVariant;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const MetallicGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 14,
    this.isGoldVariant = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradientColors = isGoldVariant
        ? [
            FarmasisPalette.cardGoldLight,
            FarmasisPalette.cardGoldDark,
          ]
        : (isHighlighted
            ? [
                const Color(0xFFF0FDF4),
                const Color(0xFFDCFCE7),
              ]
            : [
                FarmasisPalette.cardSteelLight,
                FarmasisPalette.cardSteelDark,
              ]);

    final Color borderColor = isGoldVariant
        ? FarmasisPalette.borderGold.withValues(alpha: 0.55)
        : (isHighlighted
            ? FarmasisPalette.emeraldBright.withValues(alpha: 0.65)
            : FarmasisPalette.borderChromeSubtle);

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: borderColor,
          width: isHighlighted ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }
}

/// Logotipo oficial de FarmaSIS
class MetallicCrossLogo extends StatelessWidget {
  final double size;

  const MetallicCrossLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.24);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: FarmasisPalette.borderChromeSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/farmasis_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Icon(
            Icons.monitor_heart_outlined,
            size: size * 0.56,
            color: FarmasisPalette.emeraldBright,
          ),
        ),
      ),
    );
  }
}

/// Icono para los módulos rápidos ("Nueva Venta POS" y "Predicción IA")
class MetallicModuleIcon extends StatelessWidget {
  final IconData icon;
  final bool isAiVariant;

  const MetallicModuleIcon({
    super.key,
    required this.icon,
    this.isAiVariant = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isAiVariant
              ? [
                  const Color(0xFF2563EB),
                  const Color(0xFF1D4ED8),
                ]
              : [
                  const Color(0xFF198754),
                  const Color(0xFF146C43),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isAiVariant
                    ? FarmasisPalette.chromeIndigo
                    : FarmasisPalette.emeraldBright)
                .withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 21,
        color: Colors.white,
      ),
    );
  }
}
