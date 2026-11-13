# 🔍 FLOW LENGKAP: DARI KNOWLEDGE BASE RETRIEVAL KE MRR CALCULATION

---

## OVERVIEW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. USER SENDS QUESTION (CHATBOT SCREEN)                        │
│    "Berapa defisit kalori harian untuk weight loss?"            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. CLIENT PROCESSING (FLUTTER APP)                             │
│    - Collect user context (pantry, diet, allergies)            │
│    - Prepare request payload                                   │
│    - Select RAG mode ('none'/'naive'/'advanced')              │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. SEND TO EDGE FUNCTION (gemini-proxy)                        │
│    POST /functions/v1/gemini-proxy                             │
│    {                                                            │
│      action: 'chatbot',                                        │
│      userMessage: 'Berapa defisit kalori...',                 │
│      rag_mode: 'naive',                                       │
│      contextData: {...}                                        │
│    }                                                            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. EDGE FUNCTION STEP 1: INITIALIZATION                        │
│    ✓ Generate run_id (UUID v4)                                 │
│    ✓ Build system prompt                                       │
│    ✓ Compute prompt_hash (SHA-256)                            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. EDGE FUNCTION STEP 2: KNOWLEDGE BASE RETRIEVAL (RAG)        │
│                                                                 │
│    RAG_MODE = 'naive' / 'advanced' ?                           │
│    ├─ YES (Retrieval):                                         │
│    │  1. Embed user question using Gemini Embedding API       │
│    │  2. Vector search in Supabase database                    │
│    │  3. Fetch top-10 candidates (RAG_INITIAL_FETCH_COUNT)   │
│    │  4. If 'advanced': Rerank dengan HF model               │
│    │  5. Keep top-3 results (RAG_RERANK_TOP_K)               │
│    │  6. Build retrieved_results JSONB with ranking          │
│    │                                                           │
│    └─ NO ('none' mode):                                        │
│       - Skip retrieval, use only Gemini                        │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. SEND TO GEMINI API (LLM)                                     │
│    - System prompt (dengan context dari retrieval)             │
│    - User message                                               │
│    - Temperature: 0.4 (stable)                                  │
│    - Max tokens: 1024-8192                                      │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. GEMINI RESPONSE                                              │
│    - Text response                                              │
│    - Token usage (input + output)                               │
│    - Finish reason                                              │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 8. SAFETY POST-PROCESSING                                       │
│    - Check for blocked keywords                                 │
│    - Detect alergen contradictions                              │
│    - Add health disclaimer if needed                            │
│    - Normalize units                                             │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 9. STORAGE                                                      │
│    ✓ Upload response to Supabase Storage (or inline)           │
│    ✓ Prepare telemetry record                                   │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 10. DATABASE LOGGING (INSERT)                                   │
│     INSERT INTO chatbot_telemetry (                             │
│       run_id, user_id, query_text, response_text,             │
│       retrieved_results, token_usage, latency_ms,              │
│       safety_flag, prompt_hash, ...                            │
│     )                                                            │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 11. RESPONSE TO CLIENT                                          │
│     Streaming response di Flutter app                           │
└─────────────┬───────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 12. RAGAS EVALUATION (OFFLINE)                                  │
│     Calculate:                                                  │
│     - Answer Relevancy                                          │
│     - Faithfulness                                              │
│     - Context Relevance                                         │
│     - MRR (Mean Reciprocal Rank)                               │
│                                                                 │
│     INPUT:                                                      │
│     - query_text (dari telemetry)                              │
│     - response_text (dari telemetry)                           │
│     - retrieved_results (dari telemetry)                       │
│     - ground_truth_context_ids (dari vignette)                 │
│     - reference_answer (dari vignette)                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## DETAIL LANGKAH-LANGKAH

### 1️⃣ USER MENGIRIM PERTANYAAN

**File:** `lib/features/chatbot/screens/chatbot_screen.dart`

