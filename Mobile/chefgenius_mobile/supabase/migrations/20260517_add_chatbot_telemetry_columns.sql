-- Add telemetry columns required by the gemini-proxy Edge Function
-- Safe to run on an existing Supabase database.

ALTER TABLE chatbot_telemetry
  ADD COLUMN IF NOT EXISTS query_text TEXT,
  ADD COLUMN IF NOT EXISTS scenario_id TEXT,
  ADD COLUMN IF NOT EXISTS reference_answer TEXT,
  ADD COLUMN IF NOT EXISTS ground_truth_document TEXT,
  ADD COLUMN IF NOT EXISTS ground_truth_chunk_idx JSONB,
  ADD COLUMN IF NOT EXISTS rag_mode TEXT,
  ADD COLUMN IF NOT EXISTS rag_documents_retrieved INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rag_retrieval_latency_ms INTEGER,
  ADD COLUMN IF NOT EXISTS reranker_latency_ms INTEGER,
  ADD COLUMN IF NOT EXISTS reranker_scores JSONB,
  ADD COLUMN IF NOT EXISTS retrieved_results JSONB,
  ADD COLUMN IF NOT EXISTS token_usage_input INTEGER,
  ADD COLUMN IF NOT EXISTS token_usage_output INTEGER;

COMMENT ON COLUMN chatbot_telemetry.query_text IS 'Original user query text used for vignette matching';
COMMENT ON COLUMN chatbot_telemetry.scenario_id IS 'Matched vignette scenario id';
COMMENT ON COLUMN chatbot_telemetry.reference_answer IS 'Ground-truth reference answer for the matched vignette';
COMMENT ON COLUMN chatbot_telemetry.ground_truth_document IS 'Ground-truth source document for the matched vignette';
COMMENT ON COLUMN chatbot_telemetry.ground_truth_chunk_idx IS 'Ground-truth chunk indices / ids used for evaluation';
COMMENT ON COLUMN chatbot_telemetry.rag_mode IS 'Active RAG mode for the request';
COMMENT ON COLUMN chatbot_telemetry.rag_documents_retrieved IS 'Number of RAG documents retrieved';
COMMENT ON COLUMN chatbot_telemetry.rag_retrieval_latency_ms IS 'Latency spent on retrieval';
COMMENT ON COLUMN chatbot_telemetry.reranker_latency_ms IS 'Latency spent on reranking';
COMMENT ON COLUMN chatbot_telemetry.reranker_scores IS 'Reranker score logs';
COMMENT ON COLUMN chatbot_telemetry.retrieved_results IS 'Retrieved RAG results payload';
COMMENT ON COLUMN chatbot_telemetry.token_usage_input IS 'Flattened token usage input count';
COMMENT ON COLUMN chatbot_telemetry.token_usage_output IS 'Flattened token usage output count';
