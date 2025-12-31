// Supabase Edge Function: gemini-proxy
// Proxy untuk Gemini API - API Key tersimpan aman di server
// Updated: Support multiple keys rotation + vision scanning

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface GeminiRequest {
    action: 'generate_recipe' | 'translate' | 'tts' | 'vision'
    prompt?: string
    text?: string
    targetLang?: string
    model?: string
    imageBase64?: string
    temperature?: number
    maxTokens?: number
}

// Get random API key from comma-separated list
function getRandomApiKey(): string {
    const keysString = Deno.env.get('GEMINI_KEYS') || Deno.env.get('GEMINI_API_KEY') || ''
    if (!keysString) return ''

    const keys = keysString.split(',').map(k => k.trim()).filter(k => k.length > 0)
    if (keys.length === 0) return ''

    const randomIndex = Math.floor(Math.random() * keys.length)
    return keys[randomIndex]
}

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Verify auth
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(
                JSON.stringify({ error: 'Unauthorized' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Verify JWT token with Supabase
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
        const supabase = createClient(supabaseUrl, supabaseAnonKey, {
            global: { headers: { Authorization: authHeader } }
        })

        const { data: { user }, error: authError } = await supabase.auth.getUser()
        if (authError || !user) {
            return new Response(
                JSON.stringify({ error: 'Invalid token' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 2. Parse request
        const body: GeminiRequest = await req.json()
        console.log(`Gemini proxy request from ${user.email}:`, body.action)

        // 3. Get Gemini API Key (with rotation)
        const geminiApiKey = getRandomApiKey()
        if (!geminiApiKey) {
            console.error('GEMINI_KEYS not configured')
            return new Response(
                JSON.stringify({ error: 'Gemini not configured' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // 4. Route to appropriate Gemini endpoint
        let geminiUrl: string
        let geminiBody: object

        switch (body.action) {
            case 'generate_recipe':
                geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${body.model || 'gemini-2.5-flash-preview-09-2025'}:generateContent?key=${geminiApiKey}`
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
                geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`
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
                    contents: [{
                        parts: [{ text: body.text }]
                    }],
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
                geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=${geminiApiKey}`
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
                    JSON.stringify({ error: 'Invalid action' }),
                    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
        }

        // 5. Call Gemini API
        const geminiResponse = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(geminiBody)
        })

        const geminiResult = await geminiResponse.json()

        // 6. Return result to client
        return new Response(
            JSON.stringify(geminiResult),
            {
                status: geminiResponse.status,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
        )

    } catch (error) {
        console.error('Gemini proxy error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