```dart
// User mengetik: "Berapa defisit kalori untuk weight loss?"
final message = _messageController.text.trim();

// Panggil sendMessageStream()
_streamSubscription = _chatbotService.sendMessageStream(message).listen(
  (partialResponse) {
    setState(() => _currentBotResponse = partialResponse);
    _scrollToBottom();
  },
);
```

---

### 2️⃣ CLIENT PROCESSING (FLUTTER)

**File:** `lib/app/services/chatbot_service.dart`

```dart
Stream<String> sendMessageStream(String userMessage) async* {
  if (userMessage.trim().isEmpty) return;

  // Simpan pesan user ke database
  await _saveMessage(userMessage, true);

  try {
    // STEP 1: Ambil konteks pengguna
    final context = await _getUserContext();
    // context berisi: pantryItems, dietPreferences, allergies, etc

    // STEP 2: Kirim ke Gemini via proxy
    final response = await _geminiProxy.sendChatMessage(
      userMessage: userMessage,
      pantryItems: context.pantryItems,
      dietPreferences: context.dietPreferences,
      allergies: context.allergies,
      recipeName: _currentRecipe?.title,
      recipeIngredients: _currentRecipe?.allIngredients.map((i) => i.name).toList(),
      recipeDescription: _currentRecipe?.description,
      ragMode: _ragMode,  // 'naive' atau 'advanced'
    );

    if (response != null) {
      // Simpan response ke database
      await _saveMessage(response, false);
      
      // Yield full response ke UI
      yield response;
    }
  } catch (e) {
    yield 'Maaf, terjadi kesalahan. Silakan coba lagi.';
  }
}

Future<UserContext> _getUserContext() async {
  // Ambil data dari Hive (local storage) & SharedPreferences
  final pantryBox = Hive.box('pantry');
  final prefs = await SharedPreferences.getInstance();
  
  return UserContext(
    pantryItems: pantryBox.values.map((v) => v.name).toList(),
    dietPreferences: prefs.getStringList('user_diet_preferences') ?? [],
    allergies: prefs.getStringList('user_allergies') ?? [],
  );
}
```

---

### 3️⃣ SEND REQUEST KE EDGE FUNCTION

**File:** `lib/app/services/gemini_proxy_service.dart`

```dart
Future<String?> sendChatMessage({
  required String userMessage,
  List<String> pantryItems = const [],
  List<String> dietPreferences = const [],
  List<String> allergies = const [],
  String? recipeName,
  List<String>? recipeIngredients,
  String? recipeDescription,
  String ragMode = 'naive',
}) async {
  final payload = {
    'action': 'chatbot',
    'userMessage': userMessage,
    'rag_mode': ragMode,  // Kirim RAG mode
    'contextData': {
      'pantryItems': pantryItems,
      'dietPreferences': dietPreferences,
      'allergies': allergies,
      'currentRecipe': recipeName != null ? {
        'name': recipeName,
        'ingredients': recipeIngredients,
        'description': recipeDescription,
      } : null,
    }
  };

  try {
    final response = await http.post(
      Uri.parse(_edgeFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'] as String?;
    }
  } catch (e) {
    print('Error: $e');
  }
  return null;
}
```

---

### 4️⃣ EDGE FUNCTION: INITIALIZATION

**File:** `supabase/functions/gemini-proxy/index.ts`

