import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/services/chatbot_service.dart';

/// Menampilkan menu popover untuk memilih mode arsitektur RAG dan embedding engine.
void showArchitectureSelectorPopover({
  required BuildContext context,
  required GlobalKey headerKey,
  required ChatbotService chatbotService,
  required VoidCallback onConfigurationChanged,
}) {
  final renderBox = headerKey.currentContext?.findRenderObject() as RenderBox?;
  final offset = renderBox?.localToGlobal(Offset.zero) ?? const Offset(56, 75);
  final size = renderBox?.size ?? const Size(180, 40);

  final screenSize = MediaQuery.of(context).size;
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  final double cardWidth = (screenSize.width - 24).clamp(280.0, 318.0);
  final double top = offset.dy + size.height + 4;
  final double left = (offset.dx - 8).clamp(12.0, (screenSize.width - cardWidth - 12.0).clamp(12.0, double.infinity));
  final double targetArrowX = offset.dx + 65;
  final double arrowLeft = (targetArrowX - left).clamp(18.0, cardWidth - 24.0);

  final cardBg = isDarkMode ? const Color(0xFF131722) : Colors.white;
  final borderColor = isDarkMode ? const Color(0xFF283146) : const Color(0xFFE2E8F0);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return StatefulBuilder(
        builder: (context, setMenuState) {
          final isPureLlm = chatbotService.ragMode == 'none';

          return Stack(
            children: [
              Positioned(
                top: top - 5.5,
                left: left + arrowLeft - 7,
                child: CustomPaint(
                  size: const Size(14, 7),
                  painter: PopoverArrowPainter(
                    color: cardBg,
                    borderColor: borderColor,
                  ),
                ),
              ),
              Positioned(
                top: top,
                left: left,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: cardWidth,
                    constraints: BoxConstraints(
                      maxHeight: screenSize.height - top - 16,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkMode ? 0.5 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                          spreadRadius: isDarkMode ? -2 : 0,
                        ),
                        if (isDarkMode)
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: Offset.zero,
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF6366F1)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Konfigurasi Arsitektur',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => Navigator.of(dialogContext).pop(),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                                      ),
                                      child: Icon(Icons.close_rounded, size: 14, color: isDarkMode ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'MODE RETRIEVAL',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildModeTile(
                                parentContext: context,
                                dialogContext: dialogContext,
                                chatbotService: chatbotService,
                                mode: 'none',
                                title: 'Pure LLM (Baseline)',
                                subtitle: 'Gemini direct tanpa retrieval context',
                                icon: Icons.bolt_rounded,
                                accentColor: const Color(0xFF64748B),
                                isDarkMode: isDarkMode,
                                setMenuState: setMenuState,
                                onConfigurationChanged: onConfigurationChanged,
                              ),
                              _buildModeTile(
                                parentContext: context,
                                dialogContext: dialogContext,
                                chatbotService: chatbotService,
                                mode: 'naive',
                                title: 'Naive RAG (Dasar)',
                                subtitle: 'Dense search pgvector murni (Top-5)',
                                icon: Icons.search_rounded,
                                accentColor: const Color(0xFF0284C7),
                                isDarkMode: isDarkMode,
                                setMenuState: setMenuState,
                                onConfigurationChanged: onConfigurationChanged,
                              ),
                              _buildModeTile(
                                parentContext: context,
                                dialogContext: dialogContext,
                                chatbotService: chatbotService,
                                mode: 'pre_retrieval',
                                title: 'Pre-Retrieval Only',
                                subtitle: 'Rewrite + Hybrid BM25/Dense (Top-5 RRF)',
                                icon: Icons.manage_search_rounded,
                                accentColor: const Color(0xFF0D9488),
                                isDarkMode: isDarkMode,
                                setMenuState: setMenuState,
                                onConfigurationChanged: onConfigurationChanged,
                              ),
                              _buildModeTile(
                                parentContext: context,
                                dialogContext: dialogContext,
                                chatbotService: chatbotService,
                                mode: 'post_retrieval',
                                title: 'Post-Retrieval Only',
                                subtitle: 'Dense Top-20 + BGE Reranker (Top-5)',
                                icon: Icons.filter_list_rounded,
                                accentColor: const Color(0xFFD97706),
                                isDarkMode: isDarkMode,
                                setMenuState: setMenuState,
                                onConfigurationChanged: onConfigurationChanged,
                              ),
                              _buildModeTile(
                                parentContext: context,
                                dialogContext: dialogContext,
                                chatbotService: chatbotService,
                                mode: 'advanced',
                                title: 'Full Advanced RAG',
                                subtitle: 'Pre-Retrieval + BGE Reranker (Lengkap)',
                                icon: Icons.auto_awesome_rounded,
                                accentColor: const Color(0xFF6366F1),
                                isDarkMode: isDarkMode,
                                setMenuState: setMenuState,
                                onConfigurationChanged: onConfigurationChanged,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    'EMBEDDING ENGINE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: isDarkMode ? Colors.white38 : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  if (isPureLlm) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: isDarkMode ? 0.15 : 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'STANDBY',
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Opacity(
                                opacity: isPureLlm ? 0.45 : 1.0,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildEngineCard(
                                        parentContext: context,
                                        dialogContext: dialogContext,
                                        chatbotService: chatbotService,
                                        engine: 'gemini',
                                        title: 'Gemini AI',
                                        dimensions: '3.072 dim',
                                        accentColor: const Color(0xFF0D9488),
                                        isDarkMode: isDarkMode,
                                        setMenuState: setMenuState,
                                        onConfigurationChanged: onConfigurationChanged,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildEngineCard(
                                        parentContext: context,
                                        dialogContext: dialogContext,
                                        chatbotService: chatbotService,
                                        engine: 'indobert',
                                        title: 'IndoBERT',
                                        dimensions: '768 dim',
                                        accentColor: const Color(0xFFD97706),
                                        isDarkMode: isDarkMode,
                                        setMenuState: setMenuState,
                                        onConfigurationChanged: onConfigurationChanged,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnimation),
          alignment: Alignment(
            ((arrowLeft + left) / screenSize.width * 2 - 1).clamp(-1.0, 1.0),
            -1.0,
          ),
          child: child,
        ),
      );
    },
  );
}

Widget _buildModeTile({
  required BuildContext parentContext,
  required BuildContext dialogContext,
  required ChatbotService chatbotService,
  required String mode,
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accentColor,
  required bool isDarkMode,
  required StateSetter setMenuState,
  required VoidCallback onConfigurationChanged,
}) {
  final isSelected = chatbotService.ragMode == mode;
  final cardBg = isSelected
      ? (isDarkMode ? const Color(0xFF1E2336) : accentColor.withValues(alpha: 0.07))
      : (isDarkMode ? const Color(0xFF181C28) : const Color(0xFFF8FAFC));
  final border = isSelected
      ? Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.2)
      : Border.all(color: isDarkMode ? const Color(0xFF242A3C) : const Color(0xFFE2E8F0), width: 1);

  return Container(
    margin: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.selectionClick();
          setMenuState(() {
            chatbotService.ragMode = mode;
          });
          onConfigurationChanged();
          Future.delayed(const Duration(milliseconds: 140), () {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
              showStatusBanner(
                context: parentContext,
                detail: '$title Aktif',
                icon: icon,
                color: accentColor,
              );
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.2)
                      : (isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isSelected ? accentColor : (isDarkMode ? Colors.white60 : Colors.black45),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDarkMode ? Colors.white38 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 10, color: accentColor),
                      const SizedBox(width: 2),
                      Text(
                        'AKTIF',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 14,
                  color: isDarkMode ? Colors.white12 : Colors.black12,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildEngineCard({
  required BuildContext parentContext,
  required BuildContext dialogContext,
  required ChatbotService chatbotService,
  required String engine,
  required String title,
  required String dimensions,
  required Color accentColor,
  required bool isDarkMode,
  required StateSetter setMenuState,
  required VoidCallback onConfigurationChanged,
}) {
  final isSelected = chatbotService.embeddingEngine == engine;
  final cardBg = isSelected
      ? (isDarkMode ? const Color(0xFF1E2336) : accentColor.withValues(alpha: 0.07))
      : (isDarkMode ? const Color(0xFF181C28) : const Color(0xFFF8FAFC));
  final border = isSelected
      ? Border.all(color: accentColor.withValues(alpha: 0.8), width: 1.2)
      : Border.all(color: isDarkMode ? const Color(0xFF242A3C) : const Color(0xFFE2E8F0), width: 1);

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setMenuState(() {
          chatbotService.embeddingEngine = engine;
        });
        onConfigurationChanged();
        Future.delayed(const Duration(milliseconds: 140), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
            showStatusBanner(
              context: parentContext,
              detail: '$title ($dimensions)',
              icon: Icons.hub_rounded,
              color: accentColor,
            );
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isSelected ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dimensions,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 13, color: accentColor)
                else
                  Icon(Icons.radio_button_off_rounded, size: 12, color: isDarkMode ? Colors.white12 : Colors.black12),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

/// Menampilkan pill notifikasi status konfigurasi yang minimalis dan mewah di bagian bawah tengah layar.
void showStatusBanner({
  required BuildContext context,
  required String detail,
  required IconData icon,
  required Color color,
  String? title,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1700),
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
                child: Icon(icon, size: 10.5, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(width: 3),
            ],
          ),
        ),
      ),
    ),
  );
}

class PopoverArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  PopoverArrowPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final borderPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PopoverArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
