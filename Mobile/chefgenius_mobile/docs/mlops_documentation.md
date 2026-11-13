# MLOps Documentation for ChefGenius Chatbot

## Overview

Dokumen ini menjelaskan konsep dan implementasi MLOps/LLMOps pada chatbot Chef Cei dalam aplikasi ChefGenius.

---

## Key Identifiers

### 1. run_id

**Definisi**: UUID v4 unik yang dihasilkan untuk setiap permintaan chatbot.

**Tujuan**:
- Traceability: Melacak satu request dari awal hingga akhir
- Debugging: Mengidentifikasi log dan error spesifik
- Correlation: Menghubungkan telemetry, response, dan review queue

**Format**: `550e8400-e29b-41d4-a716-446655440000`

**Lokasi Penyimpanan**:
- Table: `chatbot_telemetry.run_id`
- Table: `review_queue.run_id` (foreign key)
- Response JSON: `{"run_id": "..."}`

**Cara Generate**:
```typescript
const runId = crypto.randomUUID();
```

---

### 2. model_version

**Definisi**: Versi model Gemini yang digunakan untuk generate response.

**Tujuan**:
- Reproducibility: Mengetahui model mana yang menghasilkan respons tertentu
- Comparison: Membandingkan kualitas antar versi model
- Audit: Tracking perubahan model dari waktu ke waktu

**Format**: `2026-01-10` (format tanggal Google)

**Lokasi Penyimpanan**:
- Table: `chatbot_telemetry.model_version`
- Constant di Edge Function: `MODEL_VERSION`

**Sumber**:
- Response Gemini API: `usageMetadata.modelVersion`
- Atau hardcoded di Edge Function jika tidak tersedia

---

### 3. prompt_version (prompt_id)

**Definisi**: Identifier versi prompt template yang digunakan.

**Tujuan**:
- Version Control: Tracking perubahan prompt dari waktu ke waktu
- A/B Testing: Membandingkan efektivitas prompt berbeda
- Rollback: Kembali ke versi prompt sebelumnya jika ada masalah

**Format**: `chef_cei_v1.2`

**Lokasi Penyimpanan**:
- Table: `chatbot_telemetry.prompt_id`
- Constant di Edge Function: `PROMPT_ID`

**Konvensi Versioning**:
```
chef_cei_v{major}.{minor}

major: Perubahan signifikan (struktur, persona, rules)
minor: Perbaikan kecil (typo, clarification)
```

---

### 4. prompt_hash

**Definisi**: SHA-256 hash dari prompt lengkap (termasuk context injection).

**Tujuan**:
- Integrity: Memastikan prompt tidak berubah tanpa disadari
- Deduplication: Mengidentifikasi request dengan prompt identik
- Caching: Potensi untuk cache response berdasarkan hash

**Format**: `sha256:a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a`

**Lokasi Penyimpanan**:
- Table: `chatbot_telemetry.prompt_hash`

**Cara Generate**:
```typescript
async function computePromptHash(prompt: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(prompt);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return `sha256:${hashHex}`;
}
```

---

## Data Flow

```
Request → Generate run_id → Build prompt → Compute prompt_hash
       → Insert initial telemetry → Call Gemini API
       → Parse response → Apply safety rules
       → Store response → Update telemetry
       → Insert to review_queue (if flagged)
       → Return response with run_id
```

---

## Telemetry Schema

| Field | Type | Description |
|-------|------|-------------|
| `run_id` | UUID | Primary identifier |
| `prompt_id` | TEXT | Prompt version |
| `prompt_hash` | TEXT | Full SHA-256 hash |
| `model_name` | TEXT | Model identifier |
| `model_version` | TEXT | Model version date |
| `token_usage` | JSONB | Token counts |
| `latency_ms` | INTEGER | Response time |
| `safety_flag` | BOOLEAN | Flagged status |
| `safety_reasons` | TEXT[] | Flag reasons |

---

## Best Practices

1. **Always log run_id** in all related logs and errors
2. **Increment prompt_id** when making prompt changes
3. **Compare prompt_hash** for reproducibility testing
4. **Track model_version** for quality regression detection
5. **Use telemetry** for performance monitoring dashboards

---

## Queries for Analysis

```sql
-- Find all runs for a specific prompt version
SELECT * FROM chatbot_telemetry 
WHERE prompt_id = 'chef_cei_v1.2' 
ORDER BY timestamp DESC;

-- Compare latency across model versions
SELECT model_version, AVG(latency_ms), PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms)
FROM chatbot_telemetry
GROUP BY model_version;

-- Find duplicate prompts (same hash)
SELECT prompt_hash, COUNT(*) as count
FROM chatbot_telemetry
GROUP BY prompt_hash
HAVING COUNT(*) > 1;
```