```typescript
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body: ChatbotRequest = await req.json()
    
    if (body.action !== 'chatbot') return // Handle other actions...

    // ============================================================
    // STEP 1: INITIALIZE
    // ============================================================
    
    const runId = crypto.randomUUID()  // Generate run_id (UUID v4)
    const timestamp = new Date()
    const startTime = performance.now()
    
    // Get configuration
    const ragMode: RagMode = body.rag_mode || DEFAULT_RAG_MODE  // 'naive' / 'advanced'
    const maxTokens = body.max_tokens || DEFAULT_MAX_TOKENS
    const temperature = body.temperature || DEFAULT_TEMPERATURE
    
    console.log(`[${runId}] Chat request: RAG mode = ${ragMode}`)

    // BUILD SYSTEM PROMPT
    const systemPrompt = buildSystemPrompt({
      userContext: body.contextData,
      ragMode: ragMode,
      currentRecipe: body.contextData?.currentRecipe,
    })

    // COMPUTE PROMPT HASH (SHA-256)
    const promptHash = await computeSHA256(systemPrompt)

    // ============================================================
    // STEP 2: KNOWLEDGE BASE RETRIEVAL (RAG)
    // ============================================================
    
    let retrievedResults = []
    let ragMetadata = { mode: ragMode, match_count: 0, threshold: RAG_MATCH_THRESHOLD }

    if (ragMode === 'none') {
      // Pure LLM, no retrieval
      console.log(`[${runId}] RAG mode: NONE (pure LLM)`)
      ragMetadata.match_count = 0
    } else {
      // RETRIEVAL: Naive or Advanced
      console.log(`[${runId}] RAG mode: ${ragMode} (with retrieval)`)
      
      // Step 2a: Embed user question
      const embeddingResponse = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key=' + geminiApiKey,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'models/embedding-001',
            content: { parts: [{ text: body.userMessage }] },
          }),
        }
      )
      
      const embeddingData = await embeddingResponse.json()
      const embedding = embeddingData.embedding.values  // Array of floats

      // Step 2b: Vector search in Supabase
      // Query knowledge_base_chunks table dengan similarity search
      const vectorSearchResults = await supabase.rpc('match_documents', {
        query_embedding: embedding,
        match_count: RAG_INITIAL_FETCH_COUNT,  // Fetch top-10 candidates
        match_threshold: RAG_MATCH_THRESHOLD,
      })

      console.log(`[${runId}] Vector search returned ${vectorSearchResults.data.length} candidates`)

      // Step 2c: Reranking (if 'advanced' mode)
      if (ragMode === 'advanced') {
        console.log(`[${runId}] Reranking with HF model...`)
        
        // Prepare pairs for reranker: [query, doc_text]
        const rerankerInput = {
          inputs: {
            texts: [body.userMessage],
            pairs: vectorSearchResults.data.map(doc => [
              body.userMessage,
              doc.chunk_text
            ]),
          }
        }

        // Call HuggingFace reranker API
        const rerankerResponse = await fetch(
          RERANKER_ENDPOINTS[0],  // Primary endpoint
          {
            method: 'POST',
            headers: {
              'Authorization': 'Bearer ' + huggingfaceToken,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(rerankerInput),
            signal: AbortSignal.timeout(RERANKER_TIMEOUT_MS),
          }
        ).catch(() => fetch(RERANKER_ENDPOINTS[1], { ... }))  // Fallback

        const rerankerScores = await rerankerResponse.json()
        
        // Add reranker scores & sort
        vectorSearchResults.data.forEach((doc, idx) => {
          doc.reranker_score = rerankerScores[idx]?.score || 0
        })
        
        vectorSearchResults.data.sort((a, b) => b.reranker_score - a.reranker_score)
      }

      // Step 2d: Keep top-3 results
      retrievedResults = vectorSearchResults.data.slice(0, RAG_RERANK_TOP_K).map((doc, rank) => ({
        rank: rank + 1,  // 1-indexed
        doc_id: doc.doc_id,
        chunk_id: doc.chunk_id,
        chunk_text: doc.chunk_text,
        title: doc.title,
        similarity_score: doc.similarity_score,
        reranker_score: doc.reranker_score || null,
      }))

      ragMetadata.match_count = retrievedResults.length
      console.log(`[${runId}] Final retrieved results: ${retrievedResults.length}`)
    }

    // ============================================================
    // STEP 3: BUILD ENHANCED SYSTEM PROMPT (dengan retrieved context)
    // ============================================================

    let enhancedSystemPrompt = systemPrompt
    
    if (retrievedResults.length > 0) {
      const contextTexts = retrievedResults
        .map(r => `[Source ${r.rank}: ${r.title}]\n${r.chunk_text}`)
        .join('\n\n')

      enhancedSystemPrompt += `\n\n## REFERENSI YANG RELEVAN:\n${contextTexts}`
    }

    // ============================================================
    // STEP 4: CALL GEMINI API
    // ============================================================

    console.log(`[${runId}] Calling Gemini API...`)

    const geminiResponse = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/models/' + MODEL_NAME + ':generateContent?key=' + geminiApiKey,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: enhancedSystemPrompt + '\n\nUser: ' + body.userMessage },
            ],
          }],
          generationConfig: {
            temperature: temperature,
            maxOutputTokens: maxTokens,
            topP: 0.95,
          },
        }),
      }
    )

    const geminiData = await geminiResponse.json()
    
    const responseText = geminiData.candidates[0]?.content.parts[0]?.text || 'No response'
    const tokenUsage = {
      input_tokens: geminiData.usageMetadata?.promptTokenCount || 0,
      output_tokens: geminiData.usageMetadata?.candidatesTokenCount || 0,
      total_tokens: geminiData.usageMetadata?.totalTokenCount || 0,
    }

    // ============================================================
    // STEP 5: SAFETY POST-PROCESSING
    // ============================================================

    let safetyFlag = false
    let safetyReasons: string[] = []

    // Check blocked keywords
    for (const keyword of BLOCKED_KEYWORDS) {
      if (responseText.toLowerCase().includes(keyword)) {
        safetyFlag = true
        safetyReasons.push(`Blocked keyword: ${keyword}`)
      }
    }

    // Add health disclaimer
    let processedResponse = responseText
    if (isHealthRelatedQuery(body.userMessage)) {
      processedResponse += DISCLAIMER
    }

    // ============================================================
    // STEP 6: STORAGE
    // ============================================================

    let responsePointer: string | null = null
    
    try {
      // Upload response to Supabase Storage
      const fileName = `responses/${runId}.txt`
      await supabase.storage.from('chatbot-responses').upload(fileName, processedResponse)
      responsePointer = `supabase_storage://chatbot-responses/${fileName}`
      console.log(`[${runId}] Response uploaded: ${responsePointer}`)
    } catch (e) {
      console.log(`[${runId}] Storage upload failed, storing inline`)
      // Fallback: store inline
    }

    // ============================================================
    // STEP 7: INSERT TELEMETRY
    // ============================================================

    const latencyMs = Math.round(performance.now() - startTime)

    const telemetryRecord = {
      run_id: runId,
      user_id: body.user_id || null,
      session_id: body.session_id || null,
      prompt_id: 'chef_cei_v1.2',
      prompt_hash: 'sha256:' + promptHash,
      model_name: MODEL_NAME,
      model_version: MODEL_VERSION,
      temperature: temperature,
      max_tokens: maxTokens,
      token_usage: tokenUsage,
      latency_ms: latencyMs,
      http_status: 200,
      response_truncated: false,
      safety_flag: safetyFlag,
      safety_reasons: safetyReasons,
      post_processing_actions: isHealthRelatedQuery(body.userMessage) ? ['add_disclaimer'] : [],
      response_pointer: responsePointer,
      response_text: responsePointer ? null : processedResponse,  // Only inline if no storage
      edge_function_version: EDGE_FUNCTION_VERSION,
      app_version: body.app_version || null,
      region: REGION,

      // RAG-SPECIFIC FIELDS
      rag_mode: ragMode,
      retrieved_results: JSON.stringify(retrievedResults),  // JSONB
      ground_truth_context_ids: null,  // Set during RAGAS evaluation
      reference_answer: null,  // Set during RAGAS evaluation
    }

    console.log(`[${runId}] Inserting telemetry...`)

    const telemetryResponse = await supabase
      .from('chatbot_telemetry')
      .insert([telemetryRecord])
      .select()

    if (telemetryResponse.error) {
      console.error(`[${runId}] Telemetry insert error:`, telemetryResponse.error)
    } else {
      console.log(`[${runId}] Telemetry inserted successfully`)
    }

    // ============================================================
    // STEP 8: RETURN RESPONSE
    // ============================================================

    return new Response(
      JSON.stringify({
        response: processedResponse,
        run_id: runId,
        metadata: {
          latency_ms: latencyMs,
          token_usage: tokenUsage,
          rag_mode: ragMode,
          retrieved_count: retrievedResults.length,
        }
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          ...corsHeaders,
        },
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})
```

---

### 5️⃣ DATABASE: TELEMETRY RECORDED

**Schema:** `supabase/migrations/chatbot_telemetry.sql`

```sql
-- Data yang di-insert ke chatbot_telemetry table:
INSERT INTO chatbot_telemetry (
  run_id,
  user_id,
  prompt_id,
  prompt_hash,
  model_name,
  model_version,
  temperature,
  max_tokens,
  token_usage,
  latency_ms,
  safety_flag,
  safety_reasons,
  response_pointer,
  response_text,
  edge_function_version,
  rag_mode,                    -- 'naive' / 'advanced' / 'none'
  retrieved_results,           -- JSONB dengan ranking info
  ground_truth_context_ids,    -- Diisi saat RAGAS evaluation
  reference_answer             -- Diisi saat RAGAS evaluation
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000'::uuid,
  'user-123'::uuid,
  'chef_cei_v1.2',
  'sha256:a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6',
  'gemini-3-flash-preview',
  '2026-01-10',
  0.4,
  1024,
  '{"input_tokens": 450, "output_tokens": 280, "total_tokens": 730}'::jsonb,
  1234,  -- latency_ms
  false,
  '{}',
  'supabase_storage://chatbot-responses/550e8400-e29b-41d4-a716-446655440000.txt',
  NULL,
  'v4.0.0-ablation',
  'naive',
  '[
    {
      "rank": 1,
      "doc_id": "Obesity_and_Weight_Management_2026",
      "chunk_id": 42,
      "chunk_text": "a 500–750 kcal/day energy deficit (irrespective of macronutrient composition) should be recommended for weight loss",
      "title": "ADA Obesity & Weight Management 2026",
      "similarity_score": 0.9234,
      "reranker_score": 2.145
    },
    {
      "rank": 2,
      "doc_id": "VA-DoD_Obesity_2025",
      "chunk_id": 18,
      "chunk_text": "recommending a daily caloric deficit of 500-750 kcal for effective weight management",
      "title": "VA-DoD Clinical Practice Guideline",
      "similarity_score": 0.8945,
      "reranker_score": 1.923
    },
    {
      "rank": 3,
      "doc_id": "EASL_LIVER_2024",
      "chunk_id": 67,
      "chunk_text": "weight loss of 5-10% can improve liver condition",
      "title": "EASL-EASD-EASO 2024",
      "similarity_score": 0.7234,
      "reranker_score": 1.512
    }
  ]'::jsonb,
  NULL,
  NULL
);
```

---

## 6️⃣ RAGAS EVALUATION (OFFLINE)

Setelah data tersimpan, script offline menjalankan RAGAS evaluation menggunakan vignettes:

**File:** `supabase/backfill_telemetry_ragas.py`

```python
#!/usr/bin/env python3
"""
RAGAS Evaluation Script untuk Chatbot Telemetry
Menghitung: Answer Relevancy, Faithfulness, Context Relevance, MRR
"""

