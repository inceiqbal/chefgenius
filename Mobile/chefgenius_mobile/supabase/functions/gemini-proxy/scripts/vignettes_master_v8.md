# Master Data Skenario Vignette RAG v8 (Definitive Single-Chunk Ground Truth)

Dokumen ini adalah **Master Reference Dataset v8** untuk pengujian dan evaluasi arsitektur **RAG (Naive vs Advanced / Gemini vs IndoBERT)** pada Tugas Akhir.
Setiap skenario dirancang dengan standar **Atomic Ground Truth (1 Skenario = Tepat 1 Dokumen = Tepat 1 Target Chunk)** untuk menjamin objektivitas, determinisme, dan ketepatan perhitungan metrik **MRR (Mean Reciprocal Rank)**, **Hit Rate**, serta dimensi evaluasi **RAGAS (Context Recall, Context Precision, Faithfulness, Answer Relevance)**.

---

## 📋 Matriks Ringkasan 15 Skenario Ground Truth

| ID | Dokumen PDF Knowledge Base | Hal. PDF (Fisik) | Hal. Dokumen (Tercetak) | Target Chunk ID | Topik Medis / Klinis |
| :---: | :--- | :---: | :---: | :---: | :--- |
| **V01** | `PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf` | **Hal 48** | Hal `- 48 -` (Tabel 23) | `90` | Krisis Hipertensi Emergensi & Sindrom Koroner Akut |
| **V02** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf` | **Hal 43-44** | Hal `- 38 - s/d - 39 -` (Tabel Kebutuhan Gizi PGTA/PEW) | `74` | Kebutuhan Energi, Protein, dan Makronutrien Pasien Hemodialisis Rutin |
| **V03** | `PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf` | **Hal 30-31** | Hal `-30- s/d -31-` | `54` | Diet Sangat Rendah Kalori (VLCD) & Durasi Maksimal |
| **V04** | `Permenkes Nomor 41 Tahun 2014.pdf` | **Hal 39** | Hal `-39-` (Tabel URT) | `64` | Kandungan Natrium Vetsin (MSG) vs Garam Meja |
| **V05** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf` | **Hal 112-113** | Hal `-112- s/d -113-` (Gambar 5) | `253` | Manajemen Perioperatif Diabetes (Operasi Singkat vs Lama) |
| **V06** | `Perkeni Dewasa 2024.pdf` | **Hal 57** | Hal `39` (Tabel 12) | `90` | Latihan Fleksibilitas & Keseimbangan Lansia Diabetes |
| **V07** | `23-11-21-Panduan-Dislipidemia-2021-Ebook.pdf` | **Hal 32** | Hal `21` (Bab C. Terapi Kombinasi) | `59` | Terapi Tambahan Inhibitor PCSK9 pada Statin Dosis Maksimal |
| **V08** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf` | **Hal 120** | Hal `- 120 -` | `208` | Rekomendasi Suplemen Metabolik pada Gagal Jantung HFrEF |
| **V09** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf` | **Hal 50-51** | Hal `- 51 -` (Tabel 13) | `103` | Dosis Suplementasi Vitamin D Defisiensi Berat Anak PGK |
| **V10** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf` | **Hal 87** | Hal `- 87 -` (Protokol ESPEN) | `149` | Protokol Nutrisi Enteral Pra-Bedah Pasien Risiko Berat |
| **V11** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf` | **Hal 72** | Hal `-72-` | `150` | Terapi Nyeri Neuropati Diabetik & Edukasi Perawatan Kaki |
| **V12** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf` | **Hal 75-76** | Hal `- 75 - s/d - 76 -` (Gambar 5) | `149` | Tatalaksana Hipertensi & Proteinuria pada PGK (ACE-I/ARB) |
| **V13** | `LAPORAN KEGIATAN KAJIAN KOMPOSISI PANGAN SEGAR 2025.pdf` | **Hal 17** | Hal `15` (Hasil & Pembahasan) | `28` | Analisis Proksimat: 3 Sayuran Segar Kadar Air Tertinggi |
| **V14** | `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf` | **Hal 105** | Hal `-105-` | `234` | Distribusi Persentase Kalori Puasa Ramadhan Pasien DM |
| **V15** | `PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf` | **Hal 64-65** | Hal `-64- s/d -65-` | `114` | Kriteria IMT & Indikasi Bedah Bariatrik Pasien Dewasa |

---

## 📐 Panduan Penilaian Dimensi RAGAS (Scoring Rubric)

1. **Context Recall / Context Precision (Retrieval Quality):**
   - **Skor 1.0 (High):** Sistem berhasil menemukan dokumen pedoman yang benar dan meletakkan target chunk (`ground_truth_chunk_idx`) pada peringkat teratas (Top-1 / Top-3).
   - **Skor 0.5 (Medium):** Target chunk terambil namun berada di peringkat bawah (peringkat 4-5).
   - **Skor 0.0 (Low):** Target chunk tidak berhasil diambil sama sekali (*retrieval miss*).

2. **Faithfulness (Ketaatan Medis & Ketiadaan Halusinasi):**
   - **Skor 1.0 (High):** Semua klaim fakta/angka dalam jawaban model didukung 100% oleh teks konteks yang terambil tanpa improvisasi dosis/angka bebas.
   - **Skor 0.5 (Medium):** Sebagian besar klaim taat, namun terdapat sedikit informasi tambahan yang tidak tertera di konteks.
   - **Skor 0.0 (Low):** Jawaban mengandung klaim medis yang bertentangan dengan konteks dokumen (*hallucination*).

3. **Answer Relevance (Kerelevanan & Kelengkapan terhadap Pertanyaan):**
   - **Skor 1.0 (High):** Respon menjawab secara tepat seluruh butir klaim (Klaim 1, 2, dan 3) yang ditanyakan dalam skenario kasus.
   - **Skor 0.5 (Medium):** Respon hanya menjawab sebagian butir klaim (misal hanya menyebut 1 klaim).
   - **Skor 0.0 (Low):** Respon melenceng dari konteks klinis yang ditanyakan.

---

## 🔬 Rincian Lengkap 15 Skenario Pengujian (V01 - V15)

---

### V01
- **Ground Truth Document:** `PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf`
- **Halaman PDF Fisik:** Hal 48
- **Halaman Tercetak Dokumen:** Hal `- 48 -` (Tabel 23: Tata laksana hipertensi emergensi per kondisi klinis spesifik)
- **Target Chunk ID:** `90`

**Pertanyaan Uji (Input Chatbot):**  
Pada pasien krisis hipertensi emergensi yang disertai Sindrom Koroner Akut (SKA), berapa target tekanan darah sistolik yang harus dicapai segera, serta apa obat suntik lini pertama dan alternatif yang direkomendasikan?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Target tekanan darah sistolik (TDS) harus segera diturunkan menjadi `< 140 mmHg`.
- **Klaim 2:** Pilihan obat intravena lini pertama adalah `Nitrogliserin` atau `Labetalol`.
- **Klaim 3:** Obat alternatif yang dapat diberikan adalah `Urapidil`.

**Kutipan Teks Verbatim (Chunk 90):**  
> *"Sindrom Koroner Akut Segera menurunkan TDS menjadi < 140 mmHg Nitrogliserin Labetalol (Urapidil) Edema paru akut Segera menurunkan TDS menjadi < 140 mmHg Nitroprusid atau nitrogliserin (dengan loop diuretic) (Urapidil) Diseksi Aorta Akut Segera menurunkan TDS menjadi < 120 mmHg DAN frekuensi nadi menjadi < 60 kali per menit Esmolol dan nitroprusid atau nitrogliserin atau nikardipin Labetalol ATAU metoprolol"*

---

### V02
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf`
- **Halaman PDF Fisik:** Hal 43-44
- **Halaman Tercetak Dokumen:** Hal `- 38 - s/d - 39 -` (Tabel Kebutuhan Zat Gizi pada Pasien PGTA dengan Malnutrisi/PEW)
- **Target Chunk ID:** `74`

