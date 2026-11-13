-- Unified idempotent migration for `public.chatbot_telemetry`
-- Safe to run on an existing DB or a fresh DB. Adds missing columns, creates table if absent,
-- ensures extensions, and creates indexes if missing.
-- Created: 2026-05-04 (unified)

-- Ensure required extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create table if it does not exist (includes full set of current columns)
CREATE TABLE IF NOT EXISTS public.chatbot_telemetry (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL,
  user_id uuid NULL,
  session_id text NULL,
  "timestamp" timestamp with time zone NULL DEFAULT now(),
  prompt_id text NOT NULL DEFAULT 'chef_cei_v1.2'::text,
  prompt_hash text NOT NULL,
  model_name text NULL DEFAULT 'gemini-3-flash-preview'::text,
  model_version text NULL,
  temperature double precision NULL DEFAULT 0.4,
  max_tokens integer NULL DEFAULT 1024,
  top_p double precision NULL DEFAULT 0.95,
  token_usage jsonb NULL,
  token_usage_input integer NULL,
  token_usage_output integer NULL,
  latency_ms integer NULL,
  http_status integer NULL,
  response_truncated boolean NULL DEFAULT false,
  safety_flag boolean NULL DEFAULT false,
  safety_reasons text[] NULL DEFAULT '{}'::text[],
  post_processing_actions text[] NULL DEFAULT '{}'::text[],
  response_pointer text NULL,
  response_text text NULL,
  query_text text NULL,
  retrieved_results jsonb NULL,
  scenario_id uuid NULL,
  ground_truth_context_ids jsonb NULL,
  reference_answer text NULL,
  edge_function_version text NULL,
  app_version text NULL,
  region text NULL DEFAULT 'asia-southeast1'::text,
  rag_mode text NULL DEFAULT 'none'::text,
  rag_documents_retrieved integer NULL DEFAULT 0,
  rag_retrieval_latency_ms integer NULL,
  reranker_latency_ms integer NULL,
  reranker_scores jsonb NULL,
  CONSTRAINT chatbot_telemetry_pkey PRIMARY KEY (id)
);

-- Add any missing columns to support older DBs (safe if they already exist)
ALTER TABLE public.chatbot_telemetry
  ADD COLUMN IF NOT EXISTS token_usage_input integer NULL,
  ADD COLUMN IF NOT EXISTS token_usage_output integer NULL,
  ADD COLUMN IF NOT EXISTS response_text text NULL,
  ADD COLUMN IF NOT EXISTS query_text text NULL,
  ADD COLUMN IF NOT EXISTS retrieved_results jsonb NULL,
  ADD COLUMN IF NOT EXISTS scenario_id uuid NULL,
  ADD COLUMN IF NOT EXISTS ground_truth_context_ids jsonb NULL,
  ADD COLUMN IF NOT EXISTS reference_answer text NULL,
  ADD COLUMN IF NOT EXISTS edge_function_version text NULL,
  ADD COLUMN IF NOT EXISTS app_version text NULL,
  ADD COLUMN IF NOT EXISTS region text NULL DEFAULT 'asia-southeast1'::text,
  ADD COLUMN IF NOT EXISTS rag_mode text NULL DEFAULT 'none'::text,
  ADD COLUMN IF NOT EXISTS rag_documents_retrieved integer NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rag_retrieval_latency_ms integer NULL,
  ADD COLUMN IF NOT EXISTS reranker_latency_ms integer NULL,
  ADD COLUMN IF NOT EXISTS reranker_scores jsonb NULL;

-- Create indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_telemetry_rag_mode ON public.chatbot_telemetry USING btree (rag_mode);
CREATE INDEX IF NOT EXISTS idx_telemetry_run_id ON public.chatbot_telemetry USING btree (run_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_user_id ON public.chatbot_telemetry USING btree (user_id);
CREATE INDEX IF NOT EXISTS idx_telemetry_timestamp ON public.chatbot_telemetry USING btree ("timestamp" DESC);
CREATE INDEX IF NOT EXISTS idx_telemetry_safety_flag ON public.chatbot_telemetry USING btree (safety_flag) WHERE (safety_flag = true);
CREATE INDEX IF NOT EXISTS idx_telemetry_prompt_hash ON public.chatbot_telemetry USING btree (prompt_hash);
CREATE INDEX IF NOT EXISTS idx_telemetry_http_status ON public.chatbot_telemetry USING btree (http_status);
CREATE INDEX IF NOT EXISTS idx_chatbot_telemetry_scenario_id ON public.chatbot_telemetry (scenario_id);

-- trigram GIN index for query_text
CREATE INDEX IF NOT EXISTS idx_chatbot_telemetry_query_text_gin ON public.chatbot_telemetry USING GIN (query_text gin_trgm_ops);

-- GIN index for JSONB retrieved_results
CREATE INDEX IF NOT EXISTS idx_chatbot_telemetry_retrieved_results ON public.chatbot_telemetry USING GIN (retrieved_results);

CREATE INDEX IF NOT EXISTS idx_chatbot_telemetry_run_id_scenario ON public.chatbot_telemetry (run_id, scenario_id);

-- Unique index for run_id (unique constraint via index to be idempotent)
CREATE UNIQUE INDEX IF NOT EXISTS idx_chatbot_telemetry_run_id_unique ON public.chatbot_telemetry (run_id);

-- Comments for documentation (idempotent: re-applying is safe)
COMMENT ON COLUMN public.chatbot_telemetry.query_text IS 'Original user query/input - Required for RAGAS (user_input in RAGAS API)';
COMMENT ON COLUMN public.chatbot_telemetry.response_text IS 'Model response/output - Required for RAGAS (response in RAGAS API)';
COMMENT ON COLUMN public.chatbot_telemetry.retrieved_results IS 'Structured retrieval results with rank, doc_id, chunk_id, chunk_text, similarity_score, reranker_score - Required for RAGAS (retrieved_contexts in RAGAS API)';
COMMENT ON COLUMN public.chatbot_telemetry.scenario_id IS 'Optional mapping to evaluation scenario id (UUID)';
COMMENT ON COLUMN public.chatbot_telemetry.ground_truth_context_ids IS 'Array of relevant chunk IDs - Used for MRR calculation and context relevance evaluation';
COMMENT ON COLUMN public.chatbot_telemetry.reference_answer IS 'Ground truth answer - Optional for RAGAS, useful for audit and debugging';
COMMENT ON COLUMN public.chatbot_telemetry.token_usage_input IS 'Input tokens count - Extracted from token_usage JSON for easier querying';
COMMENT ON COLUMN public.chatbot_telemetry.token_usage_output IS 'Output tokens count - Extracted from token_usage JSON for easier querying';

-- Add check constraint for retrieved_results being an array (if not present)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_retrieved_results_array'
  ) THEN
    ALTER TABLE public.chatbot_telemetry
      ADD CONSTRAINT check_retrieved_results_array
      CHECK (retrieved_results IS NULL OR jsonb_typeof(retrieved_results) = 'array');
  END IF;
END$$;

-- Optionally add a foreign key to auth.users if the table exists (safe guard)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relname = 'users' AND n.nspname = 'auth') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname = 'chatbot_telemetry_user_id_fkey'
    ) THEN
      ALTER TABLE public.chatbot_telemetry
        ADD CONSTRAINT chatbot_telemetry_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE SET NULL;
    END IF;
  END IF;
END$$;
