import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tenant_subscription_model.dart';
import 'auth_provider.dart';

final tenantSubscriptionProvider = FutureProvider<TenantSubscriptionModel?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    // 1. Ambil tenant_id & role dari profiles
    final profileRes = await supabase
        .from('profiles')
        .select('tenant_id, role')
        .eq('id', user.id)
        .maybeSingle();

    if (profileRes == null) return null;

    final role = (profileRes['role'] as String? ?? '').toUpperCase().trim();
    final isAdmin = role == 'ADMIN' || role == 'SUPER_ADMIN' || role == 'TENANT_ADMIN';
    if (!isAdmin) return null;

    final tenantId = profileRes['tenant_id'] as String?;
    if (tenantId == null) return null;

    // 2. Ambil data langganan tenant & paket SaaS
    final tenantRes = await supabase
        .from('tenants')
        .select('id, name, slug, subscription_status, subscription_expires_at, plan_id, saas_plans(name, price_monthly)')
        .eq('id', tenantId)
        .maybeSingle();

    if (tenantRes == null) return null;

    return TenantSubscriptionModel.fromJson(tenantRes);
  } catch (e) {
    // ignore: avoid_print
    print('[tenantSubscriptionProvider] Error: $e');
    return null;
  }
});

