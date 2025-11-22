import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class ChefStatusBar extends StatelessWidget {
  final GlobalKey showcaseKey;
  final int userXp;
  final int userLevel;
  final String userTitle;
  final int xpPerLevel;

  const ChefStatusBar({
    super.key,
    required this.showcaseKey,
    required this.userXp,
    required this.userLevel,
    required this.userTitle,
    required this.xpPerLevel,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (userXp % xpPerLevel) / xpPerLevel.toDouble();

    return Showcase(
      key: showcaseKey,
      title: 'Level Koki',
      description: 'Makin sering masak, makin tinggi level lo!',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 2,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.stars_rounded, size: 20, color: Colors.amber[700]),
            const SizedBox(width: 8),
            Text(
              "Lv.$userLevel $userTitle",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[700]!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${userXp % xpPerLevel}/$xpPerLevel XP",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}