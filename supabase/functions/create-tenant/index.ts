import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from '../_shared/cors.ts';
import {
  createAdminClient,
  getCallerContext,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts';

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createAdminClient();

    // 1. Wajib login sebagai super_admin
    const caller = await getCallerContext(req, supabaseAdmin);
    if (!caller.isServiceRole && caller.role !== 'super_admin') {
      throw new Error("Akses ditolak: Hanya Super Admin yang diizinkan membuat tenant/klien baru.");
    }

    const {
      email,
      password,
      owner_name,
      company_name,
      plan_id,
      custom_max_customers,
      subscription_status = 'active',
      subscription_expires_at = null
    } = await req.json();

    if (!email || !password || !company_name) {
      throw new Error("Email, Password, dan Nama Usaha WiFi wajib diisi.");
    }

    if (password.length < 6) {
      throw new Error("Password minimal 6 karakter.");
    }

    console.log(`[SuperAdmin] Creating tenant "${company_name}" for owner ${email}...`);

    // 2. Buat akun Auth user
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: owner_name || company_name,
        company_name: company_name
      }
    });

    if (authError) throw authError;
    if (!authData.user) throw new Error("Gagal membuat user auth.");

    const newUserId = authData.user.id;

    // 3. Ambil tenant yang otomatis dibuatkan oleh trigger handle_new_user
    // Beri jeda kecil agar trigger selesai berjalan
    let tenantRow: any = null;
    for (let i = 0; i < 5; i++) {
      const { data: tenant } = await supabaseAdmin
        .from('tenants')
        .select('*')
        .eq('owner_id', newUserId)
        .maybeSingle();

      if (tenant) {
        tenantRow = tenant;
        break;
      }
      await new Promise((res) => setTimeout(res, 300));
    }

    if (!tenantRow) {
      // Fallback: cari dari profiles.tenant_id
      const { data: prof } = await supabaseAdmin
        .from('profiles')
        .select('tenant_id')
        .eq('id', newUserId)
        .maybeSingle();

      if (prof?.tenant_id) {
        const { data: tenant } = await supabaseAdmin
          .from('tenants')
          .select('*')
          .eq('id', prof.tenant_id)
          .maybeSingle();
        tenantRow = tenant;
      }
    }

    if (!tenantRow) {
      throw new Error("Akun pengguna berhasil dibuat, namun data tenant gagal ditemukan.");
    }

    // 4. Update data tenant sesuai pilihan Super Admin (Paket, Custom Kuota, Lifetime Status)
    const updatePayload: Record<string, any> = {
      name: company_name,
      subscription_status: subscription_status || 'active',
      subscription_expires_at: subscription_expires_at || null,
      updated_at: new Date().toISOString()
    };

    if (plan_id) {
      updatePayload.plan_id = plan_id;
    }

    // custom_max_customers: jika ada angka (misal 100, 300, 500)
    if (custom_max_customers !== undefined) {
      updatePayload.custom_max_customers = custom_max_customers === null || custom_max_customers === '' 
        ? null 
        : Number(custom_max_customers);
    }

    const { data: updatedTenant, error: updateError } = await supabaseAdmin
      .from('tenants')
      .update(updatePayload)
      .eq('id', tenantRow.id)
      .select('*, saas_plans(name, max_customers, slug)')
      .single();

    if (updateError) {
      console.warn("Peringatan saat update tenant:", updateError);
    }

    return jsonResponse({
      success: true,
      message: `Akun mitra "${company_name}" berhasil dibuat!`,
      tenant: updatedTenant || tenantRow,
      user_id: newUserId
    }, 200, corsHeaders);

  } catch (error: any) {
    console.error("Error in create-tenant Edge Function:", error);
    return jsonResponse({ error: error.message }, errorStatus(error, 400), corsHeaders);
  }
});