import pandas as pd
from ragas import evaluate
from ragas.metrics import answer_relevancy, faithfulness, context_relevance
import json
from sqlalchemy import create_engine
from typing import List, Dict, Any
import numpy as np

# ============================================================
# 1. CONNECT TO SUPABASE DATABASE
# ============================================================

DATABASE_URL = "postgresql://user:password@db.supabase.co:5432/postgres"
engine = create_engine(DATABASE_URL)

# ============================================================
# 2. LOAD TELEMETRY DATA & VIGNETTES
# ============================================================

# Load dari chatbot_telemetry
query = """
SELECT 
  run_id,
  prompt_id,
  response_text,
  response_pointer,
  retrieved_results,
  rag_mode,
  token_usage,
  latency_ms
FROM chatbot_telemetry
WHERE ground_truth_context_ids IS NULL  -- Only unevaluated records
LIMIT 100
"""

df_telemetry = pd.read_sql_query(query, engine)

# Load vignettes (dari metadata di index.ts)
vignettes = [
  {
    "scenario_id": "V01",
    "query_text": "Untuk penyandang diabetes yang tubuhnya gemuk, berapa persen kebutuhan kalorinya harus dikurangi?",
    "ground_truth_context_ids": ["Perkeni Dewasa 2024.pdf"],
    "reference_answer": "Penyandang DM yang gemuk, kebutuhan kalori dikurangi sekitar 20-30% tergantung tingkat kegemukan."
  },
  {
    "scenario_id": "V02",
    "query_text": "Kalau saya mengurangi 10% asupan karbohidrat, berapa turun HbA1c saya setelah 6 bulan?",
    "ground_truth_context_ids": ["IDF_Rec_2025.pdf"],
    "reference_answer": "Setiap penurunan 10% karbohidrat menurunkan HbA1c 0.2% (3 mmol/mol) setelah 6 bulan."
  },
  {
    "scenario_id": "V09",
    "query_text": "Berapa besar defisit energi harian yang direkomendasikan untuk weight loss?",
    "ground_truth_context_ids": ["Obesity_and_Weight_Management_2026.pdf", "VA-DoD_Obesity_2025.pdf"],
    "reference_answer": "Defisit energi 500-750 kkal per hari untuk weight loss. Untuk wanita biasanya 1200-1500 kkal/hari."
  },
  # ... vignette lainnya (V03-V15)
]

