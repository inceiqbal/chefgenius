import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Buat debugPrint
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../app/config/gemini_config.dart';

class GeminiTtsService {
  // Singleton pattern biar hemat resource
  static final GeminiTtsService _instance = GeminiTtsService._internal();
  factory GeminiTtsService() => _instance;
  GeminiTtsService._internal();

  // HAPUS YANG LAMA (YANG CUMA 1 KEY)
  // static const String _apiKey = ...

  // Cache sederhana di memori service
  final Map<String, String> _pathCache = {};

  /// Fungsi utama: Minta file audio berdasarkan teks langkah & index
  Future<String> getAudioFile({
    required String stepTextRaw,
    required int stepIndex,
    required String recipeId, 
  }) async {
    // Kunci unik buat cache map & nama file
    // Format: idResep_step_nomorStep (Contoh: 123_step_0)
    final String uniqueKey = "${recipeId}_step_$stepIndex";

    // 1. Cek Cache Memory (RAM)
    if (_pathCache.containsKey(uniqueKey)) {
      final cachedPath = _pathCache[uniqueKey]!;
      final file = File(cachedPath);
      if (await file.exists()) {
        debugPrint("🔊 GeminiTtsService: Pake file cache RAM -> $cachedPath");
        return cachedPath;
      } else {
        _pathCache.remove(uniqueKey); // Hapus record hantu kalau file fisiknya ilang
      }
    }

    // 2. Cek Cache Fisik (Storage HP) - "Simpan Jangan Buang"
    // Pake getApplicationDocumentsDirectory biar lebih awet dari temporary
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/tts_$uniqueKey.wav';
    final file = File(filePath);

    if (await file.exists()) {
      debugPrint("🔊 GeminiTtsService: Pake file cache HP -> $filePath");
      _pathCache[uniqueKey] = filePath; // Masukin ke RAM biar next lebih cepet
      return filePath;
    }

    // 3. Validasi API Key (PAKE ROTASI DARI CONFIG)
    final apiKey = GeminiConfig.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('API Key Gemini belum diset di gemini_config.dart!');
    }

    // 4. Proses Teks (Smart Language Logic)
    final isEnglish = _isStepEnglish(stepTextRaw);
    final directive = isEnglish ? "Say in English: " : "Say in Indonesian: ";
    final prefix = isEnglish ? "Step ${stepIndex + 1}. " : "Langkah ${stepIndex + 1}. ";
    // Bersihin karakter aneh biar AI gak bingung
    final cleanText = stepTextRaw.replaceAll(RegExp(r'[*#]'), '');
    final textToSpeak = "$directive$prefix$cleanText";

    debugPrint("🔊 GeminiTtsService: Requesting AI -> '$textToSpeak'");

    // 5. Hit API (Lazy Loading - Cuma dipanggil kalo file belum ada)
    // PAKE KEY DARI VARIABLE apiKey (YANG UDAH ROTASI)
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$apiKey');

    final payload = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": textToSpeak}
          ]
        }
      ],
      "generationConfig": {
        "responseModalities": ["AUDIO"],
        "speechConfig": {
          "voiceConfig": {
            "prebuiltVoiceConfig": {"voiceName": "Aoede"} // Cewek Kalem
          }
        }
      },
      "model": "gemini-2.5-flash-preview-tts"
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: payload,
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      
      if (result['candidates'] == null || result['candidates'].isEmpty) {
        throw Exception('Response API kosong/berubah struktur.');
      }
      final audioContent = result['candidates'][0]['content'];
      if (audioContent == null || audioContent['parts'] == null) {
        throw Exception('Part audio tidak ditemukan.');
      }

      // Decode Audio
      final audioData = audioContent['parts'][0]['inlineData']['data'];
      final mimeType = audioContent['parts'][0]['inlineData']['mimeType'];
      final sampleRate = int.tryParse(mimeType.split('rate=')[1]) ?? 24000;
      final pcmData = base64Decode(audioData);

      // 6. Simpan ke File WAV (Write Cache)
      await _createWavFile(file, pcmData, sampleRate);
      
      // Simpan path ke memory cache
      _pathCache[uniqueKey] = file.path;
      
      return file.path;
    } else {
      throw Exception('Gagal TTS API (${response.statusCode}): ${response.body}');
    }
  }

  // --- Private Helper Methods (Tetap Sama) ---

  bool _isStepEnglish(String stepText) {
    final lowerText = stepText.toLowerCase();
    final englishKeywords = [
      ' the ', ' and ', ' to ', ' of ', ' in ', ' with ', ' for ', 
      ' add ', ' mix ', ' cook ', ' boil ', ' fry ', ' heat ', ' cut ',
      ' stir ', ' serve ', ' minutes ', ' until ', ' salt ', ' pepper ',
      ' bake ', ' roast ', ' chop ', ' slice ', ' peel ', ' grate ',
      ' pour ', ' whisk ', ' preheat ', ' season ', ' garnish '
    ];
    for (var word in englishKeywords) {
      if (lowerText.contains(word)) return true;
    }
    return false;
  }

  // Update: Nerima File object langsung biar efisien
  Future<void> _createWavFile(File file, Uint8List pcmData, int sampleRate) async {
    final dataLength = pcmData.length;
    final header = _buildWavHeader(dataLength, sampleRate, 1, 16);

    final fileBytes = BytesBuilder();
    fileBytes.add(header.buffer.asUint8List());
    fileBytes.add(pcmData);

    await file.writeAsBytes(fileBytes.toBytes(), flush: true);
  }

  ByteData _buildWavHeader(
      int dataLength, int sampleRate, int numChannels, int bitsPerSample) {
    final totalLength = dataLength + 44;
    final byteRate = (sampleRate * numChannels * bitsPerSample) ~/ 8;
    final blockAlign = (numChannels * bitsPerSample) ~/ 8;
    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, totalLength - 8, Endian.little);
    // WAVE
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataLength, Endian.little);
    return header;
  }
}