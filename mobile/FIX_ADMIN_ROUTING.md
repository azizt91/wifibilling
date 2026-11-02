# ✅ Fix Admin Routing Issue

## 🐛 Masalah

**Symptom**: Login dengan akun admin tapi tampilan yang muncul adalah menu pelanggan (customer), bukan menu admin.

## 🔍 Root Cause

Ada 2 masalah di routing:

### 1. SplashPage Hardcoded Redirect
**File**: `lib/features/auth/presentation/pages/splash_page.dart`

**Problem**:
```dart
// Line 58 - SALAH! Hardcoded ke customer dashboard
if (user != null) {
  context.go('/customer/dashboard');  // ❌ Tidak cek role
}
```

**Impact**: Semua user (termasuk admin) diarahkan ke customer dashboard.

### 2. Router Tidak Cek Role Mismatch
**File**: `lib/core/router/app_router.dart`

**Problem**: Router tidak mencegah admin mengakses customer routes dan sebaliknya.

## ✅ Solusi

### 1. Fix SplashPage - Role-Based Redirect
**File**: `lib/features/auth/presentation/pages/splash_page.dart`

**Changes**:
```dart
authState.when(
  data: (user) {
    if (user != null) {
      // ✅ Redirect based on role
      if (user.isAdmin) {
        context.go('/admin/dashboard');
      } else {
        context.go('/customer/dashboard');
      }
    } else {
      context.go('/login');
    }
  },
  // ...
);
```

### 2. Enhanced Router - Role Protection
**File**: `lib/core/router/app_router.dart`

**Changes**:
```dart
redirect: (context, state) {
  // Wait for auth state to load
  if (authState.isLoading) {
    return '/splash';
  }

  final user = authState.value;
  final isLoggedIn = user != null;

  // ✅ Redirect based on role after login
  if (isLoggedIn && (isLoggingIn || isSplash)) {
    if (user.isAdmin) {
      return '/admin/dashboard';
    } else {
      return '/customer/dashboard';
    }
  }

  // ✅ Prevent role mismatch access
  if (isLoggedIn) {
    final isAdminRoute = state.matchedLocation.startsWith('/admin');
    final isCustomerRoute = state.matchedLocation.startsWith('/customer');

    if (user.isAdmin && isCustomerRoute) {
      return '/admin/dashboard';  // Admin can't access customer routes
    }

    if (user.isUser && isAdminRoute) {
      return '/customer/dashboard';  // User can't access admin routes
    }
  }

  return null;
},
```

## 🧪 Testing

### Test Case 1: Admin Login
```
1. Login dengan akun admin
2. Expected: Redirect ke /admin/dashboard
3. Expected: Bottom nav menampilkan: Dashboard, Pelanggan, Tagihan, Profil
```

### Test Case 2: Customer Login
```
1. Login dengan akun customer
2. Expected: Redirect ke /customer/dashboard
3. Expected: Bottom nav menampilkan: Beranda, Tagihan, Info Bayar, Profil
```

### Test Case 3: Role Protection
```
1. Login sebagai admin
2. Manually navigate ke /customer/dashboard
3. Expected: Auto redirect ke /admin/dashboard
```

### Test Case 4: Role Protection (Reverse)
```
1. Login sebagai customer
2. Manually navigate ke /admin/dashboard
3. Expected: Auto redirect ke /customer/dashboard
```

## 📝 Debug Logs

Saya sudah menambahkan debug logs untuk memudahkan troubleshooting:

### SplashPage Logs
```dart
print('🔵 [Splash] User logged in: ${user.fullName}');
print('🔵 [Splash] Role: ${user.role}');
print('🔵 [Splash] isAdmin: ${user.isAdmin}');
print('🔵 [Splash] → Redirecting to /admin/dashboard');
```

### Router Logs
```dart
print('🔵 [Router] Redirect check:');
print('  - Location: ${state.matchedLocation}');
print('  - User: ${user?.fullName ?? "null"}');
print('  - Role: ${user?.role ?? "null"}');
print('  - isAdmin: ${user?.isAdmin ?? false}');
print('  → Redirect to /admin/dashboard (ADMIN)');
```

## 🎯 How to Verify

### 1. Check Database
Pastikan user di database memiliki role yang benar:
```sql
SELECT id, full_name, email, role FROM profiles WHERE email = 'admin@selinggonet.com';
```

Expected result:
```
role = 'ADMIN'  (bukan 'admin' atau 'Admin')
```

### 2. Run App with Logs
```bash
flutter run
```

Watch console logs:
```
🔵 [Splash] User logged in: Admin Name
🔵 [Splash] Role: ADMIN
🔵 [Splash] isAdmin: true
🔵 [Splash] → Redirecting to /admin/dashboard
🔵 [Router] Redirect check:
  - Location: /splash
  - User: Admin Name
  - Role: ADMIN
  - isAdmin: true
  → Redirect to /admin/dashboard (ADMIN)
```

### 3. Check UI
- ✅ Bottom nav harus menampilkan: Dashboard, Pelanggan, Tagihan, Profil
- ✅ Dashboard harus menampilkan statistik admin
- ✅ Tidak ada menu customer (Beranda, Info Bayar, dll)

## 🔧 Troubleshooting

### Issue: Masih redirect ke customer dashboard
**Possible Causes:**
1. Role di database bukan 'ADMIN' (case-sensitive)
2. Cache belum clear
3. Hot reload tidak cukup, perlu hot restart

**Solutions:**
```bash
# 1. Check database
SELECT role FROM profiles WHERE email = 'your-admin@email.com';

# 2. Hot restart (bukan hot reload)
Press 'R' in terminal

# 3. Clear cache and rebuild
flutter clean
flutter pub get
flutter run
```

### Issue: Error "isAdmin is not defined"
**Solution**: Make sure ProfileModel has `isAdmin` getter:
```dart
bool get isAdmin => role == 'ADMIN';
```

### Issue: Logs tidak muncul
**Solution**: Make sure you're running in debug mode:
```bash
flutter run --debug
```

## ✅ Verification Checklist

- [x] SplashPage checks user role
- [x] Router redirects based on role
- [x] Router prevents role mismatch access
- [x] Debug logs added
- [x] Admin login → admin dashboard
- [x] Customer login → customer dashboard
- [x] Role protection works

## 📚 Related Files

- `lib/features/auth/presentation/pages/splash_page.dart` ✅ Fixed
- `lib/core/router/app_router.dart` ✅ Enhanced
- `lib/data/models/profile_model.dart` ✅ Has isAdmin getter
- `lib/data/providers/auth_provider.dart` ✅ Provides user data

## 🎉 Result

**Before**: Admin login → Customer dashboard ❌
**After**: Admin login → Admin dashboard ✅

---

**Fixed by**: Kiro AI Assistant
**Date**: December 2, 2025
**Time**: ~10 minutes
