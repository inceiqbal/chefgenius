# 🏗️ PROSES SISTEM CHATBOT CHEFGENIUS (LENGKAP)

---

## EXECUTIVE SUMMARY

Chatbot Chef Cei adalah sistem AI-powered yang menghubungkan pengguna mobile app dengan Google Gemini LLM melalui Supabase Edge Function. Sistem ini dirancang untuk memberikan konsultasi nutrisi & kuliner dengan evaluation menggunakan RAGAS metrics untuk mengukur kualitas RAG retrieval.

**Key Components:**
- Frontend: Flutter Mobile App
- Backend: Supabase + Edge Functions (Deno)
- LLM: Google Gemini API
- Database: PostgreSQL (Supabase)
- Evaluation: RAGAS Python Library

---

## 1. ARSITEKTUR SISTEM KESELURUHAN

```
┌────────────────────────────────────────────────────────────────────┐
│                        USER LAYER                                  │
│                   (Flutter Mobile App)                             │
└──────────────────┬───────────────────────────────────────────────┬─┘
                   │                                               │
        Chat Input │                                    Pantry/Diet│
                   ↓                                               ↓
┌────────────────────────────┐                      ┌──────────────────────┐
│  ChatbotService (Dart)     │◄───────────────────►│  Local Storage       │
│  - Message Management       │   SharedPreferences  │  - Hive (Pantry)     │
│  - Context Collection       │   &  Hive           │  - SharedPrefs (Diet)│
│  - Stream Handling          │                      │  - User Preferences  │
└────────────────────┬────────┘                      └──────────────────────┘
                     │
        HTTP Request │ POST /functions/v1/gemini-proxy
                     │ {
                     │   action: 'chatbot',
                     │   userMessage: '...',
                     │   contextData: {...},
                     │   rag_mode: 'naive'
                     │ }
                     ↓
        ┌─────────────────────────────────────────┐
        │    SUPABASE EDGE FUNCTION               │
        │    (gemini-proxy/index.ts)              │
        │                                         │
        │  LAYER 1: INITIALIZATION                │
        │  - Generate run_id (UUID v4)            │
        │  - Build system prompt                  │
        │  - Compute prompt_hash (SHA-256)        │
        │                                         │
        │  LAYER 2: KNOWLEDGE BASE RETRIEVAL      │
        │  ┌─────────────────────────────────┐   │
        │  │ IF rag_mode != 'none':          │   │
        │  │                                 │   │
        │  │ Step 2a: Embed Query            │   │
        │  │ ─────────────────────────────── │   │
        │  │ User message → Gemini Embedding │   │
        │  │ Output: embedding vector        │   │
        │  │                                 │   │
        │  │ Step 2b: Vector Search          │   │
        │  │ ─────────────────────────────── │   │
        │  │ Query embedding → Supabase RPC  │   │
        │  │ match_documents()               │   │
        │  │ Output: Top-10 candidates       │   │
        │  │                                 │   │
        │  │ Step 2c: Reranking (advanced)   │   │
        │  │ ─────────────────────────────── │   │
        │  │ IF rag_mode == 'advanced':      │   │
        │  │   Rerank with HuggingFace       │   │
        │  │   model: BAAI/bge-reranker-v2   │   │
        │  │   Output: Scored results        │   │
        │  │                                 │   │
        │  │ Step 2d: Final Selection        │   │
        │  │ ─────────────────────────────── │   │
        │  │ Keep top-3 results with ranking │   │
        │  │ Output: retrieved_results JSONB │   │
        │  └─────────────────────────────────┘   │
        │                                         │
        │  LAYER 3: LLM PROCESSING                │
        │  ┌─────────────────────────────────┐   │
        │  │ Build Enhanced Prompt           │   │
        │  │ ─────────────────────────────── │   │
        │  │ System prompt + retrieved       │   │
        │  │ contexts + user message         │   │
        │  │                                 │   │
        │  │ Call Gemini API                 │   │
        │  │ ─────────────────────────────── │   │
        │  │ Model: gemini-3-flash-preview   │   │
        │  │ Temperature: 0.4 (stable)       │   │
        │  │ Max tokens: 1024-8192           │   │
        │  │ Output: response_text + tokens  │   │
        │  └─────────────────────────────────┘   │
        │                                         │
        │  LAYER 4: SAFETY & POST-PROCESSING      │
        │  ┌─────────────────────────────────┐   │
        │  │ Check Safety Rules              │   │
        │  │ - Blocked keywords detection    │   │
        │  │ - Alergen contradiction check   │   │
        │  │ - Add disclaimer if health      │   │
        │  │ - Normalize units               │   │
        │  │                                 │   │
        │  │ Output: processed_response      │   │
        │  └─────────────────────────────────┘   │
        │                                         │
        │  LAYER 5: PERSISTENCE                   │
        │  ┌─────────────────────────────────┐   │
        │  │ Storage Decision                │   │
        │  │ IF response.length < threshold: │   │
        │  │   Store inline in DB            │   │
        │  │ ELSE:                           │   │
        │  │   Upload to Supabase Storage    │   │
        │  │   → response_pointer            │   │
        │  │                                 │   │
        │  │ Prepare Telemetry Record        │   │
        │  │ - All metadata                  │   │
        │  │ - retrieved_results (JSONB)     │   │
        │  │ - Token usage                   │   │
        │  │ - Latency                       │   │
        │  │                                 │   │
        │  │ INSERT to chatbot_telemetry     │   │
        │  └─────────────────────────────────┘   │
        │                                         │
        └─────────────────────────────────────────┘
                     ↑
        HTTP Response │ 200 OK
                     │ {
                     │   response: 'Defisit kalori...',
                     │   run_id: 'uuid-xxx',
                     │   metadata: {...}
                     │ }
                     │
┌────────────────────┴────────────────────────────┐
│      SUPABASE POSTGRESQL DATABASE               │
│                                                 │
│  ┌─ chat_messages                              │
│  │  - id, user_id, message, is_user, timestamp│
│  │                                             │
│  ├─ chatbot_telemetry                         │
│  │  - run_id, query_text, response_text       │
│  │  - retrieved_results (JSONB with ranking)  │
│  │  - token_usage, latency, safety_flag       │
│  │  - ground_truth_context_ids (RAGAS)        │
│  │  - ragas_answer_relevancy (score)          │
│  │  - ragas_faithfulness (score)              │
│  │  - ragas_context_relevance (score)         │
│  │  - ragas_mrr (score)                       │
│  │                                             │
│  ├─ knowledge_base_chunks                     │
│  │  - chunk_id, doc_id, chunk_text            │
│  │  - embedding, title                        │
│  │                                             │
│  └─ review_queue                              │
│     - id, run_id, flag_reason, status         │
│                                                 │
└────────────────────────────────────────────────┘
                     ↓
        ┌──────────────────────────────┐
        │  EXTERNAL APIs               │
        │                              │
        ├─ Google Gemini API           │
        │  - LLM inference             │
        │  - Token counting            │
        │                              │
        ├─ Gemini Embedding API        │
        │  - Query embedding           │
        │                              │
        ├─ HuggingFace Reranker API    │
        │  - Document reranking        │
        │  (if advanced mode)          │
        │                              │
        └──────────────────────────────┘
                     ↓
        ┌──────────────────────────────┐
        │  SUPABASE STORAGE            │
        │  - Response text cache       │
        │  - Response pointer refs     │
        │                              │
        └──────────────────────────────┘
```

