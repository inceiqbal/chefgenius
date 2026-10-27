declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { RagMode, EmbeddingEngine } from './types.ts'

export const DEFAULT_RAG_MODE: RagMode = 'advanced'
export const DEFAULT_EMBEDDING_ENGINE: EmbeddingEngine = 'indobert'

export const EDGE_FUNCTION_VERSION = "v4.4.0-dual-embedding-indobert"
export const MODEL_NAME = "gemini-3-flash-preview"
export const MODEL_VERSION = "2026-01-10"
export const EMBEDDING_MODEL = "gemini-embedding-001"
export const INDOBERT_MODEL = "firqaaa/indo-sentence-bert-base"

export const RAG_MATCH_COUNT = 5
export const RAG_MATCH_THRESHOLD = 0.5
export const RAG_ADVANCED_THRESHOLD = 0.25

export const RAG_INITIAL_FETCH_COUNT = Number(Deno.env.get("RAG_INITIAL_FETCH_COUNT") || 20)
export const BM25_FETCH_COUNT = Number(Deno.env.get("BM25_FETCH_COUNT") || 20)
export const RAG_RRF_K = Number(Deno.env.get("RAG_RRF_K") || 5)
export const RAG_RERANK_CANDIDATE_COUNT = Number(Deno.env.get("RAG_RERANK_CANDIDATE_COUNT") || 20)
export const RAG_RERANK_TOP_K = Number(Deno.env.get("RAG_RERANK_TOP_K") || 5)

export const BGE_QUERY_MODE: 'original' | 'rewritten' =
    (Deno.env.get("BGE_QUERY_MODE") || "original").toLowerCase() as 'original' | 'rewritten'

export const BGE_PASSAGE_MODE: 'content_only' | 'citation_plus_content' =
    (Deno.env.get("BGE_PASSAGE_MODE") || "citation_plus_content").toLowerCase() as 'content_only' | 'citation_plus_content'

export const RERANKER_MODEL = 'BAAI/bge-reranker-v2-m3'
export const RERANKER_ENDPOINTS = [
    `https://router.huggingface.co/hf-inference/models/${RERANKER_MODEL}`,
]
export const RERANKER_TIMEOUT_MS = Number(Deno.env.get("RERANKER_TIMEOUT_MS") || 60000)

export const DEFAULT_TEMPERATURE = 0.4
export const DEFAULT_MAX_TOKENS = 8192
export const MAX_TOKENS_LIMIT = 8192
export const REGION = Deno.env.get("DENO_REGION") || "asia-southeast1"

export const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export const BLOCKED_KEYWORDS = [
    "resep obat", "meresepkan", "dosis obat", "konsumsi obat kimia"
]

export const DISCLAIMER = "\n\n *Informasi ini bersifat edukatif dan tidak menggantikan saran tenaga kesehatan profesional.*"

export function generateUUID(): string {
    return crypto.randomUUID()
}

export function getRandomApiKey(): string {
    const singleKey = (Deno.env.get('GEMINI_API_KEY') || '').trim()
    const rawKeys = Deno.env.get('GEMINI_KEYS') || ''
    const keys = rawKeys.split(/[,;\n]+/).map(k => k.trim()).filter(Boolean)
    if (singleKey && !keys.includes(singleKey)) {
        keys.unshift(singleKey)
    }
    if (keys.length === 0) return singleKey
    return keys[Math.floor(Math.random() * keys.length)]
}

export function sigmoid(x: number): number {
    return 1 / (1 + Math.exp(-x))
}