# 🧪 RAGAS EVALUATION IMPLEMENTATION GUIDE

Panduan lengkap untuk menjalankan RAGAS evaluation pada chatbot ChefGenius dengan **standardized context** agar hasil fair dan reproducible.

---

## 1. OVERVIEW: RAGAS EVALUATION GOALS

### Apa yang Dievaluasi?

```
┌─────────────────────────────────────────────────────────┐
│           RAGAS QUALITY METRICS                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. ANSWER RELEVANCY (AR)                              │
│     ✓ Seberapa relevan jawaban terhadap pertanyaan?    │
│     ✓ Range: 0-1 (higher is better)                   │
│     ✓ Formula: Similarity antara q & answer keywords   │
│                                                         │
│  2. FAITHFULNESS (F)                                   │
│     ✓ Seberapa faithful jawaban terhadap context?      │
│     ✓ Range: 0-1 (higher is better)                   │
│     ✓ Formula: Fact verification vs retrieved docs    │
│                                                         │
│  3. CONTEXT RELEVANCE (CR)                             │
│     ✓ Seberapa relevant retrieved docs terhadap query? │
│     ✓ Range: 0-1 (higher is better)                   │
│     ✓ Formula: Count of relevant docs / total docs    │
│                                                         │
│  4. MRR (Mean Reciprocal Rank)                         │
│     ✓ Ranking posisi dari relevant doc yang pertama    │
│     ✓ Range: 0-1 (higher is better)                   │
│     ✓ Formula: 1 / rank_of_first_relevant_doc         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Mengapa Standardized Context Penting?

```
❌ WRONG APPROACH: Variable Context Per Query

Query 1: "Diabetes?"
  context = {pantryItems: [100 items], ...}
  mrr_1 = 0.75

Query 2: "Kalori?"
  context = {pantryItems: [5 items], ...}
  mrr_2 = 0.45

Masalah:
- mrr_1 vs mrr_2 tidak bisa dibandingkan (context beda!)
- Results biased oleh quantity pantry items
- Conclusion tentang RAG mode jadi invalid

---

✅ CORRECT APPROACH: Fixed Context For All Queries

Query 1: "Diabetes?"
  context = STANDARD_CONTEXT (fixed)
  mrr_1 = 0.75

Query 2: "Kalori?"
  context = STANDARD_CONTEXT (same as Query 1)
  mrr_2 = 0.45

Hasil:
- mrr_1 vs mrr_2 dapat dibandingkan (context SAMA!)
- Fair evaluation dari RAG quality
- Conclusion valid & reproducible
```

---

## 2. SETUP: ENVIRONMENT & DEPENDENCIES

### Python Environment Setup

```bash
# Create virtual environment
python -m venv ragas_env
source ragas_env/bin/activate  # Windows: ragas_env\Scripts\activate

# Install required packages
pip install ragas==0.1.15
pip install langchain==0.1.0
pip install google-generativeai==0.3.0
pip install pandas==2.0.0
pip install numpy==1.24.0
pip install python-dotenv==1.0.0
```

### Environment Variables (.env)

```bash
# .env file
GEMINI_API_KEY=your_gemini_api_key_here
SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_KEY=your_service_key
PYTHON_ENV=evaluation
```

### Folder Structure

```
d:\chefgenius\
├── supabase/
│   └── functions/
│       └── gemini-proxy/
│           └── index.ts
├── ragas_eval/
│   ├── __init__.py
│   ├── config.py                    # ← Configuration
│   ├── vignette_loader.py           # ← Load vignettes
│   ├── chatbot_client.py            # ← Call chatbot API
│   ├── context_provider.py          # ← STANDARDIZED context
│   ├── metrics_calculator.py        # ← Calculate RAGAS
│   ├── evaluation_runner.py         # ← Main evaluation loop
│   ├── results_analyzer.py          # ← Analyze results
│   └── main.py                      # ← Entry point
├── results/
│   ├── evaluation_results_2026-05-11.json
│   ├── mrr_scores.csv
│   ├── ragas_metrics.csv
│   └── summary_report.md
└── vignettes/
    └── vignettes_metadata.json      # 15 vignettes
