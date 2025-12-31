import 'package:flutter/foundation.dart';
import 'gemini_proxy_service.dart';

class TranslationService {
  // Singleton pattern
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Cache terjemahan di memory (key = "$text|$targetLang")
  final Map<String, String> _cache = {};

  /// Deteksi apakah teks kemungkinan berbahasa Indonesia
  bool isLikelyIndonesian(String text) {
    final lowerText = text.toLowerCase();
    
    // Kata-kata khas Indonesia yang jarang ada di bahasa lain
    final indonesianKeywords = [
      ' yang ', ' untuk ', ' dengan ', ' dari ', ' akan ', ' dalam ',
      ' karena ', ' saja ', ' bisa ', ' juga ', ' sudah ', ' belum ',
      ' tidak ', ' ada ', ' ini ', ' itu ', ' sudah ', ' jadi ',
      ' seperti ', ' hanya ', ' sangat ', ' lebih ', ' kalau ', ' kalian ',
      ' aku ', ' kamu ', ' gue ', ' gw ', ' lo ', ' lu ', ' nih ', ' nya ',
      ' banget ', ' dong ', ' sih ', ' deh ', ' lho ', ' wkwk ', ' hehe ',
      ' mantap ', ' keren ', ' enak ', ' sedap ', ' lezat ', 
      ' masak ', ' goreng ', ' rebus ', ' kukus ', ' tumis ',
    ];
    
    for (var word in indonesianKeywords) {
      if (lowerText.contains(word)) return true;
    }
    
    // Cek suffix kata Indonesia yang khas
    if (lowerText.contains('nya') || 
        lowerText.contains('kan') || 
        lowerText.contains('lah') ||
        lowerText.contains('kah')) {
      return true;
    }
    
    return false;
  }

  /// Deteksi apakah teks kemungkinan berbahasa Inggris
  bool isLikelyEnglish(String text) {
    final lowerText = text.toLowerCase();
    
    final englishKeywords = [
      ' the ', ' and ', ' to ', ' of ', ' in ', ' is ', ' it ',
      ' for ', ' with ', ' this ', ' that ', ' are ', ' was ',
      ' have ', ' has ', ' will ', ' would ', ' could ', ' should ',
      ' you ', ' your ', ' they ', ' their ', ' we ', ' our ',
      ' very ', ' really ', ' just ', ' only ', ' also ', ' too ',
      ' cook ', ' add ', ' mix ', ' stir ', ' heat ', ' serve ',
      ' delicious ', ' tasty ', ' yummy ', ' love ', ' like ',
      ' amazing ', ' great ', ' good ', ' nice ', ' awesome ',
    ];
    
    for (var word in englishKeywords) {
      if (lowerText.contains(word)) return true;
    }
    
    return false;
  }

  /// Cek apakah teks perlu diterjemahkan berdasarkan bahasa aplikasi
  /// Akan return true jika bahasa teks berbeda dengan bahasa aplikasi
  bool needsTranslation(String text, String appLanguage) {
    if (text.trim().length < 10) return false; // Terlalu pendek
    
    final isIndonesian = isLikelyIndonesian(text);
    final isEnglish = isLikelyEnglish(text);
    
    // Jika app bahasa Indonesia tapi teks bahasa Inggris -> perlu translate
    if (appLanguage == 'id' && isEnglish && !isIndonesian) {
      return true;
    }
    
    // Jika app bahasa Inggris tapi teks bahasa Indonesia -> perlu translate
    if (appLanguage == 'en' && isIndonesian && !isEnglish) {
      return true;
    }
    
    return false;
  }

  /// Terjemahkan teks ke bahasa target menggunakan Gemini API via Proxy
  Future<String?> translate({
    required String text,
    required String targetLanguage, // 'id' atau 'en'
    int maxRetries = 3,
  }) async {
    if (text.trim().isEmpty) return null;
    
    // 1. Check cache
    final cacheKey = '${text.hashCode}|$targetLanguage';
    if (_cache.containsKey(cacheKey)) {
      debugPrint('🌐 TranslationService: Cache hit');
      return _cache[cacheKey];
    }
    
    // 2. Call via proxy (with retry)
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint('🌐 TranslationService: Translating via proxy (attempt ${attempt + 1})...');
        
        final result = await GeminiProxyService().translate(
          text: text,
          targetLang: targetLanguage,
        );
        
        if (result != null && result.isNotEmpty) {
          // Cache result
          _cache[cacheKey] = result;
          debugPrint('✅ TranslationService: Translation successful');
          return result;
        }
        
        // If failed, wait before retry
        if (attempt < maxRetries - 1) {
          final waitSeconds = (attempt + 1) * 2;
          debugPrint('⚠️ TranslationService: Retrying in ${waitSeconds}s...');
          await Future.delayed(Duration(seconds: waitSeconds));
        }
      } catch (e) {
        debugPrint('❌ TranslationService: Error - $e');
        if (attempt == maxRetries - 1) return null;
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }
    
    return null;
  }

  /// Clear cache (if needed)
  void clearCache() {
    _cache.clear();
  }
}