---

## 2. REQUEST-RESPONSE FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                    T0: USER ACTION                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  User types question in ChatbotScreen:                         │
│  "Berapa defisit kalori untuk turun berat badan 5kg?"         │
│                                                                 │
│  _messageController.text = "Berapa defisit kalori..."         │
│  _sendMessage() called                                          │
│                                                                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓ T0 + 10ms
        ┌────────────────────────────┐
        │  T1: CLIENT CONTEXT         │
        │  COLLECTION                 │
        └────────────────────────────┘
        
        _getUserContext() runs:
        
        ┌─ LocalStorage Queries ──────────────────────┐
        │                                             │
        │  1. Hive('pantry')                         │
        │     ├─ Eggs (3)                            │
        │     ├─ Chicken (500g)                      │
        │     └─ Rice (2kg)                          │
        │                                             │
        │  2. SharedPreferences('user_diet')         │
        │     ├─ Low-Sugar (✓)                       │
        │     ├─ Vegan (✗)                           │
        │     └─ Gluten-Free (✓)                     │
        │                                             │
        │  3. SharedPreferences('user_allergies')    │
        │     ├─ Nut Allergy (✓)                     │
        │     ├─ Seafood Allergy (✗)                 │
        │     └─ Dairy Allergy (✓)                   │
        │                                             │
        └─────────────────────────────────────────────┘
        
        UserContext object created:
        {
          pantryItems: ["Eggs", "Chicken", "Rice"],
          dietPreferences: ["Low-Sugar", "Gluten-Free"],
          allergies: ["Nut Allergy", "Dairy Allergy"],
          currentRecipe: null
        }
                     │
                     ↓ T1 + 50ms
        ┌────────────────────────────┐
        │  T2: HTTP REQUEST           │
        │  CONSTRUCTION & SEND        │
        └────────────────────────────┘
        
        Payload:
        {
          "action": "chatbot",
          "userMessage": "Berapa defisit kalori untuk turun 5kg?",
          "rag_mode": "naive",
          "contextData": {
            "pantryItems": ["Eggs", "Chicken", "Rice"],
            "dietPreferences": ["Low-Sugar", "Gluten-Free"],
            "allergies": ["Nut Allergy", "Dairy Allergy"],
            "currentRecipe": null
          },
          "user_id": "user-123",
          "session_id": "session-456",
          "app_version": "1.2.0"
        }
        
        POST /functions/v1/gemini-proxy
                     │
                     ↓ T2 + 100ms (Network latency)
        ┌────────────────────────────────────────────┐
        │  T3: EDGE FUNCTION                         │
        │  RECEIVES REQUEST                          │
        └────────────────────────────────────────────┘
        
        ┌─ Step 3.1: INITIALIZE ──────────────┐
        │                                     │
        │  runId = UUID v4()                 │
        │  → '550e8400-e29b-41d4-a716...'    │
        │                                     │
        │  timestamp = NOW()                 │
        │                                     │
        │  systemPrompt = buildPrompt({       │
        │    role: 'Chef Cei',               │
        │    context: userContext,           │
        │    constraints: {...}              │
        │  })                                │
        │                                     │
        │  promptHash = SHA256(systemPrompt) │
        │  → 'sha256:a1b2c3d4e5f6...'       │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 50ms
        ┌─ Step 3.2: RAG RETRIEVAL ───────────┐
        │                                     │
        │  IF rag_mode == 'naive':            │
        │                                     │
        │  3.2a. Embed Query                 │
        │  ────────────────────              │
        │  POST Gemini Embedding API          │
        │  Input: "Berapa defisit kalori?"   │
        │  Output: embedding [0.12, 0.45...] │
        │                                     │
        │  3.2b. Vector Search               │
        │  ────────────────────              │
        │  CALL supabase.rpc('match_docs')   │
        │  Input: embedding + threshold      │
        │  Output: Top-10 candidates         │
        │    1. Obesity_2026 (0.92)          │
        │    2. VA-DoD_2025 (0.89)           │
        │    3. EASL_2024 (0.72)             │
        │    4. ADA_2026 (0.68)              │
        │    ... (6 more)                    │
        │                                     │
        │  3.2c. No Reranking (naive mode)   │
        │  ────────────────────              │
        │  Keep top-3 results only           │
        │                                     │
        │  3.2d. Build Results JSONB         │
        │  ────────────────────              │
        │  retrievedResults = [               │
        │    {                                │
        │      rank: 1,                      │
        │      doc_id: "Obesity_2026",       │
        │      chunk_id: 42,                 │
        │      chunk_text: "500-750 kkal..." │
        │      title: "ADA Obesity 2026",    │
        │      similarity_score: 0.92        │
        │    },                              │
        │    {                               │
        │      rank: 2,                      │
        │      doc_id: "VA-DoD_2025",        │
        │      chunk_id: 18,                 │
        │      chunk_text: "defisit 500..."  │
        │      title: "VA-DoD Guidelines",   │
        │      similarity_score: 0.89        │
        │    },                              │
        │    {                               │
        │      rank: 3,                      │
        │      doc_id: "EASL_2024",          │
        │      chunk_id: 67,                 │
        │      chunk_text: "weight loss..."  │
        │      title: "EASL Liver 2024",     │
        │      similarity_score: 0.72        │
        │    }                               │
        │  ]                                 │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 200ms
        ┌─ Step 3.3: BUILD ENHANCED PROMPT ──┐
        │                                     │
        │  enhancedSystemPrompt =             │
        │    systemPrompt +                   │
        │    "\n\n## REFERENSI:\n" +         │
        │    "[Source 1: ADA Obesity 2026]   │
        │     500-750 kkal/hari untuk..." +  │
        │    "\n[Source 2: VA-DoD...]" +     │
        │    "\n[Source 3: EASL...]"         │
        │                                     │
        │  Full prompt length: ~2500 tokens   │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 250ms
        ┌─ Step 3.4: CALL GEMINI API ────────┐
        │                                     │
        │  POST generativelanguage.googleapis │
        │                                     │
        │  Request:                           │
        │  {                                  │
        │    model: "gemini-3-flash-preview", │
        │    contents: [{                     │
        │      parts: [{                      │
        │        text: enhancedSystemPrompt + │
        │               "\n\nUser: Berapa..." │
        │      }]                             │
        │    }],                              │
        │    generationConfig: {              │
        │      temperature: 0.4,              │
        │      maxOutputTokens: 1024,         │
        │      topP: 0.95                     │
        │    }                                │
        │  }                                  │
        │                                     │
        │  Response (T3 + 1500ms):            │
        │  {                                  │
        │    candidates: [{                   │
        │      content: {                     │
        │        parts: [{                    │
        │          text: "Defisit kalori yang │
        │                  disarankan adalah  │
        │                  500-750 kkal/hari.│
        │                  Untuk menurunkan 5│
        │                  kg dibutuhkan 7-10 │
        │                  minggu dengan diet │
        │                  Low-Sugar sesuai   │
        │                  preferensi Anda..."│
        │        }]                           │
        │      }                              │
        │    }],                              │
        │    usageMetadata: {                 │
        │      promptTokenCount: 450,         │
        │      candidatesTokenCount: 280,     │
        │      totalTokenCount: 730           │
        │    }                                │
        │  }                                  │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 1600ms
        ┌─ Step 3.5: SAFETY CHECK ────────────┐
        │                                     │
        │  responseText = "Defisit kalori..." │
        │                                     │
        │  safetyFlag = false                 │
        │  safetyReasons = []                 │
        │                                     │
        │  FOR keyword IN BLOCKED_KEYWORDS:   │
        │    IF responseText.contains(kw):    │
        │      safetyFlag = true              │
        │      safetyReasons.push(kw)         │
        │                                     │
        │  IF isHealthQuery(userMessage):     │
        │    processedResponse +=             │
        │      "\n*Informasi ini bersifat..." │
        │      (disclaimer)                   │
        │                                     │
        │  IF userAllergies.includes('nut'):  │
        │    IF response.includes('kacang'):  │
        │      FLAG for review                │
        │      safetyFlag = true              │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 1650ms
        ┌─ Step 3.6: STORAGE ─────────────────┐
        │                                     │
        │  IF processedResponse.length >      │
        │     STORAGE_THRESHOLD (5000):       │
        │                                     │
        │    fileName = "responses/" + runId  │
        │    supabase.storage.upload(         │
        │      'chatbot-responses',           │
        │      fileName,                      │
        │      processedResponse              │
        │    )                                │
        │    responsePointer =                │
        │      "supabase_storage://..." + fn  │
        │    responseText = NULL (not stored) │
        │                                     │
        │  ELSE:                              │
        │    responsePointer = NULL           │
        │    responseText = response (inline) │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 1700ms
        ┌─ Step 3.7: TELEMETRY LOG ──────────┐
        │                                     │
        │  telemetryRecord = {                │
        │    run_id: '550e8400...',           │
        │    user_id: 'user-123',             │
        │    prompt_id: 'chef_cei_v1.2',      │
        │    prompt_hash: 'sha256:a1b2...',   │
        │    model_name: 'gemini-3-flash',    │
        │    temperature: 0.4,                │
        │    token_usage: {                   │
        │      input_tokens: 450,             │
        │      output_tokens: 280,            │
        │      total_tokens: 730              │
        │    },                               │
        │    latency_ms: 1700,                │
        │    safety_flag: false,              │
        │    retrieved_results: [JSONB],      │
        │    response_text: "Defisit...",     │
        │    rag_mode: 'naive'                │
        │  }                                  │
        │                                     │
        │  INSERT chatbot_telemetry VALUES    │
        │    (telemetryRecord)                │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 1750ms
        ┌─ Step 3.8: RETURN RESPONSE ────────┐
        │                                     │
        │  HTTP 200 OK                        │
        │  Content-Type: application/json     │
        │                                     │
        │  {                                  │
        │    "response": "Defisit kalori...", │
        │    "run_id": "550e8400...",         │
        │    "metadata": {                    │
        │      "latency_ms": 1700,            │
        │      "token_usage": {...},          │
        │      "rag_mode": "naive",           │
        │      "retrieved_count": 3           │
        │    }                                │
        │  }                                  │
        │                                     │
        └─────────────────────────────────────┘
                     │
                     ↓ T3 + 1850ms (Network latency)
        ┌────────────────────────────────┐
        │  T4: CLIENT RECEIVES RESPONSE   │
        └────────────────────────────────┘
        
        StreamSubscription receives:
        
        _streamSubscription = _chatbotService
          .sendMessageStream(message)
          .listen(
            (partialResponse) {
              setState(() {
                _currentBotResponse = partialResponse;
                // Response displayed in chat UI
                // "Defisit kalori yang disarankan..."
              });
              _scrollToBottom();
            },
            onDone: () {
              setState(() {
                _isLoading = false;
                _isStreaming = false;
              });
              // Save to local database
              _saveMessage(response, false);
            }
          );
                     │
                     ↓ T4 + 100ms
        ┌────────────────────────────────┐
        │  T5: UI UPDATE & PERSISTENCE    │
        └────────────────────────────────┘
        
        1. Response displayed in ChatBubble
           - Streaming text animation
           - Markdown rendering
           - User can copy/share
        
        2. Save to local chat history:
           INSERT chat_messages VALUES (
             id, user_id, "Defisit kalori...",
             false, NOW()
           )
        
        3. Display in conversation:
           [User]  "Berapa defisit kalori?"
           [Cei]   "Defisit kalori yang disarankan
                    adalah 500-750 kkal/hari..."