# ============================================================
# 3. PREPARE DATASET UNTUK RAGAS
# ============================================================

ragas_dataset = []

for _, row in df_telemetry.iterrows():
    # Parse retrieved_results JSONB
    retrieved = json.loads(row['retrieved_results']) if isinstance(row['retrieved_results'], str) else row['retrieved_results']
    
    # Get response text
    response_text = row['response_text']
    if not response_text and row['response_pointer']:
        # Load dari storage
        response_text = load_from_storage(row['response_pointer'])
    
    # Extract retrieved contexts
    retrieved_contexts = [r['chunk_text'] for r in (retrieved or [])]
    context_ids = [r['chunk_id'] for r in (retrieved or [])]
    
    # Match with vignette
    vignette = match_vignette(row['run_id'], vignettes)
    
    if vignette:
        ragas_dataset.append({
            'question': vignette['query_text'],
            'answer': response_text,
            'contexts': retrieved_contexts,
            'context_ids': context_ids,
            'ground_truth_context_ids': vignette['ground_truth_context_ids'],
            'reference_answer': vignette['reference_answer'],
            'run_id': row['run_id'],
            'rag_mode': row['rag_mode'],
            'retrieved_count': len(retrieved_contexts),
        })

# ============================================================
# 4. INITIALIZE RAGAS METRICS
# ============================================================

