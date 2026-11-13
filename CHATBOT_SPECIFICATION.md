# 📋 SPESIFIKASI CHATBOT CHEFGENIUS (LENGKAP)

---

## 1. IDENTITAS CHATBOT

**Nama:** Chef Cei (Chatbot Assistant)
**Peran:** Asisten Dapur Pintar & Konsultan Gizi Kuliner
**Platform:** Aplikasi Mobile Flutter (ChefGenius)
**Teknologi:** Google Gemini API via Supabase Edge Function
**Status:** MVP untuk Tesis (Food Consultation Feature)

---

## 2. TOPIK & DOMAIN PEMBAHASAN

Chatbot Chef Cei mengbahas topik-topik berikut:

### A. Konsultasi Nutrisi & Kesehatan 🏥

#### Diabetes Management
- Target kalori harian berdasarkan usia & kondisi kesehatan
- Pengurangan kalori aman (500-750 kkal/hari)
- Rekomendasi karbohidrat untuk diabetik
- Monitoring gula darah & HbA1c
- Contoh: Untuk penyandang DM yang gemuk, kebutuhan kalori dikurangi 20-30%
- Reference: Perkeni Dewasa 2024, IDF Rec 2025

#### Tekanan Darah & Hipertensi
- Target tekanan darah (<130/80 mmHg)
- Target sistolik <120 mmHg untuk high-risk individuals
- Pengelolaan sodium & potassium intake (0.5-1.0 g/hari)
- Diet DASH recommendations
- Reference: ESC 2024 BP Guidelines

#### Kolesterol & Dyslipidemia
- LDL-C target untuk pasien very high-risk (<55 mg/dL)
- Penurunan nilai LDL-C ≥50% dari baseline
- Makanan pengontrol kolesterol
- Pola makan Mediterania
- Reference: ESC/EAS Dyslipidaemia Guidelines 2025

#### Penyakit Ginjal Kronis (CKD)
- Rekomendasi protein intake (0.8 g/kg/hari) untuk non-dialisis
- Kebutuhan energi 25-35 kkal/kg/hari
- Pembatasan mineral elektrolit
- Monitoring volume cairan
- Reference: KDIGO 2022, KDOQI 2020

#### Pengelolaan Berat Badan & Obesitas
- Defisit energi untuk weight loss: 500-750 kkal/hari
- Target penurunan 5%, 7-10%, ≥10% untuk berbagai kondisi
- Berbagai pendekatan diet (low-carb, low-fat, Mediterranean, dll)
- Terapi GLP-1 supportive information
- Reference: ADA 2026, VA-DoD 2025, WHO GLP-1 2025

#### Penyakit Hati (MASLD - Metabolic Dysfunction-Associated Steatotic Liver Disease)
- Target berat badan reduction: 
  - ≥5% mengurangi lemak hati
  - 7-10% memperbaiki inflamasi hati
  - ≥10% memperbaiki fibrosis hati
- Diet Mediterranean guidelines
- Mengurangi makanan ultra-processed
- Menghindari minuman berpemanis
- Reference: EASL-EASD-EASO 2024

#### Kehamilan & Gestational Diabetes (GDM)
- Minimum karbohidrat harian: 175g
- Target glukosa puasa: <95 mg/dL
- Target glukosa 1-jam postprandial: <140 mg/dL
- Target glukosa 2-jam postprandial: <120 mg/dL
- Kebutuhan nutrisi spesifik ibu hamil
- Reference: ADA Diabetes in Pregnancy 2026

### B. Manajemen Alergi & Intoleransi 🚫

- **Nut Allergy** (Kacang)
- **Seafood Allergy** (Makanan Laut - Ikan, Udang, Kepiting, Kerang)
- **Dairy Allergy** (Alergi Susu/Lactose Intolerant)
- **Gluten-Free Diet** (Bebas Gandum/Sereal)
- **Jain Diet** (Tanpa Bawang/Bawang Merah)
- Deteksi & pencegahan reaksi alergi
- Alergen cross-contamination awareness

### C. Generasi Resep Customized 🍳