**Pertanyaan Uji (Input Chatbot):**  
Untuk pasien gagal ginjal kronik yang rutin menjalani cuci darah (hemodialisis), berapa kebutuhan asupan energi dan protein harian per kilogram berat badan ideal, serta bagaimana penyesuaian kebutuhan pada kondisi malnutrisi (PEW) atau rekomendasi komposisi makronutrien lainnya?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Target asupan energi harian adalah `30 - 35 kal/kg/hari` (kkal/kgBB ideal/hari) berdasarkan usia, jenis kelamin, tingkat aktivitas fisik, komposisi tubuh, target berat badan, stadium CKD, dan komorbiditas (dapat lebih tinggi jika disertai PEW berat).
- **Klaim 2:** Target asupan protein harian untuk hemodialisis rutin adalah `1 - 1,2 g/kg/hari`, dan dapat ditingkatkan hingga `> 1,2 - 1,3 g/kgBB/hari` pada kondisi PEW berat atau hiperkatabolik.
- **Klaim 3:** Rekomendasi komposisi makronutrien lain meliputi lemak `25 - 30%` dari total asupan kalori (lemak jenuh 7-10%, MUFA sampai 20%, PUFA sampai 10%), karbohidrat dari sisa kalori nonprotein (terutama karbohidrat kompleks), serta serat `20 - 25 g/hari`.

