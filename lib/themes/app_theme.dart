import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primary = Color(0xFF4F46E5);   // indigo
const Color accent = Color(0xFF7C3AED);    // violet
const Color bgLight = Color(0xFFF8F9FF);   // page background
const Color surface = Colors.white;
const Color textDark = Color(0xFF1E1B4B);
const Color textMid = Color(0xFF6B7280);

const List<Color> nodeColors = [
  Color(0xFF6366F1), // indigo
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFFF59E0B), // amber
  Color(0xFF10B981), // emerald
  Color(0xFF3B82F6), // blue
];

// 8 Theme Palettes for the Customization Panel
final Map<String, List<Color>> themePalettes = {
  'Ocean': [
    const Color(0xFF0077B6),
    const Color(0xFF0096C7),
    const Color(0xFF00B4D8),
    const Color(0xFF48CAE4),
    const Color(0xFF90E0EF),
    const Color(0xFFADE8F4),
  ],
  'Forest': [
    const Color(0xFF2D6A4F),
    const Color(0xFF40916C),
    const Color(0xFF52B788),
    const Color(0xFF74C69D),
    const Color(0xFF95D5B2),
    const Color(0xFFB7E4C7),
  ],
  'Sunset': [
    const Color(0xFFE63946),
    const Color(0xFFF4A261),
    const Color(0xFFE76F51),
    const Color(0xFFD90429),
    const Color(0xFFEF233C),
    const Color(0xFFF55C47),
  ],
  'Mono': [
    const Color(0xFF212529),
    const Color(0xFF343A40),
    const Color(0xFF495057),
    const Color(0xFF6C757D),
    const Color(0xFFADB5BD),
    const Color(0xFFCED4DA),
  ],
  'Candy': [
    const Color(0xFFFFB5A7),
    const Color(0xFFFFCAD4),
    const Color(0xFFF4D35E),
    const Color(0xFFB5E2FA),
    const Color(0xFFC5A3FF),
    const Color(0xFFE8AEFF),
  ],
  'Deep Space': [
    const Color(0xFF120C1F),
    const Color(0xFF321A5C),
    const Color(0xFF5C2C90),
    const Color(0xFF8D42A1),
    const Color(0xFFC059B3),
    const Color(0xFFF472C6),
  ],
  'Earth': [
    const Color(0xFF7F5539),
    const Color(0xFF9C6644),
    const Color(0xFFB07D62),
    const Color(0xFFC6AC8F),
    const Color(0xFFE6CCB2),
    const Color(0xFF8C7853),
  ],
  'Neon': [
    const Color(0xFF39FF14),
    const Color(0xFFFF073A),
    const Color(0xFF00FFFF),
    const Color(0xFFFF00FF),
    const Color(0xFFFFE600),
    const Color(0xFFBF00FF),
  ],
};

const double cardRadius = 20.0;
const double nodeRadius = 50.0;
const double buttonRadius = 14.0;

const BoxShadow cardShadow = BoxShadow(
  color: Color(0x14000000),
  blurRadius: 24,
  offset: Offset(0, 6),
);

// Space Grotesk helper (Headings)
TextStyle headingStyle({
  double fontSize = 24.0,
  Color color = textDark,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
  );
}

// Plus Jakarta Sans helper (Body)
TextStyle bodyStyle({
  double fontSize = 14.0,
  Color color = textDark,
  FontWeight fontWeight = FontWeight.w400,
  double? height,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    height: height,
  );
}
