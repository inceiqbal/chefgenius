import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'gemini_proxy_service.dart';
import 'notification_service.dart';
import '../data/models/recipe_model.dart';

/// Service untuk mengelola interaksi konsultasi chatbot
/// Mengintegrasikan sinkronisasi riwayat chat dengan Supabase dan proxy Gemini RAG.
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final _geminiProxy = GeminiProxyService();
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();

  final List<ChatMessage> _messages = [];
  Recipe? _currentRecipe;

  // Konfigurasi eksperimental Tugas Akhir
  String _ragMode = 'advanced';
  String _embeddingEngine = 'indobert';

  // Mode evaluasi terstandarisasi untuk eksperimen RAGAS
  bool _isEvaluationMode = false;
  UserContext? _standardizedContext;

  bool _isProcessingInBackground = false;
  String? _lastBackgroundResponse;

  bool get isProcessingInBackground => _isProcessingInBackground;
  String? get lastBackgroundResponse => _lastBackgroundResponse;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  Recipe? get currentRecipe => _currentRecipe;

  String get ragMode => _ragMode;
  set ragMode(String mode) {
    if (['none', 'naive', 'pre_retrieval', 'post_retrieval', 'advanced'].contains(mode)) {
      _ragMode = mode;
      debugPrint('ChatbotService: Mode RAG diubah ke $mode');
    }
  }

  String get embeddingEngine => _embeddingEngine;
  set embeddingEngine(String engine) {
    if (['gemini', 'indobert'].contains(engine)) {
      _embeddingEngine = engine;
      debugPrint('ChatbotService: Engine embedding diubah ke $engine');
    }
  }

  bool get isEvaluationMode => _isEvaluationMode;

  /// Mengaktifkan mode pengujian RAGAS dengan konteks terstandarisasi
  void enableEvaluationMode(UserContext standardizedContext) {
    _isEvaluationMode = true;
    _standardizedContext = standardizedContext;
    debugPrint('ChatbotService: Mode evaluasi aktif');
  }

  /// Menonaktifkan mode pengujian untuk kembali ke mode produksi
  void disableEvaluationMode() {
    _isEvaluationMode = false;
    _standardizedContext = null;
    debugPrint('ChatbotService: Mode evaluasi nonaktif');
  }

  Future<void> init() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(100);

      _messages.clear();
      for (var row in response) {
        _messages.add(ChatMessage(
          id: row['id'],
          text: row['message'],
          isUser: row['is_user'],
          timestamp: DateTime.parse(row['created_at']),
        ));
      }
    } catch (e) {
      debugPrint('ChatbotService: Inisialisasi riwayat chat gagal - $e');
    }
  }

  void setCurrentRecipe(Recipe? recipe) {
    _currentRecipe = recipe;
  }

  Future<void> _saveMessage(String text, bool isUser) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('chat_messages')
          .insert({
            'user_id': userId,
            'message': text,
            'is_user': isUser,
          })
          .select()
          .single();

      _messages.add(ChatMessage(
        id: response['id'],
        text: text,
        isUser: isUser,
        timestamp: DateTime.parse(response['created_at']),
      ));
    } catch (e) {
      debugPrint('ChatbotService: Gagal menyimpan pesan - $e');
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Mengirim pesan ke chatbot dan menerima respons secara streaming
  Stream<String> sendMessageStream(String userMessage) async* {
    if (userMessage.trim().isEmpty) return;

    await _saveMessage(userMessage, true);

    try {
      final UserContext context = (_isEvaluationMode && _standardizedContext != null)
          ? _standardizedContext!
          : await _getUserContext();

      final response = await _geminiProxy.sendChatMessage(
        userMessage: userMessage,
        pantryItems: context.pantryItems,
        dietPreferences: context.dietPreferences,
        allergies: context.allergies,
        recipeName: _currentRecipe?.title,
        recipeIngredients: _currentRecipe?.allIngredients.map((i) => i.name).toList(),
        recipeDescription: _currentRecipe?.description,
        ragMode: _ragMode,
        embeddingEngine: _embeddingEngine,
        isEvaluation: _isEvaluationMode,
      );

      if (response != null) {
        await _saveMessage(response, false);
        yield response;
      }
    } catch (e) {
      debugPrint('ChatbotService: Kendala pengiriman pesan - $e');
      yield 'Maaf, terjadi kesalahan saat memproses jawaban. Silakan coba kembali.';
    }
  }

  /// Menangani penyelesaian di latar belakang jika pengguna berpindah halaman
  Future<void> continueInBackground(String userMessage, String partialResponse) async {
    if (_isProcessingInBackground) return;

    _isProcessingInBackground = true;
    _lastBackgroundResponse = null;

    try {
      if (partialResponse.isNotEmpty) {
        _lastBackgroundResponse = partialResponse;
        await _notificationService.showChatbotCompletedNotification(
          preview: partialResponse.length > 50
              ? '${partialResponse.substring(0, 50)}...'
              : partialResponse,
        );
      }
    } catch (e) {
      debugPrint('ChatbotService: Notifikasi latar belakang gagal - $e');
    } finally {
      _isProcessingInBackground = false;
    }
  }

  void clearBackgroundState() {
    _lastBackgroundResponse = null;
    _notificationService.cancelChatbotNotification();
  }

  Future<String?> sendMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return null;

    await _saveMessage(userMessage, true);

    try {
      final UserContext context = (_isEvaluationMode && _standardizedContext != null)
          ? _standardizedContext!
          : await _getUserContext();

      final response = await _geminiProxy.sendChatMessage(
        userMessage: userMessage,
        pantryItems: context.pantryItems,
        dietPreferences: context.dietPreferences,
        allergies: context.allergies,
        recipeName: _currentRecipe?.title,
        recipeIngredients: _currentRecipe?.allIngredients.map((i) => i.name).toList(),
        recipeDescription: _currentRecipe?.description,
        ragMode: _ragMode,
        embeddingEngine: _embeddingEngine,
        isEvaluation: _isEvaluationMode,
      );

      if (response != null) {
        await _saveMessage(response, false);
        return response;
      }
      return null;
    } catch (e) {
      debugPrint('ChatbotService: Exception sendMessage - $e');
      return null;
    }
  }

  Future<UserContext> _getUserContext() async {
    List<String> pantryItems = [];
    try {
      final userEmail = _supabase.auth.currentUser?.email ?? 'guest';
      final boxName = 'pantry_$userEmail';
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<String>(boxName);
        pantryItems = box.values.map((item) {
          final parts = item.split('|');
          return parts[0];
        }).toList();
      }
    } catch (e) {
      debugPrint('ChatbotService: Gagal membaca pantry - $e');
    }

    List<String> dietPreferences = [];
    List<String> allergies = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final allDiets = prefs.getStringList('user_diet_preferences') ?? [];

      final allergyKeys = ['nut_allergy', 'seafood_allergy', 'dairy_allergy'];
      for (var diet in allDiets) {
        if (allergyKeys.contains(diet)) {
          allergies.add(_formatDietLabel(diet));
        } else {
          dietPreferences.add(_formatDietLabel(diet));
        }
      }
    } catch (e) {
      debugPrint('ChatbotService: Gagal membaca preferensi diet - $e');
    }

    return UserContext(
      pantryItems: pantryItems,
      dietPreferences: dietPreferences,
      allergies: allergies,
    );
  }

  String _formatDietLabel(String key) {
    switch (key) {
      case 'halal': return 'Halal';
      case 'vegetarian': return 'Vegetarian';
      case 'vegan': return 'Vegan';
      case 'keto': return 'Keto';
      case 'low_carb': return 'Low Carb';
      case 'gluten_free': return 'Gluten Free';
      case 'low_sugar': return 'Low Sugar (Diabetes)';
      case 'nut_allergy': return 'Alergi Kacang';
      case 'seafood_allergy': return 'Alergi Seafood';
      case 'dairy_allergy': return 'Alergi Susu/Laktosa';
      case 'no_onion': return 'Tanpa Bawang';
      default: return key.replaceAll('_', ' ');
    }
  }

  void clearSession() {
    _currentRecipe = null;
  }

  Future<void> deleteAllHistory() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('chat_messages')
            .delete()
            .eq('user_id', userId);
      }
      _messages.clear();
      _currentRecipe = null;
    } catch (e) {
      debugPrint('ChatbotService: Gagal menghapus riwayat - $e');
    }
  }
}

class ChatMessage {
  final String? id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class UserContext {
  final List<String> pantryItems;
  final List<String> dietPreferences;
  final List<String> allergies;

  UserContext({
    required this.pantryItems,
    required this.dietPreferences,
    required this.allergies,
  });
}
