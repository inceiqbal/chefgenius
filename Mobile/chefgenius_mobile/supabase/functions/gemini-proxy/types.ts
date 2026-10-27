export type RagMode = 'none' | 'naive' | 'pre_retrieval' | 'post_retrieval' | 'advanced'
export type EmbeddingEngine = 'gemini' | 'indobert'

export interface ChatbotRequest {
    action: 'chatbot' | 'generate_recipe' | 'translate' | 'tts' | 'vision' | 'diagnose_reranker'
    rag_mode?: RagMode
    embedding_engine?: EmbeddingEngine
    query_embedding?: number[]
    user_id?: string
    session_id?: string
    app_version?: string
    userMessage?: string
    max_tokens?: number
    contextData?: {
        pantryItems?: string[]
        dietPreferences?: string[]
        allergies?: string[]
        currentRecipe?: {
            name?: string
            ingredients?: string[]
            description?: string
        }
    }
    prompt?: string
    text?: string
    targetLang?: string
    model?: string
    imageBase64?: string
    temperature?: number
    maxTokens?: number
}

export interface TokenUsage {
    input_tokens: number
    output_tokens: number
    total_tokens: number
}

export interface TelemetryRecord {
    run_id: string
    user_id: string | null
    session_id: string | null
    prompt_id: string
    prompt_hash: string
    model_name: string
    model_version: string
    temperature: number
    max_tokens: number
    token_usage: TokenUsage | null
    latency_ms: number | null
    http_status: number | null
    response_truncated: boolean
    safety_flag: boolean
    safety_reasons: string[]
    post_processing_actions: string[]
    response_pointer: string | null
    response_text: string | null
    scenario_id: string | null
    reference_answer: string | null
    ground_truth_document: string | null
    ground_truth_chunk_idx: string[] | null
    edge_function_version: string
    app_version: string | null
    region: string
    rag_mode: RagMode
    embedding_engine?: EmbeddingEngine
    rag_documents_retrieved: number
    rag_retrieval_latency_ms: number | null
    reranker_latency_ms: number | null
    reranker_scores: Record<string, number>[] | null
}

export interface SafetyResult {
    text: string
    safety_flag: boolean
    safety_reasons: string[]
    post_processing_actions: string[]
}

export interface RAGDocument {
    id: string
    category: string
    title: string
    content: string
    source: string
    citation_text?: string
    confidence?: number
    entry_type?: string
    metadata?: Record<string, unknown>
    similarity: number
    reranker_score?: number
    rrf_score?: number
    hybrid_score?: number
    rank_original?: number
    rank_rewritten?: number
    rank_bm25?: number
}

export interface RerankerScoreLog {
    chunk_id: string
    title: string
    similarity: number
    rrf_score?: number
    reranker_score: number
    hybrid_score?: number
}

export type RerankerStatus =
    | 'success'
    | 'skipped_no_key'
    | 'skipped_no_documents'
    | 'fallback_api_error'
    | 'fallback_score_mismatch'
    | 'fallback_timeout'
    | 'fallback_exception'
    | 'fallback_gemini_ranker'

export type QueryRewriteStatus =
    | 'success'
    | 'fallback_api_error'
    | 'fallback_empty'
    | 'fallback_validation'
    | 'fallback_exception'

export interface QueryRewriteResult {
    query: string
    status: QueryRewriteStatus
    fallback_reason?: string
}
