import 'package:flutter/material.dart';

class MatchScoreBadge extends StatelessWidget {
  final double score;
  final VoidCallback? onTap;

  const MatchScoreBadge({
    super.key,
    required this.score,
    this.onTap,
  });

  Color _getColor() {
    if (score >= 80) return const Color(0xFF0D6B4F); // Green
    if (score >= 60) return const Color(0xFFD97706); // Amber
    return const Color(0xFF64748B); // Slate
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${score.toStringAsFixed(0)}% Match',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: badge,
      );
    }

    return badge;
  }
}
