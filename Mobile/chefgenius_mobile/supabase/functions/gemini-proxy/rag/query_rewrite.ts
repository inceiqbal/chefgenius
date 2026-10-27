import { QueryRewriteResult } from '../types.ts'
import { MODEL_NAME, getRandomApiKey } from '../config.ts'
import { log } from '../utils/logger.ts'

export function isValidRewrittenQuery(text: string): boolean {
    const trimmed = text.trim()
    if (trimmed.length <= 10) return false

    const suspiciousPatterns = [
        /[\r\n]/,
        /\?/,
        /\*/,
        /`/,
        /^\s*(?:[-*+]\s+|#{1,6}\s+|>\s+)/m,
        /\brule\s+\d+/i,
        /\b(i|we|my|saya|kami)\s+(should|shouldn't|should not|must|mustn't|must not|cannot|can't|need|will|have to|harus|tidak boleh|am|was|do not|don't)\b/i,
        /\b(in the input|the input|from the input|the query|the prompt|the user|user query|input query|in the prompt|the patient asks|pengguna menanyakan)\b/i,
        /\b(shouldn't|should not|cannot|can't|mustn't|must not|avoid adding|don't add|do not add|tidak boleh|dilarang|tidak perlu menambahkan)\b/i,
        /\b(reasoning|instructions?|guidelines? says?|as per instructions?|per rule|berdasarkan instruksi)\b/i,
    ]
    if (suspiciousPatterns.some(p => p.test(trimmed))) return false

    const wordCount = trimmed.split(/\s+/).filter(Boolean).length
    if (wordCount > 40) return false

    return true
}

export async function rewriteQueryForRetrieval(
    userMessage: string,
    apiKey: string,
    runId: string
): Promise<QueryRewriteResult> {
    const prompt = `Tugasmu adalah melakukan query rewriting untuk sistem Information Retrieval pedoman medis Indonesia.
Ubah pertanyaan pengguna menjadi istilah pencarian medis/klinis yang padat, presisi, dan mempertahankan entitas medis kunci tanpa mengubah makna asli.

PRINSIP REWRITE (WAJIB TAATI):
1. Pertahankan seluruh entitas medis, akronim klinis/singkatan kapital, nama obat/terapi, dan topik spesifik dari query pengguna tanpa diubah.
2. Pertahankan istilah klinis kunci seperti nama kondisi, nama organ, jenis zat gizi (energi, protein, natrium), jenis latihan, atau golongan terapi.
3. JANGAN membuang kata kunci spesifik atau menggantinya dengan istilah yang terlalu umum.
4. JANGAN menambahkan diagnosis baru atau menebak jawaban yang tidak ada pada query.
5. Output HANYA berupa 1 baris frasa pencarian ringkas (sekitar 4-8 kata kunci utama yang padat entitas), tanpa tanda petik, tanpa format markdown, dan tanpa kalimat pengantar/penjelasan.

Contoh 1:
Input: "Dada terasa panas seperti terbakar setelah makan pedas dan sering kumat di malam hari, penanganan utamanya apa?"
Output: penatalaksanaan GERD gastroesophageal reflux heartburn nocturnal terapi lini pertama

Contoh 2:
Input: "Sesak napas mendadak saat cuaca dingin disertai bunyi mengi pada pasien dewasa, tindakan awal di faskes?"
Output: penanganan sesak napas wheezing asma bronkial eksaserbasi akut dewasa faskes

Contoh 3:
Input: "Pasien dengan keluhan nyeri lutut kronis saat menaiki tangga dan kaku sendi pagi hari, rekomendasi latihan fisik yang tepat apa?"
Output: program latihan fisik osteoarthritis genu nyeri sendi lutut fleksibilitas penguatan otot

Contoh 4:
Input: "Pemeriksaan skrining awal untuk wanita hamil trimester pertama dengan riwayat tekanan darah tinggi keluarga?"
Output: skrining awal hipertensi kehamilan preeklampsia antenatal care trimester pertama

Input: "${userMessage}"
Output:`

    let attempts = 0
    const maxAttempts = 5
    let lastHttpStatus: number | null = null

    while (attempts < maxAttempts) {
        attempts++
        const currentKey = attempts === 1 ? apiKey : getRandomApiKey()

        try {
            const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${currentKey}`
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }] }],
                    generationConfig: { temperature: 0, maxOutputTokens: 512 },
                }),
            })

            if (!response.ok) {
                lastHttpStatus = response.status
                if ([429, 500, 502, 503].includes(response.status)) {
                    await new Promise(r => setTimeout(r, 600 * attempts))
                    continue
                }
                const reason = `http_${response.status}`
                log.warn(runId, 'QueryRewrite: API error, using original query', { status: response.status, reason })
                return {
                    query: userMessage,
                    status: 'fallback_api_error',
                    fallback_reason: reason,
                }
            }

            const result = await response.json() as Record<string, unknown>
            const candidates = result.candidates as Array<Record<string, unknown>> | undefined
            const rewritten = candidates?.[0]?.content as Record<string, unknown> | undefined
            const parts = rewritten?.parts as Array<Record<string, unknown>> | undefined
            const rawText = parts?.[0]?.text as string | undefined

            if (!rawText || rawText.trim().length === 0) {
                log.warn(runId, 'QueryRewrite: Empty result, using original query')
                return {
                    query: userMessage,
                    status: 'fallback_empty',
                    fallback_reason: 'empty_output',
                }
            }

            let cleanedText = rawText.trim()
            cleanedText = cleanedText.replace(/^```[a-z]*\n?/i, '').replace(/\n?```$/i, '').trim()
            cleanedText = cleanedText.replace(/^(Output:\s*|Query:\s*|Rewritten:\s*)/i, '').trim()
            cleanedText = cleanedText.replace(/^["']|["']$/g, '').trim()

            if (isValidRewrittenQuery(cleanedText)) {
                log.info(runId, 'QueryRewrite: Success', {
                    original: userMessage.slice(0, 80),
                    rewritten: cleanedText.slice(0, 80),
                    attempts,
                })
                return {
                    query: cleanedText,
                    status: 'success',
                }
            }

            log.warn(runId, 'QueryRewrite: Validation rejected, using original query', {
                original: userMessage.slice(0, 80),
                rejected: cleanedText.slice(0, 150),
            })
            return {
                query: userMessage,
                status: 'fallback_validation',
                fallback_reason: 'validation_rejected',
            }
        } catch (e) {
            if (attempts < maxAttempts) {
                await new Promise(r => setTimeout(r, 500 * attempts))
                continue
            }
            const errorMsg = e instanceof Error ? e.message : String(e)
            log.warn(runId, 'QueryRewrite: Exception, using original query', { error: errorMsg })
            return {
                query: userMessage,
                status: 'fallback_exception',
                fallback_reason: 'exception',
            }
        }
    }

    const reason = `http_${lastHttpStatus || 503}`
    log.warn(runId, 'QueryRewrite: Exhausted retries for API error, using original query', { lastHttpStatus, reason })
    return {
        query: userMessage,
        status: 'fallback_api_error',
        fallback_reason: reason,
    }
}