```

---

## 3. STANDARDIZED CONTEXT SETUP

### Define Fixed Context

**File: `ragas_eval/context_provider.py`**

```python
"""
Context Provider for RAGAS Evaluation
Provides standardized, fixed context for all queries
"""

from typing import Dict, List, Optional

class ContextProvider:
    """
    Provides standardized context for RAGAS evaluation
    All queries use the SAME context to ensure fair comparison
    """
    
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # STANDARDIZED CONTEXT - FIXED FOR ALL EVALUATION QUERIES
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    STANDARD_PANTRY = [
        'Rice',
        'Eggs', 
        'Chicken',
        'Tomato',
        'Onion',
        'Garlic',
        'Salt',
        'Oil',
        'Spices'
    ]
    
    STANDARD_DIET_PREFERENCES = [
        'Vegetarian'
    ]
    
    STANDARD_ALLERGIES = [
        'Nut Allergy'
    ]
    
    STANDARD_CURRENT_RECIPE = None
    
    @classmethod
    def get_standard_context(cls) -> Dict[str, any]:
        """
        Returns the standardized context for evaluation
        
        Returns:
            Dict with pantryItems, dietPreferences, allergies, currentRecipe
        """
        return {
            'pantryItems': cls.STANDARD_PANTRY,
            'dietPreferences': cls.STANDARD_DIET_PREFERENCES,
            'allergies': cls.STANDARD_ALLERGIES,
            'currentRecipe': cls.STANDARD_CURRENT_RECIPE
        }
    
    @classmethod
    def get_no_context(cls) -> Dict[str, None]:
        """
        Returns empty context for baseline evaluation (none mode)
        
        Returns:
            Dict with all None values
        """
        return {
            'pantryItems': None,
            'dietPreferences': None,
            'allergies': None,
            'currentRecipe': None
        }
    
    @classmethod
    def validate_context(cls, context: Dict) -> bool:
        """
        Validate context structure
        """
        required_keys = {'pantryItems', 'dietPreferences', 'allergies', 'currentRecipe'}
        return all(key in context for key in required_keys)
    
    @classmethod
    def get_context_summary(cls) -> str:
        """
        Get human-readable summary of standard context
        """
        ctx = cls.get_standard_context()
        return f"""
STANDARD EVALUATION CONTEXT:
════════════════════════════
Pantry Items: {', '.join(ctx['pantryItems'])}
Diet Preferences: {', '.join(ctx['dietPreferences'])}
Allergies: {', '.join(ctx['allergies'])}
Current Recipe: {ctx['currentRecipe']}
        """
```

### Context Usage Philosophy

```python
# ✅ CORRECT: Use get_standard_context() untuk SEMUA queries
for vignette in vignettes:
    context = ContextProvider.get_standard_context()
    # context adalah SAMA untuk setiap vignette
    response = chatbot_client.send_message(
        query=vignette['query'],
        context=context,
        rag_mode='naive'
    )

# ✅ CORRECT: Use get_no_context() untuk baseline
for vignette in vignettes:
    context = ContextProvider.get_no_context()
    # context adalah EMPTY untuk semua vignette
    response = chatbot_client.send_message(
        query=vignette['query'],
        context=context,
        rag_mode='none'
    )

# ❌ WRONG: JANGAN ambil context dari local storage!
for vignette in vignettes:
    context = get_user_context_from_storage()  # ← JANGAN!
    response = chatbot_client.send_message(
        query=vignette['query'],
        context=context,
        rag_mode='naive'
    )
```

---

## 4. VIGNETTE LOADER

**File: `ragas_eval/vignette_loader.py`**

```python
"""
Vignette Loader for RAGAS Evaluation
Loads 15 test vignettes with ground truth data
"""

import json
from typing import List, Dict, Optional
from pathlib import Path