```

---

## 3. DATA FLOW ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA MOVEMENT                               │
└─────────────────────────────────────────────────────────────────┘

INPUT DATA:
━━━━━━━━━━━━━
├─ User Message
│  └─ Text: "Berapa defisit kalori untuk turun 5kg?"
│     Type: String
│     Length: ~50 chars
│
├─ User Context (Local Storage)
│  ├─ Pantry Items (Hive)
│  │  └─ [{name: "Eggs", qty: 3}, {...}]
│  │
│  ├─ Diet Preferences (SharedPrefs)
│  │  └─ ["Low-Sugar", "Gluten-Free"]
│  │
│  └─ Allergies (SharedPrefs)
│     └─ ["Nut", "Dairy"]
│
└─ Session Metadata
   ├─ user_id: "user-123"
   ├─ session_id: "sess-456"
   └─ app_version: "1.2.0"

TRANSFORMATION 1: Embedding
━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  "Berapa defisit kalori untuk turun 5kg?"
        ↓
        Gemini Embedding API
        ↓
Output: embedding: [0.123, -0.456, 0.789, ..., -0.234]  // 768 dims

TRANSFORMATION 2: Vector Search & Ranking
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  embedding vector
        ↓
        Supabase RPC: match_documents()
        ↓
        Compare with 10,000+ document chunks in DB
        ↓
Output: [{
  chunk_id: 42,
  doc_id: "Obesity_2026",
  similarity_score: 0.923,
  chunk_text: "500-750 kkal deficit..."
}, ...]  // Top-10 candidates

TRANSFORMATION 3: Optional Reranking (Advanced Mode)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  Top-10 results
        ↓
        HuggingFace Reranker Model
        ↓
        Sort by relevance score
        ↓
Output: [{
  chunk_id: 42,
  reranker_score: 2.145
}, ...]  // Top-3 with reranker scores

TRANSFORMATION 4: Prompt Construction
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  System Prompt Template + Retrieved Contexts + User Message
        ↓
        String concatenation
        ↓
Output: Complete Enhanced Prompt (~2500 tokens)
        "You are Chef Cei...
         Context: [Eggs, Chicken, Rice]
         Preferences: Low-Sugar, Gluten-Free
         Allergies: Nut, Dairy
         References: [3 retrieved chunks]
         
         User: Berapa defisit kalori...?"

TRANSFORMATION 5: LLM Generation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  Enhanced Prompt (~2500 tokens)
        ↓
        Gemini API (temp=0.4, max_tokens=1024)
        ↓
Output: Response Text + Token Usage
        {
          text: "Defisit kalori yang disarankan...",
          tokens: {
            input: 450,
            output: 280,
            total: 730
          }
        }

TRANSFORMATION 6: Safety Processing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  Response Text + Safety Rules + User Context
        ↓
        Check:
        - Blocked keywords?
        - Health-related query?
        - Allergy contradiction?
        ↓
Output: Processed Response + Safety Flags + Disclaimers

TRANSFORMATION 7: Storage Decision
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  Response Text (processed)
        ↓
        IF size > 5KB:
          Upload to Supabase Storage
          → response_pointer
        ELSE:
          Store inline in DB
          → response_text
        ↓
Output: Storage Reference (pointer or inline)

TRANSFORMATION 8: Telemetry Serialization
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Input:  All metadata + results
        ↓
        Convert to JSONB (for PostgreSQL)
        ↓
Output: {
  run_id: UUID,
  token_usage: JSONB,
  retrieved_results: JSONB (with ranking),
  prompt_hash: SHA-256,
  latency_ms: integer,
  ...
}

OUTPUT DATA:
━━━━━━━━━━━━
├─ Response to User
│  └─ "Defisit kalori yang disarankan adalah 500-750 kkal/hari..."
│
├─ Stored in chat_messages Table
│  ├─ User message
│  └─ Bot response
│
├─ Stored in chatbot_telemetry Table
│  ├─ Query text
│  ├─ Response text (or pointer)
│  ├─ Retrieved results with ranking
│  ├─ Token usage
│  ├─ Latency
│  └─ Safety flags
│
└─ Available for RAGAS Evaluation
   ├─ question: query_text
   ├─ answer: response_text
   ├─ contexts: extracted from retrieved_results
   └─ ground_truth_context_ids: from vignette
```

