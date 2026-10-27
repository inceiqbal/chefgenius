import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service penghubung antara aplikasi mobile dengan Supabase Edge Function (`gemini-proxy`).
///
/// Mengelola pemanggilan model generatif Gemini dan pipeline RAG secara aman tanpa
/// mengekspos API Key pada sisi client. Dilengkapi manajemen timeout adaptif,
/// pelacakan ID request untuk idempotensi, serta mekanisme fallback koneksi.
class GeminiProxyService {
  static final GeminiProxyService _instance = GeminiProxyService._internal();
  factory GeminiProxyService() => _instance;
  GeminiProxyService._internal();

  final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const bool _pollingEnabled = false;

  /// Menentukan alokasi batas waktu adaptif berdasarkan kompleksitas arsitektur RAG.
  Duration _timeoutForRagMode(String ragMode) {
    switch (ragMode) {
      case 'advanced':
      case 'post_retrieval':
        return const Duration(seconds: 120);
      case 'pre_retrieval':
      case 'naive':
        return const Duration(seconds: 90);
      case 'none':
      default:
        return const Duration(seconds: 45);
    }
  }

  /// Membuat rekomendasi resep masakan berbasis Gemini
  Future<Map<String, dynamic>?> generateContent({
    required String prompt,
    String model = 'gemini-3-flash-preview',
    double temperature = 0.9,
    int maxTokens = 8192,
  }) async {
    return _callProxy('generate_recipe', {
      'prompt': prompt,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
    });
  }

  /// Menerjemahkan teks antar bahasa
  Future<String?> translate({
    required String text,
    required String targetLang,
  }) async {
    final result = await _callProxy('translate', {
      'text': text,
      'targetLang': targetLang,
    });

    if (result != null && result['candidates'] != null) {
      try {
        return result['candidates'][0]['content']['parts'][0]['text'];
      } catch (e) {
        debugPrint('GeminiProxy: Gagal mem-parsing translasi - $e');
        return null;
      }
    }
    return null;
  }

  /// Mengonversi teks ke audio (Text-to-Speech)
  Future<Map<String, dynamic>?> textToSpeech({
    required String text,
  }) async {
    return _callProxy('tts', {'text': text});
  }

  /// Identifikasi bahan pangan dari gambar visual
  Future<List<Map<String, String>>> scanIngredients({
    required Uint8List imageBytes,
    String? customPrompt,
  }) async {
    final base64Image = base64Encode(imageBytes);

    final result = await _callProxy('vision', {
      'imageBase64': base64Image,
      'prompt': customPrompt ?? '''
Identifikasi bahan makanan dan jumlahnya (jika terlihat) dalam gambar.
Aturan:
1. Kemasan -> Nama produk + jumlah jika ada label (misal: {"name": "Telur", "quantity": "10 butir"}).
2. Jika jumlah TIDAK terlihat, kosongkan quantity: {"name": "Garam", "quantity": ""}.
3. Output: JSON Array of Objects.
4. Format: [{"name": "Bahan", "quantity": "jumlah satuan or empty"}].
5. Contoh: [{"name": "Telur", "quantity": "10 butir"}, {"name": "Garam", "quantity": ""}].
6. NO TEXT LAIN.
''',
    });

    if (result != null && result['candidates'] != null) {
      try {
        final text = result['candidates'][0]['content']['parts'][0]['text'];
        final jsonString = text
            .toString()
            .replaceAll('```json\n', '')
            .replaceAll('\n```', '')
            .trim();
        final List<dynamic> items = jsonDecode(jsonString);
        return items
            .map((e) => {
                  'name': e['name'].toString(),
                  'quantity': e['quantity']?.toString() ?? '',
                })
            .toList();
      } catch (e) {
        debugPrint('GeminiProxy: Gagal mem-parsing hasil deteksi gambar - $e');
        return [];
      }
    }
    return [];
  }