class VignetteLoader:
    """Load and manage vignettes for RAGAS evaluation"""
    
    def __init__(self, vignettes_path: str):
        self.vignettes_path = Path(vignettes_path)
        self.vignettes: List[Dict] = []
        self._load_vignettes()
    
    def _load_vignettes(self) -> None:
        """Load vignettes from JSON file"""
        if not self.vignettes_path.exists():
            raise FileNotFoundError(f"Vignettes file not found: {self.vignettes_path}")
        
        with open(self.vignettes_path, 'r', encoding='utf-8') as f:
            self.vignettes = json.load(f)
        
        print(f"✅ Loaded {len(self.vignettes)} vignettes")
    
    def get_vignettes(self) -> List[Dict]:
        """Get all vignettes"""
        return self.vignettes
    
    def get_vignette_by_id(self, scenario_id: str) -> Optional[Dict]:
        """Get specific vignette by scenario ID"""
        for v in self.vignettes:
            if v.get('scenario_id') == scenario_id:
                return v
        return None
    
    def validate_vignettes(self) -> bool:
        """
        Validate vignette structure
        Each vignette must have:
        - scenario_id
        - ground_truth_context_ids
        - query_text_part
        - reference_answer
        """
        required_fields = {
            'scenario_id',
            'ground_truth_context_ids',
            'query_text_part',
            'reference_answer'
        }
        
        for v in self.vignettes:
            if not all(field in v for field in required_fields):
                print(f"❌ Invalid vignette: {v.get('scenario_id', 'UNKNOWN')}")
                return False
        
        print(f"✅ All {len(self.vignettes)} vignettes are valid")
        return True
    
    def print_vignettes_summary(self) -> None:
        """Print summary of all vignettes"""
        print("\n" + "="*60)
        print("VIGNETTES SUMMARY")
        print("="*60)
        
        for v in self.vignettes:
            scenario_id = v.get('scenario_id', 'N/A')
            context_ids = v.get('ground_truth_context_ids', 'N/A')
            query = v.get('query_text_part', '')[:50] + '...'
            
            print(f"\n[{scenario_id}] {query}")
            print(f"  Ground Truth Docs: {context_ids}")

# Contoh penggunaan:
if __name__ == "__main__":
    loader = VignetteLoader('vignettes/vignettes_metadata.json')
    loader.validate_vignettes()
    loader.print_vignettes_summary()
```

---

## 5. CHATBOT CLIENT

**File: `ragas_eval/chatbot_client.py`**

```python
"""
Chatbot Client for RAGAS Evaluation
Calls the Gemini Proxy Edge Function with standardized context
"""

import json
import time
from typing import Dict, List, Optional
import httpx
from dotenv import load_dotenv
import os

load_dotenv()

class ChatbotClient:
    """Client to interact with ChefGenius chatbot API"""
    
    def __init__(self, edge_function_url: str, api_key: Optional[str] = None):
        self.edge_function_url = edge_function_url
        self.api_key = api_key or os.getenv('SUPABASE_API_KEY')
        self.client = httpx.Client(timeout=60.0)
    
    def send_message(
        self,
        query: str,
        context: Dict,
        rag_mode: str = 'naive',
        session_id: str = 'eval_session_001'
    ) -> Dict:
        """
        Send query to chatbot with standardized context
        
        Args:
            query: User query/question
            context: Standardized context (from ContextProvider)
            rag_mode: 'none', 'naive', or 'advanced'
            session_id: Session identifier
        
        Returns:
            Response dict with text, retrieved_docs, metrics
        """
        
        payload = {
            'action': 'chatbot',
            'userMessage': query,
            'contextData': context,
            'rag_mode': rag_mode,
            'session_id': session_id,
            'user_id': 'eval_agent'  # ← Indicator ini evaluation, bukan real user
        }
        
        headers = {
            'Content-Type': 'application/json'
        }
        
        if self.api_key:
            headers['Authorization'] = f'Bearer {self.api_key}'
        
        try:
            print(f"  📤 Sending to {rag_mode} mode...")
            start_time = time.time()
            
            response = self.client.post(
                self.edge_function_url,
                json=payload,
                headers=headers
            )
            
            elapsed = time.time() - start_time
            
            if response.status_code != 200:
                print(f"  ❌ Error: HTTP {response.status_code}")
                return None
            
            data = response.json()
            data['latency_ms'] = int(elapsed * 1000)
            
            print(f"  ✅ Response received in {elapsed:.2f}s")
            return data
            
        except Exception as e:
            print(f"  ❌ Exception: {str(e)}")
            return None
    
    def close(self) -> None:
        """Close HTTP client"""
        self.client.close()

