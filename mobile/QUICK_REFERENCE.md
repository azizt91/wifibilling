# 🚀 Quick Reference - Selinggonet Flutter

## 📱 Admin Panel - Quick Commands

### Run App
```bash
flutter run
```

### Login Admin
```
Email: admin@selinggonet.com
Password: (check database)
```

### Hot Reload
```
Press 'r' in terminal
```

## 📂 File Locations

### Admin Pages
```
lib/features/admin/
├── dashboard/presentation/pages/admin_dashboard_page.dart
├── customers/presentation/pages/admin_customers_page.dart
├── invoices/presentation/pages/admin_invoices_page.dart
└── profile/presentation/pages/admin_profile_page.dart
```

### Admin Widgets
```
lib/features/admin/dashboard/presentation/widgets/
├── stat_card.dart
├── revenue_chart_card.dart
├── customer_chart_card.dart
└── quick_action_card.dart
```

### Core Files
```
lib/core/
├── widgets/admin_scaffold.dart
├── router/app_router.dart
└── theme/app_colors.dart
```

### Data Layer
```
lib/data/
├── providers/dashboard_provider.dart
├── repositories/dashboard_repository.dart
└── models/
```

## 🎯 Navigation Routes

### Admin Routes
```dart
/admin/dashboard      // Dashboard
/admin/customers      // Customer list
/admin/invoices       // Invoice list
/admin/profile        // Profile
```

### Customer Routes
```dart
/customer/dashboard   // Customer dashboard
/customer/invoices    // Customer invoices
/customer/profile     // Customer profile
/customer/payment-info // Payment info
/customer/wifi        // WiFi settings
/customer/help        // Help
```

## 🔧 Common Tasks

### Add New Admin Page
1. Create page in `lib/features/admin/[feature]/presentation/pages/`
2. Add route in `lib/core/router/app_router.dart`
3. Add navigation in `lib/core/widgets/admin_scaffold.dart` (if needed)

### Add New Provider
1. Create provider in `lib/data/providers/`
2. Use in page with `ref.watch(yourProvider)`

### Add New Repository
1. Create repository in `lib/data/repositories/`
2. Add provider in `lib/data/providers/`
3. Use in pages

### Refresh Data
```dart
ref.invalidate(yourProvider);
```

### Navigate
```dart
context.push('/admin/customers');
context.go('/admin/dashboard');
```

## 🎨 UI Components

### StatCard
```dart
StatCard(
  title: 'Profit',
  value: 'Rp 1.000.000',
  icon: Icons.trending_up,
  color: AppColors.success,
  onTap: () => context.push('/detail'),
)
```

### RevenueChartCard
```dart
RevenueChartCard(
  revenueData: [100, 200, 300],
  expensesData: [50, 100, 150],
  labels: ['Jan', 'Feb', 'Mar'],
)
```

### CustomerChartCard
```dart
CustomerChartCard(
  customerData: [10, 20, 30],
  labels: ['Jan', 'Feb', 'Mar'],
)
```

### QuickActionCard
```dart
QuickActionCard(
  title: 'Tambah Pelanggan',
  icon: Icons.person_add,
  color: AppColors.primary,
  onTap: () => context.push('/add'),
)
```

## 🔍 Debug Tips

### Print Debug
```dart
print('🔵 [Tag] Message');  // Info
print('✅ [Tag] Success');  // Success
print('❌ [Tag] Error: $e'); // Error
```

### Check Provider State
```dart
final state = ref.watch(yourProvider);
state.when(
  data: (data) => print('Data: $data'),
  loading: () => print('Loading...'),
  error: (e, s) => print('Error: $e'),
);
```

### Invalidate Cache
```dart
ref.invalidate(dashboardStatsProvider);
ref.invalidate(allCustomersProvider);
```

## 📊 Data Providers

### Dashboard
```dart
ref.watch(dashboardStatsProvider)
ref.watch(dashboardChartsDataProvider)
```

### Customers
```dart
ref.watch(allCustomersProvider)
ref.watch(customersFilterProvider)
ref.watch(customersSearchProvider)
```

### Invoices
```dart
ref.watch(invoicesByStatusProvider('unpaid'))
ref.watch(invoicesByStatusProvider('paid'))
```

### Auth
```dart
ref.watch(authStateProvider)
ref.watch(currentUserProvider)
```

## 🎨 Colors

```dart
AppColors.primary      // #6A5ACD Purple
AppColors.success      // #10B981 Green
AppColors.danger       // #EF4444 Red
AppColors.warning      // #F59E0B Orange
AppColors.info         // #3B82F6 Blue
AppColors.background   // #F8F9FE Light Gray
AppColors.surface      // #FFFFFF White
```

## 📝 Common Patterns

### Loading State
```dart
data.when(
  data: (value) => YourWidget(value),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
)
```

### Pull to Refresh
```dart
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(yourProvider);
  },
  child: ListView(...),
)
```

### Search
```dart
TextField(
  onChanged: (value) {
    ref.read(searchProvider.notifier).state = value;
  },
)
```

### Filter
```dart
FilterChip(
  label: Text('Active'),
  selected: filter == 'active',
  onSelected: (selected) {
    ref.read(filterProvider.notifier).state = 'active';
  },
)
```

## 🚨 Common Errors

### "Provider not found"
**Solution**: Make sure provider is defined in correct file and imported

### "No data returned"
**Solution**: Check database has data, check RPC function exists

### "Role not found"
**Solution**: Check user has role 'ADMIN' in profiles table

### "Charts not showing"
**Solution**: Check data exists, check RPC function returns correct format

## 📚 Documentation

- **Admin Panel Guide**: `ADMIN_PANEL_GUIDE.md`
- **Development Summary**: `DEVELOPMENT_SUMMARY.md`
- **Quick Start**: `README_ADMIN.md`
- **Completed Features**: `COMPLETED_ADMIN_PANEL.md`
- **This File**: `QUICK_REFERENCE.md`

## 🎯 Next Tasks

1. Customer Detail & Edit Form
2. Invoice Payment Form
3. Create Monthly Invoices
4. Package Management
5. Expense Management

## 💡 Pro Tips

1. Use `const` for static widgets
2. Use `AutoDispose` for providers
3. Use `ref.invalidate()` to refresh
4. Use `context.push()` for navigation
5. Use `print()` for debugging
6. Use `getDiagnostics` to check errors
7. Use hot reload for fast development

## 🔗 Useful Links

- [Flutter Docs](https://flutter.dev/docs)
- [Riverpod Docs](https://riverpod.dev/)
- [GoRouter Docs](https://pub.dev/packages/go_router)
- [FL Chart Docs](https://pub.dev/packages/fl_chart)
- [Supabase Docs](https://supabase.com/docs)

---

**Quick Reference v1.0.0**
**Last Updated**: December 2, 2025
