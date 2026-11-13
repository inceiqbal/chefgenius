# Telemetry Schema untuk RAGAS Evaluation

## Overview
Skema telemetry yang dirancang untuk mendukung evaluasi RAGAS (Retrieval-Augmented Generation Assessment) dengan metrik:
- **Answer Relevancy**: Relevansi jawaban terhadap query
- **Faithfulness**: Konsistensi jawaban terhadap retrieved contexts
- **Context Relevance**: Relevansi konteks yang diambil terhadap query

---

## Kolom Baru (Added 2026-05-04)

### 🔴 WAJIB - Required untuk RAGAS Metrics

#### `query_text` (TEXT)
- **Tujuan**: Teks pertanyaan/input asli dari user
- **RAGAS API**: Memetakan ke `user_input` parameter
- **Digunakan oleh**: Answer Relevancy, Context Relevance
- **Contoh**:
  ```
  "Apakah ada pengurangan kalori untuk usia 50 tahun dengan diabetes?"
  ```

#### `response_text` (TEXT)
- **Tujuan**: Teks jawaban/output dari model
- **RAGAS API**: Memetakan ke `response` parameter
- **Digunakan oleh**: Answer Relevancy, Faithfulness
- **Catatan**: Bisa sama dengan `response_pointer` atau bisa berbeda jika ada post-processing
- **Contoh**:
  ```
  "Halo! Saya **Chef Cei**, Ahli Gizi dan Konsultan Kuliner Sehat..."
  ```

#### `retrieved_results` (JSONB)
- **Tujuan**: Hasil retrieval terstruktur dengan urutan ranking
- **RAGAS API**: Bisa diekstrak menjadi `retrieved_contexts` (array text) atau `context_ids` (array identifiers)
- **Digunakan oleh**: Faithfulness, Context Relevance, MRR calculation
- **Format**:
  ```json
  [
    {
      "rank": 1,
      "doc_id": "Perkeni-Dewasa-2024",
      "chunk_id": 73,
      "chunk_text": "Pada usia 50 tahun, tubuh mengalami penurunan Basal Metabolic Rate (BMR)...",
      "title": "Perkeni Dewasa 2024",
      "similarity_score": 0.7447,
      "reranker_score": 1.948
    },
    {
      "rank": 2,
      "doc_id": "Pedoman-DM-2021",
      "chunk_id": 48,
      "chunk_text": "Kebutuhan kalori basal memang perlu disesuaikan seiring bertambahnya usia...",
      "title": "Pedoman Pengelolaan Diabetes Melitus 2021",
      "similarity_score": 0.7071,
      "reranker_score": 1.822
    }
  ]
  ```
- **Critical**: Urutan `rank` harus konsisten karena MRR dan Context Relevance bergantung pada posisi hasil relevan

---

### 🟡 SUPPORT - Useful untuk meningkatkan evaluasi

#### `scenario_id` (UUID)
- **Tujuan**: Link ke vignette/scenario dari evaluation dataset
- **Foreign Key**: `vignettes.id` (jika ada tabel vignettes)
- **Kegunaan**: 
  - Tracking dataset dan replay
  - Grouping hasil per scenario
  - Audit dan reproducibility
- **Contoh**: `550e8400-e29b-41d4-a716-446655440000`

#### `ground_truth_context_ids` (JSONB)
- **Tujuan**: Array chunk IDs yang relevan menurut ground truth
- **Kegunaan**:
  - Perbandingan dengan `retrieved_results` untuk MRR calculation
  - Context relevance evaluation (precision/recall dari retrieval)
  - Validasi relevance judgement
- **Format**:
  ```json
  [73, 48, 52, 74]
  ```

#### `reference_answer` (TEXT)
- **Tujuan**: Jawaban ground truth / golden reference
- **RAGAS API**: Optional, bisa digunakan untuk perbandingan tambahan
- **Kegunaan**:
  - Audit dan debugging
  - Similarity comparison dengan model response
  - Manual evaluation reference
- **Catatan**: **BUKAN** wajib untuk 3 metrik RAGAS utama, tapi berguna untuk enhanced evaluation

---

### 🟢 BONUS - Untuk analisis biaya/performa

#### `token_usage_input` (INTEGER)
- **Tujuan**: Jumlah input tokens (split dari `token_usage` JSON)
- **Kegunaan**: Analisis biaya, performa LLM, query efficiency
- **Contoh**: `393`

#### `token_usage_output` (INTEGER)
- **Tujuan**: Jumlah output tokens (split dari `token_usage` JSON)
- **Kegunaan**: Analisis biaya, response length, performa
- **Contoh**: `936`

