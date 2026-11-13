# 🧪 CHATBOT MODIFICATIONS FOR RAGAS EVALUATION

Dokumentasi perubahan yang dilakukan pada ChatbotService untuk mendukung RAGAS evaluation dengan standardized context.

---

## SUMMARY: What Changed?

✅ **Added Evaluation Mode** - Flag untuk membedakan evaluation vs production  
✅ **Standardized Context Support** - Gunakan fixed context untuk fair comparison  
✅ **Telemetry Tracking** - Track yang ini evaluation query (untuk logging)  
✅ **Easy Toggle** - Simple methods to enable/disable evaluation mode  

---

## FILES MODIFIED

### 1. `lib/app/services/chatbot_service.dart`

#### Added Fields
```dart
// RAGAS EVALUATION MODE
bool _isEvaluationMode = false;
UserContext? _standardizedContext;
```

#### Added Methods
```dart
/// Enable evaluation mode dengan standardized context
void enableEvaluationMode(UserContext standardizedContext)

/// Disable evaluation mode
void disableEvaluationMode()

/// Getter untuk check apakah sedang evaluation
bool get isEvaluationMode
```

#### Updated Methods
```dart
// sendMessageStream() - now checks evaluation mode
if (_isEvaluationMode && _standardizedContext != null) {
  context = _standardizedContext!;  // Use fixed context
  debugPrint('🧪 [EVAL] Using standardized context');
} else {
  context = await _getUserContext();  // Use user-specific context
  debugPrint('📱 [PROD] Using user-specific context');
}

// sendMessage() - same logic applied
```

---

### 2. `lib/app/services/gemini_proxy_service.dart`

#### Updated Method Signature
```dart
Future<String?> sendChatMessage({
  // ... existing parameters ...
  String ragMode = 'naive',
  bool isEvaluation = false,  // ← NEW
}) async {
  final result = await _callProxy('chatbot', {
    // ... existing fields ...
    'is_evaluation': isEvaluation,  // ← Pass to Edge Function
  });
}
```

---

### 3. `lib/app/services/evaluation_context_provider.dart` (NEW FILE)

Simple provider untuk standardized context:

```dart
class EvaluationContextProvider {
  static const List<String> STANDARD_PANTRY = [
    'Rice', 'Eggs', 'Chicken', 'Tomato', 'Onion', 'Garlic', 'Salt', 'Oil', 'Spices'
  ];
  
  static const List<String> STANDARD_DIET_PREFERENCES = ['Vegetarian'];
  static const List<String> STANDARD_ALLERGIES = ['Nut Allergy'];
  
  static UserContext getStandardContext() { ... }
  static UserContext getNoContext() { ... }
  static String getContextSummary() { ... }
}
```

---

## HOW TO USE FOR EVALUATION

### Basic Usage

```dart
import 'package:chefgenius/app/services/evaluation_context_provider.dart';

// 1. Initialize chatbot
final chatbot = ChatbotService();

// 2. Get standardized context
final evalContext = EvaluationContextProvider.getStandardContext();

// 3. Enable evaluation mode
chatbot.enableEvaluationMode(evalContext);

print(EvaluationContextProvider.getContextSummary());

// 4. Run evaluation queries
for (var vignette in vignettes) {
  final response = await chatbot.sendMessage(vignette.query);
  
  // Process response for RAGAS metrics
  final mrr = calculateMRR(response.retrievedDocs, vignette.groundTruthDocs);
  final answerRelevancy = calculateAnswerRelevancy(response.text, vignette.query);
}

// 5. Disable evaluation when done
chatbot.disableEvaluationMode();
```

### Advanced: Using Different Contexts

```dart
// Use no context for baseline
chatbot.enableEvaluationMode(
  EvaluationContextProvider.getNoContext()
);

// Run rag_mode='none' evaluation

// Then switch to fixed context
chatbot.enableEvaluationMode(
  EvaluationContextProvider.getStandardContext()
);

// Run rag_mode='naive' and 'advanced' evaluation
```

---

## WHAT THIS ACHIEVES

### ✅ Fair Evaluation

```
BEFORE (WRONG):
- Query 1: context from user A's storage
- Query 2: context from user B's storage
- → MRR scores NOT comparable!

AFTER (CORRECT):
- Query 1: standardized context
- Query 2: standardized context (SAME as Query 1)
- → MRR scores ARE comparable!
```

### ✅ Production Unaffected