- Resep berdasarkan bahan yang tersedia (Pantry Items)
- Filter by Negara/Region Kuliner
- Persona Chef Style (5 varian)
- Substitusi bahan untuk diet khusus
- Estimasi Nutrisi otomatis:
  - Kalori (kcal)
  - Protein (g)
  - Karbohidrat (g)
  - Lemak (g)
- Halal Status detection
- Durasi & Jumlah Porsi
- Language Adaptation (Resep dalam bahasa user)

### D. Referensi Standar Nutrisi & Pedoman Klinis 📚

**Organisasi & Guidelines yang Direferensikan:**
- **ADA (American Diabetes Association)** - Pedoman Diabetes 2026
- **IDF (International Diabetes Federation)** - Global Guidelines 2025
- **ESC (European Society of Cardiology)** - BP Management 2024, Dyslipidaemia 2025
- **EASL-EASD-EASO** - Liver Disease Guidelines 2024
- **KDIGO** - Diabetes in CKD 2022
- **KDOQI** - Nutrition in CKD 2020
- **WHO** - GLP-1 Therapy Guidelines 2025
- **TKPI (Tabel Komposisi Pangan Indonesia)** - Nutrient Database
- **Perkeni** - Pedoman DM Indonesia
- **VA-DoD** - Clinical Practice Guideline Obesity 2025
- **Pedoman Kesehatan Indonesia** - GERMAS, Label GGL, dll

---

## 3. FITUR & KAPABILITAS

### A. Chat Interaktif 💬
- **Streaming Response:** Respon bertahap (real-time typing effect)
- **Context Awareness:** Memahami resep yang sedang didiskusikan
- **Multi-turn Conversation:** Percakapan berkelanjutan dengan history
- **Background Processing:** Lanjut processing jika user meninggalkan screen
- **Markdown Support:** Response dengan formatting, list, emphasis

### B. Konteks Data User 👤
- **Pantry Items:** Bahan tersedia di dapur user
- **Diet Preferences:** Preferensi diet pilihan user (Vegan, Keto, Low-Sugar, dll)
- **Allergies:** Alergi & intoleransi yang terdaftar
- **Current Recipe Context:** Resep yang sedang dimasak
- **User Level:** Level user (unlock fitur tertentu di Lv. 5+)
- **XP Tracking:** Experience points dari aktivitas masak

### C. RAG Mode (Retrieval-Augmented Generation) 🔍
3 Mode tersedia:
1. **'none'** - Hanya Gemini, tanpa retrieval
2. **'naive'** - Retrieval sederhana dari knowledge base
3. **'advanced'** - RAG kompleks dengan reranking & metadata

### D. Telemetry & Evaluation 📊
- **Chatbot Telemetry Table** - Tracking semua pertanyaan & response
- **RAGAS Evaluation** - Metrik:
  - Answer Relevancy - Relevansi jawaban terhadap query
  - Faithfulness - Konsistensi jawaban terhadap retrieved contexts
  - Context Relevance - Relevansi konteks terhadap query
- **Token Usage Tracking** - Input/Output token monitoring
- **Latency Measurement** - Response time tracking
- **Safety Flagging** - Deteksi topik sensitif/berbahaya
- **MRR Calculation** - Mean Reciprocal Rank untuk retrieval ranking

---

## 4. SAFETY & CONTENT FILTERING 🛡️

### A. Safety Rules Applied

```
1. ❌ BLOCK: Diagnosis permintaan ("Saya punya gejala...")
2. ❌ BLOCK: Resep obat-obatan atau treatment medis
3. ❌ BLOCK: Klaim penyembuhan tanpa disclaimer
4. ⚠️ FLAG: Topik alergi/kesehatan serius → Disclaimer ditambah
5. ⚠️ FLAG: Resep dengan alergen → Warning notification
```

### B. Disclaimer Standar

**Health Disclaimer (Mandatory untuk response kesehatan):**
```
"Informasi ini hanya untuk tujuan edukasi dan tidak menggantikan 
saran profesional kesehatan. Jika memiliki kondisi kesehatan khusus 
atau alergi, konsultasikan dengan profesional kesehatan atau ahli 
gizi terdaftar SEBELUM mengikuti resep apapun."
```

**AI Recipe Disclaimer:**
```
"Resep yang dihasilkan AI mungkin belum teruji. 
Disediakan 'as-is' tanpa jaminan. Anda bertanggung jawab 
penuh atas penggunaan, pengolahan, dan konsumsi."
```