**Kutipan Teks Verbatim (Chunk 74):**  
> *"untuk Pasien PGTA dengan Malnutrisi/ PEW [Peringkat bukti: Level IV] Zat Gizi Kebutuhan Zat Gizi pada PGTA dengan Malnutrisi Protein 1-1,2 g/kg/hari (pada pasien dengan hemodialisis rutin); dapat > 1,2-1,3 gr/kgBB/hari untuk pasien dengan PEW yang lebih berat atau pasien hiperkatabolik Energi 30-35 kal/kg/hari (berdasarkan usia, jenis kelamin, tingkat aktifitas fisik, komposisi tubuh, target berat badan, stadium CKD dan penyakit penyerta atau adanya inflamasi) Dapat lebih tinggi jika disertai PEW berat Lemak (% dari total asupan kalori) 25-30%; Lemak jenuh 7-10%, Monounsaturated Fatty Acid (MUFA) sampai 20%, Polyunsaturated Fatty Acid sampai 10% Karbohidrat Sisa kalori nonprotein; terutama karbohidrat kompleks. Serat (g/hari) 20 – 25 Mineral dan Vitamin Natrium (mg/hari) < 2300 Kalium (meq/hari) 70-80 (kebutuhan disesuaikan per individu sesuai kadar kalium darah) Fosfor (mg/hari) < 800 Kalsium (mg/hari) < 800; kebutuhan disesuaikan dengan penggunaan pengikat fosfor berbasis kalsium."*

---

### V03
- **Ground Truth Document:** `PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf`
- **Halaman PDF Fisik:** Hal 30-31
- **Halaman Tercetak Dokumen:** Hal `-30- s/d -31-` (Bagian Diet Berdasarkan Kalori)
- **Target Chunk ID:** `54`

**Pertanyaan Uji (Input Chatbot):**  
Berapa batasan asupan kalori harian yang mendefinisikan diet sangat rendah kalori (VLCD), berapa durasi maksimal pelaksanaannya, serta apa syarat keselamatan medis yang wajib dipenuhi selama terapi diet tersebut?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Diet sangat rendah kalori (*Very Low-Calorie Diet* / VLCD) membatasi asupan energi `< 800 kkal/hari` (sedangkan diet rendah kalori 800-1000 kkal/hari).
- **Klaim 2:** Terapi diet berdasarkan kalori ini hanya boleh berlangsung maksimal selama `12 minggu`.
- **Klaim 3:** Terapi wajib diobservasi langsung oleh tim medis dan disertai asupan cairan sebanyak `2 - 3 liter per hari`.

**Kutipan Teks Verbatim (Chunk 54):**  
> *"1) Diet berdasarkan kalori a) Terbagi menjadi diet sangat rendah kalori (very low- calorie diet) <800 kkal/hari dan diet rendah kalori (low calorie diet) 800−1000 kkal/hari. KEMENTERIAN KESEHATAN jdih.kemkes.go.id -31- b) Terapi diet berdasarkan kalori ini harus diobservasi oleh tim medis dan hanya boleh berlangsung maksimal selama 12 minggu dengan konsumsi air 2−3 liter per hari selama ‘fase"*

