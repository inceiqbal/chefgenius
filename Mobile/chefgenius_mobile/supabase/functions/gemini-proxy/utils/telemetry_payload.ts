import type { TelemetryRecord } from '../types.ts'
import { vignettesMetadata } from '../vignettes_master_v10_data.ts'

export function matchEvaluationScenario(query: string, scenarioId?: string | null) {
    // Tier 1: Explicit Scenario ID from client
    if (scenarioId) {
        const found = vignettesMetadata.find(v => v.scenario_id.toLowerCase() === scenarioId.toLowerCase())
        if (found) return found
    }
    if (!query) return null
    const normalize = (text: string) => text.normalize('NFC').toLowerCase().replace(/[^\w\s]/g, ' ').replace(/\s+/g, ' ').trim()
    const normalizedQuery = normalize(query)
    const rawLower = query.toLowerCase()

    // Tier 2: Substring Match
    const directMatch = vignettesMetadata.find(v => {
        const normTarget = normalize(v.query_text_part)
        return normalizedQuery.includes(normTarget) || normTarget.includes(normalizedQuery)
    })
    if (directMatch) return directMatch

    // Tier 3: Word Overlap Match (>= 40% of target keywords)
    const queryWords = new Set(normalizedQuery.split(' ').filter(w => w.length > 2))
    if (queryWords.size > 0) {
        let bestScenario = null
        let maxOverlap = 0
        for (const v of vignettesMetadata) {
            const targetWords = normalize(v.query_text_part).split(' ').filter(w => w.length > 2)
            if (targetWords.length === 0) continue
            let matchCount = 0
            for (const tw of targetWords) {
                if (queryWords.has(tw)) matchCount++
            }
            const ratio = matchCount / targetWords.length
            if (ratio > maxOverlap && ratio >= 0.4) {
                maxOverlap = ratio
                bestScenario = v
            }
        }
        if (bestScenario) return bestScenario
    }

    // Tier 4: Clinical Intent & Signature Keyword Fallback (v10 Scenarios)
    const sigMap: Record<string, boolean> = {
        'V01': rawLower.includes('dash') && (rawLower.includes('hipertensi') || rawLower.includes('tekanan darah')),
        'V02': (rawLower.includes('cuci darah') || rawLower.includes('hemodialisis') || rawLower.includes('pgk-hd')) && (rawLower.includes('kalori') || rawLower.includes('energi') || rawLower.includes('kgbb') || rawLower.includes('malnutrisi')),
        'V03': (rawLower.includes('serat') || rawLower.includes('asupan serat')) && (rawLower.includes('obesitas') || rawLower.includes('38 tahun') || rawLower.includes('metabolik')),
        'V04': (rawLower.includes('penyedap') || rawLower.includes('msg') || rawLower.includes('bumbu gurih') || rawLower.includes('garam dapur')) && (rawLower.includes('hipertensi') || rawLower.includes('darah tinggi') || rawLower.includes('tekanan darah') || rawLower.includes('145')),
        'V05': (rawLower.includes('jus mangga') || rawLower.includes('jus buah') || rawLower.includes('olahan buah')) && (rawLower.includes('diabetes') || rawLower.includes('dm') || rawLower.includes('gula darah')),
        'V06': rawLower.includes('mediterania') && rawLower.includes('telur'),
        'V07': (rawLower.includes('biskuit') || rawLower.includes('kue kering') || rawLower.includes('roti kemasan') || rawLower.includes('lemak trans') || rawLower.includes('daging berlemak')) && (rawLower.includes('kolesterol') || rawLower.includes('ldl') || rawLower.includes('dislipidemia') || rawLower.includes('175')),
        'V08': (rawLower.includes('stanol') || rawLower.includes('sterol') || (rawLower.includes('serat larut') && (rawLower.includes('5 gram') || rawLower.includes('tanpa obat')))) && (rawLower.includes('ldl') || rawLower.includes('kolesterol') || rawLower.includes('dislipidemia')),
        'V09': (rawLower.includes('pengurangan') || rawLower.includes('defisit') || rawLower.includes('bertahap') || rawLower.includes('250')) && rawLower.includes('kalori') && (rawLower.includes('diabetes') || rawLower.includes('obesitas')),
        'V10': rawLower.includes('vitamin d') && rawLower.includes('anak') && (rawLower.includes('ginjal') || rawLower.includes('pgk')),
        'V11': (rawLower.includes('sahur') || rawLower.includes('ramadhan') || rawLower.includes('puasa')) && (rawLower.includes('diabetes') || rawLower.includes('dm') || rawLower.includes('kalori')),
        'V12': (rawLower.includes('bengkak') || rawLower.includes('cairan') || rawLower.includes('mi instan') || rawLower.includes('padang') || rawLower.includes('rendang') || rawLower.includes('natrium')) && (rawLower.includes('ginjal') || rawLower.includes('pgk') || rawLower.includes('stadium 4')),
        'V13': (rawLower.includes('kalsium') || rawLower.includes('500 mg')) && (rawLower.includes('osteoporosis') || rawLower.includes('62 tahun') || rawLower.includes('susu')),
        'V14': (rawLower.includes('komplikasi ginjal') || rawLower.includes('ginjal diabetik') || rawLower.includes('nefropati')) && (rawLower.includes('protein') || rawLower.includes('kgbb') || rawLower.includes('0,8') || rawLower.includes('0.8')),
        'V15': (rawLower.includes('perlemakan hati') || rawLower.includes('fatty liver') || rawLower.includes('mafld') || rawLower.includes('radang hati') || rawLower.includes('steatohepatitis') || (rawLower.includes('perlemakan') && (rawLower.includes('hati') || rawLower.includes('peradangan')))) && (rawLower.includes('95 kg') || rawLower.includes('3 sampai 4') || rawLower.includes('3-4 kg') || rawLower.includes('penurunan berat badan'))
    }

    for (const [targetId, matched] of Object.entries(sigMap)) {
        if (matched) {
            const found = vignettesMetadata.find(v => v.scenario_id === targetId)
            if (found) return found
        }
    }

    return null
}

export function buildTelemetryPayload(telemetry: TelemetryRecord, query: string) {
    // embedding_engine is recorded in post_processing_actions; it has no DB column.
    const { embedding_engine: _embeddingEngine, ...record } = telemetry
    return {
        ...record,
        query_text: query,
        token_usage_input: telemetry.token_usage?.input_tokens ?? null,
        token_usage_output: telemetry.token_usage?.output_tokens ?? null,
    }
}