# Contoh penggunaan:
if __name__ == "__main__":
    client = ChatbotClient(
        edge_function_url='https://your-project.supabase.co/functions/v1/gemini-proxy'
    )
    
    from context_provider import ContextProvider
    
    response = client.send_message(
        query="Berapa kalori nasi putih?",
        context=ContextProvider.get_standard_context(),
        rag_mode='naive'
    )
    
    print(json.dumps(response, indent=2))
    client.close()
```

---

## 6. METRICS CALCULATOR

**File: `ragas_eval/metrics_calculator.py`**

```python
"""
RAGAS Metrics Calculator
Calculates Answer Relevancy, Faithfulness, Context Relevance, MRR
"""

from typing import List, Dict
from ragas.metrics import answer_relevancy, faithfulness, context_relevance
from ragas.llm import LangChainLLMWrapper
from langchain.llms import GooglePalm
import os
from dotenv import load_dotenv

load_dotenv()

class MetricsCalculator:
    """Calculate RAGAS evaluation metrics"""
    
    def __init__(self):
        # Initialize Gemini LLM for RAGAS metrics
        gemini_api_key = os.getenv('GEMINI_API_KEY')
        self.llm = GooglePalm(google_api_key=gemini_api_key, temperature=0)
    
    def calculate_mrr(
        self,
        retrieved_docs: List[Dict],
        ground_truth_doc_ids: List[str]
    ) -> float:
        """
        Calculate Mean Reciprocal Rank (MRR)
        
        Args:
            retrieved_docs: List of retrieved documents
            ground_truth_doc_ids: List of ground truth document IDs
        
        Returns:
            MRR score (0-1, higher is better)
        """
        
        if not ground_truth_doc_ids:
            return 0.0
        
        # Find rank of first relevant document
        for rank, doc in enumerate(retrieved_docs, 1):
            doc_id = doc.get('id') or doc.get('source')
            if doc_id in ground_truth_doc_ids:
                mrr = 1.0 / rank
                return mrr
        
        # No relevant document found
        return 0.0
    
    def calculate_answer_relevancy(
        self,
        query: str,
        answer: str
    ) -> float:
        """
        Calculate Answer Relevancy
        Measures how relevant the answer is to the question
        
        Range: 0-1 (higher is better)
        """
        # Using RAGAS built-in metric
        # Implementation using Gemini LLM
        score = answer_relevancy.score(
            answer=answer,
            question=query
        )
        return score
    
    def calculate_faithfulness(
        self,
        answer: str,
        context: str
    ) -> float:
        """
        Calculate Faithfulness
        Measures how faithful the answer is to the retrieved context
        
        Range: 0-1 (higher is better)
        """
        score = faithfulness.score(
            answer=answer,
            context=context
        )
        return score
    
    def calculate_context_relevance(
        self,
        query: str,
        context_texts: List[str]
    ) -> float:
        """
        Calculate Context Relevance
        Measures how relevant the retrieved context is to the query
        
        Range: 0-1 (higher is better)
        """
        score = context_relevance.score(
            question=query,
            context=context_texts
        )
        return score
    
    def calculate_all_metrics(
        self,
        query: str,
        answer: str,
        retrieved_docs: List[Dict],
        ground_truth_doc_ids: List[str]
    ) -> Dict[str, float]:
        """
        Calculate all RAGAS metrics
        
        Returns dict with AR, F, CR, MRR scores
        """
        
        # Extract text from documents
        context_texts = [doc.get('content', '') for doc in retrieved_docs]
        context_str = '\n\n'.join(context_texts)
        
        return {
            'answer_relevancy': self.calculate_answer_relevancy(query, answer),
            'faithfulness': self.calculate_faithfulness(answer, context_str),
            'context_relevance': self.calculate_context_relevance(query, context_texts),
            'mrr': self.calculate_mrr(retrieved_docs, ground_truth_doc_ids)
        }