---

### V04
- **Ground Truth Document:** `Permenkes Nomor 41 Tahun 2014.pdf`
- **Halaman PDF Fisik:** Hal 39
- **Halaman Tercetak Dokumen:** Hal `-39-` (Tabel Daftar Makanan Tinggi Natrium / URT)
- **Target Chunk ID:** `64`

**Pertanyaan Uji (Input Chatbot):**  
Berapa kandungan natrium dalam takaran satu sendok teh penyedap rasa vetsin (MSG), dan bagaimana perbandingannya jika dibandingkan dengan takaran satu sendok teh garam meja?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Kandungan natrium dalam 1 sendok teh vetsin (MSG) adalah `492 mg`.
- **Klaim 2:** Kandungan natrium dalam 1 sendok teh garam meja adalah `2000 mg`.
- **Klaim 3:** Kandungan natrium dalam 1 sendok teh MSG setara dengan sekitar seperempat (`1/4`) dari kandungan natrium garam meja pada takaran sendok teh yang sama.

**Kutipan Teks Verbatim (Chunk 64):**  
> *"sebagai berikut: Daftar Makanan Tinggi Natrium 1) Bahan Penyedap Nama Makanan Ukuran Rumah Tangga (URT) Kandungan Natrium Garam Meja 1 Sendok Teh 2000 mg Acar Bawang Merah 1 Sendok Teh 1620 mg Acar bawang Putih 1 Sendok Teh 1850 mg MSG (Vetsin) 1 Sendok Teh 492 mg Kecap 1 Sendok Teh 343 mg Meat Tenderizer (Pelunak Daging) 1 Sendok Teh 1750 mg"*

---

