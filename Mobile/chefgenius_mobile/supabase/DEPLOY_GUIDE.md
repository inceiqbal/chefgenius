# 🔔 Panduan Deploy Push Notification (Tanpa CLI)

Karena Supabase CLI butuh Node.js v20+, kita deploy lewat **Dashboard**.

---

## Langkah 1: Enable pg_net Extension

1. Buka **Supabase Dashboard** → **Database** → **Extensions**
2. Cari `pg_net`
3. Klik toggle untuk **Enable**

---

## Langkah 2: Deploy Edge Function via Dashboard

1. Buka **Supabase Dashboard** → **Edge Functions**
2. Klik **"Create a new function"**
3. Nama function: `send-push-notification`
4. Copy-paste code dari file: `supabase/functions/send-push-notification/index.ts`
5. Klik **Deploy**

---

## Langkah 3: Set Secrets

Di **Supabase Dashboard** → **Edge Functions** → **Secrets**:

Tambahkan 3 secrets berikut:

| Name | Value |
|------|-------|
| `FCM_PROJECT_ID` | `chefgenius-c80a8` |
| `FCM_CLIENT_EMAIL` | `firebase-adminsdk-fbsvc@chefgenius-c80a8.iam.gserviceaccount.com` |
| `FCM_PRIVATE_KEY` | (copy seluruh private key termasuk BEGIN dan END) |

---

## Langkah 4: Jalankan SQL Trigger

1. Buka **Supabase Dashboard** → **SQL Editor**
2. Copy-paste SQL di bawah ini:

```sql
-- Buat function untuk kirim push notification
CREATE OR REPLACE FUNCTION notify_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  actor_username TEXT;
  notification_title TEXT;
  edge_function_url TEXT;
BEGIN
  -- Skip jika user mengirim notifikasi ke diri sendiri
  IF NEW.user_id = NEW.actor_id THEN
    RETURN NEW;
  END IF;

  -- Dapatkan username actor
  SELECT username INTO actor_username
  FROM profiles
  WHERE id = NEW.actor_id;
  
  notification_title := COALESCE(actor_username, 'Seseorang');

  -- URL Edge Function
  edge_function_url := 'https://zfiyfhmsuhitytsuioml.supabase.co/functions/v1/send-push-notification';

  -- Panggil Edge Function
  PERFORM
    net.http_post(
      url := edge_function_url,
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpmaXlmaG1zdWhpdHl0c3Vpb21sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDY5OTI1NSwiZXhwIjoyMDc2Mjc1MjU1fQ.lbQTZQYsGOqNQvIjDTbpHfYgOqyTQkYNjhXeZ2MkJrY"}'::jsonb,
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notification_title,
        'body', NEW.message,
        'data', jsonb_build_object(
          'type', NEW.type,
          'related_id', NEW.related_id
        )
      )
    );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Push notification error: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Buat trigger
DROP TRIGGER IF EXISTS on_notification_insert ON notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_notification();
```

3. Klik **Run**

---

## Test Push Notification

1. **Tutup app** ChefGenius dari HP (kill dari recent apps)
2. Dari device lain, **like postingan** user pertama
3. **Notifikasi harus muncul** di notification bar HP user pertama! 🔔

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| Function error | Cek log di Dashboard → Edge Functions → Logs |
| pg_net error | Pastikan extension pg_net sudah enabled |
| Token tidak tersimpan | Pastikan user sudah login ulang di app |