### C. Safety Post-Processing
- Block diagnosis/medication keywords
- Check allergy contradictions
- Add disclaimer if health-related
- Normalize units (gr → gram)
- Alergen detection & warning

---

## 5. ARSITEKTUR TEKNIS

```
User (Mobile App - Flutter)
    ↓
ChatbotService (Dart Service)
    ├─ Message Management
    ├─ Context Collection
    └─ Stream Handling
    ↓
GeminiProxyService (HTTP Client)
    └─ Secure API communication
    ↓
Supabase Edge Function (gemini-proxy)
    ├─ Safety Filtering
    ├─ Prompt Engineering
    ├─ Token Counting
    └─ Telemetry Logging
    ↓
Google Gemini API (LLM Processing)
    ├─ Model: gemini-3-flash-preview
    ├─ Temperature: 0.4 (stabil & konsisten)
    ├─ Max Tokens: 1024-8192
    └─ System Prompt: Persona + Constraints
    ↓
Response Processing
    ├─ Safety Post-Processing
    ├─ Alergen Detection
    ├─ Unit Normalization
    └─ Response Validation
    ↓
Supabase PostgreSQL (Data Persistence)
    ├─ chat_messages table (History)
    ├─ chatbot_telemetry table (Logging)
    └─ review_queue table (Flagged content)
    ↓
User Screen (Real-time Streaming)
    └─ Markdown rendered chat UI
```

---

## 6. PERSONA CHEF CEI (5 VARIAN) 👨‍🍳

Masing-masing persona memiliki instruksi unik & level unlock:

### Standard Chef (Level 0)
- **Gaya:** Profesional & Friendly
- **Instruksi:** "Use polite, professional, and informative language like a standard chef."
- **Contoh Komunikasi:** Bahasa sopan, penjelasan detail, fokus pada teknik & fakta

### Loving Grandma (Level 2)
- **Gaya:** Hangat & Peduli
- **Instruksi:** "Act as an old grandmother who spoils her grandchild. Call the user 'My dear grandchild', 'Sweetie', or 'Kid'. Use very gentle, loving language, and nag them to eat more ('Come on, eat more', 'Don't be too skinny'). Treat the user as your golden grandchild."
- **Contoh Komunikasi:** Nagging dengan penuh kasih sayang, panggilan hangat, encouraging eating

### Nutritionist (Level 5)
- **Gaya:** Serius & Detail Medis
- **Instruksi:** "Act as a strict Nutritionist. Focus descriptions on the health benefits of each ingredient. Use smart medical/nutritional terms."
- **Contoh Komunikasi:** Istilah medis, fokus benefit kesehatan, data nutrisi detail, scientific approach

### Beloved Wife (Level 7)
- **Gaya:** Romantis & Spoiled
- **Instruksi:** "Act as a young wife who is deeply in love ('bucin') with her husband. Call the user 'Honey', 'Darling', or 'Hubby'. Use spoiled, flirty, attentive language, and always want to provide the best dish for your beloved husband. Insert romantic words."
- **Contoh Komunikasi:** Panggilan romantis, bahasa yang memanjakan, fokus pada kepuasan partner

### Strict Chef (Level 10)
- **Gaya:** Fierce & Sarcastic (Gordon Ramsay-style)
- **Instruksi:** "Act as a Celebrity Chef who is FIERCE, perfectionist, and sarcastic (like Gordon Ramsay). Use challenging language, slightly belittling but still providing a very delicious recipe. Insert shouting (ALL CAPS) occasionally."
- **Contoh Komunikasi:** Challenging, sarcastic, perfeksionist, ALL CAPS untuk emphasis, demanding quality

---

## 7. PROMPT ENGINEERING 🧠

### System Prompt Structure

