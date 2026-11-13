# BAB 3 - METODOLOGI PENELITIAN

## 3.1 Pendahuluan

Bab ini menjelaskan metodologi yang digunakan dalam pengembangan dan evaluasi chatbot Chef Cei pada aplikasi ChefGenius. Fokus penelitian adalah pada aspek **LLMOps (Large Language Model Operations)** yang mencakup instrumentasi, pengujian, dan evaluasi kualitas respons chatbot berbasis Gemini API untuk konsultasi kuliner dan nutrisi.

## 3.2 Desain Penelitian

Penelitian ini menggunakan pendekatan **Research and Development (R&D)** dengan fokus pada evaluasi integrasi dan kualitas sistem. Metodologi pengembangan mengadopsi prinsip **Rapid Application Development (RAD)** yang memungkinkan iterasi cepat berdasarkan feedback pengguna dan hasil pengujian.

### 3.2.1 Arsitektur Sistem

Arsitektur integrasi chatbot Chef Cei terdiri dari beberapa komponen utama:

1. **Flutter Mobile Application**: Antarmuka pengguna yang mengirimkan permintaan konsultasi
2. **ChatbotService**: Layer service di Flutter yang mengelola sesi chat dan konteks pengguna
3. **GeminiProxyService**: Proxy service yang berkomunikasi dengan Supabase Edge Function
4. **Supabase Edge Function (gemini-proxy)**: Serverless function yang memproses permintaan, menerapkan safety rules, dan memanggil Gemini API
5. **Google Gemini API**: Model bahasa besar (LLM) yang menghasilkan respons
6. **Supabase PostgreSQL**: Database untuk menyimpan telemetri dan antrian review

### 3.2.2 Prompt Engineering

Sistem prompt dirancang dengan prinsip **context-aware prompting** yang menyisipkan informasi kontekstual pengguna meliputi:
- Bahan makanan yang tersedia di pantry pengguna
- Preferensi diet (vegetarian, halal, keto, low sugar, dll.)
- Alergi dan pantangan makanan
- Resep yang sedang dibahas (jika ada)

Setiap prompt diberi identifikasi versi (prompt_id) dan hash SHA-256 (prompt_hash) untuk keperluan traceability dan reproducibility pengujian.

## 3.3 Instrumentasi dan Telemetri

### 3.3.1 Run-Level Logging

Setiap permintaan chatbot menghasilkan record telemetri dengan atribut:
- **run_id**: UUID unik per permintaan
- **prompt_hash**: Hash SHA-256 dari prompt lengkap
- **token_usage**: Jumlah token input dan output
- **latency_ms**: Waktu respons dalam milidetik
- **safety_flag**: Indikator apakah respons ditandai untuk review
- **post_processing_actions**: Tindakan post-processing yang diterapkan

### 3.3.2 Safety Post-Processing

Layer keamanan diterapkan dengan aturan:
1. **Keyword Blocking**: Respons yang mengandung kata kunci diagnosis/obat diblokir
2. **Allergy Check**: Respons yang menyebut alergen pengguna ditandai dengan peringatan
3. **Disclaimer Injection**: Respons terkait kondisi kesehatan metabolik diberi disclaimer
4. **Unit Normalization**: Satuan unit dinormalisasi ke standar Indonesia

### 3.3.3 Human-in-the-Loop

Respons yang ditandai (safety_flag = true) dimasukkan ke antrian review (review_queue) untuk dievaluasi oleh ahli gizi. Sistem menyimpan keputusan reviewer untuk keperluan audit dan perbaikan model.

## 3.4 Pengujian dan Evaluasi

### 3.4.1 Vignette-Based Testing

Pengujian menggunakan 15 skenario gold-standard (vignettes) yang mencakup:
- Permintaan resep untuk berbagai preferensi diet
- Pertanyaan nutrisi untuk kondisi metabolik (diabetes, hipertensi, kolesterol)
- Skenario alergi dan pantangan makanan
- Kasus rejection (permintaan diagnosis/obat yang harus ditolak)

Setiap vignette dijalankan 3 kali (total 45 runs) untuk memastikan konsistensi respons.

### 3.4.2 Kriteria Evaluasi

Evaluasi kualitas respons menggunakan rubrik 4 poin (0-4) dengan kriteria:
1. **Kesesuaian (Relevance)**: Respons sesuai dengan pertanyaan dan konteks pengguna
2. **Keamanan (Safety)**: Tidak memberikan diagnosis/obat, ada peringatan alergi jika relevan
3. **Kelengkapan (Completeness)**: Informasi nutrisi lengkap dengan data angka
4. **Personalisasi (Personalization)**: Mempertimbangkan preferensi diet dan bahan tersedia

### 3.4.3 Load Testing

Pengujian beban dilakukan menggunakan k6 dengan tiga skenario:
- **Baseline**: 100 virtual users selama 60 detik
- **Moderate**: 250 virtual users selama 60 detik
- **Stress**: 500 virtual users selama 60 detik

Metrik yang diukur meliputi:
- Latency percentiles (p50, p95, p99)
- Success rate dan error rate
- Safety flag rate
- Penggunaan token rata-rata

## 3.5 Metrik Observabilitas

Sistem menyediakan view agregasi harian (chatbot_metrics_daily) yang menghitung:
- Total permintaan per hari
- Jumlah respons yang ditandai (flagged)
- Safety pass rate (persentase respons yang lolos safety check)
- Rata-rata dan percentile latency
- Error rate

## 3.6 Batasan Penelitian

1. **Bukan Aplikasi Klinis**: Chatbot Chef Cei adalah konsultan kuliner dan nutrisi edukatif, bukan alat diagnosis medis
2. **Scope Penyakit Metabolik**: Fokus pada diabetes, hipertensi, kolesterol, asam urat, dan obesitas
3. **Evaluasi Non-Medis**: Evaluasi dilakukan dari perspektif kualitas informasi gizi dan pengalaman pengguna, bukan validitas klinis
4. **Infrastructure Constraints**: Pengujian menggunakan Supabase Free tier dengan batasan tertentu

## 3.7 Kesimpulan Metodologi

Metodologi yang diterapkan memungkinkan evaluasi komprehensif terhadap integrasi chatbot Chef Cei dengan fokus pada:
- **Traceability**: Setiap respons dapat dilacak melalui run_id dan prompt_hash
- **Safety**: Layer keamanan multi-level untuk mencegah respons berbahaya
- **Quality Assurance**: Vignette testing dengan rubrik evaluasi terstandar
- **Performance**: Load testing untuk memastikan skalabilitas sistem
- **Observability**: Dashboard metrik untuk monitoring berkelanjutan

Kombinasi instrumentasi LLMOps, pengujian sistematis, dan evaluasi berbasis rubrik memberikan kerangka kerja yang robust untuk menilai kualitas chatbot AI dalam domain konsultasi kuliner dan nutrisi.

---

*Total kata: ~780 kata*
