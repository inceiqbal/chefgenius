# ChefGenius Chatbot LLMOps - Deployment Guide

## Overview

This guide covers the deployment of the enhanced `gemini-proxy` Edge Function with LLMOps features including:
- Prompt versioning & SHA-256 hashing
- Structured telemetry logging
- Safety post-processing
- Human-in-the-loop review queue

---

## Prerequisites

- Supabase project (Free tier or above)
- Supabase CLI installed (`npm install -g supabase`)
- Access to Supabase Dashboard
- Google Gemini API key(s)

---

## Step 1: Database Migration

Run the SQL DDL in Supabase SQL Editor:

1. Open Supabase Dashboard → SQL Editor
2. Create new query
3. Copy contents from `supabase/migrations/chatbot_telemetry.sql`
4. Execute the query

**Verification:**
```sql
-- Check tables created
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN ('chatbot_telemetry', 'review_queue');

-- Check extension
SELECT * FROM pg_extension WHERE extname = 'pgcrypto';
```

---

## Step 2: Environment Variables

Set these secrets in Supabase Dashboard → Edge Functions → Secrets:

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Auto | Injected automatically |
| `SUPABASE_ANON_KEY` | Auto | Injected automatically |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes | For telemetry writes (Dashboard → Settings → API → service_role) |
| `GEMINI_KEYS` | Yes | Comma-separated API keys for rotation |
| `STORAGE_BUCKET_NAME` | No | Bucket name for response storage (optional) |

**Example command to set secrets:**
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
supabase secrets set GEMINI_KEYS=key1,key2,key3
```

---

## Step 3: Deploy Edge Function

```bash
cd supabase/functions
supabase functions deploy gemini-proxy
```

---

## Step 4: Local Testing

### Using curl:

```bash
# Get access token first (replace with your test credentials)
ACCESS_TOKEN=$(curl -s -X POST 'https://YOUR_PROJECT.supabase.co/auth/v1/token?grant_type=password' \
  -H 'Content-Type: application/json' \
  -H 'apikey: YOUR_ANON_KEY' \
  -d '{"email":"test@example.com","password":"testpassword"}' | jq -r '.access_token')

# Test chatbot endpoint
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/gemini-proxy' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'apikey: YOUR_ANON_KEY' \
  -d '{
    "action": "chatbot",
    "session_id": "test-session-001",
    "app_version": "1.0.0",
    "userMessage": "Apa sumber protein terbaik untuk vegetarian?",
    "contextData": {
      "pantryItems": ["tahu", "tempe", "bayam"],
      "dietPreferences": ["vegetarian"],
      "allergies": []
    },
    "max_tokens": 1024
  }'
```

### Expected Response:

```json
{
  "run_id": "550e8400-e29b-41d4-a716-446655440000",
  "result": "Halo! Untuk sumber protein vegetarian...",
  "safety_flag": false,
  "safety_reasons": []
}
```

---

## Step 5: Verify Telemetry

Check telemetry in Supabase:

```sql
SELECT run_id, prompt_hash, latency_ms, safety_flag, token_usage 
FROM chatbot_telemetry 
ORDER BY timestamp DESC 
LIMIT 10;
```

---

## Step 6: Running E2E Tests

### Prerequisites:
```bash
cd supabase/functions/gemini-proxy/tests
npm init -y
npm install typescript ts-node @types/node
```

### Create .env file:
```env
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=testpassword
OUTPUT_FILE=telemetry_results.csv
```

### Run tests:
```bash
npx ts-node e2e_runner.ts
```

Expected output: `telemetry_results.csv` with 45 rows (15 vignettes × 3 runs)

---

## Step 7: Load Testing (Optional)

### Install k6:
```bash
# macOS
brew install k6

# Windows (chocolatey)
choco install k6

# Linux
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

### Run load tests:
```bash
# Get access token first
ACCESS_TOKEN="your_access_token"

# Baseline (100 VUs)
k6 run --env SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
       --env SUPABASE_ANON_KEY=your_anon_key \
       --env TEST_ACCESS_TOKEN=$ACCESS_TOKEN \
       --env SCENARIO=baseline \
       load_test.js

# Moderate (250 VUs)
k6 run --env SCENARIO=moderate load_test.js

# Stress (500 VUs)
k6 run --env SCENARIO=stress load_test.js
```

---

## Troubleshooting

### Issue: "SUPABASE_SERVICE_ROLE_KEY not set"
**Solution:** Set the secret in Supabase Dashboard → Edge Functions → Secrets

### Issue: "gen_random_uuid() does not exist"
**Solution:** Run `CREATE EXTENSION IF NOT EXISTS "pgcrypto";` in SQL Editor

### Issue: Telemetry not being saved
**Solution:** Check that:
1. Service role key is set correctly
2. RLS is disabled (for development)
3. Check Edge Function logs in Dashboard

### Issue: High latency
**Solution:** 
1. Reduce `max_tokens` to 512-1024
2. Check Gemini API rate limits
3. Enable multiple API keys for rotation

---

## Production Checklist

- [ ] Set production API keys
- [ ] Enable RLS on telemetry tables (see SQL comments)
- [ ] Configure storage bucket for response archiving
- [ ] Set up monitoring alerts
- [ ] Review and adjust safety rules
- [ ] Test all vignette scenarios
- [ ] Run load test to establish baselines

---

## Files Reference

| File | Description |
|------|-------------|
| `index.ts` | Main Edge Function with LLMOps features |
| `chatbot_telemetry.sql` | Database schema for telemetry & review queue |
| `tests/vignettes.json` | 15 gold-standard test cases |
| `tests/e2e_runner.ts` | E2E test runner (Node.js/TypeScript) |
| `tests/load_test.js` | k6 load test script |

---

## Support

For issues with this implementation, check:
1. Edge Function logs in Supabase Dashboard
2. Database query results for telemetry
3. k6 output for load test issues
