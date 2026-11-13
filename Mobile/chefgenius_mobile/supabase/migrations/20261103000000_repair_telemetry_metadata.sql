-- Non-destructive repair for existing telemetry installations. Run before deploying
-- the telemetry repair. No session, app version, or execution region is invented.
BEGIN;

ALTER TABLE public.chatbot_telemetry
  ADD COLUMN IF NOT EXISTS session_id text,
  ADD COLUMN IF NOT EXISTS app_version text,
  ADD COLUMN IF NOT EXISTS region text,
  ADD COLUMN IF NOT EXISTS query_text text,
  ADD COLUMN IF NOT EXISTS scenario_id text,
  ADD COLUMN IF NOT EXISTS reference_answer text,
  ADD COLUMN IF NOT EXISTS ground_truth_document text,
  ADD COLUMN IF NOT EXISTS ground_truth_chunk_idx jsonb,
  ADD COLUMN IF NOT EXISTS token_usage_input integer,
  ADD COLUMN IF NOT EXISTS token_usage_output integer;

-- The older unified migration declared UUID, but dataset identifiers are V01, V02, ...
-- Casting UUIDs to text preserves existing values.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chatbot_telemetry'
      AND column_name = 'scenario_id' AND data_type = 'uuid'
  ) THEN
    ALTER TABLE public.chatbot_telemetry
      ALTER COLUMN scenario_id TYPE text USING scenario_id::text;
  END IF;
END $$;

UPDATE public.chatbot_telemetry
SET token_usage_input = (token_usage->>'input_tokens')::integer
WHERE token_usage_input IS NULL
  AND token_usage->>'input_tokens' ~ '^[0-9]{1,9}$';

UPDATE public.chatbot_telemetry
SET token_usage_output = (token_usage->>'output_tokens')::integer
WHERE token_usage_output IS NULL
  AND token_usage->>'output_tokens' ~ '^[0-9]{1,9}$';