---

## 4. PROCESSING LAYERS (5 LAYER ARCHITECTURE)

### Layer 1: REQUEST HANDLING
```
Input: HTTP Request (JSON)
Process:
  1. Parse request body
  2. Validate action type
  3. Extract parameters
Output: ChatbotRequest object ready for processing

Time: ~10ms
```

### Layer 2: KNOWLEDGE BASE RETRIEVAL
```
Input: User message
Process:
  Mode 'none':
    - Skip this layer
  Mode 'naive':
    - Embed query (Gemini)
    - Vector search (Supabase)
    - Keep top-3
  Mode 'advanced':
    - Embed query (Gemini)
    - Vector search (Supabase) → top-10
    - Rerank (HF model) → top-3
Output: retrieved_results JSONB with ranking

Time: 200-800ms (depending on mode)
```

### Layer 3: LLM PROCESSING
```
Input: Enhanced system prompt + user message
Process:
  1. Build complete prompt
  2. Call Gemini API
  3. Stream/collect response
  4. Extract token usage
Output: response_text + token_usage

Time: 1000-2000ms (API latency)
```

### Layer 4: SAFETY & POST-PROCESSING
```
Input: Response text + user context
Process:
  1. Check blocked keywords
  2. Check alergen contradictions
  3. Add disclaimers if needed
  4. Normalize units
Output: processed_response + safety_flags

Time: 50-100ms
```