### V05
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf`
- **Halaman PDF Fisik:** Hal 112-113
- **Halaman Tercetak Dokumen:** Hal `-112- s/d -113-` (Gambar 5 / Bab Manajemen Perioperatif)
- **Target Chunk ID:** `253`

**Pertanyaan Uji (Input Chatbot):**  
Bagaimana panduan tatalaksana obat diabetes pada pasien yang menjalani operasi singkat dengan hanya melewatkan satu jadwal makan, dan pada kondisi operasi seperti apa infus insulin intravena baru diwajibkan?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Pasien operasi singkat yang hanya melewatkan satu jadwal makan cukup dilakukan modifikasi/penyesuaian terapi diabetes yang sedang berjalan.
- **Klaim 2:** Infus insulin intravena tidak diperlukan pada kasus yang hanya melewatkan satu kali makan.
- **Klaim 3:** Infus insulin intravena (drip dosis bervariasi) diwajibkan bila pasien diperkirakan akan melewatkan lebih dari satu jadwal makan.

**Kutipan Teks Verbatim (Chunk 253):**  
> *"2. Pasien dengan waktu operasi yang singkat (melewatkan hanya satu jadwal makan) hanya dilakukan modifikasi terapi diabetesnya. 3. Pasien yang diperkirakan akan melewatkan lebih dari satu jadwal makan perlu mendapatkan infus insulin intravena dengan dosis bervariasi 4. Cairan yang digunakan untuk infus insulin intravena adalah natrium klorida 0,45% dengan glukosa 5% dan salah satu dari kalium klorida 0,15% atau kalium klorida 0,3 %"*

---

### V06
- **Ground Truth Document:** `Perkeni Dewasa 2024.pdf`
- **Halaman PDF Fisik:** Hal 57
- **Halaman Tercetak Dokumen:** Hal `39` (Tabel 12: Jenis Latihan Fisik dan Manfaatnya)
- **Target Chunk ID:** `90`

**Pertanyaan Uji (Input Chatbot):**  
Kombinasi jenis latihan fisik apa yang paling direkomendasikan bagi lansia penderita diabetes untuk mengatasi sendi kaku dan gaya berjalan yang tidak stabil, serta apa manfaat spesifik dari kombinasi latihan tersebut?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Rekomendasi utama adalah kombinasi latihan fleksibilitas (kelenturan) dan latihan keseimbangan.
- **Klaim 2:** Latihan fleksibilitas bermanfaat meningkatkan luas pergerakan/lingkup gerak sendi secara penuh.
- **Klaim 3:** Latihan keseimbangan bermanfaat memperbaiki pola langkah/berjalan (*gait*) dan secara signifikan menurunkan risiko jatuh.

**Kutipan Teks Verbatim (Chunk 90):**  
> *"pola berjalan/langkah (gait) dan mencegah jatuh. lipid, dan tekanan darah • Kombinasi latihan fleksibilitas dan keseimbangan memperbaiki HbA1c • Kombinasi latihan fleksibilitas dan keseimbangan pada lansia dapat meningkatkan lingkup gerak sendi dan menurunkan risiko jatuh Intensitas aktivitas fisik dapat ditentukan berdasarkan beberapa parameter, MET, konsumsi oksigen maksimal (VO 2 ), rerata denyut jantung maksimal"*

---

### V07
- **Ground Truth Document:** `23-11-21-Panduan-Dislipidemia-2021-Ebook.pdf`
- **Halaman PDF Fisik:** Hal 32
- **Halaman Tercetak Dokumen:** Hal `21` (Bab C. Terapi Kombinasi)
- **Target Chunk ID:** `59`

**Pertanyaan Uji (Input Chatbot):**  
Jika terapi statin dosis maksimal masih belum mampu menurunkan kolesterol LDL ke target yang diharapkan, bagaimana rekomendasi terapi kombinasi dengan inhibitor PCSK9 dan berapa persentase tambahan penurunan LDL yang dapat dicapai?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Golongan obat kombinasi yang direkomendasikan adalah `Inhibitor PCSK9`.
- **Klaim 2:** Terapi kombinasi ini diindikasikan pada pasien dengan kadar K-LDL yang sangat tinggi atau intoleran statin dosis tinggi.
- **Klaim 3:** Penambahan inhibitor PCSK9 pada terapi statin mampu memberikan tambahan penurunan K-LDL sebesar `43% hingga 64%`.

**Kutipan Teks Verbatim (Chunk 59):**  
> *"• Statin dengan inhibitor PCSK9. Kombinasi statin dengan inhibitor PCSK9 direkomendasikan pada pasien dengan kadar K-LDL yang sangat tinggi atau pada pasien yang tidak dapat mentoleransi pemberian statin dosis tinggi. Penambahan PCSK9 pada terapi statin mampu menambah penurunan K-LDL sekitar 43%-64%. Berbagai penelitian telah menjukkan efektivitas dari kombinasi kedua golongan ini terhadap outcomes kardiovaskular"*

---

### V08
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf`
- **Halaman PDF Fisik:** Hal 117-118
- **Halaman Tercetak Dokumen:** Hal `- 117 -` s/d `- 118 -` (Tabel/Ringkasan Rekomendasi Nutrisi Gagal Jantung)
- **Target Chunk ID:** `207` `208`

**Pertanyaan Uji (Input Chatbot):**  
Bagaimana anjuran klinis mengenai pemberian suplemen nutrisi seperti koenzim Q10, karnitin, taurin, dan antioksidan pada penderita gagal jantung dengan fraksi ejeksi rendah (HFrEF), dan pada kelompok gejala seperti apa aturan ini berlaku?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Suplementasi nutrisi koenzim Q10, karnitin, taurin, dan antioksidan `tidak direkomendasikan` untuk terapi gagal jantung HFrEF.
- **Klaim 2:** Derajat rekomendasi klinis untuk ketidakrekomendasian ini adalah `Rekomendasi B`.
- **Klaim 3:** Aturan ini berlaku mengikat baik untuk pasien yang sedang mengalami gejala saat ini maupun yang memiliki riwayat gejala sebelumnya.

**Kutipan Teks Verbatim (Chunk 207):**  
> *"Suplementasi nutrisi (koenzim Q10, karnitin, taurin, dan antioksidan) tidak direkomendasikan pada pasien gagal jantung (HFrEF) dengan gejala sebelumnya atau gejala saat ini. (Rekomendasi B)"*

---

