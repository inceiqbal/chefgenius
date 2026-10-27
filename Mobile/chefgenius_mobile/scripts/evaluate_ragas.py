#!/usr/bin/env python3

import os
import sys
import json
import time
import math
import urllib.request
import numpy as np
import pandas as pd
from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://zfiyfhmsuhitytsuioml.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "YOUR_SUPABASE_SERVICE_ROLE_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "YOUR_OPENAI_API_KEY")

OPENAI_MODEL = "gpt-5.5"

INDOBERT_URL = "http://localhost:8000/embed"

MODES = [
    ("none", "Baseline (No RAG)"),
    ("naive", "Naive RAG"),
    ("pre_retrieval", "Pre-Retrieval Only"),
    ("post_retrieval", "Post-Retrieval Only"),
    ("advanced", "Full Advanced RAG")
]

def call_openai_json(prompt: str, system_prompt: str = "You are an expert medical AI evaluator. Output strictly valid JSON.") -> dict:
    payload = {
        "model": OPENAI_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt}
        ],
        "response_format": {"type": "json_object"}
    }
    
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        },
        data=json.dumps(payload).encode("utf-8")
    )
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                content = data["choices"][0]["message"]["content"]
                return json.loads(content)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            print(f"\n[OpenAI HTTP Error {e.code}] {err_body}")
            if "credit_balance_exhausted" in err_body or "insufficient_quota" in err_body:
                raise RuntimeError(f"OpenAI Credit Balance Exhausted: {err_body}")
            if attempt < max_retries - 1:
                time.sleep(2)
            else:
                raise
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2)
            else:
                print(f"[OpenAI Error] {e}")
                raise

_indobert_service_available = None

def get_indobert_embedding(text: str) -> list:
    global _indobert_service_available
    if _indobert_service_available is not False:
        payload = {"text": text[:512]}
        req = urllib.request.Request(
            "http://127.0.0.1:8000/embed",
            headers={"Content-Type": "application/json"},
            data=json.dumps(payload).encode("utf-8")
        )
        try:
            with urllib.request.urlopen(req, timeout=0.5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                _indobert_service_available = True
                return data.get("embedding", [])
        except Exception:
            _indobert_service_available = False

    # Fallback to OpenAI embedding for semantic similarity
    try:
        payload = {
            "model": "text-embedding-3-small",
            "input": text[:512]
        }
        req = urllib.request.Request(
            "https://api.openai.com/v1/embeddings",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json"
            },
            data=json.dumps(payload).encode("utf-8")
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["data"][0]["embedding"]
    except Exception as e:
        print(f"[Embedding Error] {e}")
        return []

def cosine_similarity(vec_a, vec_b) -> float:
    if not vec_a or not vec_b:
        return 0.0
    a, b = np.array(vec_a), np.array(vec_b)
    norm = (np.linalg.norm(a) * np.linalg.norm(b))
    if norm == 0:
        return 0.0
    return float(np.dot(a, b) / norm)
    
def clean_response_text(text: str) -> str:
    if not text:
        return ""
    markers = [
        "📦 **Dokumen RAG Terambil",
        "📦 Dokumen RAG Terambil",
        "*Informasi ini bersifat edukatif dan tidak menggantikan",
        "*(Mode:"
    ]
    cleaned = text
    for marker in markers:
        if marker in cleaned:
            cleaned = cleaned.split(marker)[0]
    return cleaned.strip()

def evaluate_faithfulness(question: str, answer: str, context: str) -> float:
    if not context or not answer:
        return 0.0
        
    prompt = f"""Tugas Anda adalah mengevaluasi kesetiaan (Faithfulness) dari klaim faktual dalam sebuah jawaban terhadap dokumen konteks medis.

Pertanyaan Pengguna:
\"\"\"{question}\"\"\"

Konteks Dokumen:
\"\"\"{context[:4000]}\"\"\"

Jawaban Chatbot:
\"\"\"{answer[:2000]}\"\"\"

Instruksi:
1. Ekstrak HANYA pernyataan faktual substantif yang bertujuan menjawab pertanyaan pengguna di atas.
   - Pecah setiap angka nilai klinis dan setiap jenis obat menjadi pernyataan atomik terpisah.
   - ABAIKAN kalimat sapaan, identitas persona (misal 'Halo saya Chef Cei...'), kalimat basa-basi, edukasi resep/kuliner tambahan di luar pertanyaan, serta peringatan umum atau disclaimer medis.
2. Untuk setiap pernyataan faktual substantif tersebut, periksa apakah fakta tersebut didukung oleh konteks dokumen:
   - verdict: 1 jika pernyataan tersebut didukung atau dapat disimpulkan langsung dari konteks.
   - verdict: 0 jika pernyataan tersebut bertentangan atau TIDAK ADA dalam konteks dokumen (halusinasi).

Keluarkan HANYA JSON dengan struktur:
{{
  "statements": [
    {{"statement": "isi klaim faktual substantif", "verdict": 1, "reason": "alasan singkat"}}
  ]
}}"""
    res = call_openai_json(prompt)
    statements = res.get("statements", [])
    if not statements:
        return 0.0
    verdicts = [s.get("verdict", 0) for s in statements]
    return sum(verdicts) / len(verdicts)

def evaluate_answer_relevance(question: str, answer: str) -> float:
    if not answer or not question:
        return 0.0
        
    prompt = f"""Tugas Anda adalah menilai relevansi sebuah jawaban terhadap pertanyaan.

Jawaban Chatbot:
\"\"\"{answer[:2000]}\"\"\"

Instruksi:
1. Buatlah 3 kemungkinan pertanyaan tiruan yang paling relevan dan tepat dijawab oleh teks jawaban di atas.
2. Tentukan apakah jawaban ini bersifat menghindar / menolak menjawab (noncommittal) seperti 'saya tidak tahu' atau 'maaf saya tidak bisa menjawab' (1 jika menghindar, 0 jika tegas menjawab).

Keluarkan HANYA JSON:
{{
  "questions": ["pertanyaan tiruan 1", "pertanyaan tiruan 2", "pertanyaan tiruan 3"],
  "noncommittal": 0
}}"""
    res = call_openai_json(prompt)
    generated_questions = res.get("questions", [])
    noncommittal = res.get("noncommittal", 0)
    
    if noncommittal == 1 or not generated_questions:
        return 0.0
        
    orig_emb = get_indobert_embedding(question)
    sims = []
    for gq in generated_questions:
        gq_emb = get_indobert_embedding(gq)
        if gq_emb:
            sims.append(cosine_similarity(orig_emb, gq_emb))
            
    if not sims:
        return 0.0
    return float(np.mean(sims))

def evaluate_context_relevance(question: str, context: str) -> float:
    if not context or not question:
        return 0.0
        
    prompt = f"""Sebagai seorang ahli yang menilai relevansi dokumen terhadap pertanyaan, tugas Anda adalah menentukan sejauh mana konteks yang ditarik menyediakan informasi yang dibutuhkan untuk menjawab pertanyaan.

Pertanyaan Pengguna:
\"\"\"{question}\"\"\"

Konteks Dokumen yang Ditarik:
\"\"\"{context[:4000]}\"\"\"

Petunjuk Skor:
- 0: Jika konteks tidak berisi informasi relevan sama sekali untuk menjawab pertanyaan.
- 1: Jika konteks hanya sebagian relevan atau relevan secara tidak langsung.
- 2: Jika konteks sepenuhnya relevan dan langsung menyediakan informasi spesifik yang dibutuhkan.

Keluarkan HANYA JSON:
{{
  "score": 0, 1, atau 2,
  "reason": "alasan singkat"
}}"""
    res = call_openai_json(prompt)
    raw_score = res.get("score", 0)
    try:
        raw_score = float(raw_score)
        if raw_score not in [0.0, 1.0, 2.0]:
            raw_score = 1.0 if raw_score > 0 else 0.0
    except:
        raw_score = 0.0
    return raw_score / 2.0

def main():
    print("=" * 70)
    print("EVALUASI RAGAS (5 MODE)")
    print("=" * 70)

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)
    
    all_results = []
    summary_by_mode = []

    existing_map = {}
    if os.path.exists("scripts/ragas_evaluation_results.csv"):
        try:
            df_old = pd.read_csv("scripts/ragas_evaluation_results.csv")
            for _, r in df_old.iterrows():
                existing_map[(r["mode"], str(r["scenario_id"]))] = r.to_dict()
            print(f"[Resume] Loaded {len(existing_map)} previously evaluated scenarios.")
        except Exception as e:
            print(f"[Warning loading existing results] {e}")

    target_mode = None
    force_eval = False
    scenario_filter = None
    custom_output = None

    for i, arg in enumerate(sys.argv[1:]):
        a = arg.lower()
        if a in [m[0] for m in MODES]:
            target_mode = a
        elif a in ["--force", "-f", "force"]:
            force_eval = True
        elif a == "--output" and i + 2 < len(sys.argv):
            custom_output = sys.argv[i + 2]
        elif arg.upper().startswith("V"):
            scenario_filter = arg.upper()

    if target_mode and force_eval:
        existing_map = {k: v for k, v in existing_map.items() if k[0] != target_mode}
        print(f"[Force] Cache cleared for mode '{target_mode}'. Akan dievaluasi ulang.")

    modes_to_run = [m for m in MODES if (target_mode is None or m[0] == target_mode)]

    # Pre-populate all_results with existing records from modes NOT being re-evaluated
    for (m_key, sc), record in existing_map.items():
        if target_mode and m_key != target_mode:
            all_results.append(record)

    for mode_key, mode_label in modes_to_run:
        print(f"\nEvaluating mode: {mode_label} ({mode_key})...")
        
        res = sb.from_("chatbot_telemetry").select("*")\
            .eq("rag_mode", mode_key)\
            .not_.is_("scenario_id", "null")\
            .order("timestamp", desc=True)\
            .limit(200).execute()
            
        latest_by_sc = {}
        for r in res.data:
            sc = r.get("scenario_id")
            if sc and sc not in latest_by_sc:
                latest_by_sc[sc] = r
                
        scenarios = sorted(latest_by_sc.keys())
        if scenario_filter:
            scenarios = [s for s in scenarios if s == scenario_filter]
        print(f"Found {len(scenarios)} scenarios: {scenarios}")
        
        f_scores, ar_scores, cr_scores = [], [], []

        for sc in scenarios:
            if (mode_key, sc) in existing_map:
                record = existing_map[(mode_key, sc)]
                f_val = float(record["faithfulness"])
                ar_val = float(record["answer_relevance"])
                cr_val = float(record["context_relevance"])
                f_scores.append(f_val)
                ar_scores.append(ar_val)
                cr_scores.append(cr_val)
                all_results.append(record)
                print(f"[{sc}] (Cached) F: {f_val:.3f} | AR: {ar_val:.3f} | CR: {cr_val:.3f}")
                continue

            row = latest_by_sc[sc]
            query = row.get("query_text") or ""
            resp_raw = row.get("response_text") or ""
            resp_clean = clean_response_text(resp_raw)
            ground_truth = row.get("reference_answer") or ""
            
            ret_raw = row.get("retrieved_results") or []
            if isinstance(ret_raw, str):
                try: ret_list = json.loads(ret_raw)
                except: ret_list = []
            else: ret_list = ret_raw
            
            context_texts = [c.get("chunk_text", "") for c in ret_list if c.get("chunk_text")]
            full_context = "\n\n".join(context_texts)
            
            if mode_key == "none":
                f_val = evaluate_faithfulness(query, resp_clean, ground_truth)
                ar_val = evaluate_answer_relevance(query, resp_clean)
                cr_val = 0.0
            else:
                f_val = evaluate_faithfulness(query, resp_clean, full_context)
                ar_val = evaluate_answer_relevance(query, resp_clean)
                cr_val = evaluate_context_relevance(query, full_context)
                
            f_scores.append(f_val)
            ar_scores.append(ar_val)
            cr_scores.append(cr_val)
            
            record = {
                "mode": mode_key,
                "mode_label": mode_label,
                "scenario_id": sc,
                "faithfulness": round(f_val, 4),
                "answer_relevance": round(ar_val, 4),
                "context_relevance": round(cr_val, 4)
            }
            all_results.append(record)
            print(f"[{sc}] F: {f_val:.3f} | AR: {ar_val:.3f} | CR: {cr_val:.3f}")
            pd.DataFrame(all_results).to_csv("scripts/ragas_evaluation_results.csv", index=False)
            time.sleep(1)
            
    df_detail = pd.DataFrame(all_results)
    df_detail.to_csv("scripts/ragas_evaluation_results.csv", index=False)
    
    summary_by_mode = []
    for m_key, m_label in MODES:
        sub = df_detail[df_detail["mode"] == m_key]
        if not sub.empty:
            avg_f = float(sub["faithfulness"].mean())
            avg_ar = float(sub["answer_relevance"].mean())
            avg_cr = float(sub["context_relevance"].mean())
            avg_ragas = (avg_f + avg_ar + avg_cr) / 3.0
            summary_by_mode.append({
                "Mode": m_label,
                "Faithfulness": round(avg_f, 4),
                "Answer Relevance": round(avg_ar, 4),
                "Context Relevance": round(avg_cr, 4),
                "Rata-rata RAGAS": round(avg_ragas, 4)
            })
            
    df_summary = pd.DataFrame(summary_by_mode)
    df_summary.to_csv("scripts/ragas_summary_5modes.csv", index=False)
    
    if custom_output:
        df_custom = pd.DataFrame([r for r in all_results if target_mode is None or r['mode'] == target_mode])
        df_custom.to_csv(custom_output, index=False)
        print(f"\n[Custom Output] Hasil evaluasi khusus mode '{target_mode}' disimpan ke: {custom_output}")

    print("\n" + "=" * 70)
    print("HASIL EVALUASI RAGAS (5 MODE)")
    print("=" * 70)
    print(df_summary.to_string(index=False))
    print("\nFile detail: scripts/ragas_evaluation_results.csv")
    print("File summary: scripts/ragas_summary_5modes.csv")

if __name__ == "__main__":
    main()
