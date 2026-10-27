import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Bubble respons streaming untuk menampilkan efek mengetik real-time dari asisten
class StreamingMessageBubble extends StatelessWidget {
  final String responseText;
  final AnimationController typingAnimController;
  final bool isDarkMode;

  const StreamingMessageBubble({
    super.key,
    required this.responseText,
    required this.typingAnimController,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🥗', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: responseText.isNotEmpty
                        ? MarkdownBody(
                            data: responseText,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              strong: TextStyle(
                                color: Colors.orange[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : _buildTypingIndicator(),
                  ),
                  const SizedBox(width: 8),
                  _buildBlinkingCursor(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: typingAnimController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (typingAnimController.value + delay) % 1.0;
            final scale = 0.5 + (0.5 * (1 - (2 * value - 1).abs()));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.orange[400],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildBlinkingCursor() {
    return AnimatedBuilder(
      animation: typingAnimController,
      builder: (context, child) {
        final opacity = (typingAnimController.value * 2 % 1.0 < 0.5) ? 1.0 : 0.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 2,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}