### V09
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf`
- **Halaman PDF Fisik:** Hal 50-51
- **Halaman Tercetak Dokumen:** Hal `- 51 -` (Tabel 13: Rekomendasi Suplementasi Vitamin D Pada Anak PGK)
- **Target Chunk ID:** `103`

**Pertanyaan Uji (Input Chatbot):**  
Pada pasien anak dengan penyakit ginjal kronik yang memiliki kadar vitamin D di bawah 5 ng/mL, apa klasifikasi derajat defisiensinya dan bagaimana pilihan dosis suplementasi awal yang direkomendasikan untuk 4 minggu pertama?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Kadar vitamin D `< 5 ng/mL` pada anak PGK diklasifikasikan ke dalam kategori `Defisiensi berat`.
- **Klaim 2:** Pilihan dosis awal harian adalah vitamin D2 (Ergokalsiferol) atau vitamin D3 (Kolekalsiferol) sebesar `8.000 IU per hari selama 4 minggu`.
- **Klaim 3:** Pilihan dosis alternatif mingguan adalah `50.000 IU per minggu selama kurun waktu 4 minggu`.

**Kutipan Teks Verbatim (Chunk 103):**  
> *"Tabel 13. Rekomendasi Suplementasi Vitamin D Pada Anak PGK Kadar vitamin D (ng/mL) Klasifikasi Dosis vitamin D2 (Ergokalsiferol) atau vitamin D3 (Kolekalsiferol) Durasi (bulan) <5 Defisiensi berat 8000 IU/hari selama 4 minggu atau 50.000 IU/minggu selama 4 minggu Dilanjutkan 4000 IU/hari selama 2 bulan atau 50.000 IU/2 minggu selama 2 bulan"*

---

### V10
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf`
- **Halaman PDF Fisik:** Hal 87
- **Halaman Tercetak Dokumen:** Hal `- 87 -` (Bagian Nutrisi Pra-Bedah / Protokol ESPEN 2006)
- **Target Chunk ID:** `149`

**Pertanyaan Uji (Input Chatbot):**  
Pada pasien pra-bedah yang mengalami penurunan berat badan drastis lebih dari 10-15% dan albumin di bawah 3,0 g/dL, berapa lama durasi dukungan nutrisi wajib diberikan sebelum operasi, serta apa rute pemberian nutrisi yang paling diutamakan?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Pasien dikategorikan memiliki `risiko nutrisi berat` dan memerlukan dukungan nutrisi selama `7 hingga 14 hari` sebelum operasi.
- **Klaim 2:** Rute pemberian nutrisi yang paling dianjurkan sebagai lini utama adalah `nutrisi enteral`.
- **Klaim 3:** Nutrisi parenteral hanya diindikasikan bila asupan oral maupun enteral terbukti tidak adekuat (diberikan `7-10 hari` pra- dan pasca-operasi).

**Kutipan Teks Verbatim (Chunk 149):**  
> *"Berdasarkan ESPEN (2006), Pasien dengan risiko nutrisi berat (kehilangan berat badan >10-15% dalam 6 bulan atau IMT <18,5 kg/m 2 , atau SGA grade C atau albumin serum <3,0 g/l) memerlukan dukungan nutrisi (dianjurkan nutrisi enteral) 7-14 hari sebelum operasi. Sedangkan pasien dengan malnutrisi berat yang asupan oral maupun enteralnya tidak adekuat memerlukan nutrisi parenteral 7-10 hari sebelum dan setelah operasi."*

---