- When `enableEvaluationMode()` is NOT called, system works as before
- Real users still get personalized context from local storage
- Zero impact on production functionality

### ✅ Reproducible Results

- Same context for all evaluation runs
- Results can be reproduced anytime
- Easy to verify thesis findings

### ✅ Clear Separation

```dart
if (_isEvaluationMode) {
  // Testing: use standardized context
} else {
  // Production: use user-specific context
}
```

---

## HOW EDGE FUNCTION USES THIS

Edge Function (Supabase) receives:

```typescript
const body: ChatbotRequest = await req.json();

// Check if this is evaluation
const isEvaluation = body.is_evaluation || false;
const userId = body.user_id || 'unknown';

if (isEvaluation) {
  // Log as evaluation query
  // Track metrics differently
  // May skip certain personalization
} else {
  // Log as normal production query
}
```

Example telemetry tracking:

```json
{
  "run_id": "eval_V01_naive_2026-05-11",
  "user_id": "eval_agent",
  "is_evaluation": true,
  "rag_mode": "naive",
  "context_source": "standardized",
  "timestamp": "2026-05-11T14:30:45Z"
}
```

---

## CONSOLE OUTPUT DURING EVALUATION

```
🧪 ChatbotService: EVALUATION MODE ENABLED
   Pantry: 9 items
   Diet Prefs: 1
   Allergies: 1

Query 1: "Berapa kalori?"
🧪 [EVAL] Using standardized context
📤 Sending to naive mode...
✅ Response received in 1.23s

Query 2: "Kalori nasi putih?"
🧪 [EVAL] Using standardized context
📤 Sending to naive mode...
✅ Response received in 1.45s

✅ ChatbotService: Evaluation mode DISABLED - Back to production
```

---

## MIGRATION GUIDE FOR THESIS

If you're using this for thesis evaluation:

### Step 1: Update Your Code

```dart
// Old way (production)
final response = await chatbot.sendMessage(query);

// New way (evaluation)
chatbot.enableEvaluationMode(evalContext);
final response = await chatbot.sendMessage(query);
chatbot.disableEvaluationMode();
```

### Step 2: Run Evaluation

```dart
// For each rag_mode
for (var ragMode in ['none', 'naive', 'advanced']) {
  chatbot.ragMode = ragMode;
  
  // Use evaluation context
  chatbot.enableEvaluationMode(evalContext);
  
  // Run all 15 vignettes
  for (var vignette in vignettes) {
    var response = await chatbot.sendMessage(vignette.query);
    // Calculate metrics
  }
  
  chatbot.disableEvaluationMode();
}
```

### Step 3: Verify Results

```dart
// Check that all queries used same context
assert(chatbot.isEvaluationMode == false);  // Should be OFF now

// Results should show:
// - Same context for all queries ✅
// - Fair comparison between rag_modes ✅
// - Reproducible MRR scores ✅
```

---

## BENEFITS

| Aspek | Before | After |
|-------|--------|-------|
| **Context per Query** | Different | Same (standardized) |
| **MRR Comparison** | ❌ Not fair | ✅ Fair |
| **Reproducibility** | ❌ Variable | ✅ Consistent |
| **Thesis Quality** | ❌ Questionable | ✅ Solid |
| **Code Complexity** | Simple | Simple (still!) |
| **Production Impact** | N/A | None (backward compatible) |

---

## TESTING YOUR CHANGES

```dart
void testEvaluationMode() {
  final chatbot = ChatbotService();
  
  // Check default state
  expect(chatbot.isEvaluationMode, false);
  
  // Enable evaluation
  final evalContext = EvaluationContextProvider.getStandardContext();
  chatbot.enableEvaluationMode(evalContext);
  expect(chatbot.isEvaluationMode, true);
  
  // Run a query
  final response = await chatbot.sendMessage("Test query?");
  expect(response, isNotNull);
  
  // Disable evaluation
  chatbot.disableEvaluationMode();
  expect(chatbot.isEvaluationMode, false);
}
```

---

## SUMMARY

✅ **Evaluation-ready** - Easy to switch between evaluation and production modes  
✅ **Standardized** - All evaluation queries use same context  
✅ **Fair** - Comparable results between RAG modes  
✅ **Simple** - Just call `enableEvaluationMode()` and `disableEvaluationMode()`  
✅ **Backward Compatible** - Production code unchanged  

Chatbot Anda sudah siap untuk RAGAS evaluation yang proper! 🧪✨
