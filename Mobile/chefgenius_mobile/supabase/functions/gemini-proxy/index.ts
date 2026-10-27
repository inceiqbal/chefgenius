declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { vignettesMetadata as vignettesMetadataV8 } from "./vignettes_master_v8_data.ts"

import {
    corsHeaders,
    MODEL_NAME,
    MODEL_VERSION,
    DEFAULT_TEMPERATURE,
    DEFAULT_MAX_TOKENS,
    MAX_TOKENS_LIMIT,
    REGION,
    EDGE_FUNCTION_VERSION,
    DEFAULT_RAG_MODE,
    DEFAULT_EMBEDDING_ENGINE,
    BGE_QUERY_MODE,
    BGE_PASSAGE_MODE,
    RERANKER_MODEL,
    getRandomApiKey,
    generateUUID,
} from './config.ts'

import {
    ChatbotRequest,
    TelemetryRecord,
    RagMode,
    EmbeddingEngine,
    RAGDocument,
} from './types.ts'

import { log } from './utils/logger.ts'
import { applySafetyPostProcessing } from './utils/safety.ts'
import { storeResponse, parseGeminiResponse, getMockGeminiResponse } from './utils/telemetry.ts'
import { rewriteQueryForRetrieval, enrichRewrittenQuery } from './rag/query_rewrite.ts'
import { retrieveContext } from './rag/retrieval.ts'
import { rerankDocuments } from './rag/reranker.ts'
import { buildSystemPrompt, computePromptHash, getRagChunkIndex } from './rag/prompt.ts'

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    const startTime = Date.now()
    const runId = generateUUID()

    const telemetry: TelemetryRecord = {
        run_id: runId,
        user_id: null,
        session_id: null,
        prompt_id: '',
        prompt_hash: '',
        model_name: MODEL_NAME,
        model_version: MODEL_VERSION,
        temperature: DEFAULT_TEMPERATURE,
        max_tokens: DEFAULT_MAX_TOKENS,
        token_usage: null,
        latency_ms: null,
        http_status: null,
        response_truncated: false,
        safety_flag: false,
        safety_reasons: [],
        post_processing_actions: [],
        response_pointer: null,
        response_text: null,
        scenario_id: null,
        reference_answer: null,
        ground_truth_document: null,
        ground_truth_chunk_idx: null,
        edge_function_version: EDGE_FUNCTION_VERSION,
        app_version: null,
        region: REGION,
        rag_mode: 'none',
        rag_documents_retrieved: 0,
        rag_retrieval_latency_ms: null,
        reranker_latency_ms: null,
        reranker_scores: null,
    }

    try {
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            log.warn(runId, 'Request without authorization header')
            return new Response(
                JSON.stringify({ error: 'Unauthorized', run_id: runId }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseUrl = Deno.env.get('SUPABASE_URL')
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')

        if (!supabaseUrl || !supabaseAnonKey) {
            log.error(runId, 'Missing Supabase configuration')
            return new Response(
                JSON.stringify({ error: 'Server configuration error', run_id: runId }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const jwt = authHeader.replace('Bearer ', '')
        const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } },
            auth: { autoRefreshToken: false, persistSession: false }
        })

        let supabaseService: SupabaseClient | null = null
        if (supabaseServiceKey) {
            supabaseService = createClient(supabaseUrl, supabaseServiceKey, {
                auth: { autoRefreshToken: false, persistSession: false }
            })
        } else {
            log.warn(runId, 'SUPABASE_SERVICE_ROLE_KEY not set, telemetry will not be saved')
        }

        let userId: string | null = null
        let userEmail: string | null = null

        const { data: { user }, error: authError } = await supabaseAuth.auth.getUser(jwt)
        if (authError || !user) {
            try {
                const payload = JSON.parse(atob(jwt.split('.')[1]))
                userId = payload.sub || null
                userEmail = payload.email || null

                if (!userId) {
                    log.error(runId, 'Could not extract user ID from JWT')
                    return new Response(
                        JSON.stringify({ error: 'Invalid token', run_id: runId }),
                        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
                }
                log.info(runId, 'User verified via JWT decode', { userId, email: userEmail })
            } catch (decodeError) {
                log.error(runId, 'JWT decode failed', decodeError)
                return new Response(
                    JSON.stringify({ error: 'Invalid token', run_id: runId }),
                    { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
        } else {
            userId = user.id
            userEmail = user.email || null
            log.info(runId, 'User verified via getUser', { userId, email: userEmail })
        }

        const body: ChatbotRequest = await req.json()
        const geminiApiKey = getRandomApiKey()

        if (!geminiApiKey) {
            log.error(runId, 'No Gemini API key configured')
            return new Response(
                JSON.stringify({ error: 'Gemini API not configured', run_id: runId }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        if (body.action === 'diagnose_reranker') {
            const hfApiKey = Deno.env.get('HUGGINGFACE_API_KEY')
            const indobertUrl = Deno.env.get('INDOBERT_EMBEDDING_URL')
            const bgeServiceUrl = Deno.env.get('BGE_RERANKER_URL') ||
                (indobertUrl ? indobertUrl.replace(/\/embed\/?$/, '/rerank') : 'http://127.0.0.1:8000/rerank')

            let bgeServiceStatus: unknown = null
            try {
                const bgeResp = await fetch(bgeServiceUrl, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        query: 'krisis hipertensi',
                        documents: ['penurunan tensi target 140', 'resep masakan padang']
                    })
                })
                const bgeData = await bgeResp.json()
                bgeServiceStatus = { status: bgeResp.status, data: bgeData }
            } catch (err) {
                bgeServiceStatus = { error: err instanceof Error ? err.message : String(err) }
            }

            const modelsToTest = ['BAAI/bge-reranker-v2-m3', 'BAAI/bge-reranker-base']
            const testResults: unknown[] = []
            for (const m of modelsToTest) {
                for (const base of ['https://router.huggingface.co/hf-inference/models/', 'https://api-inference.huggingface.co/models/']) {
                    const url = `${base}${m}`
                    try {
                        const res = await fetch(url, {
                            method: 'POST',
                            headers: {
                                'Authorization': `Bearer ${hfApiKey}`,
                                'Content-Type': 'application/json',
                            },
                            body: JSON.stringify({
                                inputs: [
                                    { text: 'krisis hipertensi', text_pair: 'tekanan darah tinggi' }
                                ]
                            })
                        })
                        const text = await res.text()
                        testResults.push({ model: m, url, status: res.status, body: text.slice(0, 300) })
                    } catch (e: unknown) {
                        testResults.push({ model: m, url, error: e instanceof Error ? e.message : String(e) })
                    }
                }
            }
            return new Response(JSON.stringify({
                reranker_model: RERANKER_MODEL,
                bge_service_url: bgeServiceUrl,
                bge_service_result: bgeServiceStatus,
                has_hf_key: !!hfApiKey,
                hf_key_preview: hfApiKey ? `${hfApiKey.slice(0, 6)}...${hfApiKey.slice(-4)}` : null,
                indobert_url: indobertUrl,
                test_results: testResults
            }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (body.action !== 'chatbot') {
            log.info(runId, 'Processing non-chatbot action', { action: body.action })

            let geminiUrl: string
            let geminiBody: object

            switch (body.action) {
                case 'generate_recipe':
                    geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${body.model || MODEL_NAME}:generateContent?key=${geminiApiKey}`
                    geminiBody = {
                        contents: [{ parts: [{ text: body.prompt }] }],
                        generationConfig: {
                            temperature: body.temperature ?? 0.9,
                            topK: 40,
                            topP: 0.95,
                            maxOutputTokens: body.maxTokens ?? 8192,
                        },
                        safetySettings: [
                            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
                            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
                            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
                            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
                        ]
                    }
                    break

                case 'translate':
                    geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${geminiApiKey}`
                    geminiBody = {
                        contents: [{
                            parts: [{
                                text: `Translate the following text to ${body.targetLang === 'id' ? 'Indonesian' : 'English'}. Only provide the translation, no explanations:\n\n${body.text}`
                            }]
                        }],
                        generationConfig: {
                            temperature: 0.3,
                            maxOutputTokens: 1024,
                        }
                    }
                    break

                case 'tts':
                    geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=${geminiApiKey}`
                    geminiBody = {
                        contents: [{ parts: [{ text: body.text }] }],
                        generationConfig: {
                            responseModalities: ["AUDIO"],
                            speechConfig: {
                                voiceConfig: {
                                    prebuiltVoiceConfig: { voiceName: "Aoede" }
                                }
                            }
                        },
                        model: "gemini-2.5-flash-preview-tts"
                    }
                    break

                case 'vision':
                    geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${geminiApiKey}`
                    geminiBody = {
                        contents: [{
                            parts: [
                                { text: body.prompt || "Identifikasi bahan makanan dalam gambar. Output: JSON Array String Bahasa Indonesia." },
                                {
                                    inlineData: {
                                        mimeType: "image/jpeg",
                                        data: body.imageBase64
                                    }
                                }
                            ]
                        }],
                        generationConfig: {
                            temperature: 0.4,
                            maxOutputTokens: 1024,
                        }
                    }
                    break

                default:
                    return new Response(
                        JSON.stringify({ error: 'Invalid action', run_id: runId }),
                        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    )
            }

            try {
                const geminiResponse = await fetch(geminiUrl, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(geminiBody)
                })

                const geminiResult = await geminiResponse.json()
                const latencyMs = Date.now() - startTime

                log.info(runId, `${body.action} completed`, {
                    status: geminiResponse.status,
                    latency_ms: latencyMs
                })

                return new Response(
                    JSON.stringify(geminiResult),
                    {
                        status: geminiResponse.status,
                        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                    }
                )
            } catch (fetchError) {
                log.error(runId, `${body.action} fetch failed`, fetchError)
                return new Response(
                    JSON.stringify({ error: 'Failed to call Gemini API', run_id: runId }),
                    { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
        }

        if (!body.userMessage) {
            return new Response(
                JSON.stringify({ error: 'userMessage is required', run_id: runId }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        telemetry.user_id = body.user_id || userId
        telemetry.session_id = body.session_id || null
        telemetry.app_version = body.app_version || null

        if (body.max_tokens && body.max_tokens > 0) {
            telemetry.max_tokens = Math.min(body.max_tokens, MAX_TOKENS_LIMIT)
        }

        log.info(runId, 'Processing chatbot request', {
            user_email: userEmail,
            max_tokens: telemetry.max_tokens
        })

        const ragMode: RagMode = body.rag_mode || DEFAULT_RAG_MODE
        telemetry.rag_mode = ragMode

        const embeddingEngine: EmbeddingEngine = body.embedding_engine || DEFAULT_EMBEDDING_ENGINE
        telemetry.embedding_engine = embeddingEngine
        telemetry.post_processing_actions.push(`embedding_engine:${embeddingEngine}`)

        const promptId = ragMode === 'none' ? 'chef_cei_v2.0_baseline'
            : ragMode === 'naive' ? `chef_cei_v2.0_naive_rag_${embeddingEngine}`
            : ragMode === 'pre_retrieval' ? `chef_cei_v2.0_pre_retrieval_rag_${embeddingEngine}`
            : ragMode === 'post_retrieval' ? `chef_cei_v2.0_post_retrieval_rag_${embeddingEngine}`
            : `chef_cei_v2.0_advanced_rag_${embeddingEngine}`
        telemetry.prompt_id = promptId

        log.info(runId, `Architecture mode: ${ragMode} | Embedding engine: ${embeddingEngine}`, { prompt_id: promptId })

        let ragDocuments: RAGDocument[] = []
        let advancedModeNotice: string | null = null

        if (ragMode !== 'none' && supabaseService) {
            const ragStartTime = Date.now()

            let queryForRetrieval = body.userMessage
            let rewrittenQueryForReranker = body.userMessage

            if (ragMode === 'advanced' || ragMode === 'pre_retrieval') {
                log.info(runId, `RAG [${ragMode}]: Starting pre-retrieval query rewriting`)
                const rewriteResult = await rewriteQueryForRetrieval(body.userMessage, geminiApiKey, runId)

                telemetry.post_processing_actions.push(`query_rewrite_status:${rewriteResult.status}`)
                if (rewriteResult.fallback_reason) {
                    telemetry.post_processing_actions.push(`query_rewrite_fallback_reason:${rewriteResult.fallback_reason}`)
                }
                if (rewriteResult.status === 'success') {
                    telemetry.post_processing_actions.push(`query_rewritten:${rewriteResult.query}`)
                }

                rewrittenQueryForReranker = enrichRewrittenQuery(rewriteResult.query, body.userMessage)
                if (rewrittenQueryForReranker !== rewriteResult.query) {
                    log.info(runId, 'QueryEnrich: Keywords injected', {
                        before: rewriteResult.query.slice(0, 80),
                        after: rewrittenQueryForReranker.slice(0, 120),
                    })
                    telemetry.post_processing_actions.push(`query_enriched:${rewrittenQueryForReranker}`)
                }

                queryForRetrieval = rewrittenQueryForReranker
                telemetry.post_processing_actions.push('hyde_disabled')
            }

            log.info(runId, `RAG [${ragMode}]: Starting retrieval with ${embeddingEngine}`)
            ragDocuments = await retrieveContext(
                supabaseService,
                queryForRetrieval,
                geminiApiKey,
                ragMode,
                runId,
                (ragMode === 'advanced' || ragMode === 'pre_retrieval') ? rewrittenQueryForReranker : undefined,
                (ragMode === 'advanced' || ragMode === 'pre_retrieval') ? body.userMessage : undefined,
                embeddingEngine,
                body.query_embedding
            )
            telemetry.rag_retrieval_latency_ms = Date.now() - ragStartTime

            if ((ragMode === 'advanced' || ragMode === 'post_retrieval') && ragDocuments.length > 0) {
                const bgeQuery = ragMode === 'post_retrieval'
                    ? body.userMessage
                    : (BGE_QUERY_MODE === 'rewritten' ? rewrittenQueryForReranker : body.userMessage)

                log.info(runId, `RAG [${ragMode}]: Starting Pure BGE Cross-Encoder Reranking`, {
                    bge_query_mode: ragMode === 'post_retrieval' ? 'original' : BGE_QUERY_MODE,
                    bge_passage_mode: BGE_PASSAGE_MODE,
                    candidate_pool_size: ragDocuments.length,
                })

                const rerankerResult = await rerankDocuments(
                    bgeQuery,
                    ragDocuments,
                    runId,
                    geminiApiKey
                )
                ragDocuments = rerankerResult.documents
                telemetry.reranker_latency_ms = rerankerResult.latency_ms
                telemetry.reranker_scores = rerankerResult.scores
                telemetry.post_processing_actions.push(`reranker_engine:${RERANKER_MODEL}`)
                telemetry.post_processing_actions.push(`reranker_applied:${rerankerResult.scores.length}`)
                telemetry.post_processing_actions.push(`bge_query_mode:${ragMode === 'post_retrieval' ? 'original' : BGE_QUERY_MODE}`)
                telemetry.post_processing_actions.push(`bge_passage_mode:${BGE_PASSAGE_MODE}`)

                if (rerankerResult.status !== 'success') {
                    telemetry.post_processing_actions.push(`reranker_fallback:${rerankerResult.status}`)
                    advancedModeNotice = rerankerResult.status === 'skipped_no_key'
                        ? '⚠️ Mode advanced: reranker nonaktif karena `HUGGINGFACE_API_KEY` belum disetel; jawaban dilanjutkan dengan fallback retrieval.'
                        : rerankerResult.status === 'fallback_gemini_ranker'
                            ? '⚠️ Mode advanced: BGE Reranker offline, sistem beralih ke fallback Gemini Reranker.'
                            : rerankerResult.status === 'fallback_timeout'
                                ? '⚠️ Mode advanced: reranker timeout; jawaban tetap dilanjutkan dengan fallback retrieval.'
                                : '⚠️ Mode advanced: reranker sedang bermasalah, jawaban tetap dilanjutkan dengan fallback retrieval.'
                }
            }

            telemetry.rag_documents_retrieved = ragDocuments.length
            if (ragDocuments.length > 0) {
                telemetry.post_processing_actions.push(`rag_retrieved:${ragDocuments.length}`)
                telemetry.post_processing_actions.push(
                    `rag_sources:${ragDocuments.map(d => d.title).join('|')}`
                )
            } else {
                telemetry.post_processing_actions.push('rag_no_results')
            }
        } else if (ragMode === 'none') {
            telemetry.post_processing_actions.push('rag_disabled_baseline')
        }

        const systemPrompt = buildSystemPrompt(body.contextData, body.userMessage, ragDocuments, ragMode)
        const promptHash = await computePromptHash(systemPrompt)
        telemetry.prompt_hash = promptHash

        let matchedScenarioId = null
        let matchedReferenceAnswer = null
        let matchedGroundTruthDocument = null
        let matchedGroundTruthChunkIdx: string[] | null = null

        const activeMetadata = vignettesMetadataV8

        for (const v of activeMetadata) {
            if (body.userMessage.includes(v.query_text_part)) {
                matchedScenarioId = v.scenario_id
                matchedReferenceAnswer = v.reference_answer
                matchedGroundTruthDocument = v.ground_truth_document
                const chunkIdxRaw = (v as Record<string, unknown>).ground_truth_chunk_idx
                if (Array.isArray(chunkIdxRaw) && chunkIdxRaw.length > 0) {
                    matchedGroundTruthChunkIdx = chunkIdxRaw.map((value: string | number) => String(value))
                } else {
                    matchedGroundTruthChunkIdx = null
                }
                log.info(runId, `Auto-detected RAGAS scenario: ${matchedScenarioId}`)
                break
            }
        }

        if (supabaseService) {
            const { error: insertError } = await supabaseService.from('chatbot_telemetry').insert({
                run_id: runId,
                user_id: telemetry.user_id,
                session_id: telemetry.session_id,
                prompt_id: promptId,
                prompt_hash: promptHash,
                model_name: MODEL_NAME,
                model_version: MODEL_VERSION,
                temperature: telemetry.temperature,
                max_tokens: telemetry.max_tokens,
                edge_function_version: EDGE_FUNCTION_VERSION,
                app_version: telemetry.app_version,
                region: REGION,
                rag_mode: ragMode,
                query_text: body.userMessage,
                scenario_id: matchedScenarioId,
                reference_answer: matchedReferenceAnswer,
                ground_truth_document: matchedGroundTruthDocument,
                ground_truth_chunk_idx: matchedGroundTruthChunkIdx,
                safety_flag: false,
                safety_reasons: [],
                post_processing_actions: [],
            })

            if (insertError) {
                log.error(runId, 'Failed to insert initial telemetry', insertError)
            } else {
                log.info(runId, 'Initial telemetry inserted')
            }
        }

        let geminiResult: unknown
        let httpStatus = 200

        if (!geminiApiKey) {
            log.info(runId, 'No API key found, using mock response')
            geminiResult = getMockGeminiResponse(body.userMessage)
            telemetry.post_processing_actions.push("used_mock_response")
        } else {
            const geminiBody = {
                contents: [{ parts: [{ text: systemPrompt }] }],
                generationConfig: {
                    temperature: telemetry.temperature,
                    topK: 40,
                    topP: 0.95,
                    maxOutputTokens: telemetry.max_tokens,
                },
                safetySettings: [
                    { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
                    { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
                    { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
                    { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
                ]
            }

            let success = false
            let attempts = 0
            const maxAttempts = 12

            while (attempts < maxAttempts && !success) {
                attempts++
                const currentKey = attempts === 1 ? geminiApiKey : getRandomApiKey()
                const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${currentKey}`

                try {
                    const geminiResponse = await fetch(geminiUrl, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(geminiBody)
                    })
                    httpStatus = geminiResponse.status
                    geminiResult = await geminiResponse.json()

                    if (httpStatus === 200) {
                        success = true
                        log.info(runId, 'Gemini API response received', { status: httpStatus, attempt: attempts })
                    } else if ([400, 401, 403, 429, 500, 503].includes(httpStatus)) {
                        log.warn(runId, `Gemini API failed with status ${httpStatus}. Retrying with new key...`, { attempt: attempts })
                        if (attempts < maxAttempts) {
                            await new Promise(r => setTimeout(r, 400))
                        } else {
                            log.error(runId, 'Max retries reached for Gemini API')
                        }
                    } else {
                        success = true
                        log.error(runId, `Gemini API failed with unrecoverable status ${httpStatus}`)
                    }
                } catch (fetchError) {
                    log.error(runId, 'Gemini API fetch failed', fetchError, { attempt: attempts })
                    if (attempts === maxAttempts) {
                        httpStatus = 503
                        geminiResult = { error: { message: 'Failed to reach Gemini API after retries' } }
                    }
                }
            }
        }

        telemetry.http_status = httpStatus

        const parsed = parseGeminiResponse(geminiResult)
        let responseText = parsed.text || ''
        telemetry.token_usage = parsed.tokenUsage
        telemetry.response_truncated = parsed.truncated

        if (parsed.error) {
            log.error(runId, 'Gemini response parsing error', null, { error: parsed.error })
            responseText = "Maaf, terjadi kesalahan saat memproses permintaan Anda. Silakan coba lagi."
            telemetry.safety_flag = true
            telemetry.safety_reasons.push("api_error:" + parsed.error)
        }

        const allergies = body.contextData?.allergies || []
        const safetyResult = applySafetyPostProcessing(responseText, allergies)

        responseText = safetyResult.text
        responseText = responseText.replace(/\n*📦\s*\*{0,2}Dokumen RAG Terambil[\s\S]*$/i, '').trimEnd()

        if (advancedModeNotice) {
            responseText += `\n\n${advancedModeNotice}`
        }

        if (ragDocuments && ragDocuments.length > 0 && ragMode !== 'none') {
            const footerLines = ragDocuments.map((doc, idx) => {
                const chunkIdx = getRagChunkIndex(doc)
                return `${idx + 1}. ${doc.title} source: ${doc.source} (chunk: ${chunkIdx})`
            })
            responseText += `\n\n📦 **Dokumen RAG Terambil (Top-${ragDocuments.length}):**\n${footerLines.join('\n')}`
        }

        const ragModeLabels: Record<RagMode, string> = {
            'none': 'Pure LLM (Tanpa RAG)',
            'naive': 'Naive RAG',
            'pre_retrieval': 'Pre-Retrieval',
            'post_retrieval': 'Post-Retrieval',
            'advanced': 'Full Advanced RAG',
        }
        const displayMode = ragModeLabels[ragMode] || ragMode
        responseText += `\n\n*(Mode: ${displayMode})*`
        if (safetyResult.safety_flag) {
            telemetry.safety_flag = true
        }
        telemetry.safety_reasons.push(...safetyResult.safety_reasons)
        telemetry.post_processing_actions.push(...safetyResult.post_processing_actions)

        const latencyMs = Date.now() - startTime
        telemetry.latency_ms = latencyMs

        if (supabaseService) {
            const storage = await storeResponse(supabaseService, runId, responseText)
            telemetry.response_pointer = storage.pointer
            telemetry.response_text = storage.inlineText
        } else {
            telemetry.response_text = responseText
        }

        if (supabaseService) {
            let retrievedResultsPayload = null
            if (ragDocuments && ragDocuments.length > 0) {
                retrievedResultsPayload = ragDocuments.map((doc, idx) => ({
                    rank: idx + 1,
                    doc_id: doc.source,
                    chunk_id: getRagChunkIndex(doc),
                    chunk_text: doc.content,
                    title: doc.title,
                    similarity_score: doc.similarity,
                    reranker_score: doc.reranker_score
                }))
            }

            const { error: updateError } = await supabaseService.from('chatbot_telemetry')
                .update({
                    token_usage: telemetry.token_usage,
                    latency_ms: latencyMs,
                    http_status: httpStatus,
                    response_truncated: telemetry.response_truncated,
                    safety_flag: telemetry.safety_flag,
                    safety_reasons: telemetry.safety_reasons,
                    post_processing_actions: telemetry.post_processing_actions,
                    response_pointer: telemetry.response_pointer,
                    response_text: telemetry.response_text,
                    rag_documents_retrieved: telemetry.rag_documents_retrieved,
                    rag_retrieval_latency_ms: telemetry.rag_retrieval_latency_ms,
                    reranker_latency_ms: telemetry.reranker_latency_ms,
                    reranker_scores: telemetry.reranker_scores,
                    token_usage_input: Object.keys(telemetry.token_usage || {}).length > 0 ? (telemetry.token_usage?.input_tokens ?? null) : null,
                    token_usage_output: Object.keys(telemetry.token_usage || {}).length > 0 ? (telemetry.token_usage?.output_tokens ?? null) : null,
                    retrieved_results: retrievedResultsPayload
                })
                .eq('run_id', runId)

            if (updateError) {
                log.error(runId, 'Failed to update telemetry', updateError)
            }
        }

        if (telemetry.safety_flag && supabaseService) {
            const priority = telemetry.safety_reasons.some(r => r.includes('api_error')) ? 3 :
                telemetry.safety_reasons.some(r => r.includes('blocked')) ? 2 : 1

            const { error: queueError } = await supabaseService.from('review_queue').insert({
                run_id: runId,
                flag_reason: telemetry.safety_reasons.join(', ') || 'unknown',
                status: 'pending',
                priority: priority,
            })

            if (queueError) {
                log.error(runId, 'Failed to insert review queue', queueError)
            } else {
                log.info(runId, 'Added to review queue', { priority })
            }
        }

        log.info(runId, 'Request completed', {
            latency_ms: latencyMs,
            safety_flag: telemetry.safety_flag,
            tokens: telemetry.token_usage?.total_tokens
        })

        return new Response(
            JSON.stringify({
                run_id: runId,
                result: responseText,
                safety_flag: telemetry.safety_flag,
                safety_reasons: telemetry.safety_reasons,
                rag_mode: telemetry.rag_mode,
                embedding_engine: telemetry.embedding_engine,
            }),
            {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        const latencyMs = Date.now() - startTime
        log.error(runId, 'Unhandled exception', error)

        try {
            const supabaseUrl = Deno.env.get('SUPABASE_URL')
            const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
            if (supabaseUrl && supabaseServiceKey) {
                const supabaseService = createClient(supabaseUrl, supabaseServiceKey)
                await supabaseService.from('chatbot_telemetry')
                    .update({
                        http_status: 500,
                        latency_ms: latencyMs,
                        safety_flag: true,
                        safety_reasons: ['server_error', error instanceof Error ? error.message : 'unknown'],
                    })
                    .eq('run_id', runId)
            }
        } catch (e) {
            log.error(runId, 'Failed to update telemetry on error', e)
        }

        return new Response(
            JSON.stringify({
                error: error instanceof Error ? error.message : 'Internal server error',
                run_id: runId,
                safety_flag: true,
                safety_reasons: ['server_error']
            }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})