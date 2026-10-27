import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../app/services/chatbot_service.dart';

class MarkdownContentPart {
  final String content;
  final bool isTable;

  MarkdownContentPart(this.content, this.isTable);
}

/// Bubble pesan chat untuk pengguna maupun asisten AI nutrisi
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDarkMode;
  final void Function(String text, {String successMessage}) onCopy;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isDarkMode,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
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
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      )
                    : null,
                color: isUser ? null : (isDarkMode ? const Color(0xFF2A2A3E) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          message.text,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => onCopy(
                              message.text,
                              successMessage: 'Pesan berhasil disalin',
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Salin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectionArea(
                          child: _buildMarkdownContent(message.text, isDarkMode),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => onCopy(
                              message.text,
                              successMessage: 'Jawaban berhasil disalin',
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: isDarkMode ? Colors.orange[200] : Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Salin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode ? Colors.orange[200] : Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(String text, bool isDarkMode) {
    final sanitizedText = text
        .replaceAll('(Mode: post_retrieval)', '(Mode: Post-Retrieval)')
        .replaceAll('(Mode: pre_retrieval)', '(Mode: Pre-Retrieval)')
        .replaceAll('(Mode: naive)', '(Mode: Naive RAG)')
        .replaceAll('(Mode: advanced)', '(Mode: Full Advanced RAG)')
        .replaceAll('(Mode: none)', '(Mode: Pure LLM (Tanpa RAG))');

    final hasTable = sanitizedText.contains('|') && sanitizedText.contains('---');

    if (!hasTable) {
      return _buildMarkdownWidget(sanitizedText, isDarkMode);
    }

    final parts = _splitMarkdownByTables(sanitizedText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        if (part.isTable) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildMarkdownWidget(part.content, isDarkMode),
            ),
          );
        } else {
          return _buildMarkdownWidget(part.content, isDarkMode);
        }
      }).toList(),
    );
  }

  List<MarkdownContentPart> _splitMarkdownByTables(String text) {
    final parts = <MarkdownContentPart>[];
    final lines = text.split('\n');

    StringBuffer currentBuffer = StringBuffer();
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isTableLine = line.trim().startsWith('|') && line.trim().endsWith('|');

      if (isTableLine && !inTable) {
        if (currentBuffer.isNotEmpty) {
          parts.add(MarkdownContentPart(currentBuffer.toString().trim(), false));
          currentBuffer.clear();
        }
        inTable = true;
      } else if (!isTableLine && inTable) {
        parts.add(MarkdownContentPart(currentBuffer.toString().trim(), true));
        currentBuffer.clear();
        inTable = false;
      }

      currentBuffer.writeln(line);
    }

    if (currentBuffer.isNotEmpty) {
      parts.add(MarkdownContentPart(currentBuffer.toString().trim(), inTable));
    }

    return parts.where((p) => p.content.isNotEmpty).toList();
  }

  Widget _buildMarkdownWidget(String text, bool isDarkMode) {
    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
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
        h1: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: Colors.orange[700],
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        listBullet: TextStyle(color: Colors.orange[700]),
        listIndent: 16,
        blockSpacing: 12,
        tableHead: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        tableBody: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
        tableBorder: TableBorder.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