export function enrichRewrittenQuery(rewrittenQuery: string, _userMessage: string): string {
    return rewrittenQuery
}

export async function generateHypotheticalDocument(
    userMessage: string,
    rewrittenQuery: string,
    apiKey: string,
    runId: string
): Promise<string> {
    const prompt = `Kamu adalah dokter spesialis penyakit dalam. Berdasarkan pertanyaan klinis berikut, tulis jawaban singkat (3-4 kalimat) seolah kamu mengutip langsung dari pedoman klinis Indonesia. Gunakan terminologi medis formal dan sebutkan nama obat/agen spesifik, angka target, dan rekomendasi kelas seperti yang tertulis di panduan.

PENTING:
- Jawab hanya dengan paragraf teks polos, tanpa pengantar atau penutup.
- Dilarang menggunakan markdown, bullet point, tanda bintang (*), atau format apapun.
- Maksimal 4 kalimat, tidak lebih.

Pertanyaan: "${userMessage}"
Konteks kata kunci: ${rewrittenQuery}

Jawaban pedoman klinis:`

    try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL_NAME}:generateContent?key=${apiKey}`
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { temperature: 0, maxOutputTokens: 400 },
            }),
        })

        if (!response.ok) {
            log.warn(runId, 'HyDE: API error, using rewritten query', { status: response.status })
            return rewrittenQuery
        }

        const result = await response.json() as Record<string, unknown>
        const candidates = result.candidates as Array<Record<string, unknown>> | undefined
        const content = candidates?.[0]?.content as Record<string, unknown> | undefined
        const parts = content?.parts as Array<Record<string, unknown>> | undefined
        const hydeText = parts?.[0]?.text as string | undefined

        if (hydeText && hydeText.trim().length > 30) {
            log.info(runId, 'HyDE: Success', {
                hyde_preview: hydeText.trim().slice(0, 120),
            })
            return hydeText.trim()
        }

        log.warn(runId, 'HyDE: Empty result, using rewritten query')
        return rewrittenQuery
    } catch (e) {
        log.warn(runId, 'HyDE: Exception, using rewritten query', { error: e instanceof Error ? e.message : String(e) })
        return rewrittenQuery
    }
}
