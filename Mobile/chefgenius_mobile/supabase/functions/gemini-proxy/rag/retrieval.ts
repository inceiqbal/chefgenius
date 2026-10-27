import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { RAGDocument, RagMode, EmbeddingEngine } from '../types.ts'
import {
    RAG_MATCH_COUNT,
    RAG_MATCH_THRESHOLD,
    RAG_ADVANCED_THRESHOLD,
    RAG_INITIAL_FETCH_COUNT,
    BM25_FETCH_COUNT,
    RAG_RRF_K,
    RAG_RERANK_CANDIDATE_COUNT,
} from '../config.ts'
import { generateEmbedding, generateIndoBertEmbedding } from '../utils/embeddings.ts'
import { getRagChunkIndex } from './prompt.ts'
import { log } from '../utils/logger.ts'

export function normalizeSearchText(text: string): string {
    return text.toLowerCase().replace(/[^a-z0-9\s-]+/g, ' ')
}

export function getRagDocKey(doc: RAGDocument): string {
    return [doc.id, doc.title, doc.source, doc.citation_text, doc.metadata?.chunk_idx].join('|')
}

export function dedupeRagDocuments(documents: RAGDocument[]): RAGDocument[] {
    const seen = new Set<string>()
    return documents.filter(doc => {
        const key = getRagDocKey(doc)
        if (seen.has(key)) {
            return false
        }
        seen.add(key)
        return true
    })
}

