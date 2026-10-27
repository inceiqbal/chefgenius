declare const Deno: {
    env: {
        get(key: string): string | undefined
    }
}

import { EMBEDDING_MODEL, getRandomApiKey } from '../config.ts'
import { log } from './logger.ts'

export async function generateEmbedding(
    text: string,
    apiKey: string,
    taskType: 'RETRIEVAL_QUERY' | 'RETRIEVAL_DOCUMENT' = 'RETRIEVAL_QUERY'
): Promise<number[] | null> {
    let attempts = 0
    const maxAttempts = 12

    while (attempts < maxAttempts) {
        attempts++
        const currentKey = attempts === 1 ? apiKey : getRandomApiKey()
        try {
            const url = `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${currentKey}`
            const response = await fetch(url, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: `models/${EMBEDDING_MODEL}`,
                    content: { parts: [{ text }] },
                    taskType,
                }),
            })

            if (!response.ok) {
                if ([400, 401, 403, 429, 500, 503].includes(response.status)) {
                    await new Promise(r => setTimeout(r, 400))
                    continue
                }
                return null
            }

            const result = await response.json() as Record<string, unknown>
            const embedding = result.embedding as Record<string, unknown> | undefined
            if (embedding && embedding.values) {
                return embedding.values as number[]
            }
            return null
        } catch {
            // Retry on network error
        }
    }
    return null
}

export async function generateIndoBertEmbedding(
    text: string,
    runId: string
): Promise<number[] | null> {
    const serviceUrl = Deno.env.get('INDOBERT_EMBEDDING_URL') ||
        Deno.env.get('INDOBERT_API_URL') ||
        'http://127.0.0.1:8000/embed'

    let attempts = 0
    const maxAttempts = 2

    while (attempts < maxAttempts) {
        attempts++
        try {
            const controller = new AbortController()
            const timeoutId = setTimeout(() => controller.abort(), 10000)

            const response = await fetch(serviceUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ text }),
                signal: controller.signal,
            })
            clearTimeout(timeoutId)

            if (!response.ok) {
                log.warn(runId, `IndoBERT embedding service error: ${response.status} (attempt ${attempts})`)
                if (attempts < maxAttempts) {
                    await new Promise(r => setTimeout(r, 400))
                    continue
                }
                return null
            }

            const data = await response.json()
            if (data.embedding && Array.isArray(data.embedding)) {
                return data.embedding as number[]
            }
            if (Array.isArray(data)) {
                return data as number[]
            }
            return null
        } catch (err) {
            log.warn(runId, `IndoBERT embedding service unreachable (attempt ${attempts})`, { error: String(err) })
            if (attempts < maxAttempts) {
                await new Promise(r => setTimeout(r, 400))
                continue
            }
            return null
        }
    }
    return null
}