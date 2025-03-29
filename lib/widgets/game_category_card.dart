import 'package:flutter/material.dart';

class GameCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int gameCount;

  const GameCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.gameCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          // TODO: Navigate to category games list
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$gameCount games',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