### V11
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf`
- **Halaman PDF Fisik:** Hal 72
- **Halaman Tercetak Dokumen:** Hal `- 72 -` (Bab Komplikasi Neuropati Diabetik)
- **Target Chunk ID:** `150`

**Pertanyaan Uji (Input Chatbot):**  
Untuk penyandang diabetes yang mengalami nyeri kebas dan kesemutan pada kaki akibat kerusakan saraf tepi (neuropati diabetik), apa saja pilihan obat untuk meredakan rasa sakit tersebut dan edukasi protektif apa yang wajib diberikan?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Terapi obat yang dapat digunakan untuk meredakan nyeri meliputi `antidepresan trisiklik`, `gabapentin`, atau `pregabalin`.
- **Klaim 2:** Semua pasien diabetes dengan neuropati perifer wajib diberikan `edukasi` dan `perawatan kaki yang memadai`.
- **Klaim 3:** Perawatan kaki protektif tersebut bertujuan penting untuk menurunkan risiko terjadinya komplikasi `ulkus kaki (luka diabetes)` dan `amputasi`.

**Kutipan Teks Verbatim (Chunk 150):**  
> *"-72- c. Neuropati 1) Komplikasi yang tersering dan paling penting pada neuropati perifer adalah berupa hilangnya sensasi distal yang berisiko tinggi untuk terjadinya ulkus kaki dan amputasi. 2) Gejala yang sering dirasakan berupa kaki terasa terbakar dan bergetar sendiri, dan lebih terasa sakit di malam hari 3) Setelah diagnosis diabetes melitus tipe 2 ditegakkan, pada setiap pasien perlu dilakukan skrining untuk mendeteksi adanya polineuropati distal simetris dengan pemeriksaan neurologi sederhana (menggunakan monofilamen 10 gram) kemudian diulang paling sedikit setiap tahun. 4) Pada keadaan polineuropati distal perlu dilakukan perawatan kaki yang memadai untuk menurunkan risiko amputasi 5) Pemberian terapi antidepresan trisiklik, gabapentin atau pregabalin dapat mengurangi rasa sakit 6) Semua pasien DM yang disertai neuropati perifer harus diberikan edukasi"*

---

### V12
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf`
- **Halaman PDF Fisik:** Hal 75-76
- **Halaman Tercetak Dokumen:** Hal `- 75 - s/d - 76 -` (Gambar 5: Algoritma Prevensi pada Pasien DM & PGK)
- **Target Chunk ID:** `149`

**Pertanyaan Uji (Input Chatbot):**  
Pada pasien penyakit ginjal kronik dengan temuan tekanan darah di atas 130/80 mmHg atau hasil pemeriksaan protein urin yang positif, apa golongan obat antihipertensi lini pertama yang wajib diberikan dan berapa batas tekanan darah yang menjadi patokan intervensi?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Batas tekanan darah yang memerlukan intervensi farmakologis adalah `≥ 130/80 mmHg` (dengan target terapi di bawah nilai tersebut).
- **Klaim 2:** Golongan obat antihipertensi pilihan utama yang wajib diberikan adalah `ACE-Inhibitor (ACE-I)` atau `Angiotensin Receptor Blocker (ARB)`.
- **Klaim 3:** Pemberian ACE-Inhibitor atau ARB juga diwajibkan bila hasil pemeriksaan protein urin pasien menunjukkan hasil `positif` untuk efek proteksi ginjal.

**Kutipan Teks Verbatim (Chunk 149):**  
> *"1) Jika HbA1C ≥7% dan tekanan darah ≥130/80 mmHg maka diberikan obat antihipertensi golongan ACE- Inhibitor atau ARB ... 4) Jika HbA1C <7%, tekanan darah <130/80 mmHg, dan hasil pemeriksaan protein urin positif maka diberikan obat golongan ACE-Inhibitor atau ARB 5) Jika HbA1C <7%, tekanan darah <130/80, dan hasil pemeriksaan protein urin negatif maka pasien dikembalikan ke Fasilitas Kesehatan Tingkat Pertama"*

---

### V13
- **Ground Truth Document:** `LAPORAN KEGIATAN KAJIAN KOMPOSISI PANGAN SEGAR 2025.pdf`
- **Halaman PDF Fisik:** Hal 17
- **Halaman Tercetak Dokumen:** Hal `15` (Hasil & Pembahasan: Analisis Proksimat)
- **Target Chunk ID:** `28`

**Pertanyaan Uji (Input Chatbot):**  
Di antara aneka komoditas sayuran segar lokal yang sering dikonsumsi, sebutkan tiga jenis sayuran yang memiliki persentase kadar air tertinggi beserta nilai persentasenya masing-masing menurut analisis laboratorium proksimat pangan?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Peringkat pertama adalah `mentimun` dengan kandungan kadar air sebesar `96,29%`.
- **Klaim 2:** Peringkat kedua adalah `sawi putih` dengan kandungan kadar air sebesar `95,92%`.
- **Klaim 3:** Peringkat ketiga adalah `selada` dengan kandungan kadar air sebesar `95,06%`.

**Kutipan Teks Verbatim (Chunk 28):**  
> *"Hasil analisis proksimat terhadap 15 komoditas sayur dan buah segar menunjukkan bahwa kadar air merupakan komponen terbesar, dengan nilai tertinggi pada mentimun (96,29%), sawi putih (95,92%), dan selada (95,06%). Tingginya kadar air ini sesuai dengan karakteristik sayuran segar yang umumnya mengandung air lebih dari 90%"*

---

### V14
- **Ground Truth Document:** `Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf`
- **Halaman PDF Fisik:** Hal 105
- **Halaman Tercetak Dokumen:** Hal `-105-` (Bab Diabetes Melitus dengan Ibadah Puasa)
- **Target Chunk ID:** `234`

**Pertanyaan Uji (Input Chatbot):**  
Bagaimana anjuran pembagian proporsi atau persentase kalori harian bagi penyandang diabetes saat berpuasa Ramadhan untuk sesi sahur dan waktu berbuka?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Porsi makan sahur dialokasikan sebesar `30% hingga 40%`, dengan snack sebelum sahur sebesar `10% hingga 20%`.
- **Klaim 2:** Porsi makanan saat awal berbuka (takjil) dialokasikan sebesar `10% hingga 20%`.
- **Klaim 3:** Porsi makan utama saat berbuka puasa dialokasikan sebesar `40% hingga 50%` dari total kalori harian.

**Kutipan Teks Verbatim (Chunk 234):**  
> *"diluar waktu puasa (sesudah berbuka sampai dengan waktu sahur). Pola makan selama puasa pada pasien DM sesuai kebutuhan kalori harian -105- dengan pola makan gizi sehat seimbang. Pembagian persentase total kalori terdiri dari snack sebelum sahur 10-20%, makan sahur 30-40%, makanan saat awal berbuka 10-20%, dan makan berbuka 40-50%. Segelas susu atau buah sebelum tidur dapat membantu menjaga gula darah dalam rentang normal sampai tiba waktu sahur."*

---

### V15
- **Ground Truth Document:** `PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf`
- **Halaman PDF Fisik:** Hal 64-65
- **Halaman Tercetak Dokumen:** Hal `-64- s/d -65-` (Bab Indikasi Operasi Bedah Bariatrik)
- **Target Chunk ID:** `114`

**Pertanyaan Uji (Input Chatbot):**  
Apa saja kriteria nilai Indeks Massa Tubuh (IMT) dan kondisi klinis penyerta yang menjadi indikasi medis bagi pasien obesitas dewasa untuk menjalani tindakan bedah bariatrik?

**Kunci Jawaban (Multi-Klaim):**  
- **Klaim 1:** Indikasi operasi berlaku untuk `IMT ≥ 35 kg/m²`, baik dengan komorbiditas (ringan hingga berat) maupun tanpa komorbid.
- **Klaim 2:** Indikasi operasi berlaku untuk `IMT 30 - 34,9 kg/m²` pada pasien yang gagal mencapai target penurunan berat badan atau komorbiditasnya tidak membaik dengan terapi obat dan gaya hidup.
- **Klaim 3:** Indikasi operasi juga berlaku untuk `IMT ≥ 30 kg/m²` jika pasien memiliki komorbiditas Diabetes Melitus tipe 2.

**Kutipan Teks Verbatim (Chunk 114):**  
> *"c. Indikasi operasi: 1) IMT ≥35 kg/m 2 baik dengan komorbid ringan hingga berat, ataupun tanpa komorbid. 2) IMT 30−34,9 kg/m 2 pada pasien yang tidak mencapai penurunan berat badan yang diharapkan ataupun tidak mengalami perbaikan komorbiditas dengan terapi medikamentosa dan/atau modifikasi gaya hidup. 3) IMT ≥30 kg/m 2 dengan DM tipe 2. 4) Indikasi operasi berdasarkan kriteria IMT hanya berlaku pada pasien dewasa."*