### Layer 5: PERSISTENCE & LOGGING
```
Input: All metadata + processed response
Process:
  1. Decide storage location
  2. Upload/store response
  3. Serialize telemetry
  4. Insert to database
Output: Confirmed in database

Time: 100-500ms
```

---

## 5. DATABASE SCHEMA (CORE TABLES)

### Table: chat_messages
```
Purpose: Store user-bot conversation history
┌──────────────┬───────────┬──────────────────────┐
│ Column       │ Type      │ Description          │
├──────────────┼───────────┼──────────────────────┤
│ id           │ UUID PK   │ Message ID           │
│ user_id      │ UUID FK   │ User reference       │
│ message      │ TEXT      │ Message content      │
│ is_user      │ BOOLEAN   │ User (T) or Bot (F)  │
│ created_at   │ TIMESTAMP │ Creation time        │
│ updated_at   │ TIMESTAMP │ Last update          │
└──────────────┴───────────┴──────────────────────┘

Example:
┌────────────┬──────────┬──────────────────────────────┬─────────┐
│ id         │ user_id  │ message                      │ is_user │
├────────────┼──────────┼──────────────────────────────┼─────────┤
│ uuid-001   │ user-123 │ Berapa defisit kalori?       │ true    │
│ uuid-002   │ user-123 │ Defisit 500-750 kkal/hari... │ false   │
└────────────┴──────────┴──────────────────────────────┴─────────┘
```

