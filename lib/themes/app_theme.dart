import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primary = Color(0xFF5E5CE6); // bright violet/indigo
const Color accent = Color(0xFFD946EF); // glowing magenta/pink
const Color bgLight = Color(0xFFFFFFFF); // Solid White background
const Color surface = Color(0xFFFFFFFF); // White card surface
const Color textDark = Color(0xFF1C1C1E); // Dark typography
const Color textMid = Color(0xFF8E8E93); // Gray text slate

const List<Color> nodeColors = [
  Color(0xFF818CF8), // indigo
  Color(0xFFA78BFA), // violet
  Color(0xFFF472B6), // pink
  Color(0xFFFBBF24), // amber
  Color(0xFF34D399), // emerald
  Color(0xFF60A5FA), // blue
];

// 8 Theme Palettes for the Customization Panel
final Map<String, List<Color>> themePalettes = {
  'Ocean': [
    const Color(0xFF0284C7),
    const Color(0xFF0EA5E9),
    const Color(0xFF38BDF8),
    const Color(0xFF7DD3FC),
    const Color(0xFFBAE6FD),
    const Color(0xFFE0F2FE),
  ],
  'Forest': [
    const Color(0xFF059669),
    const Color(0xFF10B981),
    const Color(0xFF34D399),
    const Color(0xFF6EE7B7),
    const Color(0xFFA7F3D0),
    const Color(0xFFD1FAE5),
  ],
  'Sunset': [
    const Color(0xFFDC2626),
    const Color(0xFFF97316),
    const Color(0xFFFB923C),
    const Color(0xFFFCA5A5),
    const Color(0xFFFECACA),
    const Color(0xFFFEE2E2),
  ],
  'Mono': [
    const Color(0xFF27272A),
    const Color(0xFF3F3F46),
    const Color(0xFF52525B),
    const Color(0xFF71717A),
    const Color(0xFFA1A1AA),
    const Color(0xFFD4D4D8),
  ],
  'Candy': [
    const Color(0xFFF472B6),
    const Color(0xFFFBCFE8),
    const Color(0xFFFDE047),
    const Color(0xFF93C5FD),
    const Color(0xFFC084FC),
    const Color(0xFFE9D5FF),
  ],
  'Deep Space': [
    const Color(0xFF1E1B4B),
    const Color(0xFF312E81),
    const Color(0xFF3730A3),
    const Color(0xFF4338CA),
    const Color(0xFF4F46E5),
    const Color(0xFF6366F1),
  ],
  'Earth': [
    const Color(0xFF78350F),
    const Color(0xFF92400E),
    const Color(0xFFB45309),
    const Color(0xFFD97706),
    const Color(0xFFF59E0B),
    const Color(0xFFFCD34D),
  ],
  'Neon': [
    const Color(0xFF22C55E),
    const Color(0xFFEF4444),
    const Color(0xFF06B6D4),
    const Color(0xFFEC4899),
    const Color(0xFFEAB308),
    const Color(0xFFA855F7),
  ],
};

const double cardRadius = 24.0;
const double nodeRadius = 50.0;
const double buttonRadius = 16.0;

const BoxShadow cardShadow = BoxShadow(
  color: Color(0x3D000000),
  blurRadius: 30,
  offset: Offset(0, 8),
);

// Inter helper (Apple minimalist headings)
TextStyle headingStyle({
  double fontSize = 24.0,
  Color color = textDark,
  FontWeight fontWeight = FontWeight.w300, // Thin modern aesthetic
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: -0.5,
    decoration: TextDecoration.none,
  );
}

// Inter helper (Apple minimalist body)
TextStyle bodyStyle({
  double fontSize = 14.0,
  Color color = textDark,
  FontWeight fontWeight = FontWeight.w300, // Thin/Light modern aesthetic
  double? height,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: -0.2,
    decoration: TextDecoration.none,
  );
}
