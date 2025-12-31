# Setup Gemini Proxy Edge Function

## 🔒 Kenapa Perlu Ini?
API Key Gemini akan tersimpan di **server Supabase**, bukan di APK. Client tidak bisa melihatnya!

---

## 📋 Langkah-langkah Deploy

### 1. Set Secret di Supabase
```bash
# Login ke Supabase CLI dulu
supabase login

# Link ke project kamu
supabase link --project-ref zfiyfhmsuhitytsuioml

# Set Gemini API Key sebagai secret
supabase secrets set GEMINI_API_KEY=YOUR_GEMINI_KEY_HERE
```

### 2. Deploy Function
```bash
cd d:\chefgenius\Mobile\chefgenius_mobile

# Deploy gemini-proxy function
supabase functions deploy gemini-proxy
```

### 3. Aktifkan Proxy di Flutter

Buka file `lib/app/services/gemini_proxy_service.dart` dan ubah:

```dart
// SEBELUM (development)
static const bool useProxy = false;

// SESUDAH (production)
static const bool useProxy = true;
```

### 4. Build APK dengan Flag Minimal
```bash
# Sekarang kamu TIDAK perlu --dart-define untuk GEMINI key!
flutter build appbundle --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
```

---

## 📱 Cara Pakai di Flutter

### Service Sudah Dibuat: `GeminiProxyService`

```dart
import '../app/services/gemini_proxy_service.dart';

// Generate Recipe
final result = await GeminiProxyService().generateContent(
  prompt: 'Buat resep nasi goreng',
  model: 'gemini-2.0-flash',
);

// Translate
final translated = await GeminiProxyService().translate(
  text: 'Hello world',
  targetLang: 'id',
);

// TTS
final audio = await GeminiProxyService().textToSpeech(
  text: 'Selamat datang di Chef Genius',
);
```

---

## ⚡ Actions yang Tersedia

| Action | Parameter | Deskripsi |
|--------|-----------|-----------|
| `generate_recipe` | `prompt`, `model` | Generate resep dengan AI |
| `translate` | `text`, `targetLang` | Terjemahkan teks |
| `tts` | `text` | Text-to-speech |

---

## ✅ Keuntungan

1. **API Key 100% Hidden** - Tidak ada di APK
2. **Toggle Mudah** - Ubah `useProxy = true/false` sesuai kebutuhan
3. **Backward Compatible** - Kode existing tetap jalan
4. **Easy Rotation** - Ganti key tanpa update app