### Table: chatbot_telemetry (MAIN FOR EVALUATION)
```
Purpose: Log all chatbot interactions for RAGAS evaluation
┌──────────────────────┬──────────┬──────────────────────┐
│ Column               │ Type     │ Description          │
├──────────────────────┼──────────┼──────────────────────┤
│ run_id               │ UUID PK  │ Unique per request   │
│ user_id              │ UUID FK  │ User reference       │
│ query_text           │ TEXT     │ User question        │
│ response_text        │ TEXT     │ Bot response (inline)│
│ response_pointer     │ TEXT     │ Storage path (if big)│
│ retrieved_results    │ JSONB    │ **KEY: Ranked docs**│
│ token_usage          │ JSONB    │ {input, output}      │
│ latency_ms           │ INTEGER  │ Response time        │
│ safety_flag          │ BOOLEAN  │ Safety reviewed?     │
│ rag_mode             │ VARCHAR  │ 'none'/'naive'/...   │
│                      │          │                      │
│ ground_truth_*       │ JSONB    │ From vignette        │
│ ragas_answer_rel*    │ FLOAT    │ Evaluation score     │
│ ragas_faithfulness   │ FLOAT    │ Evaluation score     │
│ ragas_context_rel*   │ FLOAT    │ Evaluation score     │
│ ragas_mrr            │ FLOAT    │ **Mean Recip Rank**  │
│                      │          │                      │
│ timestamp            │ TIMESTAMP│ Creation time        │
└──────────────────────┴──────────┴──────────────────────┘

retrieved_results JSONB structure:
[
  {
    "rank": 1,                          ← RANKING
    "chunk_id": 42,
    "doc_id": "Obesity_2026",
    "chunk_text": "500-750 kkal...",
    "title": "ADA Obesity Guidelines",
    "similarity_score": 0.923,          ← From embedding
    "reranker_score": 2.145             ← From reranker (if advanced)
  },
  {
    "rank": 2,
    "chunk_id": 18,
    ...
  },
  ...
]
```

### Table: knowledge_base_chunks
```
Purpose: Store embeddings of clinical documents
┌──────────────────┬──────────┬──────────────────────┐
│ Column           │ Type     │ Description          │
├──────────────────┼──────────┼──────────────────────┤
│ chunk_id         │ INTEGER  │ Chunk ID             │
│ doc_id           │ VARCHAR  │ Document identifier  │
│ chunk_text       │ TEXT     │ Chunk content        │
│ embedding        │ vector   │ 768-dim embedding    │
│ title            │ TEXT     │ Document title       │
│ source_pdf       │ VARCHAR  │ Source PDF file      │
│ page_number      │ INTEGER  │ Page in PDF          │
│ metadata         │ JSONB    │ Additional data      │
└──────────────────┴──────────┴──────────────────────┘

Vector search enabled on 'embedding' column
for similarity search with threshold 0.5
```

---

## 6. TIMING BREAKDOWN