```
1. ROLE DEFINITION
   └─ "Anda adalah Chef Cei, asisten dapur pintar yang siap membantu..."

2. CONTEXT GATHERING
   ├─ Pantry items (Hive local storage)
   ├─ Diet preferences (SharedPreferences)
   ├─ Allergies
   └─ Current recipe (optional)

3. CONSTRAINT RULES
   ├─ Language Adaptation (Output dalam bahasa user)
   ├─ Safety Boundaries
   ├─ Disclaimer Requirements
   └─ Format Specifications

4. PERSONA INJECTION
   └─ Selected chef personality instruction

5. KNOWLEDGE BASE
   ├─ Clinical Guidelines References
   ├─ Nutrition Database (TKPI)
   ├─ Recipe Generation Rules
   └─ Health Consultation Rules

6. OUTPUT FORMAT
   ├─ Markdown formatting
   ├─ JSON structure untuk recipe
   └─ Clear sectioning & readability
```

### Prompt Components

**For Recipe Generation:**
- Language Adaptation: Detect user language & output in same language
- Diet Enforcement: Apply strict diet rules based on user preferences
- Nutrition Calculation: Mandatory nutrition object per recipe
- Halal Status: Always include halal status detection
- Substitution Mention: Explicitly mention any substitutions made

**For Health Consultation:**
- Always include disclaimer if health-related
- Reference to clinical guidelines
- Evidence-based recommendations
- Allergy contradiction checking
- User context consideration

---

## 8. DATABASE SCHEMA 🗄️

### chat_messages Table
```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id),
  message TEXT NOT NULL,
  is_user BOOLEAN NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

**Fields:**
- `id` - Unique identifier (UUID)
- `user_id` - Foreign key ke profiles table
- `message` - Konten chat (teks)
- `is_user` - Boolean: True = user message, False = bot response
- `created_at` - Timestamp pembuatan
- `updated_at` - Timestamp update terakhir

### chatbot_telemetry Table (RAGAS Evaluation)
```sql
CREATE TABLE chatbot_telemetry (
  run_id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id),
  query_text TEXT NOT NULL,
  response_text TEXT NOT NULL,
  retrieved_results JSONB,
  ground_truth_context_ids JSONB,
  scenario_id UUID,
  reference_answer TEXT,
  safety_flag BOOLEAN DEFAULT FALSE,
  flag_reason TEXT,
  token_usage_input INTEGER,
  token_usage_output INTEGER,
  latency_ms INTEGER,
  prompt_id UUID,
  prompt_hash TEXT,
  response_pointer TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Fields Wajib (RAGAS Required):**
- `query_text` - Pertanyaan user asli
- `response_text` - Jawaban bot
- `retrieved_results` - Hasil retrieval terstruktur dengan ranking

**Fields Support (Opsional tapi berguna):**
- `scenario_id` - Link ke vignette/scenario
- `ground_truth_context_ids` - Chunk IDs relevan menurut ground truth
- `reference_answer` - Jawaban golden reference

**Fields Bonus (Untuk analisis biaya/performa):**
- `token_usage_input` - Input token count
- `token_usage_output` - Output token count
- `latency_ms` - Response time dalam milliseconds

### review_queue Table (Moderation)
```sql
CREATE TABLE review_queue (
  id UUID PRIMARY KEY,
  run_id UUID NOT NULL REFERENCES chatbot_telemetry(run_id),
  flag_reason TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'pending',
  reviewer_id UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Status:** pending, approved, rejected

---

## 9. LIMITATION & FEATURES ⚙️

### A. Batasan Chatbot

**✅ BISA LAKUKAN:**
- Konsultasi nutrisi general education
- Rekomendasi resep sehat berdasarkan guidelines
- Edukasi kesehatan based on clinical evidence
- Jawab pertanyaan tentang bahan/teknik masak
- Alergen awareness & allergy management
- Meal planning recommendations
- Nutrition information & calculation

**❌ TIDAK BOLEH LAKUKAN:**
- Memberikan diagnosa medis ("Anda punya diabetes")
- Resep obat atau treatment klinis
- Klaim penyembuhan penyakit ("Ini bisa menyembuhkan kanker")
- Mengganti saran dokter/ahli gizi profesional
- Riset medis mendalami
- Prescription medication advice
- Replace professional medical consultation

### B. Features MVP (Current)

1. ✅ Chat Interface dengan Streaming Response
2. ✅ Context-aware responses dengan user data
3. ✅ Safety filtering & flagging system
4. ✅ Telemetry logging untuk RAGAS evaluation
5. ✅ Multi-language support (Indonesian/English)
6. ✅ Background processing jika user minimize
7. ✅ Message history sync via Supabase
8. ✅ 5 Persona chef styles dengan level unlock

### C. Features In Development

- ⏳ Advanced RAG dengan reranking
- ⏳ Multi-modal input (image recognition)
- ⏳ Voice input/output support
- ⏳ Offline chat capability
- ⏳ Extended knowledge base integration
- ⏳ Personalized nutrition planning

---

## 10. DISCLAIMER & COMPLIANCE ⚖️

### Health Disclaimer (Mandatory)
```
🔴 SELALU TAMPILKAN untuk response kesehatan:

