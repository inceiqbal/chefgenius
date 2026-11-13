import { VignetteScenario } from './types.ts'

export const vignettesMetadata: any[] = [
  {
    "scenario_id": "V01",
    "scenario_type": "explicit",
    "ground_truth_document": "PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf",
    "ground_truth_chunk_idx": [
      "46"
    ],
    "pdf_page": "Halaman 26 - 27",
    "doc_page": "Halaman 26 - 27",
    "document_section": "Tabel 12. Rincian Pola Diet DASH (Karbohidrat 55%, Lemak 27%, Protein 18%) & Tabel 13",
    "query_text_part": "Saya penderita hipertensi dan sedang mencoba diet DASH, bagaimana anjuran pembagian persentase porsi karbohidrat, lemak, dan protein yang tepat untuk kebutuhan harian saya?",
    "reference_answer": "- **Klaim 1:** Rekomendasi komposisi makronutrien pada pola diet DASH terdiri dari asupan karbohidrat sebesar `55%`, lemak sebesar `27%` (dengan lemak jenuh dibatasi `6%`), dan protein sebesar `18%` dari total energi harian."
  },
  {
    "scenario_id": "V02",
    "scenario_type": "explicit",
    "ground_truth_document": "KONSENSUS NUTRISI PENYAKIT GINJAL KRONIK.pdf",
    "ground_truth_chunk_idx": [
      "30"
    ],
    "pdf_page": "Halaman 23",
    "doc_page": "Halaman 11",
    "document_section": "Panduan 3.2 Kebutuhan Energi Pasien Penyakit Ginjal Kronik Lanjut & Hemodialisis (PGK-HD)",
    "query_text_part": "Ayah saya pasien PGK-HD dengan berat badan ideal 60 kg, berapakah rekomendasi asupan energi kalori per kgBB ideal per hari agar terhindar dari malnutrisi?",
    "reference_answer": "- **Klaim 1:** Target kebutuhan asupan energi harian untuk pasien penyakit ginjal kronik yang menjalani hemodialisis (PGK-HD) rutin adalah sebesar `30 - 35 kkal/kg BB ideal/hari` (setara `1.800 - 2.100 kkal/hari` untuk berat badan ideal 60 kg)."
  },
  {
    "scenario_id": "V03",
    "scenario_type": "explicit",
    "ground_truth_document": "KONSENSUS TATA LAKSANA MULTIDISIPLIN OBESITAS PADA DEWASA 2025.pdf",
    "ground_truth_chunk_idx": [
      "104",
      "105"
    ],
    "pdf_page": "Halaman 49 - 50",
    "doc_page": "Halaman 34 - 35",
    "document_section": "Bab IV. Tata Laksana Obesitas - A. Terapi Nutrisi (Poin 7. Rekomendasi Asupan Serat Harian Obesitas)",
    "query_text_part": "Saya seorang pria berusia 38 tahun dengan obesitas, berapa gram target anjuran asupan serat harian untuk membantu regulasi metabolik dan penurunan berat badan saya?",
    "reference_answer": "- **Klaim 1:** Rekomendasi asupan serat harian untuk individu obesitas dewasa berusia < 51 tahun adalah sebesar `38 gram per hari untuk pria` (dan 25 gram per hari untuk wanita) guna mendukung fungsi saluran pencernaan, rasa kenyang, serta regulasi kadar glukosa dan lemak darah."
  },
  {
    "scenario_id": "V04",
    "scenario_type": "implicit",
    "ground_truth_document": "PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf",
    "ground_truth_chunk_idx": [
      "43",
      "44"
    ],
    "pdf_page": "Halaman 25 - 26",
    "doc_page": "Halaman 25 - 26",
    "document_section": "BAB III Bagian C.1.a Pembatasan Konsumsi Natrium & Penggunaan MSG",
    "query_text_part": "Tekanan darah saya masih sering bertahan di angka 145/90 mmHg meskipun masakan di rumah sudah tidak pakai garam dapur sama sekali, tetapi keluarga saya menggantinya dengan bumbu penyedap gurih seperti MSG karena mengira itu bukan garam. Apakah kebiasaan mengganti garam dengan bumbu penyedap ini aman untuk tekanan darah saya?",
    "reference_answer": "- **Pedoman Klinis (RAG):** Batas aman konsumsi natrium harian untuk pasien hipertensi dianjurkan tidak melebihi `2 gram per hari` (setara 5-6 gram NaCl atau 1 sendok teh garam dapur / 3 sendok teh MSG), dengan target penurunan lebih optimal hingga `1.500 mg per hari`. Pengurangan asupan natrium sebanyak 1.000 mg/hari dari kebiasaan sudah dapat menurunkan tekanan darah. Kandungan natrium dalam MSG adalah 12,28 g/100 g (sepertiga dari garam dapur), dan substitusi 1/2 sdt NaCl dengan 1/2 sdt MSG mengurangi natrium sekitar 37%.\n- **Kesimpulan Klinis:** Kebiasaan mengganti garam dapur dengan bumbu penyedap rasa gurih (MSG) secara bebas **tidak aman** untuk pasien hipertensi (145/90 mmHg) jika tidak dibatasi ketat, karena MSG tetap menyumbang natrium yang signifikan (12,28 g/100 g atau sepertiga dari garam dapur) yang memicu tekanan darah tetap tinggi; pasien wajib membatasi total asupan natrium harian dari seluruh bumbu dan makanan maksimal 2 gram/hari (atau 1.500 mg/hari) untuk membantu penurunan tekanan darah."
  },
  {
    "scenario_id": "V05",
    "scenario_type": "implicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "52"
    ],
    "pdf_page": "Halaman 26 - 27",
    "doc_page": "Halaman 26 - 27",
    "document_section": "Poin 4. Kebutuhan Karbohidrat (Pembatasan Minuman Mengandung Gula & Jus Buah)",
    "query_text_part": "Saya baru terdiagnosis diabetes melitus tipe 2 dan setiap pagi rutin meminum 2 gelas jus mangga karena menganggap semua olahan buah pasti sehat untuk tubuh. Apakah kebiasaan saya meminum jus buah setiap hari ini aman bagi saya?",
    "reference_answer": "- **Pedoman Klinis (RAG):** Pasien diabetes melitus dan mereka yang berisiko disarankan untuk menghindari minuman yang mengandung gula, termasuk jus buah, untuk mengendalikan kontrol glikemik dan berat badan serta mengurangi risiko penyakit kardiovaskular dan perlemakan hati; disarankan meminimalkan konsumsi makanan/minuman dengan tambahan gula dan menggantinya dengan pilihan yang lebih sehat serta padat nutrisi.\n- **Kesimpulan Klinis:** Kebiasaan rutin meminum jus buah manis tidak aman karena proses pembuatan jus menghilangkan serat alami dan memicu lonjakan glikemik cepat dari gula sederhana/fruktosa bebas; penderita diabetes disarankan menggantinya dengan air putih atau buah segar utuh berserat tinggi."
  },
  {
    "scenario_id": "V06",
    "scenario_type": "explicit",
    "ground_truth_document": "Perkeni Dewasa 2024.pdf",
    "ground_truth_chunk_idx": [
      "120"
    ],
    "pdf_page": "Halaman 68",
    "doc_page": "Halaman 56 - 57",
    "document_section": "Tabel 18. Contoh Pola Makan yang Dianjurkan pada Penyandang DMT2 (Diet Mediterania)",
    "query_text_part": "Sebagai penyandang diabetes melitus yang menerapkan pola diet Mediterania, berapa batas konsumsi telur mingguan yang dianjurkan untuk menjaga profil kardiovaskular?",
    "reference_answer": "- **Klaim 1:** Dalam penerapan pola diet Mediterania untuk penyandang diabetes melitus, konsumsi telur dianjurkan dibatasi `kurang dari 4 butir per minggu (< 4 butir/minggu)` untuk mendukung penurunan risiko kejadian kardiovaskular mayor, perbaikan HbA1c, dan kontrol trigliserida."
  },
  {
    "scenario_id": "V07",
    "scenario_type": "implicit",
    "ground_truth_document": "23-11-21-Panduan-Dislipidemia-2021-Ebook.pdf",
    "ground_truth_chunk_idx": [
      "44",
      "45"
    ],
    "pdf_page": "Halaman 25 - 26",
    "doc_page": "Halaman 14 - 15",
    "document_section": "BAB IV Tata Laksana Non-Farmakologis, Poin B Terapi Nutrisi Medis & Tabel 6",
    "query_text_part": "Saya sudah sebulan ini menghindari daging berlemak karena LDL saya 175 mg/dL, tetapi saya masih sering ngemil biskuit, kue kering, dan roti kemasan. Kenapa kolesterol jahat saya belum juga membaik?",
    "reference_answer": "- **Pedoman Klinis (RAG):** Menghindari daging berlemak hanya membatasi asupan asam lemak jenuh, sedangkan biskuit, kue kering, dan roti kemasan merupakan sumber utama asam lemak trans industri (minyak terhidrogenasi/shortening). Berdasarkan Tabel 6 pedoman klinis dislipidemia, pengurangan asupan lemak trans memiliki pengaruh sangat besar dalam menurunkan kolesterol total dan kolesterol LDL dengan **Tingkat Bukti A (+++)**, serta terbukti meningkatkan kadar kolesterol baik HDL dengan **Tingkat Bukti A (+++)**. Mengonsumsi camilan berlemak trans secara aktif menggagalkan perbaikan kadar kolesterol jahat.\n- **Kesimpulan Klinis:** Untuk menurunkan kadar LDL tinggi (175 mg/dL), pasien wajib menghentikan camilan tinggi lemak trans dan menggantinya dengan bahan pangan yang terbukti menurunkan LDL, seperti buah/sayur tinggi serat larut air (10-25 g/hari) dan tanaman stanol/sterol (2 g/hari)."
  },
  {
    "scenario_id": "V08",
    "scenario_type": "explicit",
    "ground_truth_document": "23-11-21-Panduan-Dislipidemia-2021-Ebook.pdf",
    "ground_truth_chunk_idx": [
      "43",
      "44"
    ],
    "pdf_page": "Halaman 25",
    "doc_page": "Halaman 14 - 15",
    "document_section": "BAB IV Poin B. Terapi Nutrisi Medis (Komponen Pangan Penurun Kolesterol LDL)",
    "query_text_part": "Sebagai pasien dislipidemia, untuk menurunkan kadar LDL-C berapa target anjuran konsumsi serat larut air harian yang harus saya penuhi?",
    "reference_answer": "- **Klaim 1:** Asupan serat larut air sebanyak 5 gram per hari belum mencukupi; pedoman terapi nutrisi medis dislipidemia merekomendasikan asupan serat larut air sebesar `10 hingga 25 gram per hari (10-25 g/hari)` serta asupan tanaman stanol/sterol sebesar `2 gram per hari (2 g/hari)` untuk membantu menurunkan kadar kolesterol LDL-C secara efektif."
  },
  {
    "scenario_id": "V09",
    "scenario_type": "explicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "188"
    ],
    "pdf_page": "Halaman 106",
    "doc_page": "Halaman 106",
    "document_section": "BAB III Poin c. Diabetes dengan Obesitas (Penurunan Berat Badan)",
    "query_text_part": "Saya menderita diabetes tipe 2 disertai obesitas dan ingin menurunkan berat badan. Berapakah pengurangan asupan kalori harian yang direkomendasikan untuk menurunkan berat badan secara bertahap?",
    "reference_answer": "- **Klaim 1:** Pengurangan asupan kalori yang direkomendasikan untuk penurunan berat badan bertahap pada pasien diabetes dengan obesitas adalah sebesar `250–500 kalori per hari` (dengan target penurunan berat badan 0,5 sampai 1 kg per minggu, serta menjaga total asupan kalori harian minimal 1.000–1.200 kkal untuk wanita dan 1.200–1.600 kkal untuk pria)."
  },
  {
    "scenario_id": "V10",
    "scenario_type": "explicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf",
    "ground_truth_chunk_idx": [
      "102",
      "103"
    ],
    "pdf_page": "Halaman 50 - 51",
    "doc_page": "Halaman 50 - 51",
    "document_section": "Tabel 7. Dosis Suplementasi Vitamin D pada Pasien Anak dengan PGK (Defisiensi Berat < 5 ng/mL)",
    "query_text_part": "Anak saya usia 7 tahun dengan penyakit ginjal kronik hasil laboratorium vitamin D-nya sangat rendah yaitu di bawah 5 ng/mL, berapakah dosis awal suplementasi vitamin D yang harus diberikan?",
    "reference_answer": "- **Klaim 1:** Dosis suplementasi awal untuk defisiensi berat (< 5 ng/mL) pada anak dengan penyakit ginjal kronik adalah pemberian vitamin D2 (Ergokalsiferol) atau vitamin D3 (Kolekalsiferol) sebesar `8.000 IU per hari selama 4 minggu` atau pilihan alternatif `50.000 IU per minggu selama 4 minggu`."
  },
  {
    "scenario_id": "V11",
    "scenario_type": "explicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "234"
    ],
    "pdf_page": "Halaman 105",
    "doc_page": "Halaman 105",
    "document_section": "Tata Laksana Diabetes Melitus pada Puasa Ramadhan (Distribusi Kalori Sahur)",
    "query_text_part": "Sebagai penyandang diabetes yang berpuasa Ramadhan, berapa anjuran alokasi persentase kalori harian untuk makan sahur agar gula darah tetap terkontrol?",
    "reference_answer": "- **Klaim 1:** Pedoman klinis merekomendasikan alokasi persentase kalori harian untuk santap makan sahur dialokasikan sebesar `30% hingga 40%`, ditambah snack sebelum sahur sebesar `10% hingga 20%` dari total kebutuhan kalori harian."
  },
  {
    "scenario_id": "V12",
    "scenario_type": "implicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf",
    "ground_truth_chunk_idx": [
      "45",
      "46"
    ],
    "pdf_page": "Halaman 25 - 26",
    "doc_page": "Halaman 25 - 26",
    "document_section": "BAB III Rekomendasi Modifikasi Gaya Hidup & Restriksi Natrium Pasien PGK Stadium 3-5D",
    "query_text_part": "Dokter mendiagnosis saya menderita PGK stadium 4 dan kaki saya belakangan ini sering bengkak cairan. Siang tadi saya sudah makan nasi padang lauk rendang, apakah malam ini saya masih boleh makan satu mangkuk mi instan kuah gurih?",
    "reference_answer": "- **Pedoman Klinis (RAG):** Pasien dewasa dengan PGK 3-5D (termasuk stadium 4) direkomendasikan membatasi asupan natrium `kurang dari 100 mmol/hari` atau `kurang dari 2,3 gram/hari (< 2.300 mg/hari)` untuk menurunkan tekanan darah dan memperbaiki kontrol volume cairan tubuh. Restriksi natrium terbukti membantu menurunkan berat badan dan volume total cairan tubuh pada pasien non-dialisis.\n- **Kesimpulan Klinis:** Pasien tidak dianjurkan/tidak boleh mengonsumsi satu mangkuk mi instan kuah tersebut. Mengingat siang hari telah mengonsumsi makanan tinggi natrium (nasi padang rendang), tambahan mi instan kuah akan melampaui batas aman kumulatif harian (< 2,3 gram natrium/hari) dan berisiko memperberat kelebihan volume cairan tubuh pada PGK stadium 4."
  },
  {
    "scenario_id": "V13",
    "scenario_type": "explicit",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Osteoporosis.pdf",
    "ground_truth_chunk_idx": [
      "115"
    ],
    "pdf_page": "Halaman 49 - 50",
    "doc_page": "Halaman 49 - 50 (Lampiran Hal. 45 - 46)",
    "document_section": "BAB III Tata Laksana Nutrisi Osteoporosis (Target Asupan Kalsium Harian)",
    "query_text_part": "Untuk pasien osteoporosis, bagaimana analisis pemenuhan asupan kalsium sejumlah 1000-1200 mg/hari bila asupan makanan tidak mencukupi sehingga memerlukan suplementasi?",
    "reference_answer": "- **Klaim 1:** Asupan kalsium 500 mg per hari tidak mencukupi; pedoman tata laksana osteoporosis merekomendasikan target asupan kalsium sebesar `1.000 hingga 1.200 mg per hari (1.000 - 1.200 mg/hari)` yang dipenuhi dari asupan makanan atau ditambah suplementasi jika tidak terpenuhi dari makanan (Rekomendasi B)."
  },
  {
    "scenario_id": "V14",
    "scenario_type": "explicit",
    "ground_truth_document": "Perkeni Dewasa 2024.pdf",
    "ground_truth_chunk_idx": [
      "185"
    ],
    "pdf_page": "Halaman 113 - 114",
    "doc_page": "Halaman 93",
    "document_section": "Bab 9.2.2.2. Penyakit Ginjal Diabetik (Rekomendasi A)",
    "query_text_part": "Untuk pasien penyakit ginjal diabetik dengan risiko nefropati, apakah aman menurunkan asupan protein sampai di bawah 0.8 g/kgBB/hari tanpa menurunkan LFG ginjal?",
    "reference_answer": "- **Klaim 1:** Pedoman Pengelolaan Diabetes Melitus Tipe 2 Dewasa merekomendasikan bahwa untuk pasien dengan penyakit ginjal diabetik, menurunkan asupan protein harian sampai di bawah `0,8 g/kgBB/hari (< 0,8 g/kgBB/hari)` tidak direkomendasikan karena terbukti tidak memperbaiki risiko kardiovaskular dan tidak menurunkan laju filtrasi glomerulus (LFG) ginjal (Peringkat Bukti A).\n- **Kesimpulan Klinis:** Batas aman asupan protein harian tidak boleh dipangkas di bawah 0,8 g/kgBB/hari untuk mencegah risiko malnutrisi tanpa memberikan perbaikan kardiovaskular atau fungsi ginjal."
  },
  {
    "scenario_id": "V15",
    "scenario_type": "implicit",
    "ground_truth_document": "KONSENSUS TATA LAKSANA MULTIDISIPLIN OBESITAS PADA DEWASA 2025.pdf",
    "ground_truth_chunk_idx": [
      "89"
    ],
    "pdf_page": "Halaman 44",
    "doc_page": "Halaman 29",
    "document_section": "Tabel 8. Target Penurunan Berat Badan dan Klinis Pasien Obesitas dengan Komplikasi (Baris MAFLD)",
    "query_text_part": "Berat badan saya saat ini 95 kg dan hasil pemeriksaan dokter menunjukkan hati saya mengalami perlemakan yang disertai peradangan. Jika target saya hanya menurunkan berat badan sekitar 3 sampai 4 kg lewat diet sehat, apakah penurunan tersebut sudah cukup untuk meredakan radang hati saya?",
    "reference_answer": "- **Pedoman Klinis (RAG):** Pada pasien obesitas dengan komplikasi perlemakan hati metabolik (MAFLD), pedoman klinis merekomendasikan target penurunan berat badan awal sebesar minimal 5% atau lebih untuk perbaikan steatosis (perlemakan), dan ditingkatkan menjadi 10% hingga 40% (≥ 10%) pada kondisi steatohepatitis (peradangan hati) guna mencapai perbaikan klinis berupa penurunan derajat perlemakan, regresi inflamasi, dan pencegahan fibrosis jaringan hati.\n- **Kesimpulan Klinis:** Penurunan berat badan sebesar 3 sampai 4 kg dari berat awal 95 kg (hanya sekitar 3,1% - 4,2%) belum mencukupi untuk meredakan peradangan hati; pasien membutuhkan penurunan berat badan minimal 10% atau setara minimal 9,5 kg ke atas (10% - 40%) melalui terapi nutrisi terstruktur dan modifikasi gaya hidup agar peradangan sel hati dapat mengalami perbaikan klinis bermakna."
  }
]
