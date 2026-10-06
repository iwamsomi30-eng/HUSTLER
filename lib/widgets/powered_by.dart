import 'package:flutter/material.dart';

/// "POWERED BY E-LAPS" - maandishi ya rangi inayoonekana nusu-uwazi (translucent)
/// kwenye kapsuli ndogo. [onDark] = tumia rangi angavu kwa mandharinyuma ya giza.
class PoweredBy extends StatelessWidget {
  final bool onDark;
  final double fontSize;
  const PoweredBy({super.key, this.onDark = false, this.fontSize = 11.5});

  @override
  Widget build(BuildContext context) {
    final colors = onDark
        ? const [Color(0xFF8CC8FF), Color(0xFFBCA7FF)]
        : const [Color(0xFF1478F6), Color(0xFF12B8D6), Color(0xFF7138F5)];
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [for (final c in colors) c.withOpacity(.14)]),
          border: Border.all(color: colors.first.withOpacity(.40)),
        ),
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(colors: [for (final c in colors) c.withOpacity(.92)]).createShader(r),
          child: Text(
            'POWERED BY E-LAPS',
            maxLines: 1,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
