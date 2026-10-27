import { BLOCKED_KEYWORDS, DISCLAIMER } from '../config.ts'
import { SafetyResult } from '../types.ts'

export function applySafetyPostProcessing(
    responseText: string,
    allergies: string[]
): SafetyResult {
    let text = responseText
    const safety_reasons: string[] = []
    const post_processing_actions: string[] = []
    let safety_flag = false

    const lowerText = text.toLowerCase()
    for (const keyword of BLOCKED_KEYWORDS) {
        if (lowerText.includes(keyword.toLowerCase())) {
            const hasMedicalDisclaimer =
                lowerText.includes("tidak bisa") ||
                lowerText.includes("maaf") ||
                lowerText.includes("silakan konsultasi") ||
                lowerText.includes("konsultasikan") ||
                lowerText.includes("anjuran dokter") ||
                lowerText.includes("tetap ikuti") ||
                lowerText.includes("berkonsultasi")

            if (!hasMedicalDisclaimer) {
                safety_flag = true
                safety_reasons.push(`contains_blocked_keyword:${keyword}`)
                text = "Maaf, saya tidak bisa memberikan diagnosis atau rekomendasi obat. Silakan konsultasikan dengan dokter atau tenaga kesehatan profesional untuk hal tersebut.\n\nNamun, saya dengan senang hati membantu Anda dengan pertanyaan seputar makanan sehat, resep, atau informasi gizi umum! 😊"
                post_processing_actions.push("blocked_diagnosis_response")
                break
            }
        }
    }

    if (!safety_flag && allergies.length > 0) {
        for (const allergy of allergies) {
            const allergyLower = allergy.toLowerCase()
            const allergyVariations = [allergyLower, allergyLower.replace(' ', ''), allergyLower.replace('alergi ', '')]
            for (const variation of allergyVariations) {
                if (lowerText.includes(variation) && variation.length > 2) {
                    safety_flag = true
                    safety_reasons.push(`allergy_mentioned:${allergy}`)
                    text += `\n\n⚠️ **PERINGATAN ALERGI**: Respons ini menyebutkan "${allergy}" yang merupakan alergen Anda. Harap pertimbangkan alternatif yang aman.`
                    post_processing_actions.push("added_allergy_warning")
                    break
                }
            }
        }
    }

    const healthKeywords = ["diabetes", "hipertensi", "kolesterol", "asam urat", "gula darah", "tekanan darah", "metabolik"]
    for (const keyword of healthKeywords) {
        if (lowerText.includes(keyword)) {
            if (!text.includes("⚠️ Informasi ini bersifat edukatif")) {
                text += DISCLAIMER
                post_processing_actions.push("added_disclaimer")
            }
            break
        }
    }

    if (text.includes(" gr ") || text.includes(" gr.") || text.includes(" gr,")) {
        text = text.replace(/ gr /g, " gram ").replace(/ gr\./g, " gram.").replace(/ gr,/g, " gram,")
        post_processing_actions.push("normalized_units")
    }

    return { text, safety_flag, safety_reasons, post_processing_actions }
}