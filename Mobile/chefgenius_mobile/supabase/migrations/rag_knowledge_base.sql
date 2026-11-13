-- ============================================================
-- RAG KNOWLEDGE BASE SCHEMA v2.0 (with enriched metadata)
-- Prerequisites: Run in Supabase SQL Editor
-- ============================================================

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Create knowledge_base table (enriched)
CREATE TABLE IF NOT EXISTS knowledge_base (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Core content
  category TEXT NOT NULL CHECK (category IN ('ingredient', 'recipe', 'health_tip', 'nutrition_guide')),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  
  -- Source attribution
  source TEXT NOT NULL DEFAULT '',
  source_url TEXT DEFAULT '',
  source_doc_ref TEXT DEFAULT '',
  source_date TEXT DEFAULT '',
  source_excerpt TEXT DEFAULT '',
  
  -- Confidence & entry typing
  confidence FLOAT DEFAULT 0.8 CHECK (confidence >= 0 AND confidence <= 1),
  entry_type TEXT DEFAULT 'fakta' CHECK (entry_type IN ('fakta', 'guideline', 'kalkulasi', 'interpretasi')),
  citation_text TEXT DEFAULT '',
  
  -- Audit trail
  curation_notes TEXT DEFAULT '',
  last_verified_at TIMESTAMPTZ DEFAULT NOW(),
  verified_by TEXT DEFAULT 'AI-assisted curation',
  
  -- Embedding
  embedding vector(3072),
  embedding_model TEXT DEFAULT 'gemini-embedding-001',
  embedding_dim INT DEFAULT 3072,
  
  -- Legacy metadata (kept for backward compatibility)
  metadata JSONB DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_knowledge_base_category ON knowledge_base(category);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_entry_type ON knowledge_base(entry_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_confidence ON knowledge_base(confidence);

-- 4. Text search indexes for fallback keyword search
CREATE INDEX IF NOT EXISTS idx_knowledge_base_title ON knowledge_base USING gin(to_tsvector('indonesian', title));
CREATE INDEX IF NOT EXISTS idx_knowledge_base_content ON knowledge_base USING gin(to_tsvector('indonesian', content));

-- 5. RPC function for semantic search (cosine similarity)
-- Returns citation_text for traceable output
CREATE OR REPLACE FUNCTION match_knowledge(
  query_embedding vector(3072),
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
    1 - (kb.embedding <=> query_embedding) AS similarity
  FROM knowledge_base kb
  WHERE 
    kb.embedding IS NOT NULL
    AND (filter_category IS NULL OR kb.category = filter_category)
    AND 1 - (kb.embedding <=> query_embedding) > match_threshold
  ORDER BY kb.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- 6. RPC function for keyword fallback search
CREATE OR REPLACE FUNCTION search_knowledge_text(
  search_query TEXT,
  match_count INT DEFAULT 3,
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
  rank FLOAT
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
    ts_rank(
      to_tsvector('indonesian', kb.title || ' ' || kb.content),
      plainto_tsquery('indonesian', search_query)
    ) AS rank
  FROM knowledge_base kb
  WHERE 
    (filter_category IS NULL OR kb.category = filter_category)
    AND to_tsvector('indonesian', kb.title || ' ' || kb.content) @@ plainto_tsquery('indonesian', search_query)
  ORDER BY rank DESC
  LIMIT match_count;
END;
$$;

-- 7. Enable RLS
ALTER TABLE knowledge_base ENABLE ROW LEVEL SECURITY;

-- 8. Allow all authenticated users to read (knowledge is public within app)
CREATE POLICY "Authenticated users can read knowledge_base" ON knowledge_base
  FOR SELECT TO authenticated USING (true);

-- 9. Metadata summary view (for audit/thesis)
CREATE OR REPLACE VIEW kb_metadata_summary AS
SELECT 
  category,
  entry_type,
  COUNT(*) as total_entries,
  ROUND(AVG(confidence)::numeric, 2) as avg_confidence,
  MIN(source_date) as earliest_source,
  MAX(last_verified_at) as last_verified
FROM knowledge_base
GROUP BY category, entry_type
ORDER BY category, entry_type;
