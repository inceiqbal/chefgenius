# Security Configuration Guide

## 🔐 File Rahasia (Jangan Commit!)

File-file berikut berisi API keys dan credentials yang **TIDAK BOLEH** di-commit ke repository:

| File | Deskripsi | Template |
|------|-----------|----------|
| `dart_defines.json` | Supabase & Gemini API keys | `dart_defines.json.example` |
| `android/app/google-services.json` | Firebase configuration | `android/app/google-services.json.example` |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config | - |
| `*.jks`, `*.keystore` | Android signing keys | - |
| `key.properties` | Keystore passwords | - |

## 📋 Setup untuk Development

### 1. Copy Template Files

```bash
# Copy dan rename template files
cp dart_defines.json.example dart_defines.json
cp android/app/google-services.json.example android/app/google-services.json
```

### 2. Isi dengan Credentials Asli

Edit `dart_defines.json`:
```json
{
    "SUPABASE_URL": "https://your-actual-project.supabase.co",
    "SUPABASE_KEY": "your-actual-supabase-anon-key",
    "GEMINI_KEYS": "your-gemini-key-1,your-gemini-key-2"
}
```

### 3. Download google-services.json

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project ChefGenius
3. Project Settings → General → Download `google-services.json`
4. Letakkan di `android/app/google-services.json`

## 🚀 Build Commands

```bash
# Build dengan dart-define dari file
flutter build apk --dart-define-from-file=dart_defines.json

# Build untuk release
flutter build appbundle --dart-define-from-file=dart_defines.json
```

## ⚠️ Jika API Keys Terekspos

Jika API keys pernah ter-commit ke repository publik:

1. **Gemini API Keys**: Revoke di [Google AI Studio](https://aistudio.google.com/) → Get API Key → Delete & create new
2. **Firebase API Key**: Restrict di [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
3. **Supabase Anon Key**: Relatif aman (public key), tapi pastikan RLS (Row Level Security) aktif

## 🔒 Best Practices

- ✅ Selalu gunakan `.gitignore` untuk file sensitif
- ✅ Gunakan environment variables atau dart-define untuk inject secrets
- ✅ Simpan secrets di Supabase Edge Functions untuk server-side operations
- ✅ Aktifkan RLS di Supabase untuk proteksi database
- ❌ Jangan hardcode API keys di source code
- ❌ Jangan commit file credentials ke repository
