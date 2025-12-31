import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service untuk memanggil Gemini API via Edge Function (aman)
/// API Key tersimpan di server, tidak ada di client/APK
class GeminiProxyService {
  static final GeminiProxyService _instance = GeminiProxyService._internal();
  factory GeminiProxyService() => _instance;
  GeminiProxyService._internal();

  final _supabase = Supabase.instance.client;

  /// Generate recipe via proxy
  Future<Map<String, dynamic>?> generateContent({
    required String prompt,
    String model = 'gemini-2.5-flash-preview-09-2025',
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

  /// Translate text via proxy
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
        debugPrint('❌ GeminiProxy: Failed to parse translate response - $e');
        return null;
      }
    }
    return null;
  }

  /// TTS via proxy
  Future<Map<String, dynamic>?> textToSpeech({
    required String text,
  }) async {
    return _callProxy('tts', {'text': text});
  }

  /// Vision (scan ingredients from image) via proxy
  Future<List<String>> scanIngredients({
    required Uint8List imageBytes,
    String? customPrompt,
  }) async {
    final base64Image = base64Encode(imageBytes);
    
    final result = await _callProxy('vision', {
      'imageBase64': base64Image,
      'prompt': customPrompt ?? '''
Identifikasi bahan makanan utama dalam gambar.
Aturan:
1. Kemasan -> Nama jenis produk (misal: 'Kecap', 'Susu').
2. JANGAN sebut komposisi.
3. Output: JSON Array String Bahasa Indonesia.
4. Contoh: ["Telur", "Tahu"].
5. NO TEXT LAIN.
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
        return items.map((e) => e.toString()).toList();
      } catch (e) {
        debugPrint('❌ GeminiProxy: Failed to parse vision response - $e');
        return [];
      }
    }
    return [];
  }

  /// Call Gemini via Supabase Edge Function
  Future<Map<String, dynamic>?> _callProxy(String action, Map<String, dynamic> params) async {
    try {
      debugPrint('🔒 GeminiProxy: Calling via Edge Function ($action)');
      
      final response = await _supabase.functions.invoke(
        'gemini-proxy',
        body: {
          'action': action,
          ...params,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        debugPrint('❌ GeminiProxy: Error ${response.status} - ${response.data}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ GeminiProxy: Exception - $e');
      return null;
    }
  }
}
