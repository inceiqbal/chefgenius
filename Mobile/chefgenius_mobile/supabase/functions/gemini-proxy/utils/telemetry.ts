declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { TokenUsage } from '../types.ts'
import { MODEL_VERSION } from '../config.ts'
import { log } from './logger.ts'

export function parseGeminiResponse(geminiResult: unknown): {
    text: string | null
    tokenUsage: TokenUsage | null
    truncated: boolean
    error: string | null
} {
    const result = geminiResult as Record<string, unknown>

    try {
        const candidates = result.candidates as Array<Record<string, unknown>> | undefined
        if (candidates && candidates.length > 0) {
            const candidate = candidates[0]
            const content = candidate.content as Record<string, unknown> | undefined
            if (content) {
                const parts = content.parts as Array<Record<string, unknown>> | undefined
                if (parts && parts.length > 0 && parts[0].text) {
                    const truncated = candidate.finishReason === "MAX_TOKENS"

                    let tokenUsage: TokenUsage | null = null
                    const usageMetadata = result.usageMetadata as Record<string, number> | undefined
                    if (usageMetadata) {
                        tokenUsage = {
                            input_tokens: usageMetadata.promptTokenCount || 0,
                            output_tokens: usageMetadata.candidatesTokenCount || 0,
                            total_tokens: usageMetadata.totalTokenCount || 0,
                        }
                    }

                    return { text: parts[0].text as string, tokenUsage, truncated, error: null }
                }
            }

            if (candidate.finishReason === "MAX_TOKENS") {
                return { text: null, tokenUsage: null, truncated: true, error: "Response truncated (MAX_TOKENS)" }
            }
        }
    } catch {
        // Fall through to error handlers
    }

    if (result.error) {
        const errorObj = result.error as Record<string, unknown>
        return {
            text: null,
            tokenUsage: null,
            truncated: false,
            error: (errorObj.message as string) || "Unknown API error"
        }
    }

    if (result.text) {
        return { text: result.text as string, tokenUsage: null, truncated: false, error: null }
    }

    return { text: null, tokenUsage: null, truncated: false, error: "Unable to parse response structure" }
}

export function getMockGeminiResponse(userMessage: string): object {
    return {
        candidates: [{
            content: {
                parts: [{
                    text: `[MOCK RESPONSE] Halo! Saya Chef Cei. Anda bertanya: "${userMessage.substring(0, 50)}..."\n\nIni adalah respons mock untuk testing. Dalam produksi, respons nyata dari Gemini API akan muncul di sini.\n\n**Contoh info gizi:**\n- Kalori: 250 kkal\n- Protein: 15 gram\n- Karbohidrat: 30 gram`
                }],
                role: "model"
            },
            finishReason: "STOP"
        }],
        usageMetadata: {
            promptTokenCount: 150,
            candidatesTokenCount: 100,
            totalTokenCount: 250
        },
        modelVersion: MODEL_VERSION
    }
}

export async function storeResponse(
    supabaseService: SupabaseClient,
    runId: string,
    responseText: string
): Promise<{ pointer: string | null; inlineText: string | null }> {
    const storageBucket = Deno.env.get('STORAGE_BUCKET_NAME')

    if (!storageBucket) {
        log.info(runId, 'No storage bucket configured, storing inline')
        return { pointer: null, inlineText: responseText }
    }

    try {
        const fileName = `responses/${runId}.txt`
        const { error: uploadError } = await supabaseService.storage
            .from(storageBucket)
            .upload(fileName, responseText, {
                contentType: 'text/plain',
                upsert: false
            })

        if (uploadError) {
            log.warn(runId, 'Storage upload failed, falling back to inline', { error: uploadError.message })
            return { pointer: null, inlineText: responseText }
        }

        log.info(runId, 'Response uploaded to storage', { bucket: storageBucket, file: fileName })
        return { pointer: `supabase_storage://${storageBucket}/${fileName}`, inlineText: null }
    } catch (storageError) {
        log.error(runId, 'Storage upload exception, falling back to inline', storageError)
        return { pointer: null, inlineText: responseText }
    }
}