---

## Mapping ke RAGAS API

### Single-turn sample format untuk RAGAS:

```python
from ragas import evaluate
from ragas.metrics import (
    context_precision,
    faithfulness,
    answer_relevancy,
)

# Dari schema telemetry -> RAGAS format
ragas_sample = {
    "user_input": row["query_text"],           # WAJIB
    "response": row["response_text"],          # WAJIB
    "retrieved_contexts": [                    # WAJIB (dari retrieved_results)
        r["chunk_text"] for r in json.loads(row["retrieved_results"])
    ],
    "reference": row["reference_answer"],      # OPTIONAL
}

# Evaluate
result = evaluate(
    dataset=[ragas_sample],
    metrics=[
        answer_relevancy,
        faithfulness,
        context_precision,
    ]
)
```

### MRR Calculation (tidak built-in RAGAS, tapi bisa pakai retrieved_results):

```python
def calculate_mrr(retrieved_chunk_ids, ground_truth_ids):
    """Mean Reciprocal Rank untuk evaluasi retrieval."""
    for rank, chunk_id in enumerate(retrieved_chunk_ids, start=1):
        if chunk_id in ground_truth_ids:
            return 1 / rank
    return 0.0

# Dari schema
retrieved_ids = [r["chunk_id"] for r in json.loads(row["retrieved_results"])]
ground_truth_ids = json.loads(row["ground_truth_context_ids"])
mrr = calculate_mrr(retrieved_ids, ground_truth_ids)
```

---

## Backfill Strategy

### Phase 1: Transform existing data
```sql
-- Jalankan migration SQL terlebih dahulu
-- Jalankan Python backfill script untuk:
--   1. Split token_usage JSON -> token_usage_input/output
--   2. Transform reranker_scores -> retrieved_results
--   3. Copy response_text jika ada dari response_pointer
```

### Phase 2: Populate dari vignettes (jika ada)
```sql
-- Join dengan vignettes table untuk populate scenario_id
-- Populate ground_truth_context_ids dari vignette dataset
```

### Phase 3: Forward strategy (new data)
```python
# Di aplikasi pipeline, ensure populate:
# - query_text: dari user input/prompt
# - response_text: dari model output
# - retrieved_results: dari retrieval + reranking pipeline
# - scenario_id: dari vignette mapping
# - ground_truth_context_ids: dari evaluation dataset
```

---

## Indexes untuk Performance

```sql
-- Untuk faster queries
CREATE INDEX idx_chatbot_telemetry_scenario_id ON chatbot_telemetry(scenario_id);
CREATE INDEX idx_chatbot_telemetry_query_text_gin ON chatbot_telemetry USING GIN(query_text gin_trgm_ops);
CREATE INDEX idx_chatbot_telemetry_retrieved_results ON chatbot_telemetry USING GIN(retrieved_results);
CREATE INDEX idx_chatbot_telemetry_run_id_scenario ON chatbot_telemetry(run_id, scenario_id);
```

---

## Checklist sebelum production

- [ ] Migration SQL sudah dijalankan di Supabase
- [ ] Backfill script sudah selesai (min. 1000 rows test)
- [ ] Indexes sudah created
- [ ] Validasi data:
  - [ ] query_text tidak ada yang NULL (critical rows)
  - [ ] retrieved_results valid JSON dengan rank terurut
  - [ ] token_usage_* extracted correctly
- [ ] Test RAGAS evaluation dengan sample data
- [ ] Update application pipeline untuk populate kolom baru
- [ ] Documentation updated untuk team

---

## FAQ

**Q: Apakah query_text wajib diisi untuk semua historical data?**
A: Tidak semua. Backfill akan diisi dengan NULL atau dari prompt_id mapping jika ada. Untuk new data, wajib diisi di aplikasi.

**Q: Bagaimana jika reranker_scores tidak ada?**
A: retrieved_results bisa diisi dari similarity scores saja, atau skip jika tidak ada retrieval di baseline mode.

**Q: Apakah reference_answer harus ada?**
A: Tidak. RAGAS 3 metrik utama tidak butuh reference_answer. Tapi jika ada, bisa digunakan untuk enhanced evaluation.

**Q: Berapa ukuran kolom JSONB untuk retrieved_results?**
A: Tergantung jumlah retrieved documents. Typical: 5-10 results = 2-5KB. PostgreSQL handle baik sampai ratusan KB per row.

---

## References
- RAGAS Documentation: https://docs.ragas.io/
- PostgreSQL JSONB: https://www.postgresql.org/docs/current/datatype-json.html