```
Total End-to-End Time: ~1750ms

T0 + 0ms    ─ User sends message
T0 + 10ms   ─ ChatbotService processes
T0 + 50ms   ─ Request construction
T0 + 100ms  ─ Edge Function receives (network)
T0 + 150ms  ─ Initialization complete
T0 + 200ms  ┬─ RAG Retrieval START
            │
T0 + 300ms  ├─ Embedding generated
T0 + 400ms  ├─ Vector search results
T0 + 600ms  ├─ Reranking (if advanced)
T0 + 800ms  ┴─ RAG Retrieval END
            │
T0 + 850ms  ─ Enhanced prompt built
            │
T0 + 900ms  ┬─ Gemini API call START
            │
T0 + 1600ms ├─ Gemini response received
            │   (~700ms API latency typical)
T0 + 1600ms ┴─ Gemini API call END
            │
T0 + 1650ms ─ Safety check & processing
T0 + 1700ms ─ Storage decision & upload
T0 + 1750ms ─ Telemetry inserted
T0 + 1800ms ─ HTTP response sent to client (network)
T0 + 1900ms ─ Client receives & displays
```

---

## 7. RAG MODES COMPARISON

```
┌────────────┬──────────┬──────────────┬──────────────────┐
│ Mode       │ Retrieval│ Reranking    │ Total Time       │
├────────────┼──────────┼──────────────┼──────────────────┤
│ 'none'     │ ✗ Skip   │ ✗ N/A        │ ~1000ms (faster) │
│ (Pure LLM) │          │              │ Only LLM call    │
├────────────┼──────────┼──────────────┼──────────────────┤
│ 'naive'    │ ✓ Yes    │ ✗ No         │ ~1400ms (medium) │
│            │ Top-3    │              │ RAG + LLM        │
├────────────┼──────────┼──────────────┼──────────────────┤
│ 'advanced' │ ✓ Yes    │ ✓ Yes        │ ~1750ms (slower) │
│            │ Top-10→3 │ HF model     │ Full RAG + LLM   │
└────────────┴──────────┴──────────────┴──────────────────┘

Quality vs Speed Tradeoff:

Quality →
    advanced ●───────
              │       │
    naive     │   ●───── ─────
              │   │       │
    none      ●───────────────
              ├─────┬─────┬─────┤
              0ms   1000  1500  2000 ← Speed

Quality Expected:
  none      : Medium (generic LLM response)
  naive     : High (with relevant docs)
  advanced  : Very High (reranked docs)

Recommended Usage:
  - 'none'     : General questions, fast feedback
  - 'naive'    : Health consultations, balance
  - 'advanced' : Critical evaluations, best quality
```

---

## 8. EVALUATION PIPELINE (RAGAS)

```
After Response Stored → Offline Processing
                              ↓
        ┌──────────────────────────────────────┐
        │ RAGAS EVALUATION SCRIPT               │
        │ (Python, runs daily/weekly)           │
        └──────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 1. Load Telemetry Records               │
    │    SELECT * FROM chatbot_telemetry      │
    │    WHERE ground_truth_context_ids NULL  │
    │                                         │
    │    → Load unevaluated records           │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 2. Match with Vignettes                 │
    │    15 test scenarios defined:           │
    │    - V01: Diabetes calorie reduction    │
    │    - V02: Carbs & HbA1c impact         │
    │    - V03: Blood pressure targets        │
    │    ... (V04-V15)                       │
    │                                         │
    │    → Pair telemetry with ground truth   │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 3. Build RAGAS Dataset                  │
    │    For each record:                     │
    │    {                                    │
    │      question: query_text,              │
    │      answer: response_text,             │
    │      contexts: from retrieved_results,  │
    │      ground_truth_ids: from vignette    │
    │    }                                    │
    │                                         │
    │    → 100-1000 samples per batch         │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 4. Evaluate Metrics                     │
    │                                         │
    │    Answer Relevancy:                    │
    │    semantic_sim(question, answer)       │
    │    Score: 0-1 (target > 0.8)            │
    │                                         │
    │    Faithfulness:                        │
    │    answer_consistency(answer,contexts)  │
    │    Score: 0-1 (target > 0.75)           │
    │                                         │
    │    Context Relevance:                   │
    │    relevant_docs / total_docs           │
    │    Score: 0-1 (target > 0.7)            │
    │                                         │
    │    Mean Reciprocal Rank (MRR):          │
    │    1 / rank(first_relevant_doc)         │
    │    Score: 0-1 (target > 0.5)            │
    │                                         │
    │    → Calculate for each sample          │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 5. Aggregate Results                    │
    │                                         │
    │    by_rag_mode = {                      │
    │      'none': {                          │
    │        count: 50,                       │
    │        avg_relevancy: 0.72,             │
    │        avg_faithfulness: 0.65,          │
    │        avg_mrr: 0.0 (no retrieval)      │
    │      },                                 │
    │      'naive': {                         │
    │        count: 150,                      │
    │        avg_relevancy: 0.82,             │
    │        avg_faithfulness: 0.78,          │
    │        avg_mrr: 0.68                    │
    │      },                                 │
    │      'advanced': {                      │
    │        count: 100,                      │
    │        avg_relevancy: 0.85,             │
    │        avg_faithfulness: 0.81,          │
    │        avg_mrr: 0.72                    │
    │      }                                  │
    │    }                                    │
    │                                         │
    │    → Summary statistics                 │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 6. Update Database                      │
    │                                         │
    │    UPDATE chatbot_telemetry SET:        │
    │      ragas_answer_relevancy = 0.85,     │
    │      ragas_faithfulness = 0.81,         │
    │      ragas_context_relevance = 0.74,    │
    │      ragas_mrr = 0.72,                  │
    │      ground_truth_context_ids = [...],  │
    │      evaluated_at = NOW()               │
    │    WHERE run_id = ...                   │
    │                                         │
    │    → Mark as evaluated                  │
    └─────────────────────────────────────────┘
                     ↓
    ┌─────────────────────────────────────────┐
    │ 7. Generate Report                      │
    │                                         │
    │    - Metrics by RAG mode                │
    │    - Improvement over baselines         │
    │    - Problem areas                      │
    │    - Recommendations                    │
    │                                         │
    │    → Export JSON/PDF report             │
    └─────────────────────────────────────────┘
```

---

## 9. ERROR HANDLING & FALLBACKS

```
┌─ Scenario: Embedding API Timeout
│  ├─ Timeout > 5 seconds?
│  ├─ YES: Fall back to 'none' mode
│  │       Log error
│  │       Continue with pure LLM
│  └─ Response: ✅ Sent (lower quality)
│
├─ Scenario: Vector Search No Results
│  ├─ Matches < threshold?
│  ├─ YES: Return empty retrieved_results
│  │       Continue with LLM only
│  └─ Response: ✅ Sent (generic response)
│
├─ Scenario: Reranker API Error
│  ├─ HF API fails?
│  ├─ YES: Use original similarity scores
│  │       Keep top-3 anyway
│  │       Log fallback
│  └─ Response: ✅ Sent (slightly lower quality)
│
├─ Scenario: Gemini API Error
│  ├─ Max retries exceeded?
│  ├─ YES: Return error to client
│  │       Flag run_id for investigation
│  │       Store error_message in telemetry
│  └─ Response: ❌ Error (user sees error msg)
│
├─ Scenario: Database Telemetry Insert Fails
│  ├─ INSERT error?
│  ├─ YES: Continue anyway
│  │       Log error to stderr
│  │       Don't block user response
│  └─ Response: ✅ Sent (telemetry lost, but user ok)
│
└─ Scenario: Storage Upload Fails
   ├─ Supabase Storage unavailable?
   ├─ YES: Store response inline in DB
   │       Set response_pointer = NULL
   │       response_text = full text
   └─ Response: ✅ Sent (stored inline)
```

---

## 10. MONITORING & METRICS

```
Real-time Monitoring Dashboard:

┌────────────────────────────────────────┐
│ SYSTEM HEALTH                          │
├────────────────────────────────────────┤
│ Requests/min:           45              │ ← Activity
│ Avg Latency:            1.24s           │ ← Performance
│ Error Rate:             0.3%            │ ← Health
│ Gemini API:             ✓ OK            │ ← Dependencies
│ Supabase:               ✓ OK            │
│ HF Reranker:            ✓ OK            │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│ RAGAS METRICS (Last 24h)               │
├────────────────────────────────────────┤
│ Mode        │ Samples │ Answer Rel │ MRR│
├─────────────┼─────────┼────────────┼───┤
│ none        │ 45      │ 0.72 ↓     │0.00│
│ naive       │ 128     │ 0.82 →     │0.68│
│ advanced    │ 92      │ 0.85 ↑     │0.72│
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│ QUALITY INDICATORS                     │
├────────────────────────────────────────┤
│ Safety Flags:           2 (0.4%)        │
│ User Satisfaction:      4.3/5 (42 votes)
│ Knowledge Base Size:    15,234 chunks   │
│ Total Conversations:    1,247           │
│ Avg Message Length:     85 chars        │
└────────────────────────────────────────┘
```

---

## RINGKASAN SISTEM LENGKAP

**Chatbot Chef Cei** adalah sistem AI terintegrasi yang:

1. **Menerima input** dari user melalui mobile app
2. **Mengumpulkan konteks** dari local storage
3. **Mengirim request** ke Edge Function dengan RAG mode
4. **Melakukan retrieval** dari knowledge base (optional)
5. **Memanggil LLM** (Gemini) dengan enhanced prompt
6. **Memproses safety** dan menambahkan disclaimer
7. **Menyimpan response** ke storage/database
8. **Mencatat telemetry** untuk evaluation
9. **Mengembalikan response** ke user
10. **Dievaluasi** dengan RAGAS untuk quality metrics

**Keunggulan:**
- RAG architecture untuk response berkualitas tinggi
- 3 RAG modes untuk flexibility
- RAGAS evaluation untuk quality measurement
- Safety checks untuk responsible AI
- Full telemetry untuk monitoring & improvement

**Target Metrics (Production):**
- Answer Relevancy: > 0.8
- Faithfulness: > 0.75
- Context Relevance: > 0.7
- MRR: > 0.5
- Latency: < 2 seconds
- Error Rate: < 1%

