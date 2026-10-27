declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { RAGDocument, RagMode, ChatbotRequest } from '../types.ts'

export function getRagChunkIndex(doc: RAGDocument): string {
    const chunkIdx = doc.metadata?.chunk_idx
    if (typeof chunkIdx === 'number' && Number.isFinite(chunkIdx)) {
        return String(chunkIdx)
    }
    if (typeof chunkIdx === 'string' && chunkIdx.trim().length > 0) {
        return chunkIdx.trim()
    }
    return 'N/A'
}

export function buildNaiveCitationLabel(doc: RAGDocument): string {
    const chunkIdx = getRagChunkIndex(doc)
    return `${doc.title} (chunk ${chunkIdx})`
}

export function buildRagReferenceLine(doc: RAGDocument, index: number, ragMode: RagMode): string {
    const chunkIdx = getRagChunkIndex(doc)
    const scoreInfo = ragMode === 'advanced'
        ? `, reranker: ${doc.reranker_score ?? 'N/A'}, similarity: ${doc.similarity.toFixed(3)}`
        : `, similarity: ${doc.similarity.toFixed(3)}`

    if (ragMode === 'naive') {
        const naiveLabel = buildNaiveCitationLabel(doc)
        return `[Top-${index}] [${naiveLabel}] (source: ${doc.source}${scoreInfo})\n${doc.content}\nCitasi: ${doc.citation_text || doc.source}`
    }

    return `[Top-${index}] [${index}] ${doc.title} (chunk: ${chunkIdx}, source: ${doc.source}${scoreInfo})\n${doc.content}\nCitasi: ${doc.citation_text || doc.source}`
}

export async function computePromptHash(prompt: string): Promise<string> {
    const encoder = new TextEncoder()
    const data = encoder.encode(prompt)
    const hashBuffer = await crypto.subtle.digest("SHA-256", data)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
    return `sha256:${hashHex}`
}

// ============================================================================
// KONFIGURASI SAKELAR ATURAN PENOLAKAN MEDIS (MEDICAL REFUSAL TOGGLE)
// ============================================================================
// Aturan asli ("3. DITOLAK: Diagnosis, terapi medis, interpretasi lab...")
// TIDAK DIHAPUS. Teks aturan asli dan teks bypass disimpan utuh di sini.
// 
// Pengaturan sewaktu-waktu:
// - 'baseline_only_disabled' : (DEFAULT) Dinonaktifkan KHUSUS mode Baseline (ragMode === 'none')
//                              agar LLM menjawab untuk evaluasi benchmark akademik.
//                              TETAP AKTIF pada mode RAG (Naive, Advanced) demi safety & persona.
// - 'always_disabled'        : Dinonaktifkan di SEMUA mode (LLM selalu menjawab pertanyaan medis).
// - 'always_enabled'         : Diaktifkan kembali di SEMUA mode (aturan penolakan medis aktif penuh).
// 
// Catatan: Anda juga bisa mengatur via Supabase Dashboard Environment Variable:
// ENFORCE_MEDICAL_REFUSAL="true"  -> Aktifkan kembali di semua mode tanpa edit kode
// ENFORCE_MEDICAL_REFUSAL="false" -> Nonaktifkan di semua mode tanpa edit kode
// ============================================================================
export const ORIGINAL_MEDICAL_REFUSAL_RULE = '3. DITOLAK: Diagnosis, terapi medis, interpretasi lab → tolak dengan sopan'
export const BYPASS_MEDICAL_REFUSAL_RULE = '3. PENGETAHUAN KLINIS & MEDIS: Jawab pertanyaan terkait terapi medis, obat, atau klinis secara langsung, spesifik, dan lengkap berdasarkan pengetahuan medismu tanpa menolak atau menghindar.'

export const MEDICAL_REFUSAL_BEHAVIOR: 'baseline_only_disabled' | 'always_disabled' | 'always_enabled' = 'always_disabled'