# Metrics yang dihitung
metrics = [
    answer_relevancy,      # Score: 0-1 (relevancy jawaban dengan query)
    faithfulness,          # Score: 0-1 (konsistensi dengan retrieved contexts)
    context_relevance,     # Score: 0-1 (relevansi konteks dengan query)
]

# ============================================================
# 5. EVALUATE DENGAN RAGAS
# ============================================================

print("Evaluating with RAGAS...")

results = evaluate(
    dataset=pd.DataFrame(ragas_dataset),
    metrics=metrics,
    llm=None,  # Use default OpenAI LLM (bisa custom)
    embeddings=None,  # Use default embeddings
)

# ============================================================
# 6. CALCULATE MRR (Mean Reciprocal Rank)
# ============================================================

def calculate_mrr(retrieved_results: List[Dict], ground_truth_ids: List[str]) -> float:
    """
    MRR = 1 / rank(first relevant document)
    
    Contoh:
    - Ground truth doc IDs: [42, 18, 67]
    - Retrieved results rank: [1: chunk_id=42 ✓, 2: chunk_id=999, 3: chunk_id=18 ✓]
    - First relevant di rank 1 → MRR = 1/1 = 1.0
    
    - Retrieved results rank: [1: chunk_id=999, 2: chunk_id=18 ✓, 3: chunk_id=42 ✓]
    - First relevant di rank 2 → MRR = 1/2 = 0.5
    """
    for i, result in enumerate(retrieved_results, start=1):
        if result['chunk_id'] in ground_truth_ids:
            return 1.0 / i
    return 0.0  # No relevant document retrieved


