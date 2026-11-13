-- ============================================================
-- Migration: Add IndoBERT match function and vector index
-- Model: firqaaa/indo-sentence-bert-base (768 dimensions)
-- Target: knowledge_base.embedding_indobert
-- ============================================================

-- 1. Ensure embedding_indobert column exists with 768 dimensions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'knowledge_base' 
          AND column_name = 'embedding_indobert'
    ) THEN
        ALTER TABLE public.knowledge_base ADD COLUMN embedding_indobert public.vector(768);
    END IF;
END $$;

-- 2. Create HNSW index for fast 768-dim cosine similarity search
CREATE INDEX IF NOT EXISTS idx_knowledge_base_embedding_indobert
ON public.knowledge_base USING hnsw (embedding_indobert vector_cosine_ops);

-- 3. Create RPC function: match_knowledge_indobert
CREATE OR REPLACE FUNCTION public.match_knowledge_indobert(
  query_embedding public.vector(768),
  match_count INT DEFAULT 3,
  match_threshold FLOAT DEFAULT 0.3,
  filter_category TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  category TEXT,
  title TEXT,
  content TEXT,
  source TEXT,
  citation_text TEXT,
  confidence FLOAT,
  entry_type TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kb.id,
    kb.category,
    kb.title,
    kb.content,
    kb.source,
    kb.citation_text,
    kb.confidence,
    kb.entry_type,
    kb.metadata,
    1 - (kb.embedding_indobert <=> query_embedding) AS similarity
  FROM public.knowledge_base kb
  WHERE 
    kb.embedding_indobert IS NOT NULL
    AND (filter_category IS NULL OR kb.category = filter_category)
    AND 1 - (kb.embedding_indobert <=> query_embedding) > match_threshold
  ORDER BY kb.embedding_indobert <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 4. Add embedding_engine column to chatbot_telemetry for thesis tracking
ALTER TABLE public.chatbot_telemetry
ADD COLUMN IF NOT EXISTS embedding_engine TEXT DEFAULT 'gemini';

