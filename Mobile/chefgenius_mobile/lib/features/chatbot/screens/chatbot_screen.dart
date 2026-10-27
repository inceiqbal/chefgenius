import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/services/chatbot_service.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/widgets/modern_alert_dialog.dart';
import '../widgets/architecture_selector_popover.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/recipe_context_card.dart';
import '../widgets/streaming_message_bubble.dart';

/// Halaman antarmuka percakapan konsultasi gizi penyakit metabolik
class ChatbotScreen extends StatefulWidget {
  final Recipe? initialRecipe;

  const ChatbotScreen({super.key, this.initialRecipe});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatbotService _chatbotService = ChatbotService();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  String _currentBotResponse = '';
  String _currentUserMessage = '';
  bool _isStreaming = false;
  StreamSubscription<String>? _streamSubscription;
  final GlobalKey _headerSelectorKey = GlobalKey();

  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initChatbot();
  }

  Future<void> _initChatbot() async {
    _chatbotService.clearBackgroundState();

    if (widget.initialRecipe != null) {
      _chatbotService.setCurrentRecipe(widget.initialRecipe);
    }
    await _chatbotService.init();
    if (mounted) {
      setState(() => _isInitialized = true);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    if (_isStreaming && _currentUserMessage.isNotEmpty) {
      _chatbotService.continueInBackground(
        _currentUserMessage,
        _currentBotResponse,
      );
    }

    _streamSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading || _isStreaming) return;

    final isOffline = context.read<ConnectivityProvider>().isOffline;
    if (isOffline) {
      setState(() => _errorMessage = 'Tidak ada koneksi internet');
      return;
    }

    setState(() {
      _isLoading = true;
      _isStreaming = true;
      _errorMessage = null;
      _currentBotResponse = '';
      _currentUserMessage = message;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      _streamSubscription = _chatbotService.sendMessageStream(message).listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _currentBotResponse = chunk;
            });
            _scrollToBottom();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Terjadi kesalahan: $error';
              _isLoading = false;
              _isStreaming = false;
              _currentUserMessage = '';
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isStreaming = false;
              _currentBotResponse = '';
              _currentUserMessage = '';
            });
            _scrollToBottom();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengirim pesan: $e';
          _isLoading = false;
          _isStreaming = false;
          _currentUserMessage = '';
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearHistory() async {
    final confirm = await ModernAlertDialog.showConfirmation(
      context: context,
      title: 'Hapus Riwayat?',
      message: 'Semua percakapan akan dihapus permanen.',
      icon: Icons.delete_forever_rounded,
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
    );
    if (confirm == true) {
      await _chatbotService.deleteAllHistory();
      if (mounted) setState(() {});
    }
  }

  Future<void> _copyMessage(String text, {String successMessage = 'Pesan berhasil disalin'}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openArchitectureSelector() {
    showArchitectureSelectorPopover(
      context: context,
      headerKey: _headerSelectorKey,
      chatbotService: _chatbotService,
      onConfigurationChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final messages = _chatbotService.messages;

    return PopScope(
      canPop: !_isStreaming && !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_isStreaming || _isLoading)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Mohon tunggu, asisten nutrisi sedang merespon...'),
                ],
              ),
              backgroundColor: Colors.orange[700],
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildModernAppBar(lang, messages.isNotEmpty, isDarkMode),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F0F1A)]
                  : [const Color(0xFFFFF8F0), const Color(0xFFFFECD9), const Color(0xFFFFF5EB)],
            ),
          ),
          child: !_isInitialized
              ? _buildLoadingState()
              : SafeArea(
                  child: Column(
                    children: [
                      _buildDisclaimerBanner(lang, isDarkMode),
                      Expanded(
                        child: messages.isEmpty && !_isStreaming && widget.initialRecipe == null
                            ? _buildEmptyState(lang, isDarkMode)
                            : _buildChatList(messages, isDarkMode),
                      ),
                      if (_errorMessage != null) _buildErrorBanner(),
                      _buildModernInputArea(lang, isDarkMode),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(LanguageProvider lang, bool hasMessages, bool isDarkMode) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.1)]
                    : [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.3)],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: (_isStreaming || _isLoading)
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange[400],
                  ),
                )
              : Icon(Icons.arrow_back_ios_new, size: 18, color: isDarkMode ? Colors.white : Colors.black87),
        ),
        onPressed: (_isStreaming || _isLoading) ? null : () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🥗', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            key: _headerSelectorKey,
            behavior: HitTestBehavior.opaque,
            onTap: _openArchitectureSelector,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Konsultasi Nutrisi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (_chatbotService.ragMode == 'advanced'
                                ? const Color(0xFF6366F1)
                                : _chatbotService.ragMode == 'post_retrieval'
                                    ? const Color(0xFFD97706)
                                    : _chatbotService.ragMode == 'pre_retrieval'
                                        ? const Color(0xFF0D9488)
                                        : _chatbotService.ragMode == 'naive'
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF64748B))
                            .withValues(alpha: isDarkMode ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_chatbotService.ragMode == 'advanced'
                                  ? const Color(0xFF6366F1)
                                  : _chatbotService.ragMode == 'post_retrieval'
                                      ? const Color(0xFFD97706)
                                      : _chatbotService.ragMode == 'pre_retrieval'
                                          ? const Color(0xFF0D9488)
                                          : _chatbotService.ragMode == 'naive'
                                              ? const Color(0xFF0284C7)
                                              : const Color(0xFF64748B))
                              .withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _chatbotService.ragMode == 'advanced'
                            ? 'ADVANCED'
                            : _chatbotService.ragMode == 'post_retrieval'
                                ? 'POST-RETR'
                                : _chatbotService.ragMode == 'pre_retrieval'
                                    ? 'PRE-RETR'
                                    : _chatbotService.ragMode == 'naive'
                                        ? 'NAIVE'
                                        : 'PURE LLM',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: _chatbotService.ragMode == 'advanced'
                              ? const Color(0xFF818CF8)
                              : _chatbotService.ragMode == 'post_retrieval'
                                  ? const Color(0xFFF59E0B)
                                  : _chatbotService.ragMode == 'pre_retrieval'
                                      ? const Color(0xFF2DD4BF)
                                      : _chatbotService.ragMode == 'naive'
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    if (_chatbotService.ragMode != 'none') ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_chatbotService.embeddingEngine == 'indobert'
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF0D9488))
                              .withValues(alpha: isDarkMode ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (_chatbotService.embeddingEngine == 'indobert'
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF0D9488))
                                .withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _chatbotService.embeddingEngine == 'indobert' ? 'INDOBERT' : 'GEMINI',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: _chatbotService.embeddingEngine == 'indobert'
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF2DD4BF),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 14,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ahli Gizi Online',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (hasMessages)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.delete_outline, size: 20, color: Colors.red[400]),
            ),
            onPressed: _clearHistory,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text('🥗', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            'Memuat Asisten Nutrisi...',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner(LanguageProvider lang, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety_outlined, color: Colors.orange, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.getText('chatbot_disclaimer'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkMode ? Colors.orange[200] : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Riwayat chat akan otomatis dihapus setelah 7 hari',
                style: TextStyle(
                  fontSize: 9,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<ChatMessage> messages, bool isDarkMode) {
    final itemCount = messages.length +
        (_isStreaming ? 1 : 0) +
        (widget.initialRecipe != null ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (widget.initialRecipe != null && index == 0) {
          return RecipeContextCard(
            recipe: widget.initialRecipe!,
            isDarkMode: isDarkMode,
          );
        }

        final adjustedIndex = widget.initialRecipe != null ? index - 1 : index;

        if (_isStreaming && adjustedIndex == messages.length) {
          return StreamingMessageBubble(
            responseText: _currentBotResponse,
            typingAnimController: _typingAnimController,
            isDarkMode: isDarkMode,
          );
        }

        if (adjustedIndex >= 0 && adjustedIndex < messages.length) {
          return ChatMessageBubble(
            message: messages[adjustedIndex],
            isDarkMode: isDarkMode,
            onCopy: _copyMessage,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(LanguageProvider lang, bool isDarkMode) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [Colors.orange.shade800, Colors.deepOrange.shade800]
                      : [Colors.orange.shade100, Colors.deepOrange.shade100],
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Text('🥗', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 24),
            Text(
              'Konsultasi Nutrisi Metabolik',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asisten Nutrisi Berbasis Pedoman Kemenkes RI',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _buildSuggestionChips(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDarkMode) {
    final suggestions = [
      '🥗 Makanan untuk diabetes',
      '💪 Tinggi protein',
      '🔥 Rendah kalori',
      '❤️ Sehat jantung',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((text) {
        return GestureDetector(
          onTap: () {
            _messageController.text = text.substring(2).trim();
            _sendMessage();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: Colors.red, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInputArea(LanguageProvider lang, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A3E) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Tanya seputar gizi & nutrisi...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                ),
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading && !_isStreaming,
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (_isLoading || _isStreaming) ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: (_isLoading || _isStreaming)
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      ),
                color: (_isLoading || _isStreaming) ? Colors.grey[300] : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.send_rounded,
                color: (_isLoading || _isStreaming) ? Colors.grey : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
