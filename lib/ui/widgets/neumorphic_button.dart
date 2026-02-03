import 'package:flutter/material.dart';

class NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double borderRadius;
  final Color? baseColor;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderRadius = 20,
    this.baseColor,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final color = baseColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]!
            : Colors.grey[200]!);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            // Light shadow (top-left)
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              offset: const Offset(-5, -5),
              blurRadius: 10,
              spreadRadius: 0,
            ),
            // Dark shadow (bottom-right)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(5, 5),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

