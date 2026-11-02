// supabase/functions/_shared/tenant.ts
// Helper bersama untuk identifikasi pemanggil & isolasi tenant di Edge Functions.

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const DEFAULT_TENANT_ID = 'a0000000-0000-4000-8000-000000000001';

export type CanonicalRole = 'super_admin' | 'admin' | 'pelanggan';

export interface CallerContext {
  /** true jika request memakai SUPABASE_SERVICE_ROLE_KEY (cron / antar-function) */
  isServiceRole: boolean;
  userId: string | null;
  tenantId: string | null;
  role: CanonicalRole | null;
}

export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export function normalizeRole(role?: string | null): CanonicalRole | null {
  if (!role) return null;
  const r = role.toLowerCase();
  if (r === 'super_admin' || r === 'superadmin') return 'super_admin';
  if (r === 'admin' || r === 'tenant_admin') return 'admin';
  if (r === 'user' || r === 'pelanggan' || r === 'customer') return 'pelanggan';
  return null;
}

export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}

function getBearerToken(req: Request): string | null {
  const header = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (!token || scheme.toLowerCase() !== 'bearer') return null;
  return token.trim();
}

/**
 * Mengidentifikasi pemanggil Edge Function.
 * - Service role key  -> isServiceRole = true (tenant harus disuplai eksplisit oleh pemanggil)
 * - JWT user          -> tenant & role diambil dari tabel profiles (sumber kebenaran),
 *                        fallback ke app_metadata JWT.
 */
export async function getCallerContext(
  req: Request,
  supabaseAdmin: SupabaseClient,
): Promise<CallerContext> {
  const token = getBearerToken(req);
  if (!token) throw new HttpError(401, 'Header Authorization tidak ditemukan.');

  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (serviceKey && token === serviceKey) {
    return { isServiceRole: true, userId: null, tenantId: null, role: null };
  }

  const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
  if (userError || !userData?.user) {
    throw new HttpError(401, 'Sesi tidak valid. Silakan login ulang.');
  }
  const user = userData.user;

  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('tenant_id, role')
    .eq('id', user.id)
    .maybeSingle();

  const tenantId: string | null =
    profile?.tenant_id ?? (user.app_metadata?.tenant_id as string | undefined) ?? null;
  const role = normalizeRole(profile?.role ?? (user.app_metadata?.role as string | undefined));

  return { isServiceRole: false, userId: user.id, tenantId, role };
}

/** Wajib admin tenant / super admin / service role. */
export function requireAdmin(ctx: CallerContext): void {
  if (ctx.isServiceRole) return;
  if (ctx.role === 'admin' || ctx.role === 'super_admin') return;
  throw new HttpError(403, 'Akses ditolak: hanya admin yang dapat melakukan aksi ini.');
}

/**
 * Menentukan tenant efektif:
 * - user biasa / admin  : selalu tenant miliknya (abaikan tenant dari body)
 * - super admin / service: boleh memakai tenant dari body
 */
export function resolveTenantId(ctx: CallerContext, requestedTenantId?: string | null): string {
  if (ctx.isServiceRole || ctx.role === 'super_admin') {
    const t = requestedTenantId || ctx.tenantId;
    if (!t) throw new HttpError(400, 'tenant_id wajib disertakan.');
    return t;
  }
  if (!ctx.tenantId) throw new HttpError(403, 'Akun Anda belum terhubung ke tenant mana pun.');
  return ctx.tenantId;
}

/** Tenant milik user target (profiles -> fallback auth app_metadata). */
export async function getUserTenantId(
  supabaseAdmin: SupabaseClient,
  userId: string,
): Promise<{ tenantId: string | null; role: CanonicalRole | null; exists: boolean }> {
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('tenant_id, role')
    .eq('id', userId)
    .maybeSingle();

  if (profile) {
    return { tenantId: profile.tenant_id ?? null, role: normalizeRole(profile.role), exists: true };
  }

  const { data: authUser } = await supabaseAdmin.auth.admin.getUserById(userId);
  if (authUser?.user) {
    return {
      tenantId: (authUser.user.app_metadata?.tenant_id as string | undefined) ?? null,
      role: normalizeRole(authUser.user.app_metadata?.role as string | undefined),
      exists: true,
    };
  }
  return { tenantId: null, role: null, exists: false };
}

/** Cegah Cross-Tenant IDOR: target harus berada di tenant yang sama dengan pemanggil. */
export async function assertSameTenant(
  supabaseAdmin: SupabaseClient,
  ctx: CallerContext,
  targetUserId: string,
): Promise<{ tenantId: string | null; role: CanonicalRole | null }> {
  const target = await getUserTenantId(supabaseAdmin, targetUserId);
  if (!target.exists) throw new HttpError(404, 'User target tidak ditemukan.');

  if (ctx.isServiceRole || ctx.role === 'super_admin') return target;

  if (target.role === 'super_admin') {
    throw new HttpError(403, 'Tidak dapat memodifikasi akun super admin.');
  }
  if (!ctx.tenantId || target.tenantId !== ctx.tenantId) {
    throw new HttpError(403, 'Akses ditolak: user target bukan milik tenant Anda.');
  }
  return target;
}

export function jsonResponse(body: unknown, status: number, corsHeaders: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function errorStatus(error: unknown, fallback = 400): number {
  return error instanceof HttpError ? error.status : fallback;
}