# Contoh penggunaan:
if __name__ == "__main__":
    calculator = MetricsCalculator()
    
    metrics = calculator.calculate_all_metrics(
        query="Berapa kalori nasi putih?",
        answer="Nasi putih mengandung sekitar 130 kalori per 100 gram.",
        retrieved_docs=[
            {'id': 'doc1', 'content': '...', 'source': 'TKPI 2020.pdf'},
            {'id': 'doc2', 'content': '...', 'source': 'ADA 2026.pdf'}
        ],
        ground_truth_doc_ids=['TKPI 2020.pdf']
    )
    
    print(f"Answer Relevancy: {metrics['answer_relevancy']:.3f}")
    print(f"Faithfulness: {metrics['faithfulness']:.3f}")
    print(f"Context Relevance: {metrics['context_relevance']:.3f}")
    print(f"MRR: {metrics['mrr']:.3f}")
```

---

## 7. EVALUATION RUNNER

**File: `ragas_eval/evaluation_runner.py`**

```python
"""
Evaluation Runner
Main loop untuk menjalankan evaluasi pada semua vignettes dan RAG modes
"""

import json
from typing import List, Dict
from datetime import datetime
from pathlib import Path

from vignette_loader import VignetteLoader
from chatbot_client import ChatbotClient
from context_provider import ContextProvider
from metrics_calculator import MetricsCalculator