mrr_scores = []

for i, row in ragas_dataset.iterrows():
    retrieved = json.loads(df_telemetry.iloc[i]['retrieved_results'] or '[]')
    ground_truth = row['ground_truth_context_ids']
    
    mrr = calculate_mrr(retrieved, ground_truth)
    mrr_scores.append(mrr)
    
    print(f"Run {row['run_id']}: MRR = {mrr:.3f}")

avg_mrr = np.mean(mrr_scores)

# ============================================================
# 7. COMPILE RESULTS
# ============================================================

results_summary = {
    'total_evaluated': len(ragas_dataset),
    'by_rag_mode': {},
    'metrics': {
        'answer_relevancy': {
            'mean': results['answer_relevancy'].mean(),
            'std': results['answer_relevancy'].std(),
            'min': results['answer_relevancy'].min(),
            'max': results['answer_relevancy'].max(),
        },
        'faithfulness': {
            'mean': results['faithfulness'].mean(),
            'std': results['faithfulness'].std(),
            'min': results['faithfulness'].min(),
            'max': results['faithfulness'].max(),
        },
        'context_relevance': {
            'mean': results['context_relevance'].mean(),
            'std': results['context_relevance'].std(),
            'min': results['context_relevance'].min(),
            'max': results['context_relevance'].max(),
        },
        'mrr': {
            'mean': avg_mrr,
            'scores': mrr_scores,
        }
    }
}

# Group by RAG mode
for mode in ['none', 'naive', 'advanced']:
    mode_data = ragas_dataset[ragas_dataset['rag_mode'] == mode]
    if len(mode_data) > 0:
        results_summary['by_rag_mode'][mode] = {
            'count': len(mode_data),
            'metrics': {
                'answer_relevancy': results[results_summary['rag_mode'] == mode]['answer_relevancy'].mean(),
                'faithfulness': results[results_summary['rag_mode'] == mode]['faithfulness'].mean(),
                'context_relevance': results[results_summary['rag_mode'] == mode]['context_relevance'].mean(),
                'mrr': np.mean([mrr_scores[j] for j, d in enumerate(ragas_dataset) if d['rag_mode'] == mode]),
            }
        }

# ============================================================
# 8. SAVE RESULTS & UPDATE DATABASE
# ============================================================

print("\n" + "="*60)
print("RAGAS EVALUATION RESULTS")
print("="*60)
print(json.dumps(results_summary, indent=2))

# Update telemetry dengan RAGAS scores
for i, row in ragas_dataset.iterrows():
    update_query = f"""
    UPDATE chatbot_telemetry
    SET 
      ground_truth_context_ids = %s,
      ragas_answer_relevancy = %s,
      ragas_faithfulness = %s,
      ragas_context_relevance = %s,
      ragas_mrr = %s,
      evaluated_at = NOW()
    WHERE run_id = %s
    """
    
    vignette = [v for v in vignettes if v['scenario_id'] == row['scenario_id']][0]
    
    with engine.connect() as conn:
        conn.execute(update_query, (
            json.dumps(vignette['ground_truth_context_ids']),
            results.iloc[i]['answer_relevancy'],
            results.iloc[i]['faithfulness'],
            results.iloc[i]['context_relevance'],
            mrr_scores[i],
            row['run_id'],
        ))