-- Evaluation metadata backfill follows, using the bundled V9 dataset.
WITH scenarios AS (
  SELECT * FROM jsonb_to_recordset($vignettes$[
  {
    "scenario_id": "V01",
    "ground_truth_document": "PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf",
    "ground_truth_chunk_idx": [
      "46"
    ],
    "query_text_part": "Pada pasien hipertensi yang menerapkan pola diet DASH, berapa anjuran komposisi persentase makronutrien (karbohidrat, lemak, dan protein), serta berapa target asupan harian yang direkomendasikan untuk kalium dan serat?",
    "reference_answer": "- **Klaim 1:** Rekomendasi komposisi makronutrien diet DASH terdiri dari karbohidrat `55%`, lemak `27%` (dengan lemak jenuh 6%), dan protein `18%`.\n- **Klaim 2:** Target asupan kalium harian yang direkomendasikan adalah sebesar `4.700 mg`.\n- **Klaim 3:** Target asupan serat harian adalah `30 gram` (dengan batas kolesterol 150 mg dan natrium < 2.300 mg, atau 1.500 mg untuk penurunan tekanan darah lebih optimal)."
  },
  {
    "scenario_id": "V02",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf",
    "ground_truth_chunk_idx": [
      "74"
    ],
    "query_text_part": "Untuk pasien gagal ginjal kronik yang rutin menjalani cuci darah (hemodialisis), berapa kebutuhan asupan energi dan protein harian per kilogram berat badan ideal, serta bagaimana penyesuaian kebutuhan pada kondisi malnutrisi (PEW) atau rekomendasi komposisi makronutrien lainnya?",
    "reference_answer": "- **Klaim 1:** Target asupan energi harian adalah `30 - 35 kal/kg/hari` (kkal/kgBB ideal/hari) berdasarkan usia, jenis kelamin, tingkat aktivitas fisik, komposisi tubuh, target berat badan, stadium CKD, dan komorbiditas (dapat lebih tinggi jika disertai PEW berat).\n- **Klaim 2:** Target asupan protein harian untuk hemodialisis rutin adalah `1 - 1,2 g/kg/hari`, dan dapat ditingkatkan hingga `> 1,2 - 1,3 g/kgBB/hari` pada kondisi PEW berat atau hiperkatabolik.\n- **Klaim 3:** Rekomendasi komposisi makronutrien lain meliputi lemak `25 - 30%` dari total asupan kalori (lemak jenuh 7-10%, MUFA sampai 20%, PUFA sampai 10%), karbohidrat dari sisa kalori nonprotein (terutama karbohidrat kompleks), serta serat `20 - 25 g/hari`."
  },
  {
    "scenario_id": "V03",
    "ground_truth_document": "PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf",
    "ground_truth_chunk_idx": [
      "54"
    ],
    "query_text_part": "Berapa batasan asupan kalori harian yang mendefinisikan diet sangat rendah kalori (VLCD), berapa durasi maksimal pelaksanaannya, serta apa syarat keselamatan medis yang wajib dipenuhi selama terapi diet tersebut?",
    "reference_answer": "- **Klaim 1:** Diet sangat rendah kalori (*Very Low-Calorie Diet* / VLCD) membatasi asupan energi `< 800 kkal/hari` (sedangkan diet rendah kalori 800-1000 kkal/hari).\n- **Klaim 2:** Terapi diet berdasarkan kalori ini hanya boleh berlangsung maksimal selama `12 minggu`.\n- **Klaim 3:** Terapi wajib diobservasi langsung oleh tim medis dan disertai asupan cairan sebanyak `2 - 3 liter per hari` selama fase puasa."
  },
  {
    "scenario_id": "V04",
    "ground_truth_document": "PNPK 2021 - Tata Laksana Hipertensi Dewasa.pdf",
    "ground_truth_chunk_idx": [
      "43",
      "44"
    ],
    "query_text_part": "Pada pasien hipertensi yang perlu membatasi asupan natrium, berapa perbandingan rasio kandungan natrium dalam MSG dibandingkan garam dapur (NaCl) per 100 gram, berapa persentase penurunan konsumsi natrium jika mengganti setengah sendok teh garam dengan MSG, serta berapa batas anjuran asupan natrium harian?",
    "reference_answer": "- **Klaim 1:** Jumlah natrium dalam MSG adalah `12,28 g / 100 g`, yang setara dengan `sepertiga (1/3)` dari jumlah natrium dalam garam dapur NaCl (`39,34 g / 100 g`).\n- **Klaim 2:** Mengganti `1/2 sendok teh garam NaCl (2,5 gram)` dengan `1/2 sendok teh MSG (2,0 gram)` dapat mengurangi konsumsi natrium sekitar `37%`.\n- **Klaim 3:** Rekomendasi penggunaan natrium sebaiknya tidak lebih dari `2 gram per hari` (setara dengan 5-6 gram NaCl atau 1 sendok teh garam dapur / setara 3 sendok teh MSG), dengan target penurunan hingga `1500 mg per hari` untuk penurunan tekanan darah yang lebih besar."
  },
  {
    "scenario_id": "V05",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "51"
    ],
    "query_text_part": "Berapa batas minimal asupan karbohidrat harian dalam gram bagi orang dewasa penderita diabetes melitus tipe 2 untuk mencukupi glukosa otak, berapa rentang persentase energi dari karbohidrat yang direkomendasikan, serta apa syarat pemilihan jenis bahan makanannya?",
    "reference_answer": "- **Klaim 1:** Asupan karbohidrat harian pada pasien diabetes dewasa direkomendasikan `tidak kurang dari 130 gram per hari` untuk memenuhi kebutuhan glukosa ke otak.\n- **Klaim 2:** Persentase total energi harian dari karbohidrat dianjurkan `minimal 45%` dan dapat mencapai `hingga 65%` dari total energi harian.\n- **Klaim 3:** Sumber karbohidrat harus menggunakan bahan makanan dengan `indeks glikemik (IG) rendah` dan `makanan berserat tinggi` (seperti sayur, buah, biji-bijian, kacang-kacangan, dan produk susu)."
  },
  {
    "scenario_id": "V06",
    "ground_truth_document": "Perkeni Dewasa 2024.pdf",
    "ground_truth_chunk_idx": [
      "123"
    ],
    "query_text_part": "Bagi penyandang diabetes melitus tipe 2, berapa target minimal asupan serat per 1.000 kkal yang dianjurkan dalam terapi nutrisi karbohidrat, bagaimana anjuran terkait konsumsi minuman berpemanis, serta aturan konsistensi karbohidrat bagi pasien yang menggunakan insulin dosis tetap?",
    "reference_answer": "- **Klaim 1:** Karbohidrat yang dianjurkan harus kaya nutrisi dan serat dengan target minimal `≥ 14 gram serat per 1.000 kkal` (dari buah, sayur, biji-bijian, kacang-kacangan/legume, dan susu rendah lemak).\n- **Klaim 2:** Minuman dengan pemanis (termasuk jus buah) sebaiknya dihindari dan diganti dengan air putih atau minuman rendah/tanpa kalori.\n- **Klaim 3:** Bagi penyandang DM yang menggunakan insulin dosis tetap, asupan karbohidrat wajib dikonsumsi dengan `jumlah dan waktu yang konsisten` agar selaras dengan waktu kerja dan dosis insulin."
  },
  {
    "scenario_id": "V07",
    "ground_truth_document": "23-11-21-Panduan-Dislipidemia-2021-Ebook.pdf",
    "ground_truth_chunk_idx": [
      "43"
    ],
    "query_text_part": "Dalam terapi nutrisi medis untuk pengelolaan dislipidemia atau kolesterol tinggi, berapa porsi minimal harian konsumsi buah dan sayur serta biji-bijian, komponen lemak apa yang perlu dibatasi, dan berapa anjuran asupan harian tanaman stanol/sterol serta serat larut air untuk membantu menurunkan kolesterol LDL?",
    "reference_answer": "- **Klaim 1:** Porsi konsumsi buah-buahan dan sayuran direkomendasikan minimal `≥ 5 porsi per hari`, dan biji-bijian minimal `≥ 6 porsi per hari`.\n- **Klaim 2:** Asupan lemak jenuh, lemak trans, dan kolesterol makanan harus dibatasi secara ketat.\n- **Klaim 3:** Makronutrien penurun LDL-C harus mencakup konsumsi tanaman stanol/sterol sebanyak `2 g/hari` dan serat larut air sebanyak `10 - 25 g/hari`."
  },
  {
    "scenario_id": "V08",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Malnutrisi Pada Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "207"
    ],
    "query_text_part": "Bagaimana anjuran klinis mengenai pemberian suplemen nutrisi seperti koenzim Q10, karnitin, taurin, dan antioksidan pada penderita gagal jantung dengan fraksi ejeksi rendah (HFrEF), dan pada kelompok gejala seperti apa aturan ini berlaku?",
    "reference_answer": "- **Klaim 1:** Suplementasi nutrisi koenzim Q10, karnitin, taurin, dan antioksidan `tidak direkomendasikan` untuk terapi gagal jantung HFrEF.\n- **Klaim 2:** Derajat rekomendasi klinis untuk ketidakrekomendasian ini adalah `Rekomendasi B`.\n- **Klaim 3:** Aturan ini berlaku mengikat baik untuk pasien yang sedang mengalami gejala saat ini maupun yang memiliki riwayat gejala sebelumnya."
  },
  {
    "scenario_id": "V09",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf",
    "ground_truth_chunk_idx": [
      "103"
    ],
    "query_text_part": "Pada pasien anak dengan penyakit ginjal kronik yang memiliki kadar vitamin D di bawah 5 ng/mL, apa klasifikasi derajat defisiensinya dan bagaimana pilihan dosis suplementasi awal yang direkomendasikan untuk 4 minggu pertama?",
    "reference_answer": "- **Klaim 1:** Kadar vitamin D `< 5 ng/mL` pada anak PGK diklasifikasikan ke dalam kategori `Defisiensi berat`.\n- **Klaim 2:** Pilihan dosis awal harian adalah vitamin D2 (Ergokalsiferol) atau vitamin D3 (Kolekalsiferol) sebesar `8.000 IU per hari selama 4 minggu`.\n- **Klaim 3:** Pilihan dosis alternatif mingguan adalah `50.000 IU per minggu selama kurun waktu 4 minggu`."
  },
  {
    "scenario_id": "V10",
    "ground_truth_document": "Perkeni Dewasa 2024.pdf",
    "ground_truth_chunk_idx": [
      "120"
    ],
    "query_text_part": "Pada penyandang diabetes melitus tipe 2, apa saja kelompok makanan utama yang dianjurkan dalam pola diet Mediterania, bagaimana anjuran konsumsi produk susu dan telur, serta manfaat metabolik dan kardiovaskular apa yang dikaitkan dengan pola makan tersebut?",
    "reference_answer": "- **Klaim 1:** Pola diet Mediterania berfokus pada konsumsi makanan berbasis tanaman (seperti buah-buahan, sayur-sayuran, biji-bijian, kacang-kacangan), ikan dan makanan laut lain, serta minyak zaitun.\n- **Klaim 2:** Konsumsi produk susu (terutama keju dan yogurt) dianjurkan dalam jumlah sedikit hingga sedang, dan konsumsi telur dibatasi dalam jumlah kurang dari 4 butir per minggu (`<4 butir per minggu`).\n- **Klaim 3:** Pola diet Mediterania dikaitkan dengan penurunan risiko DM, penurunan HbA1c, dan penurunan risiko kardiovaskular."
  },
  {
    "scenario_id": "V11",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "53"
    ],
    "query_text_part": "Berapa anjuran asupan protein harian per kilogram berat badan atau persentase kalori untuk penyandang diabetes melitus tipe 2, bagaimana pertimbangan terhadap asupan protein yang melebihi 2 g/kgBB per hari terkait fungsi ginjal, serta apa saja contoh sumber protein yang direkomendasikan?",
    "reference_answer": "- **Klaim 1:** Asupan protein harian pada pasien diabetes direkomendasikan `tidak kurang dari 1,2 g/kgBB per hari` atau sebesar `10 - 20% dari total asupan kalori` (dibandingkan fisiologis minimal dewasa 0,8-1 g/kgBB/hari).\n- **Klaim 2:** Pemberian protein `melebihi 2 g/kgBB per hari tidak terbukti bermanfaat` dan bahkan dapat `mengganggu fungsi ginjal`.\n- **Klaim 3:** Bahan makanan sumber protein yang direkomendasikan antara lain ikan, ayam tanpa kulit, produk susu tanpa/rendah lemak, kacang-kacangan, dan biji-bijian (mengurangi konsumsi daging sapi, babi, kambing, dan olahan ber-SAFA tinggi)."
  },
  {
    "scenario_id": "V12",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Penyakit Ginjal Kronik Tahun 2023..pdf",
    "ground_truth_chunk_idx": [
      "45"
    ],
    "query_text_part": "Pada pasien dewasa dengan PGK stadium 3–5D, berapa batas maksimal asupan natrium harian yang direkomendasikan, apa tujuan klinis pembatasan tersebut, dan keterampilan praktis apa yang perlu diedukasikan kepada pasien?",
    "reference_answer": "- **Klaim 1:** Batasan asupan natrium yang direkomendasikan bagi pasien dewasa dengan PGK 3-5D adalah `kurang dari 100 mmol/hari` atau `kurang dari 2,3 gram/hari` (`< 2.300 mg/hari`).\n- **Klaim 2:** Pembatasan natrium bertujuan klinis untuk `menurunkan tekanan darah`, `memperbaiki kontrol volume cairan tubuh`, serta membantu mencapai berat badan yang diinginkan.\n- **Klaim 3:** Mengonsumsi diet rendah natrium memerlukan edukasi keterampilan praktis pasien berupa `teknik memasak rendah natrium` dan `keterampilan membaca label informasi nilai gizi makanan/minuman`."
  },
  {
    "scenario_id": "V13",
    "ground_truth_document": "KONSENSUS TATA LAKSANA MULTIDISIPLIN OBESITAS PADA DEWASA 2025.pdf",
    "ground_truth_chunk_idx": [
      "94"
    ],
    "query_text_part": "Pada pasien obesitas dewasa yang menjalani terapi nutrisi, berapa proporsi energi harian yang dianjurkan berasal dari karbohidrat, lemak, dan protein, serta bagaimana batas asupan lemak jenuh, lemak tak jenuh ganda, dan lemak tak jenuh tunggal?",
    "reference_answer": "- **Klaim 1:** Komposisi energi harian yang dianjurkan secara umum adalah karbohidrat sebesar `45-60%`, lemak sebesar `20-25%`, dan protein sebesar `15-20%` dari total kalori harian.\n- **Klaim 2:** Asupan lemak jenuh dibatasi `kurang dari 7% (< 7%)` dari total kalori harian.\n- **Klaim 3:** Asupan lemak tak jenuh ganda (*polyunsaturated fatty acid* / PUFA) dianjurkan `hingga 10%`, dan lemak tak jenuh tunggal (*monounsaturated fatty acid* / MUFA) dianjurkan `hingga 20%` dari total kalori harian."
  },
  {
    "scenario_id": "V14",
    "ground_truth_document": "Pedoman Nasional Pelayanan Kedokteran (PNPK) Tata Laksana Diabetes Melitus Tipe 2 Dewasa..pdf",
    "ground_truth_chunk_idx": [
      "234"
    ],
    "query_text_part": "Bagaimana anjuran pembagian proporsi atau persentase kalori harian bagi penyandang diabetes saat berpuasa Ramadhan untuk sesi sahur dan waktu berbuka?",
    "reference_answer": "- **Klaim 1:** Porsi makan sahur dialokasikan sebesar `30% hingga 40%`, dengan snack sebelum sahur sebesar `10% hingga 20%`.\n- **Klaim 2:** Porsi makanan saat awal berbuka (takjil) dialokasikan sebesar `10% hingga 20%`.\n- **Klaim 3:** Porsi makan utama saat berbuka puasa dialokasikan sebesar `40% hingga 50%` dari total kalori harian."
  },
  {
    "scenario_id": "V15",
    "ground_truth_document": "PEDOMAN NASIONAL PELAYANAN KLINIS TATA LAKSANA OBESITAS DEWASA.pdf",
    "ground_truth_chunk_idx": [
      "57"
    ],
    "query_text_part": "Pada tata laksana obesitas dewasa, bagaimana anjuran penurunan asupan energi harian untuk intervensi diet defisit kalori, serta apa mekanisme penurunan berat badan dan risiko defisiensi mikronutrien dari diet tinggi protein rendah karbohidrat?",
    "reference_answer": "- **Klaim 1:** Total asupan energi per hari direkomendasikan untuk `dikurangi 500 kkal` dengan `restriksi lemak (< 30% dari total kalori)`, protein, dan karbohidrat (Rekomendasi A).\n- **Klaim 2:** Mekanisme penurunan berat badan cepat pada diet tinggi protein rendah karbohidrat dipicu oleh `kehilangan cairan` dan `penekanan nafsu makan akibat ketosis (ketosis-induced appetite suppression)`.\n- **Klaim 3:** Kelemahan nutrisi diet tinggi protein rendah karbohidrat adalah risiko `kekurangan vitamin (A, B12, B6, asam folat, C, E)` dan `mineral (magnesium, kalium, kalsium, zat besi)`, serta perlu kehati-hatian pada penderita sakit ginjal, osteoporosis, atau kadar LDL tinggi."
  }
]$vignettes$::jsonb) AS v(
    scenario_id text, query_text_part text, reference_answer text,
    ground_truth_document text, ground_truth_chunk_idx jsonb
  )
)
UPDATE public.chatbot_telemetry AS t
SET scenario_id = COALESCE(t.scenario_id, v.scenario_id),
    reference_answer = COALESCE(t.reference_answer, v.reference_answer),
    ground_truth_document = COALESCE(t.ground_truth_document, v.ground_truth_document),
    ground_truth_chunk_idx = COALESCE(t.ground_truth_chunk_idx, v.ground_truth_chunk_idx)
FROM scenarios AS v
WHERE lower(btrim(regexp_replace(normalize(t.query_text, NFC), '\s+', ' ', 'g')))
    = lower(btrim(regexp_replace(normalize(v.query_text_part, NFC), '\s+', ' ', 'g')))
  AND (t.scenario_id IS NULL OR t.scenario_id = v.scenario_id)
  AND (t.scenario_id IS NULL OR t.reference_answer IS NULL
       OR t.ground_truth_document IS NULL OR t.ground_truth_chunk_idx IS NULL);

COMMIT;
