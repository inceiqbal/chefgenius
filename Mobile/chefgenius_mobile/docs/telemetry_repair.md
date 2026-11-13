# Perbaikan telemetry 2026-11-03

## Penyebab kolom kosong

- Mobile sebelumnya tidak mengirim `session_id` dan `app_version`.
- Pemeriksaan source deployment 394 mengonfirmasi dataset V04 di server masih
  memakai pertanyaan lama tentang kandungan natrium per sendok teh. Pertanyaan
  baru tentang rasio per 100 gram tidak cocok, sehingga referensinya NULL.
- Pencocokan skenario sebelumnya sensitif terhadap kapitalisasi dan whitespace.
- Migration lama mendefinisikan `scenario_id` sebagai UUID; dataset memakai `V04`.
  Tipe harus `text` agar insert referensi skenario berhasil. Database aktif sudah
  menerima V01/V04, sehingga perubahan tipe tidak diperlukan pada project ini.
- Penyimpanan akhir sebelumnya hanya UPDATE. Jika insert awal gagal, UPDATE
  dapat berhasil tanpa menyimpan baris apa pun. Sekarang menggunakan UPSERT
  seluruh metadata dan memeriksa baris hasilnya.

## Penerapan

1. Jalankan **hanya** `supabase/migrations/20261103000000_repair_telemetry_metadata.sql`
   pada database target, setelah meninjau perubahan. Script ini menambahkan kolom
   yang diperlukan, mempertahankan nilai lama, dan mengisi token serta referensi
   skenario untuk pertanyaan yang cocok dengan snapshot dataset V9.
   Jangan menjalankan ulang `chatbot_telemetry.sql`: file lama itu berisi DROP TABLE.
2. Deploy `gemini-proxy` dari source saat ini. Versi telemetry yang baru adalah
   `v4.4.0-dual-embedding-indobert`, mengikuti penanda konfigurasi embedding pengguna.
3. Build/jalankan ulang aplikasi mobile supaya metadata versi dan sesi ikut dikirim.
   Sesi bertahan selama service aktif, diganti saat clear session, hapus riwayat,
   atau pengguna aktif berubah. Sesi baru juga dibuat setelah aplikasi dimulai ulang.
4. Kirim pertanyaan V04 dan ekspor telemetry baru. Periksa versi backend, metadata
   aplikasi, `scenario_id = V04`, chunk `43`/`44`, dan token input/output.

## NULL yang tetap valid

- `response_pointer`: kosong jika respons disimpan langsung di `response_text`.
- Reranker latency/scores: kosong jika reranker tidak dijalankan.
- Referensi evaluasi: kosong untuk pertanyaan yang tidak cocok dengan dataset.
- Token: kosong jika API tidak memberikan usage; angka nol hanya untuk usage nol.
- Session, versi aplikasi, dan region historis tidak dapat direkonstruksi dari CSV.
  Migration tidak menebak nilainya. Client lama tanpa metadata tetap menghasilkan NULL.

## Verifikasi lokal

```powershell
flutter test --no-pub test/chatbot_telemetry_test.dart
flutter analyze --no-pub lib/app/services/chatbot_service.dart lib/app/services/gemini_proxy_service.dart
deno test supabase/functions/gemini-proxy/utils/telemetry_payload_test.ts
```

Tes Flutter menggunakan HTTP mock, tanpa menghubungi Supabase/Gemini. Tes backend
memeriksa seluruh pertanyaan dataset, variasi whitespace/kapitalisasi, referensi
yang tidak cocok, dan kelengkapan payload akhir termasuk pembedaan NULL dari nol.

Hasil pemeriksaan perubahan: 1 tes Flutter dan 5 tes Deno lulus; analyzer kedua
service serta `deno check` Edge Function lulus. Migration SQL belum diuji pada
server PostgreSQL lokal karena instalasi lokal hanya menyediakan command-line tools.

## Penerapan langsung pada chef-genius

Pada 2026-11-03, project `zfiyfhmsuhitytsuioml` diperiksa lewat CLI dan REST API:

- 884 baris diaudit; 218 baris diperbaiki dan diverifikasi melalui REST API.
- 215 baris memperoleh token input/output dari JSON token yang sudah tersimpan.
- 3 baris pertanyaan V04 memperoleh scenario, reference answer, source document,
  dan chunk 43/44. Nilai non-NULL tidak ditimpa.
- Backend `gemini-proxy` dideploy dari versi 394 ke 395, status ACTIVE, dengan
  penanda sementara `v4.4.1-telemetry-completeness`. Penanda ini kemudian
  dikembalikan ke `v4.4.0-dual-embedding-indobert` sesuai fungsi kolom untuk
  pelacakan konfigurasi embedding pengguna. Perbaikan telemetry tetap dipertahankan.
- Script `scripts/repair_telemetry.ps1` menyediakan audit default dan opsi
  `-Apply`. Salinan nilai sebelum perubahan disimpan di
  `supabase/.temp/telemetry-repair/before-20261103-111630.json`.
- Source deployment sebelumnya disimpan di
  `supabase/.temp/telemetry-deploy-backup/supabase/functions/gemini-proxy`.
- SQL migration tidak dijalankan pada project ini karena kolom yang diperlukan
  sudah tersedia. Backfill dilakukan melalui REST dengan pemeriksaan NULL dan
  verifikasi hasil setiap perubahan.
- Perubahan aplikasi masih memerlukan aplikasi dijalankan ulang dari source baru.
  Tidak ada perangkat Android tersambung saat pemeriksaan `flutter devices`.
- Uji end-to-end melalui `scripts/check_live_telemetry.ps1` berhasil pada deployment
  aktif: V04, chunk 43/44, reference answer dan source sesuai dataset, region
  `ap-southeast-1`, token input 2362/output 721, serta session/app version tersimpan.
  Akun uji dibuat tanpa email, lalu akun dan telemetry uji dibersihkan. Ringkasan
  pemeriksaan ada di `supabase/.temp/telemetry-live-check.json`.
- Audit ulang setelah backfill dan pembersihan: 884 baris, 0 baris yang masih
  dapat diperbaiki dari dataset V9 atau token yang tersedia.
