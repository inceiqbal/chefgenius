import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../app/services/chatbot_service.dart';

class MarkdownContentPart {
  final String content;
  final bool isTable;

  MarkdownContentPart(this.content, this.isTable);
}

/// Helper class to reconstruct clean line breaks, list numbering, and paragraphs
/// from Flutter's SelectionArea SelectedContent (which strips line breaks between widgets).
class ChatTextFormatter {
  static List<({String clean, bool isListItem, bool isHeader})> parseMarkdownLines(String md) {
    final lines = md.split('\n');
    final parsed = <({String clean, bool isListItem, bool isHeader})>[];

    for (final l in lines) {
      final stripped = l.trim();
      if (stripped.isEmpty) continue;

      final isHeader = RegExp(r'^#{1,6}\s*').hasMatch(stripped);
      final isList = RegExp(r'^(?:\d{1,2}\.|\*|-)\s*').hasMatch(stripped);

      // Clean markdown tokens
      String clean = stripped.replaceAll(RegExp(r'^(?:#{1,6}\s*|\s*[*+-]\s*)'), '');
      clean = clean.replaceAllMapped(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), (m) => m[1]!);
      clean = clean.replaceAllMapped(RegExp(r'_{1,3}([^_]+)_{1,3}'), (m) => m[1]!).trim();

      if (clean.isNotEmpty) {
        parsed.add((clean: clean, isListItem: isList, isHeader: isHeader));
      }
    }
    return parsed;
  }

  static String formatSelection(String rawSelected, String originalMarkdown) {
    if (rawSelected.trim().isEmpty) return rawSelected;

    final parsedLines = parseMarkdownLines(originalMarkdown);
    String result = rawSelected;

    // Restore line breaks based on the line beginnings from the original content
    for (final item in parsedLines) {
      final sep = item.isListItem ? '\n' : '\n\n';
      final clean = item.clean;

      for (final length in [40, 30, 20, 14, 10]) {
        final prefix = clean.length <= length ? clean : clean.substring(0, length);
        final prefixNoSpace = prefix.replaceFirst(RegExp(r'^(\d{1,2}\.)\s+'), r'$1');

        for (final candidate in [prefix, prefixNoSpace]) {
          if (candidate.length >= 5 && result.contains(candidate)) {
            int idx = 0;
            while (true) {
              idx = result.indexOf(candidate, idx);
              if (idx == -1) break;

              if (idx > 0 && result[idx - 1] != '\n') {
                result = '${result.substring(0, idx)}$sep${result.substring(idx)}';
                idx += candidate.length + sep.length;
              } else {
                idx += candidate.length;
              }
            }
          }
        }
      }
    }

    // Fix missing spaces after list numbering: e.g. '1.PNPK' -> '1. PNPK'
    result = result.replaceAllMapped(
      RegExp(r'(^|\n)(\d{1,2})\.([^\s\d])'),
      (m) => '${m[1]}${m[2]}. ${m[3]}',
    );

    // Fallback: if numbered items glued to preceding text e.g. ')2.Perkeni'
    result = result.replaceAllMapped(
      RegExp(r'([^\n\d])(\d{1,2})\.\s*([A-Za-z])'),
      (m) => '${m[1]}\n${m[2]}. ${m[3]}',
    );

    // Normalize excessive newlines (max 2 consecutive)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    final lines = result.split('\n').map((l) => l.trimRight()).toList();
    return lines.join('\n').trim();
  }
}

/// A wrapper around SelectionArea that intercepts copy actions and reconstructs
/// proper newlines and list formatting.
class _SelectableChatBubble extends StatefulWidget {
  final String originalText;
  final Widget child;
  final void Function(String text, {String successMessage}) onCopy;

  const _SelectableChatBubble({
    required this.originalText,
    required this.child,
    required this.onCopy,
  });

  @override
  State<_SelectableChatBubble> createState() => _SelectableChatBubbleState();
}

class _SelectableChatBubbleState extends State<_SelectableChatBubble> {
  String _selectedText = '';

  void _handleCopy(String rawText) {
    if (rawText.isEmpty) return;
    final formatted = ChatTextFormatter.formatSelection(rawText, widget.originalText);
    Clipboard.setData(ClipboardData(text: formatted));
    widget.onCopy(formatted, successMessage: 'Teks terpilih berhasil disalin');
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
          onInvoke: (CopySelectionTextIntent intent) {
            if (_selectedText.isNotEmpty) {
              _handleCopy(_selectedText);
            }
            return null;
          },
        ),
      },
      child: SelectionArea(
        onSelectionChanged: (SelectedContent? content) {
          _selectedText = content?.plainText ?? '';
        },
        contextMenuBuilder: (context, selectableRegionState) {
          final buttonItems = List<ContextMenuButtonItem>.from(
            selectableRegionState.contextMenuButtonItems,
          );
          final copyIndex = buttonItems.indexWhere((item) => item.type == ContextMenuButtonType.copy);
          if (copyIndex != -1) {
            final orig = buttonItems[copyIndex];
            buttonItems[copyIndex] = ContextMenuButtonItem(
              type: ContextMenuButtonType.copy,
              label: orig.label,
              onPressed: () {
                selectableRegionState.hideToolbar();
                if (_selectedText.isNotEmpty) {
                  _handleCopy(_selectedText);
                }
              },
            );
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
        child: widget.child,
      ),
    );
  }
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

  String _sanitizeText(String text) {
    var sanitized = text
        .replaceAll('(Mode: post_retrieval)', '(Mode: Post-Retrieval)')
        .replaceAll('(Mode: pre_retrieval)', '(Mode: Pre-Retrieval)')
        .replaceAll('(Mode: naive)', '(Mode: Naive RAG)')
        .replaceAll('(Mode: advanced)', '(Mode: Full Advanced RAG)')
        .replaceAll('(Mode: none)', '(Mode: Baseline)')
        .replaceAll('(Mode: Pure LLM (Tanpa RAG))', '(Mode: Baseline)');

    // Ensure RAG footer only mentions the pdf filename once (removes duplicate title before source:)
    // e.g. "1. Title source: Title.pdf (chunk: 46)" -> "1. Title.pdf (chunk: 46)"
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(^|\n)(\d+\.\s*)[^\n]+?\s+source:\s*([^\n]+\.pdf\s*\(chunk:\s*\d+\))'),
      (m) => '${m[1]}${m[2]}${m[3]}',
    );

    return sanitized;
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final sanitizedText = isUser ? message.text : _sanitizeText(message.text);

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
                        _SelectableChatBubble(
                          originalText: sanitizedText,
                          onCopy: onCopy,
                          child: Text(
                            message.text,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => onCopy(
                              sanitizedText,
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
                        _SelectableChatBubble(
                          originalText: sanitizedText,
                          onCopy: onCopy,
                          child: _buildMarkdownContent(sanitizedText, isDarkMode),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => onCopy(
                              sanitizedText,
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

  Widget _buildMarkdownContent(String sanitizedText, bool isDarkMode) {
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
      selectable: false,
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