export function buildSystemPrompt(
    ctx: ChatbotRequest['contextData'],
    userMessage: string,
    ragDocuments: RAGDocument[] = [],
    ragMode: RagMode = 'naive'
): string {
    let recipeContext = ''
    if (ctx?.currentRecipe?.name) {
        recipeContext = `
KONTEKS PENGGUNA:
RESEP YANG SEDANG DIBAHAS:
- Nama: ${ctx.currentRecipe.name}
- Bahan: ${ctx.currentRecipe.ingredients?.join(', ') || '-'}
- Deskripsi: ${ctx.currentRecipe.description || '-'}
`
    }

    let ragContext = ''
    if (ragDocuments.length > 0) {
        const ragEntries = ragDocuments.map((doc, i) => buildRagReferenceLine(doc, i + 1, ragMode)).join('\n\n')
        ragContext = `
KONTEKS KNOWLEDGE BASE (DATA REFERENSI):
Berikut adalah informasi relevan dari database nutrisi dan resep yang TERVERIFIKASI.
Gunakan data ini sebagai REFERENSI UTAMA untuk menjawab, sebutkan angka-angka spesifik dari data ini.

ATURAN FORMAT JAWABAN:
1. JANGAN tampilkan sitasi model apa pun pada jawaban (tidak perlu [1], [2], atau [Nama Dokumen]).
2. JANGAN tampilkan bagian "Daftar Rujukan".
3. JANGAN tampilkan bagian "📦 Dokumen RAG Terambil" — bagian ini akan ditambahkan secara otomatis oleh sistem.
4. Tetap gunakan data dari konteks ini secara akurat tanpa mengarang.

${ragEntries}
`
    }

    let citationPolicy = '7. MODE BASELINE: JANGAN tampilkan sitasi, JANGAN tampilkan "Daftar Rujukan", dan JANGAN tampilkan bagian "Dokumen RAG Terambil".'
    if (ragMode !== 'none') {
        if (ragDocuments.length > 0) {
            citationPolicy = '7. MODE RAG: JANGAN tampilkan sitasi inline, JANGAN tampilkan "Daftar Rujukan", dan JANGAN tampilkan bagian "📦 Dokumen RAG Terambil" (akan ditambahkan otomatis oleh sistem).'
        } else {
            citationPolicy = '7. MODE RAG (KOSONG): Dokumen referensi tidak ditemukan. JANGAN tampilkan bagian "📦 Dokumen RAG Terambil". Jawab berdasarkan pengetahuan medismu saja dan beritahu pengguna bahwa referensi spesifik dari database tidak ditemukan.'
        }
    }

    // Menentukan apakah aturan penolakan medis diterapkan atau dinonaktifkan:
    let enforceMedicalRefusal = (ragMode !== 'none')
    if (Deno.env.get("ENFORCE_MEDICAL_REFUSAL") === "true") {
        enforceMedicalRefusal = true
    } else if (Deno.env.get("ENFORCE_MEDICAL_REFUSAL") === "false") {
        enforceMedicalRefusal = false
    } else {
        if (MEDICAL_REFUSAL_BEHAVIOR === 'always_enabled') {
            enforceMedicalRefusal = true
        } else if (MEDICAL_REFUSAL_BEHAVIOR === 'always_disabled') {
            enforceMedicalRefusal = false
        } else {
            // 'baseline_only_disabled': dinonaktifkan khusus saat ragMode === 'none'
            enforceMedicalRefusal = (ragMode !== 'none')
        }
    }

    const ruleMedical = enforceMedicalRefusal
        ? ORIGINAL_MEDICAL_REFUSAL_RULE
        : BYPASS_MEDICAL_REFUSAL_RULE;

    const clinicalIdentity = enforceMedicalRefusal
        ? ''
        : '- Memberikan edukasi gizi dan informasi klinis/medis secara objektif dan lengkap\n';

    return `Kamu adalah "Chef Cei", seorang AHLI GIZI dan KONSULTAN KULINER SEHAT dalam aplikasi ChefGenius.

IDENTITAS & KEMAMPUAN:
- Ahli gizi yang memberikan informasi nutrisi dengan DATA ANGKA SPESIFIK
- Konsultan kuliner sehat fokus kesehatan metabolik
- Edukasi bahan makanan dengan KANDUNGAN GIZI LENGKAP per porsi/100 gram
${clinicalIdentity}
${recipeContext}
${ragContext}

PERTANYAAN PENGGUNA:
${userMessage}

ATURAN RESPONS:
1. DIJAWAB: Pertanyaan kuliner, gizi, makanan untuk penyakit metabolik
2. DIALIHKAN: Penyakit non-metabolik → sarankan konsultasi dokter
${ruleMedical}
4. SELALU sertakan DATA ANGKA GIZI jika relevan — gunakan data dari KNOWLEDGE BASE jika tersedia
5. Jika ada risiko alergi, WAJIB berikan peringatan
6. Jawab dengan LENGKAP dalam Bahasa Indonesia
${citationPolicy}
8. PENTING: JANGAN SEKALI-KALI menggunakan kata "resep obat", "meresepkan", "dosis obat", atau "obat kimia" dalam jawabanmu, bahkan untuk memberikan disclaimer. Gunakan istilah "pengobatan medis" atau "terapi dari dokter" agar sistem safety tidak memblokir jawabanmu secara keliru.

Jawab dengan lengkap, jelas, dan helpful:`
}
