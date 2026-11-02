import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from '../_shared/cors.ts';
import {
  createAdminClient,
  getCallerContext,
  requireAdmin,
  resolveTenantId,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts';

interface CustomerData {
  email: string;
  password?: string;
  full_name: string;
  address: string;
  whatsapp_number: string;
  gender?: string;
  status: 'AKTIF' | 'NONAKTIF';
  device_type?: string;
  ip_static_pppoe?: string;
  photo_url?: string;
  idpl: string;
  installation_date: string;
  package_id: number;
  amount: number;
  latitude?: number;
  longitude?: number;
  tenant_id?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log('=== CREATE CUSTOMER FUNCTION START ===');
    const supabaseAdmin = createAdminClient();

    // 1. Dapatkan caller context & pastikan admin
    const caller = await getCallerContext(req, supabaseAdmin);
    requireAdmin(caller);

    const customerData: CustomerData = await req.json();
    console.log('Received customer data:', JSON.stringify({ ...customerData, password: '***' }, null, 2));

    // 2. Tentukan tenant_id yang valid
    const tenantId = resolveTenantId(caller, customerData.tenant_id);

    // 3. Pre-check kuota & status tenant sebelum membuat auth user
    const { data: quota, error: quotaError } = await supabaseAdmin.rpc('get_tenant_quota', {
      p_tenant_id: tenantId
    });

    if (quotaError) {
      console.warn('Gagal cek kuota tenant via RPC:', quotaError.message);
    } else if (quota && quota.can_add_customer === false) {
      if (!quota.is_active) {
        throw new Error('Masa aktif langganan SaaS tenant telah berakhir atau disuspend. Silakan perpanjang langganan.');
      }
      throw new Error(`Kuota pelanggan untuk paket "${quota.plan_name}" telah penuh (${quota.used_customers}/${quota.max_customers}). Silakan upgrade paket.`);
    }

    // Validation
    if (!customerData.password) throw new Error("Password dibutuhkan.");
    if (!customerData.package_id) throw new Error("Paket harus dipilih.");
    if (!customerData.email) throw new Error("Email dibutuhkan.");
    if (!customerData.full_name) throw new Error("Nama lengkap dibutuhkan.");

    // Type checking
    if (typeof customerData.package_id !== 'number' || customerData.package_id <= 0) {
      throw new Error("Package ID harus berupa angka yang valid.");
    }
    if (typeof customerData.amount !== 'number' || customerData.amount <= 0) {
      throw new Error("Amount harus berupa angka yang valid.");
    }

    console.log(`Validation passed. Creating auth user for tenant ${tenantId}...`);

    // 4. Create user dengan app_metadata & user_metadata membawa tenant_id dan role 'pelanggan'
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email: customerData.email,
      password: customerData.password,
      email_confirm: true,
      app_metadata: {
        tenant_id: tenantId,
        role: 'pelanggan'
      },
      user_metadata: {
        full_name: customerData.full_name,
        tenant_id: tenantId,
        role: 'pelanggan',
        user_type: 'customer'
      }
    });

    if (authError) throw authError;
    if (!authData.user) throw new Error("Gagal membuat pengguna di sistem otentikasi.");
    const newUserId = authData.user.id;

    console.log('Auth user created:', newUserId, 'Updating profile...');

    // Pastikan IDPL selalu 5 karakter (2 huruf kapital + 3 angka acak, misal: UD417)
    let finalIdpl = customerData.idpl;
    if (!finalIdpl) {
      const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
      const l1 = letters.charAt(Math.floor(Math.random() * letters.length));
      const l2 = letters.charAt(Math.floor(Math.random() * letters.length));
      const num = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
      finalIdpl = `${l1}${l2}${num}`;
    }

    // 5. Update profile (dibuat otomatis oleh trigger handle_new_user dengan tenant_id dari app_metadata)
    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .update({
        idpl: finalIdpl,
        full_name: customerData.full_name,
        address: customerData.address,
        gender: customerData.gender || 'LAKI-LAKI',
        whatsapp_number: customerData.whatsapp_number,
        status: customerData.status || 'AKTIF',
        role: 'USER',
        tenant_id: tenantId,
        installation_date: customerData.installation_date,
        device_type: customerData.device_type,
        ip_static_pppoe: customerData.ip_static_pppoe,
        photo_url: customerData.photo_url || 'assets/avatar_male.svg',
        package_id: customerData.package_id,
        latitude: customerData.latitude,
        longitude: customerData.longitude,
      })
      .eq('id', newUserId);

    if (profileError) {
      console.error('Profile update error, rollback auth user:', profileError);
      await supabaseAdmin.auth.admin.deleteUser(newUserId);
      throw profileError;
    }

    console.log('Creating initial invoice...');

    const now = new Date();
    const currentMonthName = new Intl.DateTimeFormat('id-ID', { month: 'long' }).format(now);
    const currentYear = now.getFullYear();

    const { error: invoiceError } = await supabaseAdmin
      .from('invoices')
      .insert({
        tenant_id: tenantId,
        customer_id: newUserId,
        package_id: customerData.package_id,
        invoice_period: `${currentMonthName} ${currentYear}`,
        amount: customerData.amount,
        total_due: customerData.amount,
        status: 'unpaid'
      });

    if (invoiceError) {
      console.warn('Invoice creation warning:', invoiceError.message);
    }

    console.log('Customer creation completed successfully');

    return jsonResponse({
      message: "Pelanggan berhasil dibuat",
      user_id: newUserId,
      tenant_id: tenantId
    }, 200, corsHeaders);

  } catch (error: any) {
    console.error('Error in create-customer function:', error);
    return jsonResponse({ error: error.message }, errorStatus(error, 400), corsHeaders);
  }
});