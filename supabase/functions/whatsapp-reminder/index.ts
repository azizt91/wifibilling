import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import {
  createAdminClient,
  getCallerContext,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts';

console.log('Fungsi whatsapp-reminder multi-tenant dimuat.');

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createAdminClient();

    // Opsional: cek caller jika dipanggil manual oleh admin
    let specificTenantId: string | null = null;
    try {
      const caller = await getCallerContext(req, supabaseAdmin);
      if (caller.role === 'admin' && caller.tenantId) {
        specificTenantId = caller.tenantId;
      }
    } catch {
      // Dipanggil oleh cron scheduler / webhook tanpa Bearer user biasa
    }

    const today = new Date();
    const currentDay = today.getDate();
    const currentMonthYear = today.toLocaleString('id-ID', { month: 'long', year: 'numeric' });
    console.log(`[Remind WA] Tanggal: ${currentDay}, Periode: ${currentMonthYear}`);

    // 1. Ambil daftar tenant yang langganannya aktif / trial
    let tenantQuery = supabaseAdmin
      .from('tenants')
      .select('id, name, subscription_status, subscription_expires_at')
      .in('subscription_status', ['active', 'trial']);

    if (specificTenantId) {
      tenantQuery = tenantQuery.eq('id', specificTenantId);
    }

    const { data: activeTenants, error: tenantError } = await tenantQuery;
    if (tenantError) throw tenantError;

    const validTenants = (activeTenants || []).filter(t => {
      if (!t.subscription_expires_at) return true;
      return new Date(t.subscription_expires_at) > today;
    });

    console.log(`Ditemukan ${validTenants.length} tenant aktif untuk diproses reminder-nya.`);

    const tenantResults: any[] = [];
    let totalSuccess = 0;
    let totalFailure = 0;

    // 2. Iterasi setiap tenant (Isolasi data & konfigurasi WA)
    for (const tenant of validTenants) {
      const tenantId = tenant.id;

      // Ambil token WA & template milik tenant ini
      const { data: waSettings } = await supabaseAdmin
        .from('whatsapp_settings')
        .select('setting_key, setting_value, is_enabled')
        .eq('tenant_id', tenantId);

      const settingsMap: Record<string, string> = {};
      waSettings?.forEach((s: any) => {
        if (s.is_enabled) settingsMap[s.setting_key] = s.setting_value || '';
      });

      const autoEnabled = settingsMap['auto_notification_enabled'] !== 'false';
      const fonnteToken = settingsMap['fonnte_token'] || Deno.env.get('FONNTE_TOKEN');

      if (!autoEnabled || !fonnteToken) {
        console.log(`Tenant ${tenant.name} (${tenantId}): reminder dilewati (notifikasi nonaktif atau token kosong).`);
        continue;
      }

      // Ambil paket & metode pembayaran milik tenant ini
      const { data: packages } = await supabaseAdmin
        .from('packages')
        .select('id, price')
        .eq('tenant_id', tenantId);

      const packagesMap = new Map((packages || []).map(p => [p.id, p.price]));

      const { data: payMethods } = await supabaseAdmin
        .from('payment_methods')
        .select('bank_name, account_number, account_holder')
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .order('sort_order', { ascending: true });

      let payMethodsText = '';
      if (payMethods && payMethods.length > 0) {
        payMethodsText = payMethods.map((m: any) => `• ${m.bank_name}: ${m.account_number} (an. ${m.account_holder})`).join('\n');
      } else {
        payMethodsText = '• Silakan cek metode pembayaran yang tersedia pada aplikasi.';
      }

      // Cari pelanggan aktif tenant ini yang jatuh tempo hari ini
      const { data: profiles, error: profErr } = await supabaseAdmin
        .from('profiles')
        .select('id, idpl, full_name, whatsapp_number, package_id, installation_date')
        .eq('tenant_id', tenantId)
        .eq('status', 'AKTIF');

      if (profErr || !profiles) continue;

      const potentialUsers = profiles.filter(p => {
        if (!p.installation_date) return false;
        const instDay = new Date(p.installation_date).getDate();
        return instDay === currentDay;
      });

      if (potentialUsers.length === 0) continue;

      // Cek yang sudah bayar bulan ini
      const potentialUserIds = potentialUsers.map(u => u.id);
      const { data: paidInvoices } = await supabaseAdmin
        .from('invoices')
        .select('customer_id')
        .eq('tenant_id', tenantId)
        .in('customer_id', potentialUserIds)
        .eq('status', 'paid')
        .eq('invoice_period', currentMonthYear);

      const paidUserIds = new Set((paidInvoices || []).map(inv => inv.customer_id));
      const usersToNotify = potentialUsers.filter(u => !paidUserIds.has(u.id));

      let tenantSuccess = 0;
      let tenantFailure = 0;

      for (const user of usersToNotify) {
        const price = packagesMap.get(user.package_id);
        if (!price || !user.whatsapp_number) continue;

        const message = `*Informasi Tagihan WiFi Anda*\n\nHai Bapak/Ibu ${user.full_name},\nID Pelanggan: ${user.idpl || '-'}\n\nTagihan Anda untuk periode *${currentMonthYear}* sebesar *Rp${new Intl.NumberFormat('id-ID').format(price)}* telah jatuh tempo.\n\n*METODE PEMBAYARAN:*\n${payMethodsText}\n\nTerima kasih atas kepercayaan Anda.\n_____________________________\n*_Pesan ini dibuat otomatis oleh ${tenant.name}. Abaikan jika sudah membayar._*`;

        try {
          const res = await fetch('https://api.fonnte.com/send', {
            method: 'POST',
            headers: {
              'Authorization': fonnteToken,
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({
              target: user.whatsapp_number,
              message: message
            })
          });

          if (res.ok) {
            tenantSuccess++;
            totalSuccess++;
          } else {
            tenantFailure++;
            totalFailure++;
          }
        } catch {
          tenantFailure++;
          totalFailure++;
        }
      }

      tenantResults.push({
        tenant_id: tenantId,
        tenant_name: tenant.name,
        notified: tenantSuccess,
        failed: tenantFailure
      });
    }

    return jsonResponse({
      message: `Proses notifikasi WhatsApp selesai. Berhasil: ${totalSuccess}, Gagal: ${totalFailure}.`,
      tenants_processed: tenantResults.length,
      details: tenantResults
    }, 200, corsHeaders);

  } catch (error: any) {
    console.error('Error in whatsapp-reminder:', error);
    return jsonResponse({ error: error.message }, errorStatus(error, 500), corsHeaders);
  }
});