# 🏠 KONTEKS PENGGUNA: LOCAL STORAGE vs RAGAS EVALUATION

---

## OVERVIEW

Ada **DUA SCENARIO** berbeda tentang bagaimana konteks pengguna ditangani:

### Scenario A: PRODUCTION / REAL USER USAGE ✅

**Sebelum mengirim pertanyaan ke Gemini API**, ChatbotService mengumpulkan konteks pengguna dari **local storage** (Hive & SharedPreferences) untuk memberikan response yang **dipersonalisasi**:

- 🛒 **Pantry Items** - Bahan makanan yang tersedia di dapur user
- 🥗 **Diet Preferences** - Preferensi diet yang dipilih user  
- ⚠️ **Allergies** - Alergi & intoleransi user

Konteks ini **DIKIRIM bersama user message** ke Edge Function dan **DIINJEKSI ke system prompt** untuk Gemini.

---

### Scenario B: RAGAS EVALUATION / TESTING ⚠️

Untuk **evaluasi MRR dan RAGAS quality metrics**, konteks TIDAK boleh berasal dari local storage (variable/inconsistent), tetapi harus:

1. **STANDARDIZED** - Konteks fixed/hardcoded untuk semua test queries
2. **CONSISTENT** - Semua query dievaluasi dengan konteks yang sama
3. **COMPARABLE** - Hasil MRR antar mode (none/naive/advanced) fair dan valid

> **Kenapa penting?** 
> - RAGAS evaluation menguji **retrieval quality** + **generation quality**
> - Jika konteks user beda-beda, MRR results jadi **tidak comparable**
> - Untuk fair evaluation, harus standardized context untuk consistency

---

## ARSITEKTUR DALAM CONTEXT

> **Kenapa penting?** 
> - RAGAS evaluation menguji **retrieval quality** + **generation quality**
> - Jika konteks user beda-beda, MRR results jadi **tidak comparable**
> - Untuk fair evaluation, harus standardized context untuk consistency

---

## SCENARIO B DETAIL: RAGAS EVALUATION TEST SETUP

### Bagaimana RAGAS Evaluation Bekerja

```
TEST EXECUTION FLOW:

FOR each vignette IN 15 vignettes:
  
  query = vignette.query_text
  ground_truth = vignette.reference_answer
  ground_truth_docs = vignette.ground_truth_context_ids
  
  FOR each RAG_MODE IN ['none', 'naive', 'advanced']:
    
    # CRITICAL: Gunakan STANDARDIZED context, bukan user-specific
    
    contextData = {
      pantryItems: null,        # ← JANGAN ambil dari Hive
      dietPreferences: null,    # ← JANGAN ambil dari SharedPrefs
      allergies: null,          # ← JANGAN ambil dari local storage
      currentRecipe: null
    }
    
    # OR gunakan FIXED CONTEXT untuk semua queries:
    contextData = {
      pantryItems: ['Rice', 'Eggs', 'Chicken', 'Tomato'],
      dietPreferences: ['Vegetarian'],
      allergies: ['Nut Allergy']
    }
    
    # Send to Edge Function
    response = await geminiProxy.sendChatMessage(
      userMessage: query,
      contextData: contextData,  # ← SAMA untuk semua queries
      ragMode: RAG_MODE
    )
    
    # Calculate metrics
    retrieved_docs = response.rag_documents
    mrr = calculateMRR(retrieved_docs, ground_truth_docs)
    answer_relevancy = ragas.answer_relevancy(response.text, query)
    faithfulness = ragas.faithfulness(response.text, retrieved_docs)
    context_relevance = ragas.context_relevance(query, retrieved_docs)
    
    # Log telemetry
    INSERT INTO chatbot_telemetry (
      user_id: 'eval_agent',  # ← Indicator ini adalah evaluation
      rag_mode: RAG_MODE,
      mrr_score: mrr,
      answer_relevancy: answer_relevancy,
      faithfulness: faithfulness,
      context_relevance: context_relevance,
      ...
    )
```

### Konteks untuk RAGAS: Fixed vs User-Specific

```
┌─────────────────────────────────────────────┐
│ OPTION 1: NO CONTEXT (Recommended)          │
├─────────────────────────────────────────────┤
│                                             │
│ contextData = {                             │
│   pantryItems: null,                        │
│   dietPreferences: null,                    │
│   allergies: null,                          │
│   currentRecipe: null                       │
│ }                                           │
│                                             │
│ Alasan:                                     │
│ - Sistem prompt minimal                     │
│ - MRR evaluation fokus pada RAG quality     │
│ - Tidak ada bias dari user context          │
│ - Easily reproducible                       │
│                                             │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ OPTION 2: FIXED CONTEXT (For testing)       │
├─────────────────────────────────────────────┤
│                                             │
│ contextData = {                             │
│   pantryItems: [                            │
│     'Rice', 'Eggs', 'Chicken',              │
│     'Tomato', 'Onion', 'Garlic'             │
│   ],                                        │
│   dietPreferences: ['Vegetarian'],          │
│   allergies: ['Nut Allergy'],               │
│   currentRecipe: null                       │
│ }                                           │
│                                             │
│ Alasan:                                     │
│ - SEMUA queries mendapat context yang sama  │
│ - Fair comparison antar rag_modes           │
│ - Consistent across evaluation runs         │
│ - Reproducible & auditable                  │
│                                             │
│ CAUTION:                                    │
│ - Jangan ubah context di tengah evaluation  │
│ - Dokumentasikan context yang digunakan     │
│ - Setiap vignette harus sama contextnya     │
│                                             │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ OPTION 3: VARIABLE CONTEXT (NOT RECOMMENDED)│
├─────────────────────────────────────────────┤
│                                             │
│ FOR each vignette:                          │
│   contextData = _getUserContextFromStorage()│
│   # ← Context berbeda setiap kali!          │
│                                             │
│ Alasan MENGAPA TIDAK BOLEH:                 │
│                                             │
│ ❌ MRR scores tidak comparable              │
│ ❌ Bias dari user-specific data             │
│ ❌ Non-reproducible results                 │
│ ❌ Evaluation tidak fair                    │
│ ❌ Hasil metrics jadi misleading             │
│                                             │
│ Contoh masalah:                             │
│ - Query A: user punya 100 pantry items      │
│ - Query B: user punya 5 pantry items        │
│ - MRR untuk Query A vs Query B tidak bisa   │
│   dibandingkan karena context beda!         │
│                                             │
└─────────────────────────────────────────────┘
```

---

## SCENARIO A DETAIL: PRODUCTION

```
┌─────────────────────────────────────────────────────┐
│           MOBILE APP LOCAL STORAGE                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │ HIVE (Pantry Items)                         │   │
│  ├─────────────────────────────────────────────┤   │
│  │                                             │   │
│  │ Box Name: 'pantry_user@email.com'           │   │
│  │ Type: Box<String>                           │   │
│  │ Key-Value Pairs:                            │   │
│  │                                             │   │
│  │  'item_1' → "Eggs|3|pcs"                   │   │
│  │  'item_2' → "Chicken|500|gram"             │   │
│  │  'item_3' → "Rice|2|kg"                    │   │
│  │  'item_4' → "Tomato|1|kg"                  │   │
│  │  'item_5' → "Onion|250|gram"               │   │
│  │                                             │   │
│  │ Format: "name|quantity|unit"                │   │
│  │                                             │   │
│  │ Capacity: ~100-500 items typical            │   │
│  │ Persistence: Disk (Hive local box)          │   │
│  │                                             │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │ SHARED PREFERENCES (Diet & Allergies)       │   │
│  ├─────────────────────────────────────────────┤   │
│  │                                             │   │
│  │ Key: 'user_diet_preferences'                │   │
│  │ Type: StringList                            │   │
│  │ Value: [                                    │   │
│  │   'vegetarian',                             │   │
│  │   'gluten_free',                            │   │
│  │   'low_sugar',                              │   │
│  │   'nut_allergy',                            │   │
│  │   'dairy_allergy'                           │   │
│  │ ]                                           │   │
│  │                                             │   │
│  │ Capacity: ~20-30 items typical              │   │
│  │ Persistence: Device secure storage          │   │
│  │                                             │   │
│  └─────────────────────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
---

## 1. SCENARIO A ARCHITECTURE

### 1.1 Penyimpanan Lokal

```
┌──────────────────────────────────────────┐
│ User sends message: "Berapa kalori?"     │
└────────────────┬─────────────────────────┘
                 ↓
        ┌─────────────────────────┐
        │ ChatbotService          │
        │ sendMessageStream()     │
        └────────────┬────────────┘
                     ↓
        ┌──────────────────────────────────┐
        │ Step 1: GET USER CONTEXT         │
        │ context = _getUserContext()      │
        └────────────┬─────────────────────┘
                     ↓
        ┌──────────────────────────────────────────────┐
        │ PARALLEL: Fetch from 2 storage sources       │
        ├──────────────────────────────────────────────┤
        │                                              │
        │  BRANCH A: Hive (Pantry)                    │
        │  ─────────────────────────────────────────   │
        │  1. Get current user email                  │
        │     userEmail = Supabase.auth.currentUser   │
        │                            .email           │
        │                 = "user@example.com"        │
        │                                              │
        │  2. Construct box name                      │
        │     boxName = 'pantry_' + userEmail         │
        │             = "pantry_user@example.com"     │
        │                                              │
        │  3. Check if box is open                    │
        │     IF NOT: Box might not initialized yet   │
        │                                              │
        │  4. Get box & extract items                 │
        │     box = Hive.box<String>(boxName)         │
        │     items = box.values.toList()             │
        │     [                                       │
        │       "Eggs|3|pcs",                         │
        │       "Chicken|500|gram",                   │
        │       "Rice|2|kg"                           │
        │     ]                                       │
        │                                              │
        │  5. Parse & extract names only              │
        │     FOR each item:                          │
        │       parts = item.split('|')               │
        │       name = parts[0]                       │
        │     Result:                                 │
        │     pantryItems = [                         │
        │       "Eggs",                               │
        │       "Chicken",                            │
        │       "Rice"                                │
        │     ]                                       │
        │                                              │
        │  BRANCH B: SharedPreferences (Diet+Allergy)│
        │  ─────────────────────────────────────────  │
        │  1. Get SharedPreferences instance          │
        │     prefs = SharedPreferences.getInstance() │
        │                                              │
        │  2. Retrieve diet list                      │
        │     allDiets = prefs.getStringList(         │
        │       'user_diet_preferences'               │
        │     ) ?? []                                 │
        │                                              │
        │     Value retrieved:                        │
        │     [                                       │
        │       'vegetarian',                         │
        │       'gluten_free',                        │
        │       'low_sugar',                          │
        │       'nut_allergy',                        │
        │       'dairy_allergy'                       │
        │     ]                                       │
        │                                              │
        │  3. Define allergy keys to identify them    │
        │     allergyKeys = [                         │
        │       'nut_allergy',                        │
        │       'seafood_allergy',                    │
        │       'dairy_allergy'                       │
        │     ]                                       │
        │                                              │
        │  4. Categorize into diets vs allergies      │
        │     dietPreferences = []                    │
        │     allergies = []                          │
        │                                              │
        │     FOR each diet IN allDiets:              │
        │       IF diet IN allergyKeys:               │
        │         allergies.push(format(diet))        │
        │       ELSE:                                 │
        │         dietPreferences.push(format(diet))  │
        │                                              │
        │     Result:                                 │
        │     dietPreferences = [                     │
        │       'Vegetarian',      ← formatted        │
        │       'Gluten Free',     ← formatted        │
        │       'Low Sugar'        ← formatted        │
        │     ]                                       │
        │     allergies = [                           │
        │       'Alergi Kacang',   ← formatted        │
        │       'Alergi Susu'      ← formatted        │
        │     ]                                       │
        │                                              │
        │  5. Format diet labels                      │
        │     _formatDietLabel('nut_allergy')         │
        │     → 'Alergi Kacang'                       │
        │                                              │
        └──────────────────────────────────────────────┘
                     ↓
        ┌──────────────────────────────────────────────┐
        │ Step 2: CREATE USER CONTEXT OBJECT           │
        │                                              │
        │ UserContext(                                 │
        │   pantryItems: ['Eggs', 'Chicken', 'Rice'],│
        │   dietPreferences: ['Vegetarian', ...],     │
        │   allergies: ['Alergi Kacang', ...]         │
        │ )                                           │
        │                                              │
        └──────────────────────┬───────────────────────┘
                               ↓
        ┌──────────────────────────────────────────────┐
        │ Step 3: SEND WITH MESSAGE                    │
        │                                              │
        │ _geminiProxy.sendChatMessage(                │
        │   userMessage: "Berapa kalori?",            │
        │   pantryItems: context.pantryItems,         │
        │   dietPreferences: context.dietPreferences,  │
        │   allergies: context.allergies,             │
        │   ragMode: 'naive',                         │
        │   ...                                       │
        │ )                                           │
        │                                              │
        └──────────────────────┬───────────────────────┘
                               ↓
        ┌──────────────────────────────────────────────┐
        │ Step 4: KONTEKS DIINJEKSI KE PROMPT         │
        │                                              │
        │ Edge Function receives & builds prompt:      │
        │                                              │
        │ systemPrompt += """                         │
        │   User Context:                             │
        │   - Pantry: Eggs, Chicken, Rice            │
        │   - Diet: Vegetarian, Gluten Free, ...     │
        │   - Allergies: Alergi Kacang, ...          │
        │                                              │
        │   User: Berapa kalori?                      │
        │   """                                       │
        │                                              │
        └──────────────────────┬───────────────────────┘
                               ↓
        ┌──────────────────────────────────────────────┐
        │ Step 5: GEMINI RESPONSE                      │
        │                                              │
        │ Gemini considers context:                    │
        │                                              │
        │ "Berdasarkan bahan-bahan di dapur Anda      │
        │  (Telur, Ayam, Nasi) dan preferensi        │
        │  Vegetarian + Gluten Free, dengan alergi    │
        │  kacang...                                  │
        │                                              │
        │  Kalori rekomendasi adalah..."              │
        │                                              │
        └──────────────────────────────────────────────┘
---

### 1.3 Kode Detail: Pengambilan Konteks (Production)

#### 1.3.A Inisialisasi & Pemanggilan

**File:** `lib/app/services/chatbot_service.dart`

```dart
/// Kirim pesan ke chatbot
Stream<String> sendMessageStream(String userMessage) async* {
  if (userMessage.trim().isEmpty) return;

  // Simpan pesan user
  await _saveMessage(userMessage, true);

  try {
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 1: AMBIL KONTEKS PENGGUNA
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final context = await _getUserContext();
    
    // context object sekarang berisi:
    // {
    //   pantryItems: ['Eggs', 'Chicken', 'Rice'],
    //   dietPreferences: ['Vegetarian', 'Gluten Free'],
    //   allergies: ['Alergi Kacang']
    // }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STEP 2: KIRIM KE GEMINI VIA PROXY
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    final response = await _geminiProxy.sendChatMessage(
      userMessage: userMessage,
      pantryItems: context.pantryItems,           // ← KONTEKS
      dietPreferences: context.dietPreferences,    // ← KONTEKS
      allergies: context.allergies,                // ← KONTEKS
      recipeName: _currentRecipe?.title,
      recipeIngredients: _currentRecipe?.allIngredients.map((i) => i.name).toList(),
      recipeDescription: _currentRecipe?.description,
      ragMode: _ragMode,
    );

    if (response != null) {
      await _saveMessage(response, false);
      yield response;
    }
  } catch (e) {
    debugPrint('❌ ChatbotService: Error - $e');
    yield 'Maaf, terjadi kesalahan. Silakan coba lagi.';
  }
}
```

#### 1.3.B Pengambilan Konteks Lengkap

```dart
/// Ambil konteks pengguna dari berbagai sumber
Future<UserContext> _getUserContext() async {
  
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 1: AMBIL PANTRY ITEMS DARI HIVE
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  List<String> pantryItems = [];
  
  try {
    // A. Dapatkan email user dari Supabase auth
    final userEmail = _supabase.auth.currentUser?.email ?? 'guest';
    
    // B. Construct box name dengan email (untuk multi-user)
    final boxName = 'pantry_$userEmail';
    //              = 'pantry_user@example.com'
    
    // C. Cek apakah box sudah terbuka/initialized
    if (Hive.isBoxOpen(boxName)) {
      
      // D. Dapatkan reference ke box
      final box = Hive.box<String>(boxName);
      
      // E. Iterate semua values dan extract nama bahan
      pantryItems = box.values.map((item) {
        // Item format: "Eggs|3|pcs"
        final parts = item.split('|');
        return parts[0];  // Ambil nama saja: "Eggs"
      }).toList();
      
      // Result: pantryItems = ["Eggs", "Chicken", "Rice"]
    }
    
  } catch (e) {
    debugPrint('❌ ChatbotService: Failed to get pantry - $e');
    // Fallback: empty list
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 2: AMBIL DIET & ALLERGIES DARI SHAREDPREFS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  List<String> dietPreferences = [];
  List<String> allergies = [];
  
  try {
    // A. Dapatkan SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // B. Retrieve list of all selected diet options
    final allDiets = prefs.getStringList('user_diet_preferences') ?? [];
    
    // allDiets value:
    // [
    //   'vegetarian',
    //   'gluten_free',
    //   'low_sugar',
    //   'nut_allergy',
    //   'dairy_allergy'
    // ]
    
    // C. Define which keys are allergies
    final allergyKeys = [
      'nut_allergy',
      'seafood_allergy',
      'dairy_allergy'
    ];
    
    // D. Categorize each item
    for (var diet in allDiets) {
      if (allergyKeys.contains(diet)) {
        // It's an allergy
        allergies.add(_formatDietLabel(diet));
      } else {
        // It's a diet preference
        dietPreferences.add(_formatDietLabel(diet));
      }
    }
    
    // Result:
    // dietPreferences = ['Vegetarian', 'Gluten Free', 'Low Sugar']
    // allergies = ['Alergi Kacang', 'Alergi Susu']
    
  } catch (e) {
    debugPrint('❌ ChatbotService: Failed to get diet prefs - $e');
    // Fallback: empty lists
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STEP 3: RETURN USER CONTEXT OBJECT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  return UserContext(
    pantryItems: pantryItems,              // ['Eggs', 'Chicken', 'Rice']
    dietPreferences: dietPreferences,      // ['Vegetarian', 'Gluten Free']
    allergies: allergies,                  // ['Alergi Kacang']
  );
}
```

#### 1.3.C Format Diet Labels

```dart
/// Format diet key menjadi label yang readable untuk user
String _formatDietLabel(String key) {
  switch (key) {
    // Diet Preferences
    case 'halal': return 'Halal';
    case 'vegetarian': return 'Vegetarian';
    case 'vegan': return 'Vegan';
    case 'keto': return 'Keto';
    case 'low_carb': return 'Low Carb';
    case 'gluten_free': return 'Gluten Free';
    case 'low_sugar': return 'Low Sugar (Diabetes)';
    
    // Allergies (stored in same list but identified separately)
    case 'nut_allergy': return 'Alergi Kacang';
    case 'seafood_allergy': return 'Alergi Seafood';
    case 'dairy_allergy': return 'Alergi Susu/Laktosa';
    
    // Special
    case 'no_onion': return 'Tanpa Bawang';
    
    // Default: replace underscore with space
    default: return key.replaceAll('_', ' ');
  }
}

// Contoh penggunaan:
_formatDietLabel('nut_allergy')     // → 'Alergi Kacang'
_formatDietLabel('gluten_free')    // → 'Gluten Free'
_formatDietLabel('low_sugar')      // → 'Low Sugar (Diabetes)'
```

---

## 2. DATA STRUCTURES

### UserContext Model

```dart
class UserContext {
  final List<String> pantryItems;
  final List<String> dietPreferences;
  final List<String> allergies;

  UserContext({
    required this.pantryItems,
    required this.dietPreferences,
    required this.allergies,
  });
}

// Contoh instance:
UserContext(
  pantryItems: [
    'Eggs',
    'Chicken',
    'Rice',
    'Tomato',
    'Onion',
  ],
  dietPreferences: [
    'Vegetarian',
    'Gluten Free',
    'Low Sugar',
  ],
  allergies: [
    'Alergi Kacang',
    'Alergi Susu/Laktosa',
  ],
)
```

---

## 3. HIVE: PANTRY STORAGE DETAIL

### Struktur Penyimpanan

```
Box: 'pantry_user@example.com'
Type: Map<String, String> (key → value)

┌──────────────┬────────────────────────────┐
│ Key          │ Value                      │
├──────────────┼────────────────────────────┤
│ 'item_1'     │ "Eggs|3|pcs"              │
│ 'item_2'     │ "Chicken|500|gram"        │
│ 'item_3'     │ "Rice|2|kg"               │
│ 'item_4'     │ "Tomato|1|kg"             │
│ 'item_5'     │ "Onion|250|gram"          │
│ 'item_6'     │ "Salt|200|gram"           │
│ 'item_7'     │ "Garlic|100|gram"         │
└──────────────┴────────────────────────────┘

Format: "name|quantity|unit"
         ┌────────────────┐
         │ Ingredient Info│
         ├────────────────┤
         │ name: "Eggs"   │
         │ qty: "3"       │
         │ unit: "pcs"    │
         └────────────────┘
```

