import 'package:flutter/material.dart';

class SwipeableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final String? leftActionLabel;
  final String? rightActionLabel;
  final Color? leftActionColor;
  final Color? rightActionColor;
  final IconData? leftActionIcon;
  final IconData? rightActionIcon;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.leftActionLabel,
    this.rightActionLabel,
    this.leftActionColor,
    this.rightActionColor,
    this.leftActionIcon,
    this.rightActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cardKey = key ?? UniqueKey();
    return Dismissible(
      key: cardKey,
      direction: _getDismissDirection(),
      background: _buildBackground(context, isLeft: true),
      secondaryBackground: _buildBackground(context, isLeft: false),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd && onSwipeRight != null) {
          onSwipeRight!();
        } else if (direction == DismissDirection.endToStart && onSwipeLeft != null) {
          onSwipeLeft!();
        }
      },
      child: child,
    );
  }

  DismissDirection _getDismissDirection() {
    if (onSwipeLeft != null && onSwipeRight != null) {
      return DismissDirection.horizontal;
    } else if (onSwipeLeft != null) {
      return DismissDirection.endToStart;
    } else if (onSwipeRight != null) {
      return DismissDirection.startToEnd;
    }
    return DismissDirection.none;
  }

  Widget _buildBackground(BuildContext context, {required bool isLeft}) {
    final color = isLeft
        ? (leftActionColor ?? Colors.red)
        : (rightActionColor ?? Colors.green);
    final label = isLeft ? leftActionLabel : rightActionLabel;
    final icon = isLeft ? leftActionIcon : rightActionIcon;
    final alignment = isLeft ? Alignment.centerLeft : Alignment.centerRight;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
          ],
          if (label != null)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

