-- ==============================================
-- SQL untuk Setup Push Notification Trigger
-- Jalankan di Supabase SQL Editor
-- ==============================================

-- 1. Buat function yang akan dipanggil trigger
CREATE OR REPLACE FUNCTION notify_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  actor_username TEXT;
  notification_title TEXT;
BEGIN
  -- Skip jika user mengirim notifikasi ke diri sendiri
  IF NEW.user_id = NEW.actor_id THEN
    RETURN NEW;
  END IF;

  -- Dapatkan username actor
  SELECT username INTO actor_username
  FROM profiles
  WHERE id = NEW.actor_id;
  
  -- Set title berdasarkan actor
  notification_title := COALESCE(actor_username, 'Seseorang');

  -- Panggil Edge Function untuk kirim push notification
  PERFORM
    net.http_post(
      url := CONCAT(
        current_setting('app.settings.supabase_url', true),
        '/functions/v1/send-push-notification'
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key', true))
      ),
      body := jsonb_build_object(
        'user_id', NEW.user_id,
        'title', notification_title,
        'body', NEW.message,
        'data', jsonb_build_object(
          'type', NEW.type,
          'related_id', NEW.related_id,
          'notification_id', NEW.id
        )
      )
    );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error tapi jangan gagalkan INSERT
    RAISE WARNING 'Push notification error: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- 2. Buat trigger pada tabel notifications
DROP TRIGGER IF EXISTS on_notification_insert ON notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_notification();

-- 3. (Opsional) Enable pg_net extension jika belum
-- CREATE EXTENSION IF NOT EXISTS pg_net;

-- ==============================================
-- CATATAN:
-- - Pastikan extension pg_net sudah diaktifkan
-- - Set secrets di Supabase Dashboard:
--   * app.settings.supabase_url
--   * app.settings.service_role_key
-- ==============================================
