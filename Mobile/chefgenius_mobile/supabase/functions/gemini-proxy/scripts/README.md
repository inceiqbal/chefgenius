# Gemini Proxy Scripts

## RAG Retrieval Evaluator

Script: `evaluate_rag_retrieval.js`

Tujuan: evaluasi kualitas retrieval `match_knowledge` tanpa generate embedding ke Gemini (menggunakan embedding chunk yang sudah tersimpan di `knowledge_base`).

### Metric yang dihitung
- `precision@k`
- `hit_rate@k` (minimal 1 dokumen relevan berdasarkan `source`)
- `exact_chunk_hit@k` (ID chunk yang sama muncul di top-k)
- `near_chunk_hit@k` (chunk index dalam rentang toleransi)

### Prasyarat
Pastikan `.env` berisi:

```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

### Jalankan (default)

```bash
npm run eval:rag
```

### Opsi CLI

```bash
node evaluate_rag_retrieval.js --sample-size 50 --k 1,3,5 --threshold 0.2
node evaluate_rag_retrieval.js --category nutrition_guide --source-regex "WHO|Diabetes"
node evaluate_rag_retrieval.js --chunk-idx-tolerance 2
```

### Environment override (opsional)

```env
SAMPLE_SIZE=50
K_VALUES=1,3,5
CATEGORY=nutrition_guide
SOURCE_REGEX=WHO|Diabetes
MATCH_THRESHOLD=0.2
CHUNK_IDX_TOLERANCE=2
```

Catatan: evaluasi ini adalah self-retrieval benchmark sederhana. Cocok untuk regresi retrieval antar perubahan pipeline/index/RPC.

---

## Comprehensive Evaluation Suite (untuk Bab 4 TA)

Script: `evaluate_comprehensive.js`

Menjalankan evaluasi lengkap **15 clinical vignettes** terhadap **3 arsitektur** (baseline, naive RAG, advanced RAG) dengan:
- Semantic retrieval (embedding-based)
- Ranking metrics (MRR, Precision@k, Hit Rate)
- Output detail + summary CSV

### Jalankan

```bash
npm run eval:comprehensive
node evaluate_comprehensive.js --k 1,3,5
```

### Output

- `evaluation_results/evaluation_detailed.json` — Detail per vignette
- `evaluation_results/evaluation_summary.csv` — Ringkasan aggregate per arsitektur

---

## RAGAS Evaluation (Faithfulness, Answer Relevance, Context Relevance)

Script: `evaluate_ragas.js`

Skoring otomatis LLM-as-judge (Gemini) untuk:
- **Faithfulness**: Response grounded di context?
- **Answer Relevance**: Response jawab query?
- **Context Relevance**: Context relevan ke query?

### Jalankan

```bash
npm run eval:ragas
node evaluate_ragas.js --input evaluation_results/evaluation_detailed.json
```

### Output

- `evaluation_results/ragas_scores.json` — Skor per vignette + aggregate

---

## Expert Evaluation + Inter-Rater Reliability

Script: `calculate_interrater_reliability.js`

### 1. Template CSV untuk Registered Dietitian (RD)

Buat dua file CSV dari masing-masing RD:

**expert_evaluation_rd1.csv:**

```csv
vignette_id,accuracy_score,safety_score,completeness_score,overall_quality,notes
V01,5,5,4,4.67,"Excellent recommendations with clear guidelines"
V02,4,5,3,4.0,"Good but missing dosage information"
```

**expert_evaluation_rd2.csv:**

```csv
vignette_id,accuracy_score,safety_score,completeness_score,overall_quality,notes
V01,5,5,5,5.0,"Outstanding, clinically sound"
V02,4,4,3,3.67,"Accurate but could be more detailed"
```

### 2. Hitung Inter-Rater Reliability

```bash
npm run eval:interrater
node calculate_interrater_reliability.js --rd1-file expert_evaluation_rd1.csv --rd2-file expert_evaluation_rd2.csv
```

### Output

- `interrater_reliability.json` — ICC(3,1), Cohen's Kappa, Pearson r per metric

---

## Full Evaluation Workflow (Bab 4)

1. **Comprehensive Metrics** → MRR, Precision@k, Hit Rate
2. **RAGAS Scoring** → Faithfulness, Answer Relevance, Context Relevance
3. **Expert Evaluation** (input dari 2 RD) → ICC(3,1), Cohen's Kappa
