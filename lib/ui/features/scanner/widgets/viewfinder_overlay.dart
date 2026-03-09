import 'package:flutter/material.dart';

/// Animated viewfinder overlay for the receipt scanner camera preview.
///
/// Draws a semi-transparent dark background with a rounded rectangular cutout
/// in the centre, corner bracket decorations, and a sweeping scan line.
class ViewfinderOverlay extends StatefulWidget {
  const ViewfinderOverlay({super.key});

  @override
  State<ViewfinderOverlay> createState() => _ViewfinderOverlayState();
}

class _ViewfinderOverlayState extends State<ViewfinderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Cutout dimensions: ~80% width, slightly wider than tall
        final cutoutWidth = size.width * 0.80;
        final cutoutHeight = cutoutWidth * 0.70;
        final cutoutLeft = (size.width - cutoutWidth) / 2;
        final cutoutTop = (size.height - cutoutHeight) / 2 - 40;

        final cutoutRect = Rect.fromLTWH(
          cutoutLeft,
          cutoutTop,
          cutoutWidth,
          cutoutHeight,
        );

        return Stack(
          children: [
            // Semi-transparent overlay with cutout
            CustomPaint(
              size: size,
              painter: _ViewfinderPainter(cutoutRect: cutoutRect),
            ),

            // Corner brackets
            CustomPaint(
              size: size,
              painter: _CornerBracketPainter(cutoutRect: cutoutRect),
            ),

            // Animated scanning line
            AnimatedBuilder(
              animation: _scanLineAnimation,
              builder: (context, child) {
                final lineY = cutoutRect.top +
                    (_scanLineAnimation.value * cutoutRect.height);
                return Positioned(
                  left: cutoutRect.left + 8,
                  top: lineY,
                  child: Container(
                    width: cutoutRect.width - 16,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Instruction text below cutout
            Positioned(
              left: 0,
              right: 0,
              top: cutoutRect.bottom + 24,
              child: Text(
                'Position receipt within the frame',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Semi-transparent overlay with cutout ──

class _ViewfinderPainter extends CustomPainter {
  final Rect cutoutRect;

  const _ViewfinderPainter({required this.cutoutRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, overlayPaint);

    // Subtle border around the cutout
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      cutoutRect != oldDelegate.cutoutRect;
}

// ── Corner bracket decorations ──

class _CornerBracketPainter extends CustomPainter {
  final Rect cutoutRect;

  const _CornerBracketPainter({required this.cutoutRect});

  static const _bracketLength = 28.0;
  static const _bracketThickness = 3.0;
  static const _cornerRadius = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bracketThickness
      ..strokeCap = StrokeCap.round;

    final left = cutoutRect.left;
    final top = cutoutRect.top;
    final right = cutoutRect.right;
    final bottom = cutoutRect.bottom;

    // Top-left corner
    _drawCorner(canvas, paint, left, top, 1, 1);
    // Top-right corner
    _drawCorner(canvas, paint, right, top, -1, 1);
    // Bottom-left corner
    _drawCorner(canvas, paint, left, bottom, 1, -1);
    // Bottom-right corner
    _drawCorner(canvas, paint, right, bottom, -1, -1);
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double dx,
    double dy,
  ) {
    final path = Path();

    // Horizontal arm
    path.moveTo(x + dx * _bracketLength, y);
    path.lineTo(x + dx * _cornerRadius, y);
    // Arc at the corner
    path.arcToPoint(
      Offset(x, y + dy * _cornerRadius),
      radius: const Radius.circular(_cornerRadius),
      clockwise: dx * dy < 0,
    );
    // Vertical arm
    path.lineTo(x, y + dy * _bracketLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter oldDelegate) =>
      cutoutRect != oldDelegate.cutoutRect;
}

// ── AnimatedBuilder helper (delegates to AnimatedWidget) ──

/// Lightweight wrapper to avoid importing AnimatedBuilder from material
/// (already available, but this matches the pattern used elsewhere in the app).
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}
