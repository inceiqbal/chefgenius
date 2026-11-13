declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { RAGDocument, RerankerStatus, RerankerScoreLog } from '../types.ts'
import {
    RERANKER_MODEL,
    RERANKER_ENDPOINTS,
    RERANKER_TIMEOUT_MS,
    RAG_RERANK_TOP_K,
    BGE_PASSAGE_MODE,
} from '../config.ts'
import { getRagChunkIndex } from './prompt.ts'
import { log } from '../utils/logger.ts'

export async function rerankDocuments(
    clinicalQuery: string,
    documents: RAGDocument[],
    runId: string,
    _geminiApiKey?: string,
    passageMode: 'content_only' | 'citation_plus_content' = BGE_PASSAGE_MODE
): Promise<{
    documents: RAGDocument[]
    latency_ms: number
    scores: Record<string, number>[]
    status: RerankerStatus
    safeguard_triggered: boolean
}> {
    const startTime = Date.now()

    if (documents.length === 0) {
        return { documents: [], latency_ms: 0, scores: [], status: 'skipped_no_documents', safeguard_triggered: false }
    }

    try {
        const queryForReranker = clinicalQuery.trim()

        const documentTexts = documents.map(doc => {
            if (passageMode === 'content_only') {
                return doc.content
            }
            const citation = typeof doc.metadata?.citation_text === 'string' && doc.metadata.citation_text.trim()
                ? doc.metadata.citation_text.trim()
                : (doc.citation_text || doc.title)
            return `${citation}\n${doc.content}`
        })

        let scores: number[] = []
        let parsedEndpoint: string | null = null
        let parsedVariant: string | null = null
        let anyTimeout = false
        let anyParseMismatch = false
        const attemptErrors: string[] = []

        // Primary: HuggingFace Inference API for BAAI/bge-reranker-v2-m3
        const hfApiKey = Deno.env.get('HUGGINGFACE_API_KEY')
        if (hfApiKey) {
            log.info(runId, 'Reranker: Calling HuggingFace Inference API for BGE', {
                model: RERANKER_MODEL,
                num_documents: documents.length,
            })

            const payloadVariants: Array<{ name: string; body: object }> = [
                {
                    name: 'text_pair_objects',
                    body: {
                        inputs: documentTexts.map(text => ({
                            text: queryForReranker,
                            text_pair: text,
                        })),
                        parameters: {
                            function_to_apply: 'none',
                            top_k: 1,
                        },
                    },
                },
                {
                    name: 'pair_array',
                    body: {
                        inputs: documentTexts.map(text => [queryForReranker, text]),
                        parameters: {
                            function_to_apply: 'none',
                            top_k: 1,
                        },
                    },
                },
            ]

            const extractScoreFromLabelArray = (item: Array<{ label?: string; score?: number }>): number => {
                const normalized = item
                    .map(entry => ({
                        label: (entry.label || '').toUpperCase(),
                        score: typeof entry.score === 'number' ? entry.score : 0,
                    }))

                if (normalized.length === 1) {
                    return normalized[0].score
                }

                const relevant = normalized.find(entry =>
                    entry.label === 'LABEL_1' || entry.label === 'RELEVANT' || entry.label === 'TRUE'
                )
                if (relevant) return relevant.score

                const irrelevant = normalized.find(entry =>
                    entry.label === 'LABEL_0' || entry.label === 'IRRELEVANT' || entry.label === 'FALSE'
                )
                if (irrelevant) return -irrelevant.score

                return normalized.reduce((maxValue, entry) => Math.max(maxValue, entry.score), 0)
            }

            const parseScoresFromResult = (result: unknown): number[] => {
                if (Array.isArray(result) && result.every(item => typeof item === 'number')) {
                    return result as number[]
                }

                if (Array.isArray(result)) {
                    return result.map((item: unknown) => {
                        if (Array.isArray(item)) {
                            return extractScoreFromLabelArray(item as Array<{ label?: string; score?: number }>)
                        }

                        if (typeof item === 'object' && item !== null) {
                            const maybeScore = (item as { score?: unknown }).score
                            if (typeof maybeScore === 'number') {
                                return maybeScore
                            }

                            const maybeLabel = (item as { label?: unknown }).label
                            if (typeof maybeLabel === 'string' && typeof maybeScore === 'number') {
                                return maybeLabel.toUpperCase() === 'LABEL_0' ? -maybeScore : maybeScore
                            }
                        }

                        return 0
                    })
                }

                if (typeof result === 'object' && result !== null) {
                    const record = result as Record<string, unknown>

                    if (Array.isArray(record.scores) && record.scores.every(item => typeof item === 'number')) {
                        return record.scores as number[]
                    }

                    if (Array.isArray(record.output)) {
                        return parseScoresFromResult(record.output)
                    }

                    if (Array.isArray(record.data)) {
                        return parseScoresFromResult(record.data)
                    }
                }

                return []
            }

            for (const endpoint of RERANKER_ENDPOINTS) {
                for (const variant of payloadVariants) {
                    const abortController = new AbortController()
                    const timeoutId = setTimeout(() => abortController.abort(), RERANKER_TIMEOUT_MS)

                    try {
                        const candidateResponse = await fetch(
                            endpoint,
                            {
                                method: 'POST',
                                headers: {
                                    'Authorization': `Bearer ${hfApiKey}`,
                                    'Content-Type': 'application/json',
                                },
                                body: JSON.stringify(variant.body),
                                signal: abortController.signal,
                            }
                        )

                        if (!candidateResponse.ok) {
                            const errorText = await candidateResponse.text()
                            attemptErrors.push(`${endpoint} [${variant.name}] -> HTTP ${candidateResponse.status}: ${errorText}`)
                            log.warn(runId, 'Reranker: HF endpoint returned non-OK response', {
                                endpoint,
                                variant: variant.name,
                                status: candidateResponse.status,
                            })
                            continue
                        }

                        const result = await candidateResponse.json()
                        const parsedScores = parseScoresFromResult(result)

                        if (parsedScores.length === documents.length) {
                            scores = parsedScores
                            parsedEndpoint = endpoint
                            parsedVariant = `hf_api_${variant.name}`
                            log.info(runId, 'Reranker: HF Inference API succeeded', {
                                endpoint,
                                variant: variant.name,
                            })
                            break
                        }

                        anyParseMismatch = true
                        attemptErrors.push(`${endpoint} [${variant.name}] -> score_mismatch expected=${documents.length} got=${parsedScores.length}`)
                    } catch (error) {
                        const isTimeout = error instanceof DOMException && error.name === 'AbortError'
                        if (isTimeout) {
                            anyTimeout = true
                            attemptErrors.push(`${endpoint} [${variant.name}] -> timeout(${RERANKER_TIMEOUT_MS}ms)`)
                        } else {
                            attemptErrors.push(`${endpoint} [${variant.name}] -> ${error instanceof Error ? error.message : String(error)}`)
                        }
                    } finally {
                        clearTimeout(timeoutId)
                    }
                }

                if (scores.length === documents.length) {
                    break
                }
            }
        }

        if (scores.length !== documents.length) {
            log.warn(runId, 'Reranker: HuggingFace BGE Cross-Encoder unavailable, falling back to retrieval order', {
                attempts: attemptErrors,
            })
            return {
                documents: documents.slice(0, RAG_RERANK_TOP_K),
                latency_ms: Date.now() - startTime,
                scores: [],
                status: anyTimeout ? 'fallback_timeout' : anyParseMismatch ? 'fallback_score_mismatch' : 'fallback_api_error',
                safeguard_triggered: false,
            }
        }

        const latency_ms = Date.now() - startTime

        const scoredDocs = documents.map((doc, i) => {
            const rawBgeScore = scores[i]
            return {
                ...doc,
                reranker_score: rawBgeScore,
                hybrid_score: rawBgeScore,
            }
        })

        scoredDocs.sort((a, b) => (b.reranker_score ?? 0) - (a.reranker_score ?? 0))

        const scoreLog: RerankerScoreLog[] = scoredDocs.map(d => ({
            chunk_id: getRagChunkIndex(d),
            title: d.title,
            similarity: d.similarity,
            rrf_score: d.rrf_score,
            reranker_score: d.reranker_score ?? 0,
            hybrid_score: d.hybrid_score,
        }))

        log.info(runId, `Reranker: Full pool scores (all ${scoredDocs.length} docs, top-${RAG_RERANK_TOP_K} kept by PURE BGE score)`, {
            latency_ms,
            endpoint: parsedEndpoint,
            payload_variant: parsedVariant,
            all_scores: scoreLog,
            safeguard_triggered: false,
            selected: scoreLog.slice(0, RAG_RERANK_TOP_K).map(s => `${s.title}#${s.chunk_id} => ${s.reranker_score.toFixed(4)}`),
        })

        const topDocs = scoredDocs.slice(0, RAG_RERANK_TOP_K)

        return {
            documents: topDocs,
            latency_ms,
            scores: scoreLog as unknown as Record<string, number>[],
            status: 'success',
            safeguard_triggered: false,
        }
    } catch (error) {
        const latency_ms = Date.now() - startTime
        const isTimeout = error instanceof DOMException && error.name === 'AbortError'
        if (isTimeout) {
            log.warn(runId, 'Reranker: Timeout, falling back to original order', {
                timeout_ms: RERANKER_TIMEOUT_MS,
            })
        } else {
            log.error(runId, 'Reranker: Exception, falling back to original order', error)
        }
        return {
            documents: documents.slice(0, RAG_RERANK_TOP_K),
            latency_ms,
            scores: [],
            status: isTimeout ? 'fallback_timeout' : 'fallback_exception',
            safeguard_triggered: false,
        }
    }
}
