// Supabase Edge Function: send-push-notification
// Menggunakan FCM V1 API dengan Service Account Authentication

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Service Account credentials - set via Supabase secrets
// supabase secrets set FCM_PROJECT_ID=chefgenius-c80a8
// supabase secrets set FCM_CLIENT_EMAIL=firebase-adminsdk-fbsvc@chefgenius-c80a8.iam.gserviceaccount.com
// supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

interface NotificationPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

// Generate OAuth2 access token using Service Account
async function getAccessToken(): Promise<string> {
  const privateKeyPem = Deno.env.get('FCM_PRIVATE_KEY')!.replace(/\\n/g, '\n')
  const clientEmail = Deno.env.get('FCM_CLIENT_EMAIL')!

  // Import private key
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const now = Math.floor(Date.now() / 1000)
  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    privateKey
  )

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: NotificationPayload = await req.json()
    console.log('Received notification payload:', payload)

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get FCM token for the user
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('fcm_token, username')
      .eq('id', payload.user_id)
      .single()

    if (profileError || !profile?.fcm_token) {
      console.log('No FCM token found for user:', payload.user_id)
      return new Response(
        JSON.stringify({ success: false, error: 'No FCM token' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get project ID
    const projectId = Deno.env.get('FCM_PROJECT_ID')
    if (!projectId) {
      console.error('FCM_PROJECT_ID not set')
      return new Response(
        JSON.stringify({ success: false, error: 'FCM not configured' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken()

    // Send push notification via FCM V1 API
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: profile.fcm_token,
            notification: {
              title: payload.title,
              body: payload.body,
            },
            android: {
              priority: 'high',
              notification: {
                channel_id: 'chefgenius_channel',
                sound: 'default',
              },
            },
            data: payload.data || {},
          },
        }),
      }
    )

    const fcmResult = await fcmResponse.json()
    console.log('FCM V1 response:', fcmResult)

    // Check if token is invalid and clear it
    if (fcmResult.error?.code === 404 || fcmResult.error?.details?.[0]?.errorCode === 'UNREGISTERED') {
      await supabase
        .from('profiles')
        .update({ fcm_token: null })
        .eq('id', payload.user_id)
      console.log('Cleared invalid FCM token for user:', payload.user_id)
    }

    return new Response(
      JSON.stringify({ success: fcmResponse.ok, result: fcmResult }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})