export async function retrieveContext(
    supabaseService: SupabaseClient,
    userMessage: string,
    apiKey: string,
    ragMode: RagMode,
    runId: string,
    secondaryQuery?: string,
    originalUserMessage?: string,
    embeddingEngine: EmbeddingEngine = 'gemini',
    clientQueryEmbedding?: number[]
): Promise<RAGDocument[]> {
    const isAdvancedLike = ragMode === 'advanced' || ragMode === 'pre_retrieval'
    const fetchCount = isAdvancedLike ? RAG_INITIAL_FETCH_COUNT : RAG_MATCH_COUNT
    const matchThreshold = isAdvancedLike || ragMode === 'post_retrieval' ? RAG_ADVANCED_THRESHOLD : RAG_MATCH_THRESHOLD
    const rpcName = embeddingEngine === 'indobert' ? 'match_knowledge_indobert' : 'match_knowledge'

    const fetchEngineEmbedding = async (txt: string, isOriginalQuery = false): Promise<number[] | null> => {
        if (isOriginalQuery && clientQueryEmbedding && clientQueryEmbedding.length > 0) {
            return clientQueryEmbedding
        }
        if (embeddingEngine === 'indobert') {
            return await generateIndoBertEmbedding(txt, runId)
        }
        return await generateEmbedding(txt, apiKey, 'RETRIEVAL_QUERY')
    }

    try {
        if (ragMode === 'naive' || ragMode === 'post_retrieval') {
            const fetchTarget = ragMode === 'post_retrieval' ? RAG_RERANK_CANDIDATE_COUNT : RAG_MATCH_COUNT
            const queryEmbedding = await fetchEngineEmbedding(userMessage, true)
            if (queryEmbedding) {
                const { data, error } = await supabaseService.rpc(rpcName, {
                    query_embedding: `[${queryEmbedding.join(',')}]`,
                    match_count: fetchTarget,
                    match_threshold: matchThreshold,
                })
                if (!error && data && data.length > 0) {
                    return data as RAGDocument[]
                }
            }
            // Fallback kata kunci jika pencarian vektor tidak mengembalikan dokumen
            const fallbackTerms: string[] = []
            const entityMatches = userMessage.match(/[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+/g) || []
            for (const ent of entityMatches) {
                if (!fallbackTerms.includes(ent)) fallbackTerms.push(ent)
            }
            const acronyms = userMessage.match(/\b[A-Z0-9]{2,}\b|\b[A-Z][a-z]*[A-Z0-9][a-zA-Z0-9]*\b/g) || []
            for (const ac of acronyms) {
                if (ac.length >= 2 && !fallbackTerms.includes(ac)) fallbackTerms.push(ac)
            }
            const stopWords = /pada pasien|berapa|apa|yang|dan|serta|untuk|dalam|terhadap|adalah|jika|masih|belum|mampu|dapat|dicapai|bagaimana/gi
            const cleanedQuery = userMessage.replace(stopWords, ' ').replace(/[^\w\s-]/g, ' ').trim()
            const words = cleanedQuery.split(/\s+/).filter(w => w.length > 3)
            if (words.length > 0) {
                const topThree = words.slice(0, 3).join(' ')
                if (!fallbackTerms.includes(topThree)) fallbackTerms.push(topThree)
            }

            const fallbackDocs: Array<Record<string, unknown>> = []
            const seenIds = new Set<string>()
            for (const term of fallbackTerms.slice(0, 4)) {
                const { data: fb } = await supabaseService
                    .from('knowledge_base')
                    .select('id, category, title, content, source, metadata')
                    .textSearch('content', term, { config: 'indonesian', type: 'plain' })
                    .limit(fetchTarget)
                for (const d of (fb || [])) {
                    const id = String(d.id || '')
                    if (id && !seenIds.has(id)) {
                        seenIds.add(id)
                        fallbackDocs.push(d)
                        if (fallbackDocs.length >= fetchTarget) break
                    }
                }
                if (fallbackDocs.length >= fetchTarget) break
            }

            return fallbackDocs.map(d => ({
                ...(d as object),
                similarity: 0.45,
            })) as RAGDocument[]
        }

        const origQueryText = originalUserMessage || userMessage
        const rewrQueryText = secondaryQuery || userMessage

        let denseOrigDocs: RAGDocument[] = []
        const origEmbedding = await fetchEngineEmbedding(origQueryText, true)
        if (origEmbedding) {
            const { data, error } = await supabaseService.rpc(rpcName, {
                query_embedding: `[${origEmbedding.join(',')}]`,
                match_count: RAG_INITIAL_FETCH_COUNT,
                match_threshold: matchThreshold,
            })
            if (!error && data && data.length > 0) {
                denseOrigDocs = data as RAGDocument[]
            }
        }

        let denseRewrDocs: RAGDocument[] = []
        if (rewrQueryText !== origQueryText) {
            const rewrEmbedding = await fetchEngineEmbedding(rewrQueryText, false)
            if (rewrEmbedding) {
                const { data, error } = await supabaseService.rpc(rpcName, {
                    query_embedding: `[${rewrEmbedding.join(',')}]`,
                    match_count: RAG_INITIAL_FETCH_COUNT,
                    match_threshold: matchThreshold,
                })
                if (!error && data && data.length > 0) {
                    denseRewrDocs = data as RAGDocument[]
                }
            }
        }

        let bm25Docs: RAGDocument[] = []
        const allKwDocs: Array<Record<string, unknown>> = []

        // Ekstraksi entitas medis dan kata kunci untuk pencarian BM25
        const searchTerms: string[] = []

        if (origQueryText) {
            const entityMatches = origQueryText.match(/[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+/g) || []
            for (const ent of entityMatches) {
                if (!searchTerms.includes(ent)) {
                    searchTerms.push(ent)
                }
            }

            const acronyms = origQueryText.match(/\b[A-Z0-9]{2,}\b|\b[A-Z][a-z]*[A-Z0-9][a-zA-Z0-9]*\b/g) || []
            const sortedAcronyms = [...new Set(acronyms)].sort((a, b) => b.length - a.length)
            for (const ac of sortedAcronyms) {
                if (ac.length >= 2 && !searchTerms.includes(ac)) {
                    searchTerms.push(ac)
                }
            }
        }

        if (rewrQueryText) {
            const stopWordsPattern = /pada pasien|berapa|apa|yang|dan|serta|untuk|dalam|terhadap|adalah/gi
            const rewrClean = rewrQueryText.replace(stopWordsPattern, ' ').replace(/[^\w\s-]/g, ' ').trim()
            const rewrWords = rewrClean.split(/\s+/).filter(w => w.length > 2)
            if (rewrWords.length <= 3 && rewrWords.length > 0) {
                const combined = rewrWords.join(' ')
                if (!searchTerms.includes(combined)) searchTerms.push(combined)
            } else if (rewrWords.length > 3) {
                const chunk1 = rewrWords.slice(0, 3).join(' ')
                const chunk2 = rewrWords.slice(3, 6).join(' ')
                if (!searchTerms.includes(chunk1)) searchTerms.push(chunk1)
                if (chunk2 && !searchTerms.includes(chunk2)) searchTerms.push(chunk2)
            }
        }

        if (searchTerms.length < 3 && origQueryText) {
            const stopWords = /pada pasien|berapa|apa|yang|dan|serta|untuk|dalam|terhadap|adalah|jika|masih|belum|mampu|dapat|dicapai|tersebut|takaran|satu|sendok|teh|rasa|dibandingkan|dengan|mengalami|lebih|dari|bawah|lama|wajib|diberikan|sebelum|atau|rutin|menjalani|harian|per|kilogram|berat|badan|ideal|syarat|dipenuhi|paling|jenis|mengatasi|tidak|stabil|spesifik|tindakan|direncanakan|antara|prosedur|saja|rekomendasi|klinis|pilihan/gi
            const origClean = origQueryText.replace(stopWords, ' ').replace(/[^\w\s-]/g, ' ').trim()
            const origWords = origClean.split(/\s+/).filter(w => w.length > 3)
            if (origWords.length >= 2) {
                const pair1 = `${origWords[0]} ${origWords[1]}`
                if (!searchTerms.includes(pair1)) searchTerms.push(pair1)
            }
        }

        for (const term of searchTerms.slice(0, 4)) {
            const { data: kwData, error: kwError } = await supabaseService
                .from('knowledge_base')
                .select('id, category, title, content, source, metadata')
                .textSearch('content', term, { config: 'indonesian', type: 'plain' })
                .limit(BM25_FETCH_COUNT)

            if (!kwError && kwData && kwData.length > 0) {
                allKwDocs.push(...kwData)
            }
        }

        if (allKwDocs.length > 0) {
            const seenIds = new Set<string>()
            const uniqueKwDocs = allKwDocs.filter(d => {
                const id = String(d.id || '')
                if (!id || seenIds.has(id)) return false
                seenIds.add(id)
                return true
            })
            bm25Docs = uniqueKwDocs.map(d => ({
                ...(d as object),
                similarity: 0.45,
            })) as RAGDocument[]
        }

        const rankOrigMap = new Map<string, number>()
        denseOrigDocs.forEach((doc, idx) => {
            const key = getRagDocKey(doc)
            if (!rankOrigMap.has(key)) rankOrigMap.set(key, idx + 1)
        })

        const rankRewrMap = new Map<string, number>()
        denseRewrDocs.forEach((doc, idx) => {
            const key = getRagDocKey(doc)
            if (!rankRewrMap.has(key)) rankRewrMap.set(key, idx + 1)
        })

        const rankBm25Map = new Map<string, number>()
        bm25Docs.forEach((doc, idx) => {
            const key = getRagDocKey(doc)
            if (!rankBm25Map.has(key)) rankBm25Map.set(key, idx + 1)
        })

        const allCandidates = dedupeRagDocuments([...denseOrigDocs, ...denseRewrDocs, ...bm25Docs])
        const candidatePoolSizeBeforeRrf = allCandidates.length

        const fusedDocs = allCandidates.map(doc => {
            const key = getRagDocKey(doc)
            const rOrig = rankOrigMap.get(key)
            const rRewr = rankRewrMap.get(key)
            const rBm25 = rankBm25Map.get(key)

            let rrfScore = 0
            if (rOrig !== undefined) rrfScore += 1 / (RAG_RRF_K + rOrig)
            if (rRewr !== undefined) rrfScore += 1 / (RAG_RRF_K + rRewr)
            if (rBm25 !== undefined) rrfScore += 1 / (RAG_RRF_K + rBm25)

            return {
                ...doc,
                rrf_score: rrfScore,
                rank_original: rOrig,
                rank_rewritten: rRewr,
                rank_bm25: rBm25,
            }
        })

        fusedDocs.sort((a, b) => (b.rrf_score ?? 0) - (a.rrf_score ?? 0))

        const targetCandidateCount = ragMode === 'pre_retrieval' ? RAG_MATCH_COUNT : RAG_RERANK_CANDIDATE_COUNT
        const finalCandidates = fusedDocs.slice(0, targetCandidateCount)

        log.info(runId, `RAG [${ragMode}]: True 3-way RRF complete`, {
            rrf_k: RAG_RRF_K,
            pool_size_before_rrf: candidatePoolSizeBeforeRrf,
            pool_size_after_rrf: finalCandidates.length,
            target_candidate_count: targetCandidateCount,
            top_candidates_preview: finalCandidates.slice(0, 5).map(d => ({
                chunk: `${d.title}#${getRagChunkIndex(d)}`,
                rrf: d.rrf_score?.toFixed(5),
                orig_rank: d.rank_original ?? 'N/A',
                rewr_rank: d.rank_rewritten ?? 'N/A',
                bm25_rank: d.rank_bm25 ?? 'N/A',
            }))
        })

        return finalCandidates
    } catch (ragError) {
        log.error(runId, `RAG [${ragMode}]: Retrieval failed`, ragError)
        return []
    }
}