"Chef Genius bukan layanan medis atau nutrisi profesional. 
Kami tidak memberikan nasihat medis, diet klinis, atau 
rekomendasi kesehatan khusus. Jika memiliki alergi, kondisi 
kesehatan tertentu, atau kebutuhan diet khusus, konsultasikan 
dengan tenaga kesehatan atau ahli gizi profesional SEBELUM 
mengikuti resep apapun."
```

### AI Recipe Disclaimer
```
🟡 SELALU TAMPILKAN untuk AI-generated recipes:

"Resep yang dihasilkan AI mungkin belum teruji. 
Disediakan 'as-is' tanpa jaminan. Anda bertanggung jawab 
penuh atas penggunaan, pengolahan, dan konsumsi resep ini."
```

### User Responsibility
```
🟠 DOKUMENTASIKAN:

• Pengguna minimal 13 tahun
• User account required untuk save recipes & pantry
• User responsible untuk account security
• User responsible untuk preparation & consumption
• Public content di Inzara community bersifat publik
```

---

## 11. EVALUATION METRICS (RAGAS) 📈

### RAGAS Metrics Calculation

| Metrik | Formula | Interpretasi | Target |
|--------|---------|--------------|--------|
| **Answer Relevancy** | Semantic similarity antara query dan response | Seberapa relevan jawaban dengan pertanyaan | > 0.8 |
| **Faithfulness** | Consistency check: response tetap konsisten dengan retrieved contexts | Tidak ada hallucination/informasi palsu | > 0.75 |
| **Context Relevance** | Proportion of relevant docs dalam retrieved results | Kualitas retrieval step | > 0.7 |
| **MRR** | 1 / rank(first relevant document) | Seberapa top-ranked dokumen relevan | > 0.5 |

### RAGAS API Parameters
```
user_input: query_text
response: response_text
retrieved_contexts: extracted dari retrieved_results
context_ids: extracted dari retrieved_results
ground_truth_context_ids: (optional) untuk validation
```

---

## 12. USE CASES 🎯

### Scenario 1: Diabetes Management
```
User: "Saya diabetik, apa resep rendah gula yang enak?"

Bot Response:
✅ Kalori calculation: 500-750 kkal deficit
✅ Ingredient substitution: Replace sugar dengan alternative
✅ Health disclaimer ditampilkan
✅ Reference guideline (Perkeni, ADA)
✅ Context: Pantry items + diet preference
```

### Scenario 2: Alergi Management
```
User: "Saya alergi kacang, ada resep mudah?"

Bot Response:
✅ Check alergi list dari user profile
✅ Generate nut-free recipe only
✅ Explicit mention: "No nuts, 100% nut-free"
✅ Warning jika resep mengandung potential cross-contamination
```

### Scenario 3: Weight Management
```
User: "Mau turun 5kg, resep apa aja?"

Bot Response:
✅ Energy deficit calculation: 500-750 kkal/hari
✅ Multiple recipe options dengan kalori info
✅ Duration: untuk mencapai target 5kg (~10-14 minggu)
✅ Reference: ADA, VA-DoD guidelines
```

### Scenario 4: Alergen Alert System
```
User: Kirim resep seafood
System: ⚠️ "Anda punya seafood allergy terdaftar! 
         Apakah Anda yakin ingin resep ini?"
         [Cancel] [Proceed Anyway]
```

### Scenario 5: Nutrient Information
```
User: "Berapa kalori dalam resep ini?"

Bot Response:
✅ Breakdown: Kalori, Protein, Carbs, Fat
✅ Per serving information
✅ Comparison dengan daily recommended intake
✅ Source: TKPI nutrient database
```

### Scenario 6: Clinical Guideline Question
```
User: "Berapa limit gula per hari untuk diabetik?"

Bot Response:
✅ Evidence-based recommendation
✅ Citation: Clinical guideline (contoh: Perkeni 2024)
✅ Personalized: Tergantung kondisi individual
✅ Disclaimer: Konsultasi dengan ahli gizi
```

---

## 13. TECHNOLOGY STACK 🔧

### Frontend
- **Framework:** Flutter
- **Language:** Dart
- **State Management:** Provider
- **UI Components:** 
  - Flutter Markdown untuk chat rendering
  - Custom AnimationController untuk typing effect
  - Modern alert dialogs

### Backend
- **Database:** Supabase PostgreSQL
- **Backend Logic:** Supabase Edge Functions (Deno TypeScript)
- **Storage:** Supabase Storage (Response cache)
- **Auth:** Supabase Authentication

### LLM & AI
- **LLM Model:** Google Gemini API (gemini-3-flash-preview)
- **Evaluation:** RAGAS Python Library
- **Knowledge Base:** Clinical Guidelines PDFs, TKPI database

### Development Tools
- **Version Control:** Git / GitHub
- **Testing:** Dart/Flutter test framework
- **Evaluation:** RAGAS for RAG system evaluation
- **Monitoring:** Telemetry logging & error tracking

### APIs & Services
- **Google Gemini API** - LLM processing
- **Supabase API** - Database & functions
- **PDF Processing** - Knowledge base ingestion

---

## 14. KNOWLEDGE BASE VIGNETTES 📖

Sistem menggunakan 15+ vignettes (test scenarios) untuk RAGAS evaluation:

### V01: Diabetes Calorie Reduction
- Query: "Untuk penyandang diabetes yang tubuhnya..."
- Context: Perkeni Dewasa 2024.pdf
- Claim: DM gemuk butuh reduce kalori 20-30%

### V02: Carbohydrate Impact on HbA1c
- Query: "Kalau saya mengurangi proporsi sumber za..."
- Context: IDF_Rec_2025.pdf
- Claim: 10% decrease carbs = 0.2% HbA1c reduction after 6 months

### V03: Blood Pressure Target
- Query: "Dengan riwayat penyakit gula dan ganggua..."
- Context: CVD Standards 2026.pdf
- Claim: Target BP <130/80 mmHg, <120 mmHg untuk high-risk

### V04-V15: Various clinical scenarios covering:
- Potassium intake recommendations
- LDL-C targets
- Liver fat reduction targets
- Protein intake for CKD
- Energy requirements
- Weight management protocols
- GLP-1 therapy guidelines
- Pregnancy nutrition
- TKPI nutrient data
- Indonesian health policies

---

## 15. DEVELOPMENT ROADMAP 🗺️

### Phase 1: MVP (Current)
- ✅ Chat interface dengan streaming
- ✅ Basic RAG (naive mode)
- ✅ Safety filtering
- ✅ Telemetry logging
- ✅ 5 persona styles

### Phase 2: Enhancement (Q2-Q3 2026)
- Advanced RAG dengan reranking
- Extended knowledge base
- Performance optimization
- RAGAS evaluation complete

### Phase 3: Extended (Q4 2026+)
- Multi-modal input (image)
- Voice I/O
- Offline capability
- Advanced personalization
- Integration dengan health wearables

---

## 16. CONTACT & SUPPORT 📞

**Developer:** Ince Iqbal Aulia Salam
- **Instagram:** @inceiqbal
- **WhatsApp:** 087845245720
- **Email:** inceiqbals6@gmail.com

---

## 17. LICENSE & COMPLIANCE ⚖️

**Terms & Conditions:**
- App untuk users ≥13 tahun
- Non-commercial personal use only
- AI features provided as-is
- Health disclaimer mandatory
- User content di Inzara bersifat publik
- Moderation & reporting system available

**Privacy Policy:**
- Data stored di Supabase (3rd party secure service)
- Password hashed & encrypted
- No selling personal data to 3rd parties
- User control untuk access/update profile
- Full transparency tentang data usage

---

**Last Updated:** May 11, 2026
**Documentation Version:** 1.0
**Status:** Production MVP