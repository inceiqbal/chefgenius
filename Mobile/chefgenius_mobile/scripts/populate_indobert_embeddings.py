import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from supabase import create_client, Client
from dotenv import load_dotenv
import numpy as np
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModel

# Load Supabase credentials
ENV_PATH = 'd:/chefgenius/Mobile/chefgenius_mobile/supabase/functions/gemini-proxy/scripts/.env'
load_dotenv(ENV_PATH)

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("[ERROR] SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing!")
    sys.exit(1)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

MODEL_NAME = "firqaaa/indo-sentence-bert-base"
PAGE_SIZE = 100
MAX_WORKERS = 15

print(f"[INFO] Loading IndoBERT model: {MODEL_NAME}...")
t_model_0 = time.time()
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModel.from_pretrained(MODEL_NAME)
model.eval()
print(f"[OK] Model loaded in {time.time() - t_model_0:.2f}s\n")

def encode_texts(texts, batch_size=32):
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch_slice = texts[i:i + batch_size]
        encoded = tokenizer(
            batch_slice,
            padding=True,
            truncation=True,
            max_length=512,
            return_tensors='pt'
        )
        with torch.no_grad():
            output = model(**encoded)
        mask = encoded['attention_mask'].unsqueeze(-1).expand(output[0].size()).float()
        summed = torch.sum(output[0] * mask, 1)
        clamped = torch.clamp(mask.sum(1), min=1e-9)
        mean_pooled = summed / clamped
        normalized = F.normalize(mean_pooled, p=2, dim=1)
        all_embeddings.append(normalized.cpu().numpy())
    return np.vstack(all_embeddings)

def get_remaining_count():
    res = supabase.table("knowledge_base").select("id", count="exact").is_("embedding_indobert", "null").limit(1).execute()
    return res.count or 0

def get_total_count():
    res = supabase.table("knowledge_base").select("id", count="exact").limit(1).execute()
    return res.count or 0

def update_single_embedding(client, doc_id, embedding_vector):
    retries = 3
    for attempt in range(retries):
        try:
            client.table("knowledge_base").update({
                "embedding_indobert": embedding_vector
            }).eq("id", doc_id).execute()
            return True
        except Exception as e:
            if attempt == retries - 1:
                print(f"[FAIL] Failed to update doc {doc_id}: {e}")
                return False
            time.sleep(0.5 * (attempt + 1))

def main():
    total_docs = get_total_count()
    remaining = get_remaining_count()
    completed = total_docs - remaining

    print("============================================================")
    print("IndoBERT Embedding Pipeline")
    print(f"   Model: {MODEL_NAME} (768 dimensions)")
    print(f"   Total knowledge base documents: {total_docs}")
    print(f"   Already embedded: {completed}")
    print(f"   Remaining to process: {remaining}")
    print("============================================================\n")

    if remaining == 0:
        print("[DONE] All documents already have embedding_indobert populated!")
        return

    start_time = time.time()
    processed_in_session = 0

    while True:
        # Fetch next batch of documents without embedding_indobert
        res = supabase.table("knowledge_base") \
            .select("id, content, title") \
            .is_("embedding_indobert", "null") \
            .limit(PAGE_SIZE) \
            .execute()

        batch = res.data
        if not batch or len(batch) == 0:
            break

        batch_texts = [doc["content"] for doc in batch]
        batch_ids = [doc["id"] for doc in batch]

        # Compute embeddings with IndoBERT
        t_enc_0 = time.time()
        embeddings = encode_texts(batch_texts, batch_size=32)
        t_enc = time.time() - t_enc_0

        # Update in Supabase concurrently
        t_up_0 = time.time()
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [
                executor.submit(update_single_embedding, supabase, doc_id, emb.tolist())
                for doc_id, emb in zip(batch_ids, embeddings)
            ]
            for future in as_completed(futures):
                future.result()
        t_up = time.time() - t_up_0

        processed_in_session += len(batch)
        total_done = completed + processed_in_session
        pct = (total_done / total_docs) * 100 if total_docs > 0 else 100
        elapsed = time.time() - start_time
        speed = processed_in_session / elapsed if elapsed > 0 else 0
        rem_docs = total_docs - total_done
        eta_sec = rem_docs / speed if speed > 0 else 0
        eta_min = eta_sec / 60

        print(
            f"[{total_done}/{total_docs}] ({pct:.1f}%) "
            f"Batch {len(batch)} done (Enc: {t_enc:.2f}s, DB: {t_up:.2f}s) "
            f"| Speed: {speed:.1f} doc/s | ETA: {eta_min:.1f}m",
            flush=True
        )

    print("\n============================================================")
    print(f"[DONE] Pipeline finished! Processed {processed_in_session} documents.")
    final_remaining = get_remaining_count()
    print(f"   Remaining without IndoBERT embedding: {final_remaining}")
    print("============================================================\n")

if __name__ == "__main__":
    main()