print("\n✅ Results saved to database!")
```

---

## 7️⃣ HASIL MRR CALCULATION

### Contoh Skenario:

**Query:** "Berapa defisit kalori untuk weight loss?"

**Retrieved Results (dari database):**
```json
[
  {
    "rank": 1,
    "chunk_id": 42,
    "doc_id": "Obesity_and_Weight_Management_2026",
    "chunk_text": "a 500–750 kcal/day energy deficit..."
  },
  {
    "rank": 2,
    "chunk_id": 999,
    "doc_id": "Other_Document",
    "chunk_text": "some unrelated content..."
  },
  {
    "rank": 3,
    "chunk_id": 18,
    "doc_id": "VA-DoD_Obesity_2025",
    "chunk_text": "recommending a daily caloric deficit of 500-750 kcal..."
  }
]
```

**Ground Truth (dari Vignette V09):**
```
ground_truth_context_ids = [42, 18, 67]
reference_answer = "Defisit energi 500-750 kkal per hari..."
```

### MRR Calculation:

```
Loop through retrieved results:
  Rank 1: chunk_id = 42 → IN ground_truth? YES! ✓
  
  First relevant document at rank 1
  MRR = 1 / 1 = 1.0  ✅ PERFECT!
```

### Interpretasi:
- **MRR = 1.0:** Dokumen relevan ter-ranking di posisi 1 (sempurna)
- **MRR = 0.5:** Dokumen relevan ter-ranking di posisi 2
- **MRR = 0.33:** Dokumen relevan ter-ranking di posisi 3
- **MRR = 0:** Tidak ada dokumen relevan dalam retrieved results

---

## RINGKASAN FLOW LENGKAP

| Step | Aksi | Input | Output | Lokasi |
|------|------|-------|--------|--------|
| 1 | User kirim pertanyaan | "Berapa defisit kalori?" | Message object | Mobile App |
| 2 | Ambil user context | Pantry, Diet, Allergies | Context object | ChatbotService |
| 3 | HTTP request ke Edge | User message + context | Request payload | GeminiProxyService |
| 4 | Initialize | Generate run_id, prompt_hash | Metadata | Edge Function |
| 5 | Embedding user query | User message | Embedding vector | Gemini API |
| 6 | Vector search | Embedding + threshold | Top-10 candidates | Supabase DB |
| 7 | Reranking (if advanced) | Top-10 + reranker | Top-3 results | HuggingFace API |
| 8 | Build enhanced prompt | System prompt + retrieved context | Full system prompt | Edge Function |
| 9 | Call Gemini LLM | Enhanced prompt + user message | Response text + tokens | Gemini API |
| 10 | Safety post-processing | Response text | Processed response + disclaimer | Edge Function |
| 11 | Storage | Response text | Storage path | Supabase Storage |
| 12 | Insert telemetry | All metadata | Telemetry record | PostgreSQL |
| 13 | Return to client | Response text + metadata | Streaming response | Mobile App |
| 14 | RAGAS Evaluation (offline) | Telemetry + vignettes | Scores | Python script |
| 15 | Calculate MRR | Retrieved results + ground truth | MRR score | Python script |
| 16 | Update database | MRR + RAGAS scores | Final evaluation record | PostgreSQL |

---

## KEY METRICS PENJELASAN

### Answer Relevancy
```
Score: semantic_similarity(query, response)
Input: "Berapa defisit kalori?" vs "Defisit kalori 500-750..."
Target: > 0.8 (sangat relevan)
```

### Faithfulness
```
Score: consistency_check(response, retrieved_contexts)
Memastikan jawaban konsisten dengan konteks yang di-retrieve
Target: > 0.75 (tidak banyak hallucination)
```

### Context Relevance
```
Score: proportion_of_relevant_docs(retrieved_results)
Contoh: 2 dari 3 dokumen relevan = 2/3 = 0.67
Target: > 0.7 (mayoritas dokumen relevan)
```

### MRR (Mean Reciprocal Rank)
```
Score: 1 / rank(first_relevant_doc)
Mengukur seberapa baik ranking dari dokumen relevan
Target: > 0.5 (dokumen relevan minimal di top-2)
```

---

Sekarang Anda memiliki pemahaman lengkap tentang flow dari knowledge base retrieval sampai MRR calculation! 🎯

