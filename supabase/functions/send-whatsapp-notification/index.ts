import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from '../_shared/cors.ts';
import {
  createAdminClient,
  getCallerContext,
  resolveTenantId,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts';

const FONNTE_TOKEN_ENV = Deno.env.get('FONNTE_TOKEN');

serve(async (req) => {
  // Handle preflight request untuk CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createAdminClient();

    // 1. Identifikasi pemanggil
    const caller = await getCallerContext(req, supabaseAdmin);

    // Ambil data dari body request
    const { target, message, tenant_id: requestedTenant } = await req.json();

    if (!target || !message) {
      throw new Error("Nomor tujuan (target) dan isi pesan (message) harus diisi.");
    }

    // 2. Tentukan tenant_id yang relevan
    const tenantId = resolveTenantId(caller, requestedTenant);

    // 3. Ambil Fonnte token dari whatsapp_settings MILIK TENANT TERSEBUT
    let fonnteToken = '';

    const { data: tokenData, error: tokenError } = await supabaseAdmin
      .from('whatsapp_settings')
      .select('setting_value')
      .eq('tenant_id', tenantId)
      .eq('setting_key', 'fonnte_token')
      .maybeSingle();

    if (!tokenError && tokenData?.setting_value && tokenData.setting_value.trim() !== '') {
      fonnteToken = tokenData.setting_value.trim();
      console.log(`Using Fonnte token from database for tenant: ${tenantId}`);
    } else if (FONNTE_TOKEN_ENV) {
      fonnteToken = FONNTE_TOKEN_ENV;
      console.log('Using fallback Fonnte token from environment variables');
    }

    if (!fonnteToken) {
      throw new Error("Token Fonnte untuk tenant Anda belum diatur di Pengaturan WhatsApp.");
    }

    // 4. Panggil API Fonnte untuk mengirim pesan
    const response = await fetch('https://api.fonnte.com/send', {
      method: 'POST',
      headers: {
        'Authorization': fonnteToken,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams({
        'target': target,
        'message': message
      })
    });

    const result = await response.json();
    if (!response.ok) {
      throw new Error(JSON.stringify(result));
    }

    return jsonResponse({ success: true, data: result }, 200, corsHeaders);

  } catch (error: any) {
    console.error('Error in send-whatsapp-notification:', error);
    return jsonResponse({ success: false, message: error.message }, errorStatus(error, 400), corsHeaders);
  }
});