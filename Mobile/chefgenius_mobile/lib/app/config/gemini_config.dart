import 'dart:math';

class GeminiConfig {
  // Kita bikin getter biar dinamis setiap kali dipanggil
  static String get apiKey {
    // 1. Coba ambil string panjang dari terminal (param: GEMINI_KEYS)
    // Contoh input terminal: --dart-define=GEMINI_KEYS="key1,key2,key3"
    const allKeysString = String.fromEnvironment('GEMINI_KEYS', defaultValue: '');

    // 2. Kalau kosong, coba ambil cara lama (single key) buat fallback
    if (allKeysString.isEmpty) {
       const singleKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
       if (singleKey.isEmpty) {
         // Balikin string kosong biar nanti di-handle error-nya di UI
         return '';
       }
       return singleKey;
    }

    // 3. Pecah string panjang tadi berdasarkan KOMA (,)
    final List<String> keys = allKeysString.split(',');

    // 4. Bersihin spasi (trim) & Pilih satu secara ACAK
    if (keys.isNotEmpty) {
      final randomKey = keys[Random().nextInt(keys.length)].trim();
      return randomKey;
    }

    return '';
  }
}