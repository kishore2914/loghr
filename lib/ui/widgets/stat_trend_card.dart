import 'package:flutter/material.dart';
import 'package:loghr_mobile/ui/widgets/glassmorphic_card.dart';

class StatTrendCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final double? trendPercentage;
  final bool isPositiveTrend;
  final String? subtitle;

  const StatTrendCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.trendPercentage,
    this.isPositiveTrend = true,
    this.subtitle,
  });

  List<Color> _getGradientColors() {
    // Create gradient based on icon color
    return [
      iconColor.withOpacity(0.25),
      iconColor.withOpacity(0.15),
      iconColor.withOpacity(0.08),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Always use dark analytics UI style with gradient backgrounds
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      blur: 15,
      borderColor: Colors.white.withOpacity(0.1),
      gradientColors: _getGradientColors(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 80;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isNarrow ? 6 : 8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: isNarrow ? 16 : 20,
                    ),
                  ),
                  if (trendPercentage != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNarrow ? 3 : 4,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isPositiveTrend ? Colors.green : Colors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositiveTrend ? Icons.arrow_upward : Icons.arrow_downward,
                            size: isNarrow ? 8 : 10,
                            color: isPositiveTrend ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: isNarrow ? 1 : 2),
                          Text(
                            '${trendPercentage!.abs().toStringAsFixed(isNarrow ? 0 : 1)}%',
                            style: TextStyle(
                              fontSize: isNarrow ? 8 : 9,
                              fontWeight: FontWeight.w600,
                              color: isPositiveTrend ? Colors.green : Colors.red,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

