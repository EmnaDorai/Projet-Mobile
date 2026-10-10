import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Symbole Bnin : une assiette vue de dessus avec un trait de sauce
/// en forme de sourire (« bnin » = délicieux).
class BninMark extends StatelessWidget {
  final double size;

  /// Avec fond olive arrondi (icône d'app) ou seulement l'assiette.
  final bool withBadge;
  const BninMark({super.key, this.size = 72, this.withBadge = true});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BninMarkPainter(withBadge)),
      );
}

class _BninMarkPainter extends CustomPainter {
  final bool withBadge;
  _BninMarkPainter(this.withBadge);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);

    if (withBadge) {
      final rrect = RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(s * 0.28));
      canvas.drawRRect(rrect, Paint()..color = AppColors.olive);
    }

    final plateR = s * (withBadge ? 0.34 : 0.48);
    // Assiette
    canvas.drawCircle(c, plateR, Paint()..color = AppColors.harissa);
    // Rebord de l'assiette
    canvas.drawCircle(
      c,
      plateR * 0.78,
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = plateR * 0.07,
    );
    // Trait de sauce en sourire
    final arc = Rect.fromCircle(center: c.translate(0, -plateR * 0.08), radius: plateR * 0.46);
    canvas.drawArc(
      arc,
      0.35,
      2.44,
      false,
      Paint()
        ..color = AppColors.saffron
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = plateR * 0.17,
    );
    // Goutte de safran (écho au point du « i » du nom)
    canvas.drawCircle(c.translate(plateR * 0.30, -plateR * 0.30), plateR * 0.10,
        Paint()..color = AppColors.saffron);
  }

  @override
  bool shouldRepaint(covariant _BninMarkPainter old) => old.withBadge != withBadge;
}

/// Nom de l'app : « bnin » en minuscules, le point du i en safran.
class BninWordmark extends StatelessWidget {
  final double fontSize;
  final Color color;
  const BninWordmark({super.key, this.fontSize = 44, this.color = AppColors.olive});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.bricolageGrotesque(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -fontSize * 0.04,
      height: 1,
      color: color,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('bn', style: style),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Text('ı', style: style), // i sans point
            Positioned(
              top: -fontSize * 0.02,
              child: Container(
                width: fontSize * 0.2,
                height: fontSize * 0.2,
                decoration: const BoxDecoration(
                    color: AppColors.saffron, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        Text('n', style: style),
      ],
    );
  }
}

/// Logo complet : symbole + nom.
class BninLogo extends StatelessWidget {
  final double markSize;
  final Color wordColor;
  const BninLogo({super.key, this.markSize = 64, this.wordColor = AppColors.olive});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BninMark(size: markSize),
          SizedBox(width: markSize * 0.22),
          BninWordmark(fontSize: markSize * 0.72, color: wordColor),
        ],
      );
}