### Pengambilan Data dari Hive

```dart
// Contoh Hive query flow:

// 1. Open box (biasanya sudah di-initialize saat app start)
if (!Hive.isBoxOpen('pantry_user@example.com')) {
  await Hive.openBox<String>('pantry_user@example.com');
}

// 2. Get box reference
final box = Hive.box<String>('pantry_user@example.com');

// 3. Get all values
List<String> rawItems = box.values.toList();
// Result: ["Eggs|3|pcs", "Chicken|500|gram", "Rice|2|kg", ...]

// 4. Extract names only
List<String> names = rawItems.map((item) {
  final parts = item.split('|');
  return parts[0];
}).toList();
// Result: ["Eggs", "Chicken", "Rice", ...]

// 5. Use in context
pantryItems = names;
```

---

## 4. SHAREDPREFERENCES: DIET STORAGE DETAIL

### Struktur Penyimpanan

```
Key: 'user_diet_preferences'
Type: StringList

Value: [
  'vegetarian',
  'gluten_free', 
  'low_sugar',
  'nut_allergy',
  'dairy_allergy'
]

Mapping:
┌────────────────────┬────────────────────────────┐
│ Code               │ Display Name               │
├────────────────────┼────────────────────────────┤
│ 'halal'            │ 'Halal'                    │
│ 'vegetarian'       │ 'Vegetarian'               │
│ 'vegan'            │ 'Vegan'                    │
│ 'keto'             │ 'Keto'                     │
│ 'low_carb'         │ 'Low Carb'                 │
│ 'gluten_free'      │ 'Gluten Free'              │
│ 'low_sugar'        │ 'Low Sugar (Diabetes)'     │
│ 'nut_allergy'      │ 'Alergi Kacang'            │
│ 'seafood_allergy'  │ 'Alergi Seafood'           │
│ 'dairy_allergy'    │ 'Alergi Susu/Laktosa'      │
│ 'no_onion'         │ 'Tanpa Bawang'             │
└────────────────────┴────────────────────────────┘
```

### Pengambilan Data dari SharedPreferences

```dart
// Contoh SharedPreferences query flow:

// 1. Get SharedPreferences instance
final prefs = await SharedPreferences.getInstance();

// 2. Retrieve the list (null-safe)
final allDiets = prefs.getStringList('user_diet_preferences') ?? [];
// Result: ['vegetarian', 'gluten_free', 'low_sugar', 'nut_allergy', 'dairy_allergy']

// 3. Define allergy identifiers
final allergyKeys = [
  'nut_allergy',
  'seafood_allergy',
  'dairy_allergy'
];

// 4. Separate into categories
List<String> diets = [];
List<String> allergies = [];

for (var item in allDiets) {
  if (allergyKeys.contains(item)) {
    allergies.add(formatLabel(item));
  } else {
    diets.add(formatLabel(item));
  }
}

// Result:
// diets = ['Vegetarian', 'Gluten Free', 'Low Sugar']
// allergies = ['Alergi Kacang', 'Alergi Susu']
```

---

## 5. KONTEKS DIINJEKSI KE GEMINI (PRODUCTION)

### System Prompt Dengan Konteks

Setelah konteks dikumpulkan, **Edge Function** membangun system prompt:

**File:** `supabase/functions/gemini-proxy/index.ts`

```typescript
// Edge Function menerima konteks dari client
const body: ChatbotRequest = await req.json()

const contextData = body.contextData
// {
//   pantryItems: ['Eggs', 'Chicken', 'Rice'],
//   dietPreferences: ['Vegetarian', 'Gluten Free'],
//   allergies: ['Alergi Kacang'],
//   currentRecipe: null
// }

// Build system prompt dengan konteks
const systemPrompt = buildSystemPrompt({
  userContext: body.contextData,
  ragMode: body.rag_mode,
  currentRecipe: body.contextData?.currentRecipe,
})

// Hasilnya: system prompt akan include konteks pengguna
// Contoh snippet dari generated prompt:

/*
You are Chef Cei, an AI culinary assistant...

USER CONTEXT & CONSTRAINTS:
────────────────────────────
Pantry Available:
  • Eggs
  • Chicken
  • Rice

Diet Preferences:
  • Vegetarian
  • Gluten Free

Allergies & Intolerances:
  • Alergi Kacang (Nut Allergy)

IMPORTANT RULES:
────────────────
1. Only suggest recipes using available pantry items
2. MUST respect diet preferences (Vegetarian, Gluten Free)
3. MUST NEVER include anything with nuts (severe allergy)
4. If user asks about nuts, warn them about allergy
5. Substitute ingredients if needed:
   - For vegetarian: no meat/fish substitutes
   - For gluten free: avoid wheat-based ingredients
*/
```

