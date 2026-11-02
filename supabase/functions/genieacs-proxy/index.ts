import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from '../_shared/cors.ts';
import {
  createAdminClient,
  getCallerContext,
  resolveTenantId,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts';

serve(async (req) => {
  // Handle CORS preflight request
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createAdminClient();

    // 1. Identifikasi pemanggil (bisa Admin maupun Pelanggan yang mengganti WiFi)
    const caller = await getCallerContext(req, supabaseAdmin);

    const requestData = await req.json();
    const { endpoint, method, body, tenant_id: requestedTenant } = requestData;

    // 2. Ambil tenant_id pemanggil
    const tenantId = resolveTenantId(caller, requestedTenant);

    // 3. Ambil URL & kredensial GenieACS dari tabel genieacs_settings milik tenant tersebut
    const { data: settingsData, error: settingsError } = await supabaseAdmin
      .from('genieacs_settings')
      .select('setting_key, setting_value, is_enabled')
      .eq('tenant_id', tenantId);

    if (settingsError) throw settingsError;

    const acsMap: Record<string, string> = {};
    settingsData?.forEach((s: any) => {
      acsMap[s.setting_key] = s.setting_value || '';
    });

    const isEnabled = acsMap['genieacs_enabled'] === 'true';
    if (!isEnabled) {
      throw new Error("Layanan GenieACS tidak diaktifkan untuk tenant ini.");
    }

    const genieacsUrl = acsMap['genieacs_url'];
    if (!genieacsUrl) {
      throw new Error("URL GenieACS belum dikonfigurasi.");
    }

    const username = acsMap['genieacs_username'] || '';
    const password = acsMap['genieacs_password'] || '';

    // Sanitasi endpoint path
    const path = endpoint?.startsWith('/') ? endpoint : `/${endpoint || ''}`;
    const targetUrl = `${genieacsUrl.replace(/\/+$/, '')}${path}`;

    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    if (username && password) {
      headers['Authorization'] = `Basic ${btoa(`${username}:${password}`)}`;
    }

    const fetchOptions: any = {
      method: method || 'GET',
      headers: headers
    };

    if (body && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
      fetchOptions.body = typeof body === 'string' ? body : JSON.stringify(body);
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);

    try {
      const response = await fetch(targetUrl, {
        ...fetchOptions,
        signal: controller.signal
      });

      clearTimeout(timeoutId);

      const contentType = response.headers.get('content-type');
      let data;

      if (contentType && contentType.includes('application/json')) {
        data = await response.json();
      } else {
        const text = await response.text();
        data = { success: response.ok, text: text };
      }

      return jsonResponse(data, response.status, corsHeaders);

    } catch (fetchError: any) {
      clearTimeout(timeoutId);
      if (fetchError.name === 'AbortError') {
        return jsonResponse({ error: 'Request timeout after 10 seconds' }, 504, corsHeaders);
      }
      throw fetchError;
    }

  } catch (error: any) {
    console.error('Error in genieacs-proxy:', error);
    return jsonResponse({
      error: error.message,
    }, errorStatus(error, 500), corsHeaders);
  }
});