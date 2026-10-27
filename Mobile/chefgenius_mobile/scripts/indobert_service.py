import json
import os
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
import torch
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModel, AutoModelForSequenceClassification

MODEL_NAME = "firqaaa/indo-sentence-bert-base"
RERANKER_MODEL_NAME = "BAAI/bge-reranker-base"
PORT = int(os.environ.get("PORT", 8000))
HOST = "0.0.0.0"

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

print(f"[INFO] Loading IndoBERT model: {MODEL_NAME}...")
t0 = time.time()
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModel.from_pretrained(MODEL_NAME)
model.eval()
print(f"[OK] IndoBERT loaded in {time.time() - t0:.2f}s on {'cuda' if torch.cuda.is_available() else 'cpu'}")

print(f"[INFO] Loading BGE Reranker model: {RERANKER_MODEL_NAME}...")
t1 = time.time()
reranker_tokenizer = AutoTokenizer.from_pretrained(RERANKER_MODEL_NAME, local_files_only=True)
reranker_model = AutoModelForSequenceClassification.from_pretrained(RERANKER_MODEL_NAME, local_files_only=True)
reranker_model.eval()
print(f"[OK] BGE Reranker loaded in {time.time() - t1:.2f}s on {'cuda' if torch.cuda.is_available() else 'cpu'}")

def compute_embeddings(text_or_list):
    texts = text_or_list if isinstance(text_or_list, list) else [str(text_or_list)]
    encoded = tokenizer(texts, padding=True, truncation=True, max_length=512, return_tensors='pt')
    with torch.no_grad():
        out = model(**encoded)
    mask = encoded['attention_mask'].unsqueeze(-1).expand(out[0].size()).float()
    summed = torch.sum(out[0] * mask, 1)
    clamped = torch.clamp(mask.sum(1), min=1e-9)
    mean_pooled = summed / clamped
    normalized = F.normalize(mean_pooled, p=2, dim=1)
    embs = normalized.cpu().tolist()
    return embs if isinstance(text_or_list, list) else embs[0]

def compute_rerank_scores(query, documents):
    if not documents:
        return []
    pairs = [[query, doc] for doc in documents]
    with torch.no_grad():
        encoded = reranker_tokenizer(pairs, padding=True, truncation=True, max_length=512, return_tensors='pt')
        logits = reranker_model(**encoded, return_dict=True).logits.view(-1).float()
        scores = logits.cpu().tolist()
        if isinstance(scores, float):
            scores = [scores]
    return scores

def compute_rerank_from_pairs(pairs):
    if not pairs:
        return []
    with torch.no_grad():
        encoded = reranker_tokenizer(pairs, padding=True, truncation=True, max_length=512, return_tensors='pt')
        logits = reranker_model(**encoded, return_dict=True).logits.view(-1).float()
        scores = logits.cpu().tolist()
        if isinstance(scores, float):
            scores = [scores]
    return scores

class IndoBertHandler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors()
        self.end_headers()

    def do_GET(self):
        if self.path in ["/", "/health"]:
            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            resp = {
                "status": "healthy",
                "embedding_model": MODEL_NAME,
                "reranker_model": RERANKER_MODEL_NAME,
                "dimensions": 768,
                "timestamp": time.time()
            }
            self.wfile.write(json.dumps(resp).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path in ["/embed", "/api/embed"]:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = json.loads(body)
            except Exception as e:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": f"Invalid JSON: {e}"}).encode('utf-8'))
                return

            text = data.get("text") or data.get("inputs") or data.get("query")
            if not text:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Missing 'text' or 'inputs' field"}).encode('utf-8'))
                return

            if isinstance(text, list):
                embeddings = compute_embeddings(text)
                resp = {"embeddings": embeddings, "dimensions": 768}
            else:
                embedding = compute_embeddings(str(text))
                resp = {"embedding": embedding, "dimensions": 768}

            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        elif self.path in ["/rerank", "/api/rerank"]:
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode('utf-8')
            try:
                data = json.loads(body)
            except Exception as e:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": f"Invalid JSON: {e}"}).encode('utf-8'))
                return

            t_start = time.time()
            if "inputs" in data and isinstance(data["inputs"], list):
                # Standard HF-like sequence pair format
                inputs_list = data["inputs"]
                if len(inputs_list) > 0 and isinstance(inputs_list[0], dict) and "text" in inputs_list[0]:
                    pairs = [[item.get("text", ""), item.get("text_pair", "")] for item in inputs_list]
                elif len(inputs_list) > 0 and isinstance(inputs_list[0], (list, tuple)):
                    pairs = [[item[0], item[1]] for item in inputs_list]
                else:
                    pairs = []
                scores = compute_rerank_from_pairs(pairs)
            else:
                query = data.get("query", "")
                documents = data.get("documents", [])
                if not query or not documents:
                    self.send_response(400)
                    self._send_cors()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(json.dumps({"error": "Missing 'query' or 'documents' field"}).encode('utf-8'))
                    return
                scores = compute_rerank_scores(query, documents)

            duration = time.time() - t_start
            resp = {
                "model": RERANKER_MODEL_NAME,
                "scores": scores,
                "latency_s": round(duration, 4),
                "count": len(scores)
            }
            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def run_server():
    server = HTTPServer((HOST, PORT), IndoBertHandler)
    print(f"[READY] IndoBERT & BGE Reranker Service listening on http://{HOST}:{PORT}")
    print(f"        Endpoints:")
    print(f"          GET  /health")
    print(f"          POST /embed   {{ \"text\": \"...\" }}")
    print(f"          POST /rerank  {{ \"query\": \"...\", \"documents\": [...] }}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[INFO] Server stopped.")

if __name__ == "__main__":
    run_server()