### Contoh Gemini Response Dengan Konteks

```
User: "Resep apa yang bisa aku buat?"

Gemini Response (DENGAN KONTEKS):
"Hai! Berdasarkan bahan-bahan di dapur Anda (Telur, 
Ayam, Nasi) dan preferensi Vegetarian + Gluten Free, 
berikut resep yang bisa Anda buat:

1. **Rice Vegetable Stir-Fry**
   ✓ Menggunakan: Rice, Eggs (untuk protein)
   ✓ Vegetarian: Yes
   ✓ Gluten Free: Yes
   ✗ Tanpa kacang (sesuai alergi Anda)
   
   Ingredients yang available:
   - Rice ✓
   - Eggs ✓
   - (Bisa tambah sayuran lain jika ada)
   
   [Resep lengkap...]

2. **Chicken Rice Bowl** 
   ✗ TIDAK bisa - Anda adalah vegetarian
   
3. **Egg Fried Rice**
   ✓ Menggunakan: Rice, Eggs
   ✓ Vegetarian: Yes
   ✓ Gluten Free: Yes
   ✓ Aman: Tanpa kacang/alergen
   
   [Resep lengkap...]

Catatan: Semua resep sudah disesuaikan dengan:
- Bahan tersedia di pantry Anda
- Preferensi Vegetarian
- Kebutuhan Gluten Free
- Alergi Kacang Anda"
```

---

## 6. ERROR HANDLING & FALLBACK

### Scenario 1: Pantry Box Tidak Initialize

```dart
// Jika box belum terbuka/tidak ada
if (!Hive.isBoxOpen(boxName)) {
  // Fallback: gunakan list kosong
  pantryItems = [];
}

// Gemini akan respond tanpa informasi pantry:
// "Tidak ada informasi bahan di pantry Anda..."
```

### Scenario 2: SharedPreferences Kosong

```dart
// Jika tidak ada diet preferences tersimpan
final allDiets = prefs.getStringList('user_diet_preferences') ?? [];
// Nilai: []

// Hasilnya: 
dietPreferences = []
allergies = []

// Gemini akan respond generic tanpa personalisasi:
// "Resep umum yang bisa dibuat..."
```

### Scenario 3: Parsing Error

```dart
try {
  pantryItems = box.values.map((item) {
    final parts = item.split('|');
    return parts[0];  // Bisa error jika format salah
  }).toList();
} catch (e) {
  // Fallback: empty list
  pantryItems = [];
  debugPrint('Error parsing pantry: $e');
}
```

---

## 7. TIMING & PERFORMANCE

```
Context Collection Timing:

T0 + 0ms    ─ _getUserContext() called
T0 + 5ms    ─ Supabase.auth.currentUser accessed
T0 + 10ms   ─ Hive box opened (if needed)
T0 + 15ms   ─ Hive values read & parsed
T0 + 20ms   ─ SharedPreferences.getInstance()
T0 + 30ms   ─ getStringList() retrieved
T0 + 40ms   ─ Format labels applied
T0 + 50ms   ─ UserContext object created
T0 + 50ms   ✓ TOTAL TIME: ~50ms

Total overhead adalah minimal (~50ms) dibanding
total request time (~1700ms keseluruhan).
```

---

## 8. MULTI-USER ISOLATION

Konteks setiap user **terisolasi** menggunakan email:

```dart
// User 1: user1@example.com
final boxName1 = 'pantry_user1@example.com'
// Pantry items hanya untuk user1

// User 2: user2@example.com  
final boxName2 = 'pantry_user2@example.com'
// Pantry items hanya untuk user2

// User 1 login → konteksnya hanya data milik user1
// User 2 login → konteksnya hanya data milik user2
// No cross-contamination
```

---

## 9. PERSISTENCE & SYNC

