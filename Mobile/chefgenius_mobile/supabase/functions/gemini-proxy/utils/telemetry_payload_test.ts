import { buildTelemetryPayload, matchEvaluationScenario } from './telemetry_payload.ts'
import type { TelemetryRecord } from '../types.ts'
import { vignettesMetadata } from '../vignettes_master_v10_data.ts'

function equal(actual: unknown, expected: unknown) {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`)
    }
}

function record(): TelemetryRecord {
    return {
        run_id: 'test-run', user_id: null, session_id: 'test-session',
        prompt_id: 'test-prompt', prompt_hash: 'test-hash', model_name: 'test-model',
        model_version: 'test-version', temperature: 0.4, max_tokens: 8192,
        token_usage: { input_tokens: 2362, output_tokens: 865, total_tokens: 4162 },
        latency_ms: 11802, http_status: 200, response_truncated: false,
        safety_flag: false, safety_reasons: [], post_processing_actions: [],
        response_pointer: null, response_text: 'Response stored inline',
        scenario_id: 'V04', reference_answer: 'Reference from dataset',
        ground_truth_document: 'source.pdf', ground_truth_chunk_idx: ['43', '44'],
        edge_function_version: 'test-version', app_version: '1.0.0+6', region: 'test-region',
        rag_mode: 'pre_retrieval', embedding_engine: 'indobert', rag_documents_retrieved: 5,
        rag_retrieval_latency_ms: 100, reranker_latency_ms: null, reranker_scores: null,
    }
}

Deno.test('V04 CSV question matches despite capitalization and copied line breaks', () => {
    const v04 = vignettesMetadata.find(v => v.scenario_id === 'V04')!
    const copiedQuery = `  ${v04.query_text_part.toUpperCase().replaceAll(' ', '\n  ')}  `
    const scenario = matchEvaluationScenario(copiedQuery)
    equal(scenario?.scenario_id, 'V04')
    equal(scenario?.ground_truth_chunk_idx, ['43', '44'])
    equal(scenario?.reference_answer, v04.reference_answer)
})

Deno.test('unrelated or incomplete questions do not receive invented ground truth', () => {
    equal(matchEvaluationScenario(''), null)
    equal(matchEvaluationScenario('Berapa natrium dalam MSG?'), null)
    equal(matchEvaluationScenario('Buatkan resep nasi goreng'), null)
})

Deno.test('every bundled evaluation question matches its own scenario', () => {
    for (const vignette of vignettesMetadata) {
        equal(matchEvaluationScenario(vignette.query_text_part)?.scenario_id, vignette.scenario_id)
    }
})

Deno.test('completed payload retains initial metadata and actual token breakdown', () => {
    const input = record()
    const payload = buildTelemetryPayload(input, 'Original question')
    equal(payload.token_usage_input, 2362)
    equal(payload.token_usage_output, 865)
    equal(payload.token_usage?.total_tokens, 4162)
    for (const key of ['session_id', 'app_version', 'region', 'scenario_id', 'reference_answer',
        'ground_truth_document', 'ground_truth_chunk_idx'] as const) {
        equal(payload[key], input[key])
    }
    equal(payload.query_text, 'Original question')
    equal('embedding_engine' in payload, false)
    equal(input.embedding_engine, 'indobert')
})

Deno.test('missing usage differs from measured zero; unused storage and reranker stay null', () => {
    const input = record()
    input.token_usage = null
    equal(buildTelemetryPayload(input, '').token_usage_input, null)
    equal(buildTelemetryPayload(input, '').token_usage_output, null)
    input.token_usage = { input_tokens: 0, output_tokens: 0, total_tokens: 0 }
    const payload = buildTelemetryPayload(input, '')
    equal(payload.token_usage_input, 0)
    equal(payload.token_usage_output, 0)
    equal(payload.response_pointer, null)
    equal(payload.response_text, 'Response stored inline')
    equal(payload.reranker_latency_ms, null)
    equal(payload.reranker_scores, null)
})
