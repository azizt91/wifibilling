// supabase/functions/update-user-auth/index.ts
// Purpose: Update user auth with Cross-Tenant IDOR prevention

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'
import {
  createAdminClient,
  getCallerContext,
  requireAdmin,
  assertSameTenant,
  jsonResponse,
  errorStatus
} from '../_shared/tenant.ts'

serve(async (req) => {
  // Menangani preflight request untuk CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, update_data } = await req.json()

    if (!user_id || !update_data) {
      throw new Error("User ID and update data are required.")
    }

    const supabaseAdmin = createAdminClient()

    // 1. Dapatkan konteks pemanggil & pastikan admin
    const caller = await getCallerContext(req, supabaseAdmin)
    requireAdmin(caller)

    // 2. Cegah Cross-Tenant IDOR: pastikan target user berada di tenant yang sama
    await assertSameTenant(supabaseAdmin, caller, user_id)

    // 3. Panggil fungsi admin untuk mengupdate user di Auth
    const { data, error } = await supabaseAdmin.auth.admin.updateUserById(
      user_id,
      {
        email: update_data.email || undefined,
        password: update_data.password || undefined,
        email_confirm: true,
      }
    )

    if (error) {
      throw error
    }

    return jsonResponse({
      success: true,
      message: "User updated successfully.",
      data
    }, 200, corsHeaders)

  } catch (error: any) {
    console.error('Error in update-user-auth function:', error)
    return jsonResponse({
      success: false,
      message: error.message
    }, errorStatus(error, 400), corsHeaders)
  }
})