class EvaluationRunner:
    """Run RAGAS evaluation on all vignettes and RAG modes"""
    
    RAG_MODES = ['none', 'naive', 'advanced']
    
    def __init__(
        self,
        vignettes_path: str,
        edge_function_url: str,
        results_dir: str = 'results'
    ):
        self.vignettes_loader = VignetteLoader(vignettes_path)
        self.chatbot_client = ChatbotClient(edge_function_url)
        self.metrics_calculator = MetricsCalculator()
        self.results_dir = Path(results_dir)
        self.results_dir.mkdir(exist_ok=True)
        
        self.results = []
        self.context_summary = ContextProvider.get_context_summary()
    
    def run_full_evaluation(self) -> Dict:
        """
        Run complete evaluation:
        - Setiap vignette
        - Setiap RAG mode
        - Calculate semua metrics
        - Save results
        """
        
        print("\n" + "="*70)
        print("STARTING RAGAS EVALUATION")
        print("="*70)
        
        print(self.context_summary)
        print("\nRunning evaluation on all vignettes...")
        print(f"Total vignettes: {len(self.vignettes_loader.get_vignettes())}")
        print(f"RAG modes: {', '.join(self.RAG_MODES)}")
        print(f"Total runs: {len(self.vignettes_loader.get_vignettes()) * len(self.RAG_MODES)}")
        
        # Get standard context
        standard_context = ContextProvider.get_standard_context()
        
        # Iterate vignettes
        for idx, vignette in enumerate(self.vignettes_loader.get_vignettes(), 1):
            scenario_id = vignette['scenario_id']
            query = vignette['query_text_part']
            ground_truth_docs = vignette['ground_truth_context_ids']
            reference_answer = vignette['reference_answer']
            
            print(f"\n[{idx}] {scenario_id}: {query[:60]}...")
            
            # Iterate RAG modes
            for rag_mode in self.RAG_MODES:
                print(f"\n  Testing {rag_mode.upper()} mode...")
                
                # Get appropriate context
                if rag_mode == 'none':
                    context = ContextProvider.get_no_context()
                else:
                    context = standard_context
                
                # Send message
                response = self.chatbot_client.send_message(
                    query=query,
                    context=context,
                    rag_mode=rag_mode,
                    session_id=f"eval_{scenario_id}_{rag_mode}"
                )
                
                if response is None:
                    print(f"  ❌ Failed to get response")
                    continue
                
                # Extract data
                answer_text = response.get('response_text', '')
                retrieved_docs = response.get('retrieved_results', [])
                
                # Calculate metrics
                metrics = self.metrics_calculator.calculate_all_metrics(
                    query=query,
                    answer=answer_text,
                    retrieved_docs=retrieved_docs,
                    ground_truth_doc_ids=ground_truth_docs.split(',')
                )
                
                # Save result
                result = {
                    'scenario_id': scenario_id,
                    'rag_mode': rag_mode,
                    'query': query,
                    'ground_truth_docs': ground_truth_docs,
                    'answer': answer_text,
                    'retrieved_count': len(retrieved_docs),
                    'metrics': metrics,
                    'timestamp': datetime.now().isoformat()
                }
                self.results.append(result)
                
                # Print metrics
                print(f"    ✓ Answer Relevancy: {metrics['answer_relevancy']:.3f}")
                print(f"    ✓ Faithfulness: {metrics['faithfulness']:.3f}")
                print(f"    ✓ Context Relevance: {metrics['context_relevance']:.3f}")
                print(f"    ✓ MRR: {metrics['mrr']:.3f}")
        
        print("\n" + "="*70)
        print("EVALUATION COMPLETE")
        print("="*70)
        
        return self._save_results()
    
    def _save_results(self) -> Dict:
        """Save evaluation results to file"""
        timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        
        # Save raw results
        results_file = self.results_dir / f"evaluation_results_{timestamp}.json"
        with open(results_file, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        print(f"\n✅ Results saved: {results_file}")
        
        # Generate summary
        summary = self._generate_summary()
        summary_file = self.results_dir / f"summary_{timestamp}.md"
        with open(summary_file, 'w', encoding='utf-8') as f:
            f.write(summary)
        print(f"✅ Summary saved: {summary_file}")
        
        return {
            'results_file': str(results_file),
            'summary_file': str(summary_file),
            'total_runs': len(self.results)
        }
    
    def _generate_summary(self) -> str:
        """Generate evaluation summary report"""
        
        # Calculate aggregated metrics by RAG mode
        metrics_by_mode = {}
        
        for result in self.results:
            mode = result['rag_mode']
            if mode not in metrics_by_mode:
                metrics_by_mode[mode] = {
                    'ar': [], 'f': [], 'cr': [], 'mrr': []
                }
            
            m = result['metrics']
            metrics_by_mode[mode]['ar'].append(m['answer_relevancy'])
            metrics_by_mode[mode]['f'].append(m['faithfulness'])
            metrics_by_mode[mode]['cr'].append(m['context_relevance'])
            metrics_by_mode[mode]['mrr'].append(m['mrr'])
        
        # Generate report
        report = f"""# RAGAS Evaluation Report
Generated: {datetime.now().isoformat()}

## Evaluation Setup
{self.context_summary}

## Results Summary

| RAG Mode | Avg AR | Avg F | Avg CR | Avg MRR |
|----------|--------|-------|--------|---------|
"""
        
        for mode in self.RAG_MODES:
            if mode in metrics_by_mode:
                m = metrics_by_mode[mode]
                avg_ar = sum(m['ar']) / len(m['ar']) if m['ar'] else 0
                avg_f = sum(m['f']) / len(m['f']) if m['f'] else 0
                avg_cr = sum(m['cr']) / len(m['cr']) if m['cr'] else 0
                avg_mrr = sum(m['mrr']) / len(m['mrr']) if m['mrr'] else 0
                
                report += f"| {mode.upper():12} | {avg_ar:.3f}  | {avg_f:.3f} | {avg_cr:.3f} | {avg_mrr:.3f} |\n"
        
        report += f"""

## Total Evaluation Runs: {len(self.results)}

## Key Findings

- Best RAG mode for Answer Relevancy: {self._find_best_mode('answer_relevancy')}
- Best RAG mode for Faithfulness: {self._find_best_mode('faithfulness')}
- Best RAG mode for Context Relevance: {self._find_best_mode('context_relevance')}
- Best RAG mode for MRR: {self._find_best_mode('mrr')}

## Notes

- All queries evaluated with STANDARDIZED context from ContextProvider
- Context is FIXED for all vignettes to ensure fair comparison
- This ensures reproducible and comparable evaluation results
"""
        
        return report
    
    def _find_best_mode(self, metric_name: str) -> str:
        """Find RAG mode with best metric score"""
        
        best_mode = None
        best_score = -1
        
        for result in self.results:
            score = result['metrics'].get(metric_name, 0)
            if score > best_score:
                best_score = score
                best_mode = result['rag_mode']
        
        return best_mode or 'N/A'

# Contoh penggunaan:
if __name__ == "__main__":
    runner = EvaluationRunner(
        vignettes_path='vignettes/vignettes_metadata.json',
        edge_function_url='https://your-project.supabase.co/functions/v1/gemini-proxy',
        results_dir='results'
    )
    
    summary = runner.run_full_evaluation()
    print(json.dumps(summary, indent=2))
```

---

## 8. MAIN ENTRY POINT

**File: `ragas_eval/main.py`**

```python
"""
Main entry point untuk RAGAS Evaluation
"""

import os
from dotenv import load_dotenv
from evaluation_runner import EvaluationRunner

load_dotenv()

def main():
    """Run full evaluation"""
    
    # Configuration
    VIGNETTES_PATH = 'vignettes/vignettes_metadata.json'
    EDGE_FUNCTION_URL = os.getenv(
        'EDGE_FUNCTION_URL',
        'https://your-project.supabase.co/functions/v1/gemini-proxy'
    )
    RESULTS_DIR = 'results'
    
    # Run evaluation
    runner = EvaluationRunner(
        vignettes_path=VIGNETTES_PATH,
        edge_function_url=EDGE_FUNCTION_URL,
        results_dir=RESULTS_DIR
    )
    
    summary = runner.run_full_evaluation()
    
    print("\n✅ Evaluation completed successfully!")
    print(f"Results saved to: {summary['results_file']}")

if __name__ == "__main__":
    main()
```

### Jalankan Evaluation

```bash
# Activate environment
source ragas_env/bin/activate

# Set environment variables
export EDGE_FUNCTION_URL="https://your-project.supabase.co/functions/v1/gemini-proxy"
export GEMINI_API_KEY="your_api_key"

# Run evaluation
python ragas_eval/main.py
```

---

## 9. EXPECTED OUTPUT

### Console Output

```
======================================================================
STARTING RAGAS EVALUATION
======================================================================

STANDARD EVALUATION CONTEXT:
════════════════════════════
Pantry Items: Rice, Eggs, Chicken, Tomato, Onion, Garlic, Salt, Oil, Spices
Diet Preferences: Vegetarian
Allergies: Nut Allergy
Current Recipe: None

Running evaluation on all vignettes...
Total vignettes: 15
RAG modes: none, naive, advanced
Total runs: 45

[1] V01: Untuk penyandang diabetes yang tubuhnya...

  Testing NONE mode...
    ✓ Answer Relevancy: 0.821
    ✓ Faithfulness: 0.756
    ✓ Context Relevance: 0.000
    ✓ MRR: 0.000

  Testing NAIVE mode...
    ✓ Answer Relevancy: 0.845
    ✓ Faithfulness: 0.812
    ✓ Context Relevance: 0.889
    ✓ MRR: 0.500

  Testing ADVANCED mode...
    ✓ Answer Relevancy: 0.867
    ✓ Faithfulness: 0.834
    ✓ Context Relevance: 0.945
    ✓ MRR: 1.000

[2] V02: Kalau saya mengurangi proporsi sumber za...
  ...

======================================================================
EVALUATION COMPLETE
======================================================================

✅ Results saved: results/evaluation_results_2026-05-11_14-30-45.json
✅ Summary saved: results/summary_2026-05-11_14-30-45.md
```

### Results JSON Structure

```json
{
  "scenario_id": "V01",
  "rag_mode": "naive",
  "query": "Untuk penyandang diabetes yang tubuhnya...",
  "ground_truth_docs": "Perkeni Dewasa 2024.pdf",
  "answer": "Kebutuhan kalori harian untuk penyandang DM yang gemuk...",
  "retrieved_count": 3,
  "metrics": {
    "answer_relevancy": 0.845,
    "faithfulness": 0.812,
    "context_relevance": 0.889,
    "mrr": 0.500
  },
  "timestamp": "2026-05-11T14:30:45.123456"
}
```

### Summary Report

```markdown
# RAGAS Evaluation Report
Generated: 2026-05-11T14:30:45.123456

## Evaluation Setup
STANDARD EVALUATION CONTEXT:
Pantry Items: Rice, Eggs, Chicken, Tomato, Onion, Garlic, Salt, Oil, Spices
Diet Preferences: Vegetarian
Allergies: Nut Allergy

## Results Summary

| RAG Mode | Avg AR | Avg F | Avg CR | Avg MRR |
|----------|--------|-------|--------|---------|
| NONE     | 0.823  | 0.756 | 0.000  | 0.000   |
| NAIVE    | 0.851  | 0.802 | 0.778  | 0.512   |
| ADVANCED | 0.876  | 0.834 | 0.912  | 0.789   |

## Total Evaluation Runs: 45

## Key Findings

- Best RAG mode for Answer Relevancy: advanced (0.876)
- Best RAG mode for Faithfulness: advanced (0.834)
- Best RAG mode for Context Relevance: advanced (0.912)
- Best RAG mode for MRR: advanced (0.789)

## Notes

- All queries evaluated with STANDARDIZED context from ContextProvider
- Context is FIXED for all vignettes to ensure fair comparison
- This ensures reproducible and comparable evaluation results
```

---

## 10. BEST PRACTICES & CHECKLIST

### ✅ Pre-Evaluation Checklist

- [ ] Vignettes JSON loaded & validated (15 vignettes)
- [ ] Ground truth documents specified for each vignette
- [ ] Standardized context defined in ContextProvider
- [ ] Edge Function URL configured & accessible
- [ ] RAGAS library installed & working
- [ ] Gemini API key configured
- [ ] Results directory created
- [ ] Environment variables set

### ✅ During Evaluation

- [ ] Monitor console output for errors
- [ ] Check latency for each request (~1500-2000ms expected)
- [ ] Verify metrics are being calculated
- [ ] Ensure context is SAME for all vignettes in same rag_mode

### ✅ Post-Evaluation

- [ ] Results JSON generated
- [ ] Summary report generated
- [ ] Metrics aggregated by RAG mode
- [ ] Results reviewed for anomalies
- [ ] Commit results to repository
- [ ] Document findings

### ⚠️ Common Pitfalls to Avoid

```
❌ Using variable context per query
   → Results will NOT be comparable

❌ Mixing RAGAS evaluation with production context
   → Biases evaluation metrics

❌ Not validating vignettes before evaluation
   → May get incomplete/invalid results

❌ Running evaluation without standardized setup
   → Results not reproducible

✅ Always use ContextProvider.get_standard_context()
✅ Always validate vignettes first
✅ Always save & document results
✅ Always use same context across evaluation runs
```

---

## CONCLUSION

Dengan implementasi RAGAS evaluation yang benar:

1. ✅ **Standardized Context** - Semua queries dievaluasi dengan konteks yang SAMA
2. ✅ **Fair Comparison** - MRR scores antar rag_modes dapat dibandingkan
3. ✅ **Reproducible** - Hasil dapat direproduksi kapan saja
4. ✅ **Valid Thesis** - Quality metrics yang reported akurat & trustworthy

Jangan lupa untuk **SELALU gunakan fixed context dari ContextProvider**, bukan ambil dari local storage saat evaluation! 🧪📊