  /// Mengirim pesan konsultasi ke Chatbot RAG
  Future<String?> sendChatMessage({
    required String userMessage,
    List<String> pantryItems = const [],
    List<String> dietPreferences = const [],
    List<String> allergies = const [],
    String? recipeName,
    List<String>? recipeIngredients,
    String? recipeDescription,
    String ragMode = 'advanced',
    String embeddingEngine = 'indobert',
    bool isEvaluation = false,
    String? clientRequestId,
  }) async {
    final result = await _callProxy(
      'chatbot',
      {
        'userMessage': userMessage,
        'rag_mode': ragMode,
        'embedding_engine': embeddingEngine,
        'contextData': {
          'pantryItems': pantryItems,
          'dietPreferences': dietPreferences,
          'allergies': allergies,
          if (recipeName != null)
            'currentRecipe': {
              'name': recipeName,
              'ingredients': recipeIngredients ?? [],
              'description': recipeDescription ?? '',
            },
        },
        'is_evaluation': isEvaluation,
      },
      clientRequestId: clientRequestId,
      timeout: _timeoutForRagMode(ragMode),
    );

    if (result == null) {
      debugPrint('GeminiProxy: Hasil chatbot null');
      return null;
    }

    if (result['result'] != null) {
      final text = result['result'] as String;
      final safetyFlag = result['safety_flag'] as bool? ?? false;
      final runId = result['run_id'] as String?;

      debugPrint('GeminiProxy: Respons diterima (run_id: $runId, safety_flag: $safetyFlag)');
      return text;
    }

    if (result['text'] != null) {
      return result['text'] as String;
    }

    if (result['error'] != null) {
      debugPrint('GeminiProxy: Error dari API - ${result['error']}');
      return null;
    }

    final candidates = result['candidates'];
    if (candidates != null && candidates is List && candidates.isNotEmpty) {
      try {
        final candidate = candidates[0];
        final finishReason = candidate['finishReason'];
        final content = candidate['content'];

        if (finishReason == 'MAX_TOKENS' &&
            (content == null || content.isEmpty || content['parts'] == null)) {
          return 'Maaf, jawaban terlalu panjang dan terpotong. Coba tanyakan dengan lebih spesifik ya! 😊';
        }

        if (content != null && content is Map) {
          final parts = content['parts'];
          if (parts != null && parts is List && parts.isNotEmpty) {
            final text = parts[0]['text'];
            if (text != null) {
              return text as String;
            }
          }
        }
      } catch (e) {
        debugPrint('GeminiProxy: Gagal mem-parsing candidate respons - $e');
        return null;
      }
    }

    debugPrint('GeminiProxy: Format respons tidak dikenali: $result');
    return null;
  }

  /// Eksekusi pemanggilan Edge Function dengan pelacakan requestId
  Future<Map<String, dynamic>?> _callProxy(
    String action,
    Map<String, dynamic> params, {
    String? clientRequestId,
    Duration timeout = _defaultTimeout,
  }) async {
    final requestId = clientRequestId ?? _uuid.v4();

    final body = {
      'action': action,
      'client_request_id': requestId,
      ...params,
    };

    try {
      debugPrint('GeminiProxy: Memanggil Edge Function ($action) [reqId: $requestId]');

      final response = await _supabase.functions
          .invoke('gemini-proxy', body: body)
          .timeout(timeout);

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint('GeminiProxy: Status error ${response.status} - ${response.data}');
        return null;
      }
    } on FunctionException catch (e) {
      debugPrint('GeminiProxy: FunctionException status ${e.status} - ${e.details}');

      if (e.status == 401) {
        return _callProxyDirectHttp(action, params, requestId, timeout);
      }
      return null;
    } on TimeoutException {
      debugPrint('GeminiProxy: Timeout setelah ${timeout.inSeconds}s untuk "$action" [reqId: $requestId]');

      if (!_pollingEnabled) {
        return null;
      }
      return _pollForResult(requestId);
    } catch (e) {
      debugPrint('GeminiProxy: Exception - $e');
      return null;
    }
  }

  /// Memeriksa status request pada server secara asinkron
  Future<Map<String, dynamic>?> _pollForResult(
    String requestId, {
    int maxAttempts = 6,
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await Future.delayed(pollInterval);

      try {
        final response = await _supabase.functions.invoke(
          'gemini-proxy',
          body: {
            'action': 'check_status',
            'client_request_id': requestId,
          },
        ).timeout(const Duration(seconds: 10));

        if (response.status == 200) {
          final data = response.data as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'completed') {
            return data;
          } else if (status == 'not_found') {
            return null;
          }
        }
      } catch (e) {
        debugPrint('GeminiProxy: Polling gagal pada iterasi $attempt: $e');
      }
    }

    return null;
  }

  /// Fallback direct HTTP invocation jika gateway mengembalikan 401
  Future<Map<String, dynamic>?> _callProxyDirectHttp(
    String action,
    Map<String, dynamic> params,
    String requestId,
    Duration timeout,
  ) async {
    try {
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
      final baseUrl = supabaseUrl.isNotEmpty
          ? supabaseUrl
          : 'https://zfiyfhmsuhitytsuioml.supabase.co';
      final targetUrl = Uri.parse('$baseUrl/functions/v1/gemini-proxy');
      final anonKey = supabaseKey.isNotEmpty
          ? supabaseKey
          : (_supabase.headers['apikey'] ?? '');

      final httpResponse = await http
          .post(
            targetUrl,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
            },
            body: jsonEncode({
              'action': action,
              'client_request_id': requestId,
              ...params,
            }),
          )
          .timeout(timeout);

      if (httpResponse.statusCode == 200) {
        return jsonDecode(httpResponse.body) as Map<String, dynamic>;
      } else {
        debugPrint('GeminiProxy: Fallback HTTP status ${httpResponse.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('GeminiProxy: Fallback HTTP timeout [reqId: $requestId]');
      return null;
    } catch (httpErr) {
      debugPrint('GeminiProxy: Fallback HTTP exception - $httpErr');
      return null;
    }
  }
}