import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../data/models/profile_model.dart';
import '../../../../../data/models/invoice_model.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/invoice_provider.dart';

class DashboardData {
  final ProfileModel user;
  final List<InvoiceModel> invoices;

  DashboardData({required this.user, required this.invoices});
}

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  // Load user first
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) throw Exception('User not found');
  
  // Then load invoices
  final invoices = await ref.watch(customerInvoicesProvider(user.id!).future);
  
  return DashboardData(user: user, invoices: invoices);
});
