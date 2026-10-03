import 'package:flutter/material.dart';

class AuthGradientScaffold extends StatelessWidget {
  const AuthGradientScaffold({
    super.key,
    required this.header,
    required this.body,
    this.showDecor = true,
  });

  final Widget header;
  final Widget body;
  final bool showDecor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFA63D),
                  Color(0xFFFCD2A6),
                ],
              ),
            ),
          ),
          if (showDecor) ...const [
            _DecorBubble(
              size: 94,
              top: -16,
              left: -18,
              color: Color(0x33FFFFFF),
            ),
            _DecorBubble(
              size: 78,
              top: 40,
              right: 24,
              color: Color(0x30F68B1F),
            ),
            _DecorBubble(
              size: 64,
              bottom: 190,
              right: -12,
              color: Color(0x26FFFFFF),
            ),
            _DecorBubble(
              size: 120,
              bottom: -34,
              left: -26,
              color: Color(0x26F68B1F),
            ),
          ],
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: header,
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(34),
                        topRight: Radius.circular(34),
                      ),
                    ),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorBubble extends StatelessWidget {
  const _DecorBubble({
    required this.size,
    required this.color,
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