```
LOCAL STORAGE (Hive & SharedPrefs)
    ↓ (When user edits pantry/diet in app)
    ↓ IMMEDIATE UPDATE in local storage
    ↓
NEXT CHAT MESSAGE
    ↓ (Baca updated values saat sendMessageStream())
    ↓
KONTEKS TERBARU dikirim ke Gemini
    ↓
RESPONS sudah reflect perubahan terbaru

Contoh:
1. User tambah "Salmon" ke pantry
   → Hive immediately updated
2. User kirim chat message
   → _getUserContext() read latest Hive values
   → Salmon included dalam pantryItems
   → Gemini suggest resep dengan Salmon
```

---

## SUMMARY

| Aspek | Detail |
|-------|--------|
| **Pantry Storage** | Hive (local disk persistence) |
| **Diet/Allergy Storage** | SharedPreferences (device secure) |
| **Retrieval Method** | Synchronous (Hive), Async (SharedPrefs) |
| **Update Frequency** | On every chat message (real-time) |
| **User Isolation** | Email-based box naming |
| **Performance Overhead** | ~50ms for context collection |
| **Error Handling** | Graceful fallback to empty lists |
| **Format** | Hive: "name\|qty\|unit", SharedPrefs: String array |
| **Konteks ke Gemini** | Injected into system prompt |
| **Personalization** | Respon disesuaikan dengan user context |

Dengan cara ini, **setiap chat response dipersonalisasi** berdasarkan pantry items, preferensi diet, dan alergi user yang tersimpan lokal! 🏠📱

---

## 10. BEST PRACTICES: CONTEXT UNTUK EVALUATION vs PRODUCTION

### Untuk Production (Real Users)
✅ **AMBIL konteks dari local storage** (Hive & SharedPreferences)
- Personalisasi untuk setiap user yang unik
- Real-time updates saat user mengubah pantry/preferensi
- Consistent dengan user experience

```python
# Production scenario
for user in real_users:
    context = get_user_context_from_storage(user)  # ← Ambil dari storage
    response = chatbot.send_message(user_query, context)
```

### Untuk RAGAS Evaluation (Quality Testing)
✅ **JANGAN ambil konteks dari local storage**
- Gunakan **standardized/fixed context** untuk semua queries
- Atau gunakan **NO context** (null) untuk baseline evaluation
- Consistency penting untuk comparable MRR scores

```python
# RAGAS evaluation scenario
STANDARD_CONTEXT = {
    'pantryItems': ['Rice', 'Eggs', 'Chicken', 'Tomato'],
    'dietPreferences': ['Vegetarian'],
    'allergies': ['Nut Allergy']
}

for vignette in vignettes:
    for rag_mode in ['none', 'naive', 'advanced']:
        # ✅ GUNAKAN standardized context
        response = chatbot.send_message(
            vignette.query,
            context=STANDARD_CONTEXT,  # ← SAMA untuk semua queries!
            rag_mode=rag_mode
        )
        
        # ✅ ATAU gunakan NO context
        response = chatbot.send_message(
            vignette.query,
            context=None,  # ← BASELINE: no personalization
            rag_mode=rag_mode
        )
        
        # Calculate MRR & RAGAS metrics
        mrr = calculate_mrr(response.retrieved_docs, vignette.ground_truth_docs)
        ragas_score = evaluate_ragas(response.text, vignette.reference_answer)
```

### Kesalahan Umum (Anti-Pattern)

❌ **JANGAN pernah**:
```python
# WRONG: Variable context per query
for vignette in vignettes:
    # ❌ MISTAKE: Context from storage (different each time!)
    context = get_user_context_from_storage()  # ← BEDA setiap kali!
    response = chatbot.send_message(vignette.query, context)
    mrr = calculate_mrr(...)  # ← MRR scores not comparable!
```

Akibatnya:
- MRR scores tidak dapat dibandingkan antar rag_modes
- RAGAS evaluation results misleading
- Thesis quality compromised
- Reproducibility tidak terjamin

---

## CONCLUSION

**Konteks pengguna dalam ChefGenius** berfungsi ganda:

1. **PRODUCTION (Real Users)** 
   - Ambil dari local storage (Hive + SharedPreferences)
   - Personalisasi setiap response
   - Real-time & responsive

2. **EVALUATION (RAGAS Testing)**
   - Gunakan **fixed/standardized context** atau **no context**
   - Ensure fair & comparable metrics
   - Reproducible results untuk thesis

Dokumentasi ini menjelaskan **KEDUA scenario** agar Anda bisa mengimplementasikan dengan benar untuk konteks yang tepat! 📋✅

