import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'level_info_dialog.dart';

class ChefStatusBar extends StatefulWidget {
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
  State<ChefStatusBar> createState() => _ChefStatusBarState();
}

class _ChefStatusBarState extends State<ChefStatusBar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _updateAnimation();
    _animController.forward();
  }
  
  @override
  void didUpdateWidget(ChefStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userXp != widget.userXp) {
      _updateAnimation();
      _animController.forward(from: 0);
    }
  }
  
  void _updateAnimation() {
    final progress = (widget.userXp % widget.xpPerLevel) / widget.xpPerLevel.toDouble();
    _progressAnimation = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getLevelEmoji(int level) {
    if (level < 2) return '🥄';
    if (level < 5) return '🍳';
    if (level < 10) return '👨‍🍳';
    if (level < 20) return '⭐';
    return '👑';
  }

  Color _getLevelColor(int level) {
    // Softer, muted colors for eye comfort
    if (level < 2) return const Color(0xFF6B7280); // Soft grey
    if (level < 5) return const Color(0xFF059669); // Soft teal-green
    if (level < 10) return const Color(0xFF3B82F6); // Soft blue
    if (level < 20) return const Color(0xFF8B5CF6); // Soft purple
    return const Color(0xFFF59E0B); // Warm amber
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final levelEmoji = _getLevelEmoji(widget.userLevel);
    final levelColor = _getLevelColor(widget.userLevel);
    final xpInLevel = widget.userXp % widget.xpPerLevel;

    return Showcase(
      key: widget.showcaseKey,
      title: 'Level Koki',
      description: 'Klik untuk lihat info level & awards!',
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => LevelInfoDialog(
              currentLevel: widget.userLevel,
              currentTitle: widget.userTitle,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: levelColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? [
                            levelColor.withOpacity(0.3),
                            levelColor.withOpacity(0.1),
                          ]
                        : [
                            levelColor.withOpacity(0.2),
                            levelColor.withOpacity(0.05),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: levelColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Level Badge
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [levelColor, levelColor.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: levelColor.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(levelEmoji, style: const TextStyle(fontSize: 28)),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${widget.userLevel}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.userTitle,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: levelColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_upward_rounded, size: 12, color: levelColor),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Lv.${widget.userLevel}',
                                          style: TextStyle(
                                            color: levelColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // XP Progress
                              Row(
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        // Background
                                        Container(
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: isDarkMode 
                                                ? Colors.white.withOpacity(0.1) 
                                                : Colors.black.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        // Progress
                                        AnimatedBuilder(
                                          animation: _progressAnimation,
                                          builder: (context, child) {
                                            return FractionallySizedBox(
                                              widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                                              child: Container(
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [levelColor, levelColor.withOpacity(0.7)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: levelColor.withOpacity(0.5),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDarkMode 
                                          ? Colors.white.withOpacity(0.1) 
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.flash_on_rounded, 
                                          size: 14, 
                                          color: Colors.amber.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$xpInLevel/${widget.xpPerLevel}',
                                          style: TextStyle(
                                            color: isDarkMode ? Colors.white70 : Colors.black54,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Info Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: levelColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: levelColor,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}