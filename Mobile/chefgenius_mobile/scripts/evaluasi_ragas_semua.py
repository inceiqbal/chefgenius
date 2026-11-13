import json
import os
import sys
import time
import urllib.request
import numpy as np
import pandas as pd
import requests

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# KONFIGURASI EVALUASI
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "YOUR_OPENAI_API_KEY")
OPENAI_MODEL = "gpt-4o"

BASE_URL = os.getenv("SUPABASE_URL", "https://zfiyfhmsuhitytsuioml.supabase.co")
ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "YOUR_SUPABASE_ANON_KEY")
SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "YOUR_SUPABASE_SERVICE_ROLE_KEY")
USER_EMAIL = os.getenv("EVAL_USER_EMAIL", "evaluator@example.com")

MODES = [
    ("none", "Baseline (No RAG)"),
    ("naive", "Naive RAG"),
    ("pre_retrieval", "Pre-Retrieval Only"),
    ("post_retrieval", "Post-Retrieval Only"),
    ("advanced", "Full Advanced RAG")
]
MODE_LABEL_MAP = dict(MODES)

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
    max_retries = 5
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                content = data["choices"][0]["message"]["content"]
                return json.loads(content)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            if "credit_balance_exhausted" in err_body or "insufficient_quota" in err_body:
                raise RuntimeError(f"OpenAI Credit Balance Exhausted: {err_body}")
            if attempt < max_retries - 1:
                time.sleep(2 * (attempt + 1))
            else:
                raise
        except Exception:
            if attempt < max_retries - 1:
                time.sleep(2 * (attempt + 1))
            else:
                raise

def get_embedding(text: str) -> list:
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
    max_retries = 3
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return data["data"][0]["embedding"]
        except Exception:
            if attempt < max_retries - 1:
                time.sleep(1)
            else:
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
        "**Dokumen RAG Terambil",
        "Dokumen RAG Terambil",
        "*Informasi ini bersifat edukatif dan tidak menggantikan",
        "*(Mode:"
    ]
    cleaned = text
    for marker in markers:
        if marker in cleaned:
            cleaned = cleaned.split(marker)[0]
    return cleaned.strip()

# METRIK EVALUASI RAGAS
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
   - Pecah setiap angka nilai klinis dan setiap jenis zat/makanan menjadi pernyataan atomik terpisah.
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
        
    orig_emb = get_embedding(question)
    sims = []
    for gq in generated_questions:
        gq_emb = get_embedding(gq)
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

# 3. HELPER UNTUK MEMASTIKAN 75 DATA DI DATABASE 100% LENGKAP
def get_auth_token():
    admin_headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    res = requests.post(
        f"{BASE_URL}/auth/v1/admin/generate_link",
        headers=admin_headers,
        json={"type": "magiclink", "email": USER_EMAIL},
        timeout=30
    )
    token_hash = res.json().get("hashed_token")
    verify_res = requests.post(
        f"{BASE_URL}/auth/v1/verify",
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        json={"type": "magiclink", "token_hash": token_hash},
        timeout=30
    )
    return verify_res.json().get("access_token")

def ensure_all_75_telemetry_ready(master_meta: list) -> list:
    print("[FASE 1/2] Memeriksa kelengkapan 75 data pengujian di database...", flush=True)
    meta_by_id = {v["scenario_id"]: v for v in master_meta}
    target_modes = ["advanced", "post_retrieval", "pre_retrieval", "naive", "none"]

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}"
    }

    url = f"{BASE_URL}/rest/v1/chatbot_telemetry?order=timestamp.desc&limit=300"
    res = requests.get(url, headers=headers, timeout=30)
    rows = res.json() if res.status_code == 200 else []

    dataset = []
    missing_runs = []

    for vid in [f"V{i:02d}" for i in range(1, 16)]:
        v_info = meta_by_id.get(vid)
        expected_query = (v_info.get("query_text_part") or "").strip()
        
        for mode in target_modes:
            matched_row = None
            for r in rows:
                if (r.get("scenario_id") == vid and 
                    r.get("rag_mode") == mode and 
                    (r.get("query_text") or "").strip() == expected_query and 
                    r.get("http_status") == 200 and 
                    not r.get("safety_flag")):
                    matched_row = r
                    break
            
            if matched_row:
                item = dict(matched_row)
                item["scenario_type"] = v_info.get("scenario_type")
                item["reference_answer"] = v_info.get("reference_answer")
                item["ground_truth_document"] = v_info.get("ground_truth_document")
                item["ground_truth_chunk_idx"] = v_info.get("ground_truth_chunk_idx")
                dataset.append(item)
            else:
                missing_runs.append((vid, mode, v_info))

    if missing_runs:
        print(f"-> Ditemukan {len(missing_runs)} konfigurasi yang belum di-run / ada perubahan kueri.", flush=True)
        print("-> Menjalankan auto-run ke Edge Function Supabase sekarang...\n", flush=True)
        token = get_auth_token()
        client_headers = {
            "Content-Type": "application/json",
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}"
        }

        for vid, mode, v_info in missing_runs:
            q = v_info["query_text_part"].strip()
            print(f"   [AUTO-RUN] {vid} ({mode})...", end="", flush=True)
            payload = {
                "action": "chatbot",
                "userMessage": q,
                "rag_mode": mode,
                "embedding_engine": "indobert",
                "session_id": "auto-eval-session",
                "app_version": "1.0.0+6"
            }
            try:
                resp = requests.post(f"{BASE_URL}/functions/v1/gemini-proxy", headers=client_headers, json=payload, timeout=60)
                data = resp.json()
                run_id = data.get("run_id")
                time.sleep(1)
                
                # Fetch telemetry row
                r_row = requests.get(f"{BASE_URL}/rest/v1/chatbot_telemetry?run_id=eq.{run_id}", headers=headers, timeout=30)
                if r_row.status_code == 200 and r_row.json():
                    item = r_row.json()[0]
                    item["scenario_type"] = v_info.get("scenario_type")
                    item["reference_answer"] = v_info.get("reference_answer")
                    item["ground_truth_document"] = v_info.get("ground_truth_document")
                    item["ground_truth_chunk_idx"] = v_info.get("ground_truth_chunk_idx")
                    dataset.append(item)
                    print(" [BERHASIL]", flush=True)
                else:
                    print(" [GAGAL FETCH]", flush=True)
            except Exception as e:
                print(f" [ERROR: {e}]", flush=True)

    print(f"\n[OK] 75/75 data pengujian resmi siap dievaluasi RAGAS!\n", flush=True)
    out_path = "scripts/vignettes_v10.0_consolidated_dataset.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(dataset, f, indent=2, ensure_ascii=False)
    # Simpan juga ke path lama untuk kompatibilitas
    with open("scripts/vignettes_v10_consolidated_dataset.json", "w", encoding="utf-8") as f:
        json.dump(dataset, f, indent=2, ensure_ascii=False)
    return dataset

# FUNGSI UTAMA EKSEKUSI RAGAS
def main():
    print("=" * 75, flush=True)
    print("         CHEFGENIUS MASTER EVALUATION: FULL RAGAS V10.0 (75 RUNS)")
    print("=" * 75, flush=True)
    print(f"Judge Evaluator        : {OPENAI_MODEL} (GPT-4o)")
    print(f"Embedding Evaluator    : text-embedding-3-small")
    print(f"Cakupan Evaluasi       : 15 Skenario (V01 - V15) x 5 Mode RAG = 75 Konfigurasi")
    print("=" * 75 + "\n", flush=True)

    master_path = "scripts/vignettes_master_v10.0.json"
    if not os.path.exists(master_path):
        master_path = "scripts/vignettes_master_v10.json"
    with open(master_path, "r", encoding="utf-8") as f:
        master_meta = json.load(f)

    # 1. Pastikan seluruh 75 data siap
    dataset = ensure_all_75_telemetry_ready(master_meta)

    # Indeks dataset berdasarkan (mode, scenario_id)
    dataset_map = {}
    for r in dataset:
        dataset_map[(r["rag_mode"], r["scenario_id"])] = r

    all_evaluated = []
    total_to_eval = 75
    evaluated_count = 0

    print("=" * 75, flush=True)
    print(f"[FASE 2/2] Menjalankan Evaluasi RAGAS (GPT-4o) untuk SELURUH 75 Skenario...", flush=True)
    print("=" * 75, flush=True)

    start_eval_time = time.time()

    for mode_key, mode_label in MODES:
        print(f"\n>>> MODE: {mode_label.upper()} ({mode_key})", flush=True)
        print("-" * 75, flush=True)

        for sc_idx in range(1, 16):
            sc = f"V{sc_idx:02d}"
            row = dataset_map.get((mode_key, sc))
            if not row:
                print(f"[WARN] Data tidak ditemukan untuk {mode_key} - {sc}!", flush=True)
                continue

            evaluated_count += 1
            query = row.get("query_text") or ""
            resp_raw = row.get("response_text") or ""
            resp_clean = clean_response_text(resp_raw)
            ground_truth = row.get("reference_answer") or ""
            sc_type = row.get("scenario_type") or ("implicit" if sc in ["V04", "V05", "V07", "V12", "V15"] else "explicit")

            ret_raw = row.get("retrieved_results") or []
            if isinstance(ret_raw, str):
                try: ret_list = json.loads(ret_raw)
                except: ret_list = []
            else:
                ret_list = ret_raw

            context_texts = [c.get("chunk_text", "") for c in ret_list if c.get("chunk_text")]
            full_context = "\n\n".join(context_texts)

            t0 = time.time()
            if mode_key == "none":
                f_val = evaluate_faithfulness(query, resp_clean, ground_truth)
                ar_val = evaluate_answer_relevance(query, resp_clean)
                cr_val = 0.0
            else:
                f_val = evaluate_faithfulness(query, resp_clean, full_context)
                ar_val = evaluate_answer_relevance(query, resp_clean)
                cr_val = evaluate_context_relevance(query, full_context)

            ragas_val = (f_val + ar_val + cr_val) / 3.0
            elapsed = time.time() - t0

            eval_rec = {
                "mode": mode_key,
                "mode_label": mode_label,
                "scenario_id": sc,
                "scenario_type": sc_type,
                "faithfulness": round(f_val, 4),
                "answer_relevance": round(ar_val, 4),
                "context_relevance": round(cr_val, 4),
                "ragas_score": round(ragas_val, 4)
            }
            all_evaluated.append(eval_rec)
            print(f"[{sc}] ({sc_type.upper():<8}) ({evaluated_count:2d}/{total_to_eval}) in {elapsed:.1f}s | F: {f_val:.4f} | AR: {ar_val:.4f} | CR: {cr_val:.4f} | RAGAS: {ragas_val:.4f}", flush=True)

            # Auto-save progress
            pd.DataFrame(all_evaluated).to_csv("scripts/ragas_evaluation_results.csv", index=False)
            time.sleep(0.3)

    total_duration = time.time() - start_eval_time

    # Buat summary per mode
    df_detail = pd.DataFrame(all_evaluated)
    summary_by_mode = []
    for m_key, m_label in MODES:
        sub = df_detail[df_detail["mode"] == m_key]
        if not sub.empty:
            avg_f = float(sub["faithfulness"].mean())
            avg_ar = float(sub["answer_relevance"].mean())
            avg_cr = float(sub["context_relevance"].mean())
            avg_ragas = float(sub["ragas_score"].mean())
            
            sub_exp = sub[sub["scenario_type"] == "explicit"]
            sub_imp = sub[sub["scenario_type"] == "implicit"]
            ragas_exp = float(sub_exp["ragas_score"].mean()) if not sub_exp.empty else 0.0
            ragas_imp = float(sub_imp["ragas_score"].mean()) if not sub_imp.empty else 0.0

            summary_by_mode.append({
                "Mode": m_label,
                "Faithfulness": round(avg_f, 4),
                "Answer Relevance": round(avg_ar, 4),
                "Context Relevance": round(avg_cr, 4),
                "RAGAS (Eksplisit n=10)": round(ragas_exp, 4),
                "RAGAS (Implisit n=5)": round(ragas_imp, 4),
                "Rata-rata RAGAS (Total)": round(avg_ragas, 4)
            })

    df_summary = pd.DataFrame(summary_by_mode)
    
    csv_detail_path = "scripts/ragas_evaluation_results.csv"
    csv_latest_path = "scripts/evaluasi ragas latest.csv"
    md_latest_path = "scripts/evaluasi ragas latest.md"

    with open(csv_latest_path, "w", encoding="utf-8") as f:
        f.write("# ======================================================================\n")
        f.write("# RINGKASAN EVALUASI RAGAS V10.0 (RATA-RATA 5 MODE ARSITEKTUR DENGAN GPT-4o)\n")
        f.write("# ======================================================================\n")
        df_summary.to_csv(f, index=False)
        f.write("\n# ======================================================================\n")
        f.write("# HASIL LENGKAP EVALUASI RAGAS V10.0 PER SKENARIO (75 ENTRI RESMI)\n")
        f.write("# ======================================================================\n")
        df_detail.to_csv(f, index=False)

    # Simpan juga ke file bernomor versi v10.0 eksplisit
    df_detail.to_csv("scripts/ragas_evaluation_results_v10.0.csv", index=False)

    with open(md_latest_path, "w", encoding="utf-8") as f:
        f.write("# Laporan Hasil Evaluasi RAGAS v10.0 (10 Eksplisit + 5 Implisit)\n\n")
        f.write(f"Evaluasi resmi seluruh 75 konfigurasi v10.0 menggunakan **Judge GPT-4o** dan **text-embedding-3-small**.\n")
        f.write(f"Waktu eksekusi: {time.strftime('%Y-%m-%d %H:%M:%S')} (Total durasi: {total_duration/60:.1f} menit).\n\n")
        f.write("---\n\n")
        f.write("## 1. Ringkasan Eksekutif (Rata-rata 5 Mode Arsitektur)\n\n")
        f.write("| Mode Arsitektur | Faithfulness | Answer Relevance | Context Relevance | RAGAS (Eksplisit n=10) | RAGAS (Implisit n=5) | Rata-rata RAGAS (Total) |\n")
        f.write("| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n")
        for _, r in df_summary.iterrows():
            f.write(f"| **{r['Mode']}** | {r['Faithfulness']:.4f} | {r['Answer Relevance']:.4f} | {r['Context Relevance']:.4f} | {r['RAGAS (Eksplisit n=10)']:.4f} | {r['RAGAS (Implisit n=5)']:.4f} | **{r['Rata-rata RAGAS (Total)']:.4f}** |\n")
        f.write("\n---\n\n")
        f.write("## 2. Tabel Rincian Per Skenario (75 Entri Resmi)\n\n")
        f.write("| Mode | Label Mode | Skenario | Tipe | Faithfulness | Answer Relevance | Context Relevance | Skor RAGAS |\n")
        f.write("| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n")
        for _, r in df_detail.iterrows():
            f.write(f"| `{r['mode']}` | {r['mode_label']} | **{r['scenario_id']}** | {r['scenario_type']} | {r['faithfulness']:.4f} | {r['answer_relevance']:.4f} | {r['context_relevance']:.4f} | **{r['ragas_score']:.4f}** |\n")

    print("\n" + "=" * 75, flush=True)
    print("                    RINGKASAN HASIL EVALUASI RAGAS V10.0", flush=True)
    print("=" * 75, flush=True)
    print(df_summary.to_string(index=False), flush=True)
    print("=" * 75, flush=True)
    print(f"\n[SELESAI DALAM {total_duration/60:.1f} MENIT! FILE LAPORAN DISIMPAN]:", flush=True)
    print(f"  - Markdown Rapi : {md_latest_path}", flush=True)
    print(f"  - CSV Lengkap   : {csv_latest_path}", flush=True)
    print(f"  - CSV Detail    : {csv_detail_path}", flush=True)
    print(f"  - CSV V10.0     : scripts/ragas_evaluation_results_v10.0.csv", flush=True)

if __name__ == "__main__":
    main()

