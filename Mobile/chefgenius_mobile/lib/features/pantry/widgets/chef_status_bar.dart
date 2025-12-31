import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'level_info_dialog.dart';

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

  IconData _getLevelIcon(int level) {
    if (level < 2) return Icons.kitchen; // Newbie
    if (level < 5) return Icons.restaurant; // Home Cook
    if (level < 10) return Icons.restaurant_menu; // Chef
    if (level < 20) return Icons.local_dining; // Sous Chef
    return Icons.workspace_premium; // Master Chef
  }

  @override
  Widget build(BuildContext context) {
    double progress = (userXp % xpPerLevel) / xpPerLevel.toDouble();
    final levelIcon = _getLevelIcon(userLevel);

    return Showcase(
      key: showcaseKey,
      title: 'Level Koki',
      description: 'Klik untuk lihat info level & awards!',
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => LevelInfoDialog(
              currentLevel: userLevel,
              currentTitle: userTitle,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade600, Colors.deepOrange.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(levelIcon, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Level $userLevel",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            userTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${userXp % xpPerLevel} / $xpPerLevel XP",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.black.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}