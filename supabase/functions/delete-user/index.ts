// Supabase Edge Function: delete-user
// Purpose: Delete user from Supabase Auth & DB with Cross-Tenant IDOR prevention

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
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id } = await req.json()

    if (!user_id) {
      return jsonResponse({ error: 'user_id is required' }, 400, corsHeaders)
    }

    const supabaseAdmin = createAdminClient()

    // 1. Dapatkan konteks pemanggil & pastikan admin
    const caller = await getCallerContext(req, supabaseAdmin)
    requireAdmin(caller)

    // 2. Cegah Cross-Tenant IDOR: pastikan target user berada di tenant yang sama
    await assertSameTenant(supabaseAdmin, caller, user_id)

    // 3. Delete user from Supabase Auth
    const { error } = await supabaseAdmin.auth.admin.deleteUser(user_id)

    if (error) {
      console.error('Error deleting user from Auth:', error)
      return jsonResponse({
        error: `Failed to delete user: ${error.message}`,
        details: error
      }, 500, corsHeaders)
    }

    return jsonResponse({
      success: true,
      message: `User ${user_id} deleted successfully from Auth`
    }, 200, corsHeaders)

  } catch (error: any) {
    console.error('Error in delete-user function:', error)
    return jsonResponse({
      error: error.message || 'Internal server error'
    }, errorStatus(error, 500), corsHeaders)
  }
})
