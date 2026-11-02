# 📜 History & Progress Catatan Proyek: WiFi Billing System (SaaS Multi-Tenant Billing)

Dokumen ini berisi rangkuman riwayat perkembangan fitur, konfigurasi arsitektur, dan status sistem terakhir untuk menjaga kesinambungan pengembangan berikutnya.

---

## 📌 Identitas Proyek & Server
- **Nama Aplikasi**: WiFi Billing System - ISP Customer & Billing Management System (SaaS Multi-Tenant)
- **Supabase Project Ref**: `oawsmjpibfwpiaebvhot`
- **Supabase URL**: `https://oawsmjpibfwpiaebvhot.supabase.co`
- **Root Direktori Lokal**: `C:\laragon\www\project-billing`
- **Tipe Arsitektur**: Multi-Tenant dengan Row-Level Security (RLS) PostgreSQL & Supabase Edge Functions (Deno).

---

## 🚀 Status Edge Functions (100% Active & Deployed)
Semua 7 Edge Functions telah berhasil di-deploy ke server Supabase CLI:

| No | Nama Fungsi | Status | JWT Verification | Deskripsi Tugas |
|---|---|---|---|---|
| 1 | `create-customer` | **ACTIVE** | `true` | Pembuatan akun pelanggan WiFi & profil otomatis |
| 2 | `create-tenant` | **ACTIVE** | `true` | Pendaftaran Mitra/Tenant baru oleh Super Admin (Auth + Tenant + Defaults) |
| 3 | `delete-user` | **ACTIVE** | `true` | Penghapusan user dari Supabase Auth & DB (Anti Cross-Tenant IDOR) |
| 4 | `genieacs-proxy` | **ACTIVE** | `true` | Proxy ke GenieACS TR-069 untuk ganti password WiFi & reboot ONT |
| 5 | `send-whatsapp-notification` | **ACTIVE** | `true` | Kirim notifikasi WhatsApp via gateway Fonnte milik tiap tenant |
| 6 | `update-user-auth` | **ACTIVE** | `true` | Update kredensial user Auth dengan proteksi IDOR |
| 7 | `whatsapp-reminder` | **ACTIVE** | `false` | Pengingat tagihan bulanan otomatis via scheduler / cron / webhook |

### Alat Deployment CLI
- **`deploy-functions.bat`**: Script Windows Batch untuk mendeploy seluruh Edge Function dengan sekali double click.
- **`deploy-functions.ps1`**: Script PowerShell untuk deployment CLI.
- **`package.json`**: Script npm seperti `npm run deploy:functions`.

---

## 👥 Arsitektur Peran & Pemisahan Portal (Portal Isolation)

Aplikasi memiliki 3 level pengguna dengan batasan hak akses yang terisolasi ketat:

### 1. Super Admin (Owner Platform SaaS)
- **Halaman Login**: `superadmin-login.html` (didukung `superadmin-login.js`)
- **Dashboard**: `superadmin.html` (didukung `superadmin.js`)
- **Tugas & Fitur**:
  - Menambah Mitra/Klien RT-RW Net baru (otomatis membuatkan akun Auth dan tenant).
  - Mengatur paket langganan SaaS (*Starter, Pro, Unlimited, Free Trial*).
  - Menyesuaikan batas kuota pelanggan WiFi secara fleksibel (*Custom Quota Override* / *Unlimited*).
  - Mengubah masa aktif langganan mitra (*Active Lifetime, Trial, Suspended, Expired*).
  - **Edit & Hapus Mitra**: Tombol Edit dan Hapus (merah) aktif untuk seluruh tenant.
- **Proteksi Akses**:
  - **Dilarang Masuk ke Dashboard Klien**: Jika akun Super Admin membuka `dashboard.html`, `pelanggan.html`, dsb., `auth.js` secara otomatis **menolak dan me-redirect langsung ke `superadmin.html`**.
  - Navigasi link ke billing dashboard di header `superadmin.html` telah ditiadakan.

### 2. Admin Mitra (Pemilik / Pengelola RT-RW Net)
- **Halaman Login**: `index.html` (didukung `login.js`)
- **Dashboard Operasional**: `dashboard.html` (didukung `dashboard.js`)
- **Fitur Operasional**:
  - Manajemen Pelanggan (`pelanggan.html`)
  - Pembuatan & Penagihan Tagihan (`tagihan.html`)
  - Laporan Keuangan & Arus Kas (`laporan.html`)
  - Pencatatan Pengeluaran Operasional (`pengeluaran.html`)
  - Paket Internet Tenant (`paket.html`)
  - Konfigurasi WhatsApp Fonnte & Pengaturan Aplikasi (`app-settings.html`)
  - Kontrol ONT / Router WiFi (`ganti-wifi.html`)
- **Isolasi Data**: Hanya dapat melihat dan mengelola data miliknya sendiri (`tenant_id = get_my_tenant_id()`).

### 3. Pelanggan WiFi Akhir
- **Halaman Login**: `index.html`
- **Dashboard Pelanggan**: `pelanggan_dashboard.html`
- **Fitur**: Melihat rincian paket, riwayat tagihan & pembayaran, QRIS, dan status WiFi.

---

## 🗄️ Database & Migrasi (Supabase PostgreSQL)

File migrasi tersimpan di folder `supabase/migrations/`:
1. `2026102701_create_saas_core_tables.sql` - Tabel `saas_plans`, `tenants`, fungsi `default_tenant_id()`.
2. `2026102702_add_tenant_id_to_existing_tables.sql` - Menambahkan kolom `tenant_id` ke seluruh tabel operasional.
3. `2026102703_auth_helpers_and_triggers.sql` - Helper normalisasi role, trigger `handle_new_user`, default tenant init.
4. `2026102704_multi_tenant_rls_policies.sql` - Kebijakan keamanan RLS menyeluruh lintas tabel.
5. `2026102705_tenant_quota_enforcement.sql` - Pembatasan kuota pelanggan otomatis di level database.
6. `2026102706_multi_tenant_storage.sql` - Kebijakan storage bucket `avatars` dan `tenant-assets`.
7. `2026102707_tenant_scoped_rpc_functions.sql` - Stored procedure aman untuk data dashboard dan invoice.
8. `2026102708_superadmin_custom_quota.sql` - Kolom `custom_max_customers` dan RPC `get_superadmin_tenants()` & `update_tenant_by_superadmin()`.
9. `2026102709_superadmin_delete_tenant.sql` - RPC `delete_tenant_by_superadmin()` untuk menghapus tenant dan akun auth owner.
10. `2026102710_cascade_delete_auth_users.sql` - Trigger `trigger_cascade_delete_tenant_auth_users` & RPC `cleanup_orphan_auth_user()` agar akun di `auth.users` (Authentication) otomatis ikut terhapus saat tenant dihapus.
11. `2026102711_fix_customer_creation_trigger.sql` - Perbaikan trigger `handle_new_user()` agar pembuatan pelanggan oleh mitra tidak lagi membuat tenant/mitra baru (Skenario B vs Skenario A).
12. `2026102712_fix_dashboard_charts_data.sql` - Perbaikan RPC `get_dashboard_charts_data()` agar mengembalikan objek dataset lengkap untuk ke-4 grafik dashboard (`revenue_chart`, `payment_status_chart`, `customer_growth_chart`, `customer_total_chart`) berbasis multi-tenant.
13. `2026102713_random_customer_idpl_function.sql` - Fungsi database `generate_customer_idpl()` untuk ID Pelanggan 5 karakter acak unik (2 huruf + 3 angka).
14. `2026102714_get_tenant_branding_by_slug.sql` - RPC database `get_tenant_branding_by_slug()` untuk memuat logo, nama, tema, dan PWA per tenant via slug unik publik.
15. `Database.sql` - Script Master All-in-One gabungan seluruh skema di atas.

---

## 🔄 Catatan Terakhir Pembaruan (Update Log)
- **ID Pelanggan Acak 5 Karakter (2 Huruf + 3 Angka, misal `UD417`)**:
  - Format ID pelanggan yang sebelumnya sekuensial (`CST001`, `CST002`) diganti menjadi format acak 5 karakter (`[A-Z]{2}[0-9]{3}`).
  - Menghilangkan huruf membingungkan seperti `I` dan `O` agar tidak tertukar dengan angka `1` dan `0`.
  - Diperbarui pada [pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js) (form tambah manual dan email otomatis), [csv-import.js](file:///c:/laragon/www/project-billing/csv-import.js) (import massal CSV), dan Edge Function `create-customer`.
- **Perbaikan 4 Grafik Statistik Dashboard**:
  - Diperbarui RPC stored procedure `get_dashboard_charts_data()` agar mereturn format data lengkap yang sesuai dengan spesifikasi Chart.js di [dashboard.js](file:///c:/laragon/www/project-billing/dashboard.js).
  - Keempat grafik (Pendapatan & Profit, Status Pembayaran, Pertumbuhan Pelanggan Bersih, dan Total Pelanggan Aktif) kini terisi akurat secara otomatis sesuai data tenant masing-masing.
  - Perbaikan kalkulasi persentase pada tooltip pie chart agar aman dari pembagian nol (`NaN`).
- **Perbaikan Pembuatan Pelanggan (Cegah Jadi Tenant Baru)**:
  - Diperbaiki Edge Function `create-customer` dengan mengirim `tenant_id`, `role: 'pelanggan'`, dan `user_type: 'customer'` pada `user_metadata` dan `app_metadata`.
  - Diperbarui trigger `handle_new_user()` agar membaca metadata pelanggan dan mengunci pembuatan baris `tenants` hanya untuk registrasi mitra/tenant baru.
  - Disediakan query pembersih tenant anomali *"Batrex"* tanpa menghapus akun login/profil pelanggan miliknya di Apik Corporation.
- **Pembaruan Logo Default Sistem (Netral / Logo WiFi Modern)**:
  - Mengganti seluruh aset logo bawaan pihak ketiga (`assets/logo_rivamnet.jpg`, `assets/logo_192x192.png`, `assets/logo_512x512.png`) dengan ikon sinyal WiFi modern melingkar bergaya tech/SaaS (gradasi indigo, violet, dan cyan) bebas copyright.
  - Menambahkan aset netral `assets/logo_wifi.png` & `assets/logo_wifi.jpg` serta memperbarui referensi di [index.html](file:///c:/laragon/www/project-billing/index.html), [register.html](file:///c:/laragon/www/project-billing/register.html), [apply-settings.js](file:///c:/laragon/www/project-billing/apply-settings.js), dan [app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js).
- **Penghapusan Tuntas Akun Authentication**:
  - Diperbaiki alur hapus mitra di [superadmin.js](file:///c:/laragon/www/project-billing/superadmin.js) agar memanggil RPC `delete_tenant_by_superadmin()` dan Edge Function `delete-user`. Akun di Supabase **Authentication -> Users** kini ikut terhapus bersih (tidak menjadi orphan).
  - Ditambahkan trigger PostgreSQL `trigger_cascade_delete_tenant_auth_users` yang otomatis menghapus seluruh `auth.users` milik tenant sebelum baris tabel tenant terhapus.
- **Fitur Reset Password Mitra oleh Super Admin**:
  - Ditambahkan kolom *"Ganti Password Login Mitra"* pada modal Edit Mitra di [superadmin.html](file:///c:/laragon/www/project-billing/superadmin.html) untuk memudahkan Super Admin mengubah password mitra via Edge Function `update-user-auth`.
- **Peningkatan Form Login**:
  - Ditambahkan tombol intip password (mata) di [index.html](file:///c:/laragon/www/project-billing/index.html).
  - Penambahan `.trim()` pada input email dan pesan error spesifik di [login.js](file:///c:/laragon/www/project-billing/login.js).
- **Login Super Admin Dipisah**: Dibuatkan `superadmin-login.html` eksklusif agar Super Admin tidak perlu melalui login umum dan tidak terlempar ke `dashboard.html`.
- **Shortcut Login Owner**: Ditambahkan link *"👑 Login Khusus Super Admin (Owner)"* di halaman `index.html`.
- **Tombol Aksi Super Admin Diperjelas**:
  - Tombol edit diberi nama **"Edit"** (sebelumnya bernama "Atur Kuota").
  - Ditambahkan tombol **"Hapus"** warna merah yang sekarang juga sudah bisa menghapus *Rivamnet Default* maupun mitra baru.
- **Isolasi Ketat Super Admin**: Super Admin dicegah mengakses `dashboard.html` untuk menjaga privasi operasional mitra/client.
- **Audit Isolasi Multi-Tenant (Tagihan, Pengeluaran, & Laporan)**:
  - Telah dilakukan pengecekan mendalam terhadap RLS PostgreSQL, RPC stored procedure, dan kode frontend di [tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js), [pengeluaran.js](file:///c:/laragon/www/project-billing/pengeluaran.js), [laporan.js](file:///c:/laragon/www/project-billing/laporan.js), [auth.js](file:///c:/laragon/www/project-billing/auth.js), dan [profile.js](file:///c:/laragon/www/project-billing/profile.js).
  - **Hasil Isolasi DB**: Seluruh tabel `invoices`, `expenses`, `packages`, `payment_methods`, `notifications`, `app_settings`, dan `whatsapp_settings` telah memiliki RLS aktif dengan pembatas `tenant_id = (SELECT public.get_my_tenant_id())` dan trigger `invoices_set_tenant`, sehingga tidak ada kebocoran data antar mitra di level database.
  - **Pembersihan Cache Logout (Anti-Bleed pada Device Bersama)**: Memperbarui fungsi logout di [auth.js](file:///c:/laragon/www/project-billing/auth.js) dan [profile.js](file:///c:/laragon/www/project-billing/profile.js) untuk membersihkan `localStorage` (`app_settings`, `whatsapp_settings`, `pwa_manifest`) saat pengguna logout, mencegah branding/pengaturan tenant terbawa saat login tenant lain di browser/perangkat yang sama.
  - **Perbaikan Status Cicilan & Kalkulasi Laporan**: Memperbaiki inkonsistensi string status di [laporan.js](file:///c:/laragon/www/project-billing/laporan.js) (`'partially_paid'` vs `'installment'`) agar cicilan dihitung ke dalam total pendapatan, filter status "Cicilan" berfungsi normal, badge status cicilan tampil dengan benar, dan export PDF/Excel menyertakan nominal cicilan secara akurat.
  - **Ketahanan Role Pembuatan Tagihan Bulanan**: Memperbarui query pelanggan di [tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js) (`.in('role', ['USER', 'pelanggan', 'user'])`) agar seluruh pelanggan aktif di tenant pembuat tagihan terikutsertakan tanpa terkendala format penulisan role.
- **Audit Isolasi Nomor Rekening & Pengaturan Aplikasi (Anti Cross-Tenant Leak)**:
  - **Tabel `payment_methods` (Nomor Rekening Bank)**:
    - Dilindungi RLS `payment_methods_member_select` (`tenant_id = (SELECT public.get_my_tenant_id())`).
    - Input nomor rekening di [payment-methods.js](file:///c:/laragon/www/project-billing/payment-methods.js) otomatis mengikat `tenant_id` milik admin yang login melalui database column default `public.get_my_tenant_id()`.
    - Saat Pelanggan Tenant A membuka dashboard ([pelanggan_dashboard.js](file:///c:/laragon/www/project-billing/pelanggan_dashboard.js)) atau info tagihan ([pelanggan_info.js](file:///c:/laragon/www/project-billing/pelanggan_info.js)), query `payment_methods` dievaluasi oleh PostgreSQL dan **hanya mereturn rekening milik Tenant A**. Pelanggan Tenant B sama sekali tidak bisa membaca rekening Tenant A.
  - **Tabel `app_settings` (QRIS, Nama Usaha, Lokasi Bayar Offline, No WA Admin)**:
    - Dilindungi RLS `app_settings_member_select` (`tenant_id = (SELECT public.get_my_tenant_id())`).
    - Tenant yang baru dibuat memiliki `qris_image_url = NULL` (menampilkan SVG netral "Belum Ada QRIS"), bukan QRIS tenant lain.
    - Halaman login publik (`index.html`) untuk anonim hanya menampilkan branding netral/default sistem tanpa mengekspos rekening/kredensial tenant manapun.
  - **Pembersihan Cache Login & Logout Total**:
    - Diperbarui fungsi login di [login.js](file:///c:/laragon/www/project-billing/login.js), logout pelanggan di [pelanggan_profile.js](file:///c:/laragon/www/project-billing/pelanggan_profile.js), dan logout superadmin di [superadmin.js](file:///c:/laragon/www/project-billing/superadmin.js) untuk membersihkan `localStorage` (`app_settings`, `whatsapp_settings`, `pwa_manifest`), menjamin nol risiko visual flash/bleed antar tenant pada perangkat yang digunakan bersama.
- **Solusi A: URL Login & PWA Khusus Tenant (`?t=slug`)**:
  - Dibuatkan RPC database `get_tenant_branding_by_slug(p_slug TEXT)` di [2026102714_get_tenant_branding_by_slug.sql](file:///c:/laragon/www/project-billing/supabase/migrations/2026102714_get_tenant_branding_by_slug.sql) dan ditambahkan ke [Database.sql](file:///c:/laragon/www/project-billing/Database.sql). Fungsi ini aman diakses oleh anonim untuk memuat nama usaha, logo, favicon, warna tema, dan ikon PWA milik tenant berdasarkan slug unik atau nama tenant.
  - Memperbarui [apply-settings.js](file:///c:/laragon/www/project-billing/apply-settings.js):
    - Otomatis mendeteksi parameter URL `?t=slug` (misal `index.html?t=apik` atau `?t=selinggonet`).
    - Mengubah logo dan nama pada form login (`#login-logo`, `#login-app-name`) sebelum user memasukkan kredensial.
    - **PWA Manifest Dinamis**: PWA yang di-install saat membuka link tenant akan **100% mengikuti nama dan logo tenant terkait** sebagai ikon di Home Screen HP, dengan `start_url` yang otomatis mengunci ke `/?t=slug`.
  - Memperbarui [superadmin.js](file:///c:/laragon/www/project-billing/superadmin.js): Tombol *"Salin Info Akun"* otomatis menyertakan link login unik dengan parameter slug (`.../index.html?t=slug_tenant`) agar Super Admin tinggal menyalin dan mengirimkannya langsung ke mitra.
- **Pembaruan Brand Default Sistem Menjadi "WiFi Billing System"**:
  - Mengganti seluruh teks nama brand default sistem dari *"REVAM NET"* menjadi **"WiFi Billing System"** di seluruh halaman HTML (title, meta, heading form login/register, copyright footer), file JavaScript ([apply-settings.js](file:///c:/laragon/www/project-billing/apply-settings.js), [app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js), [pelanggan_dashboard.js](file:///c:/laragon/www/project-billing/pelanggan_dashboard.js), [pelanggan_info.js](file:///c:/laragon/www/project-billing/pelanggan_info.js), [receipt-printer.js](file:///c:/laragon/www/project-billing/receipt-printer.js), [sw.js](file:///c:/laragon/www/project-billing/sw.js)), dan [manifest.json](file:///c:/laragon/www/project-billing/manifest.json).
  - Tampilan login tanpa parameter kini menampilkan nama netral **WiFi Billing System** dengan logo WiFi modern.
- **Fitur Hapus Tagihan (Hanya Tagihan Belum Dibayar / Unpaid)**:
  - **Single Delete via Menu Titik Tiga (`⋮`)**:
    - Tombol `Cicil` pada kartu tagihan belum dibayar diringkas ke dalam dropdown menu kebab `⋮` di samping tombol `LUNAS` pada [tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js).
    - Menu dropdown menyediakan 2 pilihan aksi:
      1. **Bayar Cicilan** (ikon biru) untuk mencatat pembayaran sebagian.
      2. **Hapus Tagihan** (ikon merah) untuk menghapus tagihan yang bersangkutan.
    - Dilengkapi dialog konfirmasi spesifik: nama pelanggan, periode tagihan, dan nominal tagihan.
  - **Bulk Delete via Checkbox Terpilih**:
    - Memanfaatkan checkbox pilihan tagihan yang sudah ada (yang sebelumnya hanya untuk broadcast WhatsApp) di [tagihan.html](file:///c:/laragon/www/project-billing/tagihan.html) dan [tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js).
    - Menambahkan tombol aksi berwarna merah **"Hapus (X)"** di samping tombol **"Broadcast (X)"** pada bilah atas saat ada satu atau lebih tagihan dicentang.
    - Mengonfirmasi jumlah total tagihan yang akan dihapus secara permanen sebelum eksekusi massal.
  - **Preservasi Indikator Status WhatsApp**:
    - Dua (2) ikon WhatsApp berwarna abu-abu yang berfungsi sebagai indikator riwayat pengiriman pesan (WA 1 & WA 2) tetap dipertahankan 100% pada posisinya tanpa perubahan.
  - **Keamanan Finansial (Database & Client)**:
    - Seluruh operasi penghapusan tagihan dikunci secara ketat dengan klausul `.eq('status', 'unpaid')`.
    - Tagihan yang sudah dibayar (*Paid / Dibayar*) atau berstatus cicilan (*Partially Paid*) tidak dapat dihapus, menjaga keutuhan buku kas dan riwayat transaksi keuangan.
- **Peningkatan Keamanan Broadcast WhatsApp (Fitur Jeda Acak Anti-Banned)**:
  - **Pilihan Mode Jeda di Modal Broadcast ([tagihan.html](file:///c:/laragon/www/project-billing/tagihan.html))**:
    - **Aman (Rekomendasi)**: Jeda acak 5 – 10 detik per nomor.
    - **Super Aman**: Jeda acak 10 – 20 detik per nomor.
    - **Kustom**: Input detik tetap sesuai preferensi pengguna.
  - **Mekanisme Jeda Cerdas Acak ([tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js))**:
    - Algoritma `calculateBroadcastDelay()` menghitung interval acak antar nomor untuk mematahkan pola konstan robotik yang menjadi pemicu deteksi spam Meta/WhatsApp.
    - Menampilkan status realtime pengiriman dan waktu hitung mundur jeda aman pada layar loading saat proses broadcast berlangsung.
  - **Pembaruan Service Worker Network-First ([sw.js](file:///c:/laragon/www/project-billing/sw.js))**:
    - Strategi caching untuk file kode/halaman diubah menjadi Network-First dengan fallback cache offline (versi cache dinaikkan ke `yourisp-v1.6.2`) agar pembaruan kode aplikasi selalu langsung ter-render di browser tanpa tertahan cache lama.
- **Penyederhanaan Import Data Pelanggan CSV & Eliminasi Field Gender**:
  - **Penghapusan Kolom Gender**:
    - Field jenis kelamin dihilangkan dari form Tambah/Edit Pelanggan dan Detail Pelanggan di [pelanggan.html](file:///c:/laragon/www/project-billing/pelanggan.html) dan [pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js).
    - Seluruh avatar default pelanggan disatukan secara seragam menggunakan aset netral [assets/avatar_male.svg](file:///c:/laragon/www/project-billing/assets/avatar_male.svg) pada [pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js), [pelanggan_dashboard.js](file:///c:/laragon/www/project-billing/pelanggan_dashboard.js), [pelanggan_profile.js](file:///c:/laragon/www/project-billing/pelanggan_profile.js), dan Edge Function `create-customer`.
  - **Penyederhanaan Template CSV ([template_import_pelanggan.csv](file:///c:/laragon/www/project-billing/template_import_pelanggan.csv) & [csv-import.js](file:///c:/laragon/www/project-billing/csv-import.js))**:
    - **Deteksi Otomatis `package_id`**: Admin tidak perlu lagi mencari ID paket di database. Sistem otomatis mencocokkan nilai kolom `amount` (nominal tagihan) dengan daftar paket aktif milik tenant (`packages.price`).
    - **Email & Password Otomatis**: Kolom `email` dan `password` kini bersifat opsional. Jika dikosongkan, sistem otomatis membuatkan email berbasis ID Pelanggan (`{idpl}@wifi.id`) dan password default `123456`.
    - **Hanya 4 Kolom Pokok Wajib**: Cukup mengisi `full_name`, `whatsapp_number`, `address`, dan `amount`. Kolom lainnya (tanggal instalasi, perangkat ONT, IP static) bersifat opsional.
    - Template download di modal import diperbarui dengan format baru yang bersih dan ramah pengguna.
- **Standarisasi Kredensial Pelanggan Default (Email `{idpl}@wifi.id` & Password `123456`)**:
  - **Form Tambah Pelanggan Manual ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js))**:
    - Email otomatis disinkronkan dengan ID Pelanggan yang di-generate: `{idpl}@wifi.id` (contoh: `gj782@wifi.id`).
    - Password otomatis diseragamkan menjadi `123456` (6 digit angka ringkas).
  - **Peningkatan Kemudahan Login ([login.js](file:///c:/laragon/www/project-billing/login.js) & [index.html](file:///c:/laragon/www/project-billing/index.html))**:
    - Input login diubah dari `type="email"` menjadi `type="text"` dengan label *"Email atau ID Pelanggan"* agar form tidak lagi dicegat validasi HTML5 bawaan browser.
    - Pelanggan kini dapat langsung mengetik **ID Pelanggan saja** (misal: `gj782` atau `GJ782` tanpa perlu mengetik `@wifi.id`) dan password `123456` pada kolom input login, sistem akan otomatis melengkapi `@wifi.id` di latar belakang.
- **Perbaikan 4 Grafik Dashboard & Resilient Client-Side Fallback ([dashboard.js](file:///c:/laragon/www/project-billing/dashboard.js))**:
  - **Identifikasi Bug Database**: Fungsi stored procedure `get_dashboard_charts_data` di database sebelumnya me-reference kolom `profiles.updated_at` yang tidak ada di skema tabel `profiles` (error PostgreSQL `42703: column "updated_at" does not exist`), menyebabkan panggilan RPC gagal dan keempat grafik tidak ter-render.
  - **Client-Side Auto Fallback ([dashboard.js](file:///c:/laragon/www/project-billing/dashboard.js))**:
    - Menambahkan fungsi `generateClientChartsData(6)` yang otomatis mengkalkulasi dan menyusun data grafik (Pendapatan & Profit, Status Pembayaran, Pertumbuhan Pelanggan Baru vs Churn, dan Total Pelanggan Aktif) secara mandiri dari tabel `profiles`, `invoices`, dan `expenses` jika RPC database mengalami kendala.
    - Menghitung keaktifan pelanggan berdasarkan `COALESCE(installation_date, created_at)` sehingga 5 pelanggan yang baru di-import langsung tampil di grafik *Total Pelanggan Aktif*.
  - **Migrasi Database Stored Procedure ([2026102715_fix_dashboard_charts_updated_at.sql](file:///c:/laragon/www/project-billing/supabase/migrations/2026102715_fix_dashboard_charts_updated_at.sql))**:
    - Menambahkan kolom `updated_at TIMESTAMPTZ` pada tabel `profiles`.
    - Memperbaiki query churn dan keaktifan pelanggan agar tidak bergantung pada kolom yang hilang.
    - Telah ditambahkan ke [Database.sql](file:///c:/laragon/www/project-billing/Database.sql).
- **Perbaikan Tampilan Tombol Hapus Tagihan Massal ([tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js) & [tagihan.html](file:///c:/laragon/www/project-billing/tagihan.html))**:
  - **Tombol Hapus Tagihan Massal**: Fungsi `updateBroadcastActions()` diperbarui agar membuka class `hidden` dan menyinkronkan jumlah badge angka pada tombol `#btn-bulk-delete` (`Hapus ( X )`) secara bersamaan dengan tombol Broadcast setiap kali satu atau beberapa checkbox tagihan dicentang.
  - **Checkbox Seluruh Tagihan Belum Dibayar**: Menghapus limitasi rendering checkbox sehingga semua tagihan berstatus `unpaid` memiliki checkbox untuk dipilih dan dihapus secara massal (bukan hanya yang memiliki nomor WhatsApp).
  - Cache Service Worker dinaikkan ke `yourisp-v1.6.7` dan versi script `tagihan.js?v=1.0.8`.
- **Integrasi Aplikasi Flutter Mobile & Fitur Cetak Struk Printer Thermal Bluetooth ([mobile/](file:///c:/laragon/www/project-billing/mobile))**:
  - **Inisialisasi Folder Mobile**: Seluruh source code Flutter Customer & Admin Panel disatukan ke dalam direktori `c:\laragon\www\project-billing\mobile`.
  - **Koneksi Supabase Multi-Tenant**: Konfigurasi `app_constants.dart` diarahkan ke database aktif multi-tenant `https://oawsmjpibfwpiaebvhot.supabase.co`.
  - **Resolusi Dependensi Flutter 3.44+**: Mengatasi constraint `intl: 0.19.0` via dependency overrides, perbaikan `CardThemeData` pada `app_theme.dart`, dan penyesuaian `widget_test.dart`.
  - **Library & Izin Bluetooth Android**: Memasang `print_bluetooth_thermal: 1.2.3` dan `esc_pos_utils_plus: 2.0.4`, serta menambahkan permission Bluetooth (`BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`) pada `AndroidManifest.xml`.
  - **Service & Provider Printer Thermal ([thermal_printer_service.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/services/thermal_printer_service.dart) & [printer_provider.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/providers/printer_provider.dart))**:
    - Mendukung scanning perangkat Bluetooth paired, auto-reconnect printer terakhir, dan pilihan kertas 58mm / 80mm.
    - Format struk standar kasir profesional: Nama ISP, info tagihan/No Ref, waktu, detail pelanggan (IDPL & Nama), periode, total tagihan, jumlah bayar, sisa cicilan, kasir/petugas, serta pesan footer.
  - **Komponen UI Printer Modal ([printer_settings_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/printer_settings_modal.dart))**: Modal bottom sheet untuk pemindaian printer, status koneksi realtime, putus/sambung, dan tombol cetak uji coba (*test print*).
  - **Integrasi di Halaman Tagihan Admin ([admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart))**:
    - Status & shortcut printer di AppBar header tagihan.
    - Tombol cetak struk langsung pada kartu tagihan lunas (`paid`).
    - Tombol cetak struk di dalam modal detail tagihan.
    - Dialog otomatis penawaran cetak struk kasir seketika setelah pembayaran/cicilan berhasil dicatat.
  - **Integrasi di Halaman Pengaturan Admin ([admin_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/settings/presentation/pages/admin_settings_page.dart))**: Card status printer thermal dengan tombol pintasan scan & hubungkan printer.
  - **Sinkronisasi Form & Login Flutter Sesuai Web Baru**:
    - **Login Fleksibel ([login_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/auth/presentation/pages/login_page.dart))**: Pelanggan kini dapat login langsung menggunakan ID Pelanggan (misal: `GJ782` dan `123456`) tanpa dicegat validasi `@`, sistem otomatis melengkapi `@wifi.id`. Navigasi diarahkan otomatis sesuai role (`user.isAdmin` ke `/admin/dashboard`, pelanggan ke `/customer/dashboard`).
    - **Form Tambah Pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart))**: Otomatis menghasilkan IDPL unik dengan card preview kredensial login (`{idpl}@wifi.id` & password default `123456`), input email/password manual dijadikan opsional, dan field gender telah dihilangkan.
    - **Form Edit Pelanggan ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart))**: Field gender dihilangkan agar sinkron dengan database.
    - **Import Pelanggan CSV ([csv_import_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/csv_import_page.dart))**: Penyederhanaan kolom wajib menjadi 4 pokok (`full_name`, `whatsapp_number`, `address`, `amount`), auto-detect `package_id` dari nominal harga paket, auto email/password, dan eliminasi validasi gender.
  - **Fitur Broadcast WhatsApp Massal & Hapus Tagihan Massal Flutter ([admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart) & [broadcast_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/broadcast_modal.dart))**:
    - **Checkbox Seleksi Tagihan**: Ditambahkan checkbox pada setiap kartu tagihan belum dibayar (`unpaid`) dan bar "Pilih Semua" di bagian atas daftar tagihan.
    - **Hapus Massal (`#btn-bulk-delete`)**: Tombol merah `Hapus ( X )` yang muncul saat 1 atau lebih tagihan dicentang, dilengkapi dialog konfirmasi pencegah ketidaksengajaan dan query hapus massal aman di Supabase.
    - **Broadcast WhatsApp Massal Anti-Banned**: Tombol hijau `Broadcast ( X )` yang membuka modal pengiriman massal dengan Anti-Banned Smart Delay (Aman 5-10s, Super Aman 10-20s, Kustom), limit batching, template kustom dinamis, serta dialog progress realtime dengan countdown jeda dan tombol pembatalan.
    - **Indikator Status Broadcast**: Ditambahkan ikon chat ganda pada kartu tagihan belum dibayar untuk menandai status broadcast ke-1 dan ke-2.
- **Penyelesaian Kompatibilitas Build Android & Environment Flutter 3.44+ (29 Oktober 2026)**:
  - **Upgrade Gradle Wrapper**: Menaikkan versi Gradle ke **8.14** pada [gradle-wrapper.properties](file:///c:/laragon/www/project-billing/mobile/android/gradle/wrapper/gradle-wrapper.properties) untuk memenuhi standar minimum Flutter SDK terbaru.
  - **Upgrade Android Gradle Plugin (AGP) & Kotlin**:
    - AGP ditingkatkan ke versi **8.6.0** di [settings.gradle](file:///c:/laragon/www/project-billing/mobile/android/settings.gradle) dan [build.gradle](file:///c:/laragon/www/project-billing/mobile/android/build.gradle).
    - Kotlin Plugin ditingkatkan ke versi **2.1.0** di [settings.gradle](file:///c:/laragon/www/project-billing/mobile/android/settings.gradle) dan [build.gradle](file:///c:/laragon/www/project-billing/mobile/android/build.gradle).
  - **Konfigurasi Android SDK 36 & NDK 26**:
    - `compileSdk` dan `targetSdk` dinaikkan ke versi **36** di [app/build.gradle](file:///c:/laragon/www/project-billing/mobile/android/app/build.gradle) dan [build.gradle](file:///c:/laragon/www/project-billing/mobile/android/build.gradle).
    - `ndkVersion` disesuaikan ke `"26.1.10909125"` sesuai kebutuhan dependensi library Android modern.
  - **Core Library Desugaring Java 8+**:
    - Mengaktifkan `coreLibraryDesugaringEnabled true` dengan dependensi `com.android.tools:desugar_jdk_libs:2.0.4` pada [app/build.gradle](file:///c:/laragon/www/project-billing/mobile/android/app/build.gradle) untuk mendukung plugin background notification (`flutter_local_notifications`).
  - **Pembersihan Dependensi Bentrok `font_awesome_flutter`**:
    - Flutter SDK versi 3.44+ menjadikan class `IconData` sebagai `final class`, sehingga package `font_awesome_flutter` versi lama menimbulkan error kompilasi.
    - Menghapus `font_awesome_flutter` dari [pubspec.yaml](file:///c:/laragon/www/project-billing/mobile/pubspec.yaml).
    - Membersihkan baris import tak terpakai di [customer_dashboard_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/dashboard/presentation/pages/customer_dashboard_page.dart) dan [help_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/help/presentation/pages/help_page.dart).
    - Mengganti icon WhatsApp di [payment_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/payment/presentation/widgets/payment_modal.dart) menjadi icon standar Flutter `Icon(Icons.chat)`.
  - **Perbaikan Sintaks Dart**:
    - Menambahkan inisialisasi `currencyFormat` pada dialog konfirmasi cetak struk kasir di [admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart).
    - Mempertahankan referensi foto lama `widget.customer['photo_url']` di [customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart).
  - **Status Analisis Dart**: Seluruh kode Dart di `mobile/` telah dianalisis via `flutter analyze` dan lolos dengan **0 error**.
- **Sesi Pengembangan Mobile App & Web Sync (29 Oktober 2026 - Malam)**:
  - **Rebranding Total Menjadi "WiFi Billing System"**:
    - Mengubah nama aplikasi menjadi **"WiFi Billing System"** di Android [strings.xml](file:///c:/laragon/www/project-billing/mobile/android/app/src/main/res/values/strings.xml) (`app_name` & `title_activity_main`), [app_constants.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/constants/app_constants.dart), [main.dart](file:///c:/laragon/www/project-billing/mobile/lib/main.dart), dan [app_settings_model.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/models/app_settings_model.dart).
    - Memperbarui logo dan teks pada [login_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/auth/presentation/pages/login_page.dart) dan [splash_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/auth/presentation/pages/splash_page.dart).
    - Menghapus seluruh watermark/logo latar belakang di kartu Profit [admin_dashboard_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/dashboard/presentation/pages/admin_dashboard_page.dart) sehingga kartu profit tampil bersih, elegan, dan fokus pada nominal kas.
  - **Pembaruan Ikon Launcher Android (`wifi_vector.png`)**:
    - Dibuatkan seluruh set ikon launcher Android (`ic_launcher.png`, `ic_launcher_round.png`, dan `ic_launcher_foreground.png`) berbasis gambar vektor [wifi_vector.png](file:///c:/laragon/www/project-billing/mobile/assets/images/wifi_vector.png) untuk seluruh kerapatan layar Android: `mipmap-mdpi` (48px/108px), `mipmap-hdpi` (72px/162px), `mipmap-xhdpi` (96px/216px), `mipmap-xxhdpi` (144px/324px), dan `mipmap-xxxhdpi` (192px/432px).
    - Ikon aplikasi di Home Screen HP kini 100% menggunakan logo WiFi modern yang seragam.
  - **Komponen Universal Foto Profil & Avatar Sistem ([app_avatar.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/app_avatar.dart))**:
    - **Akar Masalah Sebelumnya**: Di database Supabase, foto profil default tersimpan sebagai `'assets/avatar_male.svg'` (sesuai sistem web). Kode Flutter sebelumnya mencoba memuatnya via `NetworkImage()` sehingga gagal (lingkaran foto di dashboard kosong/blank) atau hanya menampilkan inisial huruf di halaman profil.
    - **Solusi Cerdas**: Menyalin aset SVG [avatar_male.svg](file:///c:/laragon/www/project-billing/mobile/assets/images/avatar_male.svg) dan [avatar_female.svg](file:///c:/laragon/www/project-billing/mobile/assets/images/avatar_female.svg) ke `mobile/assets/images/`, serta membuat widget universal `AppAvatar`.
    - `AppAvatar` menangani secara otomatis:
      1. Foto profil default sistem berbasis SVG (`assets/avatar_male.svg`).
      2. URL internet publik (`http://` / `https://`) hasil upload pengguna ke Supabase Storage bucket `avatars`.
      3. Data URI Base64 (`data:image/...`).
      4. Fallback inisial/ikon yang elegan tanpa pernah blank.
    - Diterapkan pada [admin_dashboard_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/dashboard/presentation/pages/admin_dashboard_page.dart), [admin_profile_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/profile/presentation/pages/admin_profile_page.dart), [customer_dashboard_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/dashboard/presentation/pages/customer_dashboard_page.dart), dan [customer_profile_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/profile/presentation/pages/customer_profile_page.dart).
  - **Perbaikan Modal Printer Thermal & Tombol Test Print ([printer_settings_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/printer_settings_modal.dart))**:
    - **Penyebab Teks Terpotong**: Modal sebelumnya tidak menggunakan `useRootNavigator: true` sehingga posisinya tertutup oleh BottomNavigationBar dan tombol floating tagihan di bawah, serta tombol OutlinedButton dibatasi tinggi statis (`height: 44`) tanpa `SafeArea` dan `SingleChildScrollView`.
    - **Perbaikan**: Mengaktifkan `useRootNavigator: true`, menambahkan pembungkus `SafeArea` dan `SingleChildScrollView`, serta merapikan padding vertikal dan ukuran font (13pt) tombol "Cetak Struk Uji Coba (Test Print)" sehingga tampil utuh, proporsional, dan nyaman di semua resolusi HP.
  - **Penyelarasan Tampilan Halaman Tagihan Mobile Sesuai Referensi Web ([admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart) & [whatsapp_icon.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/whatsapp_icon.dart))**:
    - **Penggantian Ikon Chat ke Ikon Resmi WhatsApp**:
      - Dibuat aset vektor [whatsapp.svg](file:///c:/laragon/www/project-billing/mobile/assets/icons/whatsapp.svg) dan widget [whatsapp_icon.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/whatsapp_icon.dart).
      - Mengganti seluruh ikon chat generik menjadi logo resmi WhatsApp pada indikator broadcast (WA 1 & WA 2), tombol kirim pesan WhatsApp per tagihan, dan tombol aksi "Broadcast (X)" di bar atas.
    - **Menu Aksi Titik Tiga (⋮) & Tombol Lunas Per Tagihan Belum Dibayar**:
      - Menyesuaikan baris kartu tagihan belum dibayar agar persis seperti versi web (`tagihan.js`): Checkbox + Nama & Periode + Indikator WhatsApp (1 & 2) + Tombol WhatsApp Hijau + Tombol **`LUNAS`** (latar soft `#EAE8F3` dan teks `#110E1B`) + Menu Dropdown Titik Tiga (`PopupMenuButton`).
      - Di dalam menu titik tiga (⋮) terdapat 2 pilihan:
        1. **Bayar Cicilan** (ikon dompet biru): membuka modal dialog pencatatan cicilan.
        2. **Hapus Tagihan** (ikon tempat sampah merah): membuka dialog konfirmasi hapus tagihan tunggal yang aman dengan eksekusi query Supabase `.from('invoices').delete().eq('id', invoice.id).eq('status', 'unpaid')`.
    - **Perbaikan Bug RenderFlex Overflow Bar Aksi Massal**:
      - Mengatasi pesan error *`A RenderFlex overflowed by 0.985 pixels on the right`* saat memilih semua tagihan. Bar aksi `_buildBulkActionBar` dijadikan compact dengan `MainAxisSize.min`, `minimumSize: Size.zero`, `tapTargetSize: MaterialTapTargetSize.shrinkWrap`, padding proporsional, dan elevation flat.
  - **Sinkronisasi Logo Default Web Menggunakan `wifi_vector.png`**:
    - Seluruh aset logo default web di [assets/](file:///c:/laragon/www/project-billing/assets/) telah diperbarui menggunakan master vektor [wifi_vector.png](file:///c:/laragon/www/project-billing/mobile/assets/images/wifi_vector.png):
      - `assets/logo_wifi.png`: Logo resolusi tinggi untuk halaman login ([index.html](file:///c:/laragon/www/project-billing/index.html)), register, dan pengaturan.
      - `assets/logo_512x512.png`: PWA app icon & favicon resolusi tinggi 512x512.
      - `assets/logo_192x192.png`: PWA icon & Apple touch icon 192x192.
      - `assets/logo_wifi.jpg`: Fallback JPG 512x512.
    - Menaikkan versi cache Service Worker pada [sw.js](file:///c:/laragon/www/project-billing/sw.js) ke `yourisp-v1.6.8` agar browser klien langsung memuat logo baru tanpa tertahan cache lama.
  - **Verifikasi & Sinkronisasi Portal Pelanggan Mobile Terhadap SaaS Multi-Tenant**:
    - **Portal Khusus Pelanggan**: Aplikasi Flutter mobile memiliki portal lengkap untuk pelanggan di bawah rute `/customer/*`:
      - Dashboard Pelanggan ([customer_dashboard_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/dashboard/presentation/pages/customer_dashboard_page.dart)): Info paket aktif, status masa aktif, kartu tagihan belum dibayar, dan riwayat pembayaran.
      - Tagihan & Riwayat ([customer_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/invoices/presentation/pages/customer_invoices_page.dart)): Tab tagihan belum bayar & riwayat pembayaran lunas beserta detail invoice.
      - Pembayaran Mandiri ([payment_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/payment/presentation/widgets/payment_modal.dart)): Pembayaran QRIS & Transfer Bank manual beserta konfirmasi WhatsApp otomatis ke CS.
      - Pengaturan WiFi TR-069 ([wifi_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/wifi/presentation/pages/wifi_settings_page.dart)): Ganti nama SSID, password WiFi, dan reboot modem ONT via Edge Function `genieacs-proxy`.
      - Profil & Bantuan ([customer_profile_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/profile/presentation/pages/customer_profile_page.dart)).
    - **Isolasi Data Multi-Tenant Otomatis (Database RLS)**:
      - Seluruh query pelanggan (`invoices`, `packages`, `payment_methods`, `app_settings`) aman terisolasi di tingkat PostgreSQL RLS (`tenant_id = get_my_tenant_id() AND customer_id = auth.uid()`). Pelanggan tidak akan pernah bisa melihat tagihan, paket, atau rekening milik tenant atau pelanggan lain.
    - **Penyelarasan Role Logic ([profile_model.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/models/profile_model.dart))**:
      - Getter `isAdmin` dan `isUser` disempurnakan menjadi *case-insensitive* dan mengenali seluruh alias role kanonik SaaS (`'admin'`, `'super_admin'`, `'pelanggan'`, `'customer'`, `'user'`), identik dengan logika `auth.js` pada portal web.
    - **Penyederhanaan Halaman Pusat Bantuan Pelanggan ([help_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/help/presentation/pages/help_page.dart))**:
      - Menghapus kolom pencarian topik bantuan, menu Pertanyaan Umum (FAQ), dan menu Panduan & Tutorial sesuai arahan.
      - Menyisakan dan memfokuskan tampilan pada 2 kanal komunikasi utama:
        1. **Live Chat (WhatsApp)**: Terintegrasi dengan widget `WhatsAppIcon`, nomor CS dinamis dari `app_settings` tenant, dan tombol aksi "Mulai Chat".
        2. **Panggilan Telepon**: Terintegrasi langsung dengan nomor CS tenant via protocol `tel:`, dilengkapi tombol aksi "Panggil".
  - **Status Analisis Dart & Kompilasi**:
    - Seluruh kode Dart di `mobile/` telah diverifikasi menggunakan `flutter analyze` dan lulus dengan **0 error**.
  - **Panduan Menjalankan Besok (Live Testing di HP)**:
    1. Sambungkan kabel data USB HP ke PC (pastikan mode *File Transfer / MTP* dan *USB Debugging* aktif).
    2. Cek koneksi perangkat via terminal:
       ```powershell
       adb devices
       ```
    3. Masuk ke direktori mobile dan jalankan aplikasi:
       ```powershell
       cd C:\laragon\www\project-billing\mobile
       flutter run
       ```
    4. Aplikasi akan langsung ter-compile, terpasang, dan terbuka live di layar HP dengan ikon WiFi baru, foto profil sistem, tombol LUNAS & titik tiga pada tagihan, serta halaman bantuan baru yang ringkas.---

## 📍 Otomasi Lokasi Pelanggan (GPS 1-Klik, Smart Parser & Interactive Map Picker) (2 November 2026)
- **Kebutuhan**: Di lapangan, menginput angka Latitude dan Longitude secara manual sangat sulit dan merepotkan bagi teknisi/admin (rawan salah ketik angka desimal atau tanda minus). Dibutuhkan solusi otomatis yang praktis untuk teknisi saat di rumah pelanggan maupun admin saat di kantor menerima share-loc WhatsApp.
- **Solusi & Perubahan yang Diterapkan**:
  1. **Aplikasi Mobile (Flutter)**:
     - **Komponen Khusus ([customer_location_picker_widget.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/widgets/customer_location_picker_widget.dart))**:
       - **Tombol "📍 Lokasi Saya (GPS)"**: Menggunakan sensor perangkat via `geolocator`. Melakukan pengecekan aktifasi GPS, izin lokasi (*runtime permissions*), dan mengambil koordinat dengan presisi tinggi (*LocationAccuracy.high*) dalam 1 klik. Menampilkan badge akurasi (misal: `±3.5 m`).
       - **Tombol "📋 Tempel WA/Maps" (Smart Parser)**: Otomatis membaca teks/link dari Clipboard atau dialog modal. Mampu mengekstrak koordinat dari link Google Maps (`https://maps.google.com/?q=...` atau `@lat,lng`), chat WhatsApp, hingga teks koordinat mentah.
       - **Aksi "🗺️ Lihat Maps"**: Jika koordinat sudah terisi, tombol cepat ini membuka Google Maps via `url_launcher` (`geo:lat,lng` atau URL browser) agar teknisi dapat memverifikasi visual satelit posisi rumah secara instan.
       - Menyediakan tombol hapus koordinat cepat jika ingin mengulang.
     - **Integrasi Halaman**:
       - Diterapkan pada Form Tambah Pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart)).
       - Diterapkan pada Form Edit Pelanggan ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart)).
  2. **Aplikasi Web**:
     - **Antarmuka Form ([pelanggan.html](file:///c:/laragon/www/project-billing/pelanggan.html) & [mobile/www/pelanggan.html](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.html))**:
       - Menambahkan tombol aksi cepat: **"📍 Ambil Lokasi Saya"** dan **"🗺️ Pilih di Peta"**.
       - Menyediakan kotak input cepat: **"Tempel link Maps / share loc WA di sini..."** dengan tombol *Tempel* otomatis.
       - Menampilkan status titik koordinat dan tombol preview link **"Lihat di Maps ↗"**.
       - Menambahkan **Modal Map Picker Interaktif** berbasis Leaflet & OpenStreetMap (gratis tanpa API key), memungkinkan pengguna menggeser pin lokasi (*drag & drop*) langsung ke atap rumah pelanggan.
     - **Logika JavaScript ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js) & [mobile/www/pelanggan.js](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.js))**:
       - `initLocationPicker()`: Mengelola event GPS browser (`navigator.geolocation`), event paste/input cerdas, dan interaksi peta Leaflet.
       - `parseLocationInput(text)`: Regex parser untuk mengekstrak latitude dan longitude dari beragam format URL Google Maps dan teks chat.
       - `updateLocationPreview()`: Sinkronisasi tampilan status dan tautan ke Google Maps.
       - Notifikasi toast non-intrusive (`showLocationToast`) memberikan umpan balik langsung tanpa membekukan antarmuka pengguna.
---

## 📱 Update Aplikasi Mobile Flutter (31 Oktober 2026)

Telah diselesaikan pembaruan menyeluruh pada aplikasi mobile Flutter (`c:\laragon\www\project-billing\mobile`):

### 1. Splash Screen Native Bersih & Tajam (Bebas Garis/Artifact)
- **Masalah**: Pada saat aplikasi diluncurkan di Android, terdapat garis vertikal abu-abu di samping kanan logo WiFi dan garis horizontal di bagian bawah logo (sesuai screenshot user).
- **Penyebab**: Terdeteksi 26 file gambar `splash.png` legacy beresolusi rendah dan mengandung artifact piksel pada folder `res/drawable-*`.
- **Solusi**:
  - Seluruh file `splash.png` legacy dihapus dari `mobile/android/app/src/main/res/drawable-*`.
  - Dihasilkan aset bersih resolusi tinggi `splash_logo.png` langsung dari vektor `wifi_vector.png` untuk seluruh densitas layar Android (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`).
  - File [launch_background.xml](file:///c:/laragon/www/project-billing/mobile/android/app/src/main/res/drawable/launch_background.xml) dikonfigurasi ulang untuk memuat `@drawable/splash_logo` di tengah layar putih bersih tanpa ada garis stray sama sekali.

### 2. Halaman Pelanggan (Avatar Default, Export CSV, Download Template & Import CSV)
- **Foto Profil Pelanggan**:
  - Mengganti pemanggilan gambar manual di [admin_customers_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/admin_customers_page.dart) dan [customer_detail_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_detail_page.dart) menggunakan [app_avatar.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/app_avatar.dart).
  - Foto profil otomatis menggunakan avatar default sistem (`assets/images/avatar_male.svg`), persis seperti pada aplikasi web.
  - Form tambah pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart)) dan import CSV ([csv_import_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/csv_import_page.dart)) diselaraskan menggunakan default `assets/avatar_male.svg`.
- **Fitur Export CSV**:
  - Ditambahkan fungsi `_exportCustomersCsv()` pada `AdminCustomersPage` yang mengekstrak seluruh data pelanggan lengkap dengan paket dan tarif (`profiles` + `packages`).
  - Format kolom standar web (`email, password, full_name, address, whatsapp_number, status, package_id, amount, installation_date, latitude, longitude, device_type, ip_static_pppoe`).
  - Tombol Export CSV dapat diakses langsung dari Header atas dan menu aksi FAB (+).
  - File CSV disimpan dengan nama `data_pelanggan_YYYY-MM-DD.csv` langsung ke folder Download perangkat via helper [csv_file_helper.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/utils/csv_file_helper.dart).
- **Download Template CSV & Import CSV**:
  - Tombol "Download Template" di [csv_import_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/csv_import_page.dart) kini benar-benar mendownload file `template_import_pelanggan.csv` ke folder Download perangkat dengan format kolom dan data sampel identik dengan web.
  - Encoding UTF-8 + BOM agar file template dan export terbaca rapi saat dibuka di Microsoft Excel.

### 3. Buat Tagihan Bulanan dengan Pilihan Bulan & Tahun
- **Masalah**: Tombol "Buat Tagihan" sebelumnya langsung membuat tagihan bulan berjalan tanpa opsi memilih periode.
- **Solusi**:
  - Pada [admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart), modal `Buat Tagihan Bulanan` kini menyediakan Dropdown Bulan (Januari s/d Desember) dan Dropdown Tahun (tahun saat ini - 1 hingga + 3), identik dengan portal web ([tagihan.html](file:///c:/laragon/www/project-billing/tagihan.html) & [tagihan.js](file:///c:/laragon/www/project-billing/tagihan.js)).
  - Mengimplementasikan alur pembuatan tagihan `_handleCreateInvoicesForPeriod()` yang memeriksa pelanggan aktif yang belum memiliki tagihan pada periode terpilih, menghitung tanggal jatuh tempo (tanggal 10 bulan berikutnya), dan menyisipkan tagihan baru secara otomatis dengan notifikasi SnackBar real-time.
- **Perbaikan Layout & Overflow Tagihan**:
  - Tombol Hapus Massal dan Broadcast Massal pada header tagihan dibungkus dengan `Flexible` dan `FittedBox` sehingga anti-overflow pada resolusi layar HP apapun.

### 4. Perubahan Package Name Menjadi `com.wifibilling.app`
- **Tujuan**: Mencegah aplikasi baru menimpa / menggantikan aplikasi Selinggonet yang sudah terpasang di HP saat menjalankan `flutter run`.
- **Perubahan yang Diterapkan**:
  - `build.gradle` ([mobile/android/app/build.gradle](file:///c:/laragon/www/project-billing/mobile/android/app/build.gradle)): `namespace` dan `applicationId` diubah menjadi `"com.wifibilling.app"`.
  - Java Structure: Direktori dan file `MainActivity.java` dipindahkan ke `mobile/android/app/src/main/java/com/wifibilling/app/MainActivity.java` dengan package `com.wifibilling.app`. Folder lama `selinggonet` telah dibersihkan.
  - Android Strings: `package_name` dan `custom_url_scheme` di [strings.xml](file:///c:/laragon/www/project-billing/mobile/android/app/src/main/res/values/strings.xml) diubah ke `com.wifibilling.app`.
  - Firebase: `package_name` di [google-services.json](file:///c:/laragon/www/project-billing/mobile/android/app/google-services.json) diselaraskan ke `com.wifibilling.app`.
  - Pubspec: `name` di [pubspec.yaml](file:///c:/laragon/www/project-billing/mobile/pubspec.yaml) diselaraskan ke `wifibilling` dan dependensi tes disinkronkan.
- **Hasil**: Aplikasi ini sekarang berdiri sendiri secara independen dan dapat terpasang berdampingan dengan aplikasi Selinggonet tanpa konflik ID maupun tumpang tindih.

### 5. Pembersihan Kolom & Informasi Gender
- **Pemeriksaan Web & Mobile**: Sesuai arahan sebelumnya, input gender telah dihapus dari antarmuka web (`pelanggan.html`). Namun kolom `'gender'` masih tertinggal pada fungsi lama `handleExportCSV()` di `pelanggan.js`.
- **Perubahan yang Diterapkan**:
  - Web ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js)): Menghapus kolom header dan field data `gender` dari fungsi export CSV.
  - Mobile ([admin_customers_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/admin_customers_page.dart)): Menghapus kolom `gender` dari fitur Export CSV pelanggan.
  - Mobile Detail ([customer_detail_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_detail_page.dart)): Menghapus baris "JENIS KELAMIN" dari grid detail pelanggan dan memberi ruang penuh untuk baris "ALAMAT".
  - Mobile Edit ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart)): Menghapus variabel sisa `_gender`.

### 6. Perbaikan Sintaks Query Supabase Dart
- **Masalah**: Terjadi error `The getter 'ascending' isn't defined` saat `flutter run` akibat sintaks JavaScript `{ascending: true}` terselip di file Dart.
- **Solusi**: Mengoreksi pemanggilan query di [admin_customers_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/admin_customers_page.dart) menjadi `.order('created_at', ascending: true)`.
- **Status Akhir**: Berhasil lulus verifikasi `flutter analyze` dengan **0 error**.

---

### 🚀 Panduan Menjalankan Besok (Live Testing di HP)
1. Sambungkan kabel data USB HP ke PC (pastikan mode *File Transfer / MTP* dan *USB Debugging* aktif).
2. Cek koneksi perangkat via terminal:
   ```powershell
   adb devices
   ```
3. Masuk ke direktori mobile dan jalankan aplikasi:
   ```powershell
   cd C:\laragon\www\project-billing\mobile
   flutter run
   ```
4. Aplikasi akan langsung ter-compile, terpasang, dan terbuka berdampingan dengan aplikasi lama di layar HP sebagai aplikasi baru bernama **WiFi Billing System** (`com.wifibilling.app`).---

## 📍 Otomasi Lokasi Pelanggan (GPS 1-Klik, Smart Parser & Interactive Map Picker) (2 November 2026)
- **Kebutuhan**: Di lapangan, menginput angka Latitude dan Longitude secara manual sangat sulit dan merepotkan bagi teknisi/admin (rawan salah ketik angka desimal atau tanda minus). Dibutuhkan solusi otomatis yang praktis untuk teknisi saat di rumah pelanggan maupun admin saat di kantor menerima share-loc WhatsApp.
- **Solusi & Perubahan yang Diterapkan**:
  1. **Aplikasi Mobile (Flutter)**:
     - **Komponen Khusus ([customer_location_picker_widget.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/widgets/customer_location_picker_widget.dart))**:
       - **Tombol "📍 Lokasi Saya (GPS)"**: Menggunakan sensor perangkat via `geolocator`. Melakukan pengecekan aktifasi GPS, izin lokasi (*runtime permissions*), dan mengambil koordinat dengan presisi tinggi (*LocationAccuracy.high*) dalam 1 klik. Menampilkan badge akurasi (misal: `±3.5 m`).
       - **Tombol "📋 Tempel WA/Maps" (Smart Parser)**: Otomatis membaca teks/link dari Clipboard atau dialog modal. Mampu mengekstrak koordinat dari link Google Maps (`https://maps.google.com/?q=...` atau `@lat,lng`), chat WhatsApp, hingga teks koordinat mentah.
       - **Aksi "🗺️ Lihat Maps"**: Jika koordinat sudah terisi, tombol cepat ini membuka Google Maps via `url_launcher` (`geo:lat,lng` atau URL browser) agar teknisi dapat memverifikasi visual satelit posisi rumah secara instan.
       - Menyediakan tombol hapus koordinat cepat jika ingin mengulang.
     - **Integrasi Halaman**:
       - Diterapkan pada Form Tambah Pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart)).
       - Diterapkan pada Form Edit Pelanggan ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart)).
  2. **Aplikasi Web**:
     - **Antarmuka Form ([pelanggan.html](file:///c:/laragon/www/project-billing/pelanggan.html) & [mobile/www/pelanggan.html](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.html))**:
       - Menambahkan tombol aksi cepat: **"📍 Ambil Lokasi Saya"** dan **"🗺️ Pilih di Peta"**.
       - Menyediakan kotak input cepat: **"Tempel link Maps / share loc WA di sini..."** dengan tombol *Tempel* otomatis.
       - Menampilkan status titik koordinat dan tombol preview link **"Lihat di Maps ↗"**.
       - Menambahkan **Modal Map Picker Interaktif** berbasis Leaflet & OpenStreetMap (gratis tanpa API key), memungkinkan pengguna menggeser pin lokasi (*drag & drop*) langsung ke atap rumah pelanggan.
     - **Logika JavaScript ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js) & [mobile/www/pelanggan.js](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.js))**:
       - `initLocationPicker()`: Mengelola event GPS browser (`navigator.geolocation`), event paste/input cerdas, dan interaksi peta Leaflet.
       - `parseLocationInput(text)`: Regex parser untuk mengekstrak latitude dan longitude dari beragam format URL Google Maps dan teks chat.
       - `updateLocationPreview()`: Sinkronisasi tampilan status dan tautan ke Google Maps.
       - Notifikasi toast non-intrusive (`showLocationToast`) memberikan umpan balik langsung tanpa membekukan antarmuka pengguna.

## 🖨️ Perbaikan Bug Bluetooth Printer: Memindai Terus-Menerus (1 November 2026)
- **Gejala Masalah**: Pada modal Pengaturan Printer Thermal Bluetooth, status "Memindai..." berputar tanpa henti dan printer paired (`EP5809AI`) tidak pernah muncul di daftar, padahal di pengaturan Bluetooth HP Android perangkat sudah terhubung/tersimpan (*paired*).
- **Akar Masalah (Root Cause)**:
  1. Pada Android 12 ke atas (API 31+), sistem memerlukan izin runtime eksplisit `BLUETOOTH_CONNECT` dan `BLUETOOTH_SCAN` (*Nearby Devices / Perangkat di sekitar*).
  2. Plugin `print_bluetooth_thermal` memiliki bug di kode Kotlin native (`PrintBluetoothThermalPlugin.kt` baris 83-85): jika izin `BLUETOOTH_CONNECT` belum diberikan, fungsi langsung melakukan `return` tanpa memanggil `result.success()` atau `result.error()`.
  3. Akibatnya, `MethodChannel` di sisi Flutter menggantung selamanya (*hang indefinitely*), sehingga status `isScanning` tetap `true` dan list printer tidak pernah terisi.
- **Solusi & Perbaikan Komprehensif**:
  1. **Native Permission Request Channel ([MainActivity.java](file:///c:/laragon/www/project-billing/mobile/android/app/src/main/java/com/wifibilling/app/MainActivity.java))**:
     - Menambahkan handler `com.wifibilling.app/bluetooth_permission` yang secara otomatis memunculkan dialog izin sistem Android (*"Izinkan aplikasi menemukan dan terhubung ke perangkat di sekitar?"*).
     - Menangani Android 12+ (`BLUETOOTH_CONNECT` & `BLUETOOTH_SCAN`) dan Android 11 ke bawah (`ACCESS_FINE_LOCATION`).
  2. **Proteksi Timeout & Anti-Hang ([thermal_printer_service.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/services/thermal_printer_service.dart))**:
     - Menambahkan pemanggilan `checkAndRequestBluetoothPermission()` sebelum memindai perangkat.
     - Menambahkan proteksi `.timeout(Duration(seconds: 4))` pada pemanggilan `pairedBluetooths` dan `.timeout(Duration(seconds: 6))` pada `connect` agar tidak pernah menggantung tanpa batas waktu.
  3. **Penyempurnaan Notifier & Auto-Scan ([printer_provider.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/providers/printer_provider.dart) & [printer_settings_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/printer_settings_modal.dart))**:
     - Jika izin ditolak, menampilkan pesan peringatan yang jelas dan informatif.
     - `PrinterSettingsModal` kini otomatis memicu pemindaian perangkat begitu modal terbuka (`auto-scan on open`).---

## 📍 Otomasi Lokasi Pelanggan (GPS 1-Klik, Smart Parser & Interactive Map Picker) (2 November 2026)
- **Kebutuhan**: Di lapangan, menginput angka Latitude dan Longitude secara manual sangat sulit dan merepotkan bagi teknisi/admin (rawan salah ketik angka desimal atau tanda minus). Dibutuhkan solusi otomatis yang praktis untuk teknisi saat di rumah pelanggan maupun admin saat di kantor menerima share-loc WhatsApp.
- **Solusi & Perubahan yang Diterapkan**:
  1. **Aplikasi Mobile (Flutter)**:
     - **Komponen Khusus ([customer_location_picker_widget.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/widgets/customer_location_picker_widget.dart))**:
       - **Tombol "📍 Lokasi Saya (GPS)"**: Menggunakan sensor perangkat via `geolocator`. Melakukan pengecekan aktifasi GPS, izin lokasi (*runtime permissions*), dan mengambil koordinat dengan presisi tinggi (*LocationAccuracy.high*) dalam 1 klik. Menampilkan badge akurasi (misal: `±3.5 m`).
       - **Tombol "📋 Tempel WA/Maps" (Smart Parser)**: Otomatis membaca teks/link dari Clipboard atau dialog modal. Mampu mengekstrak koordinat dari link Google Maps (`https://maps.google.com/?q=...` atau `@lat,lng`), chat WhatsApp, hingga teks koordinat mentah.
       - **Aksi "🗺️ Lihat Maps"**: Jika koordinat sudah terisi, tombol cepat ini membuka Google Maps via `url_launcher` (`geo:lat,lng` atau URL browser) agar teknisi dapat memverifikasi visual satelit posisi rumah secara instan.
       - Menyediakan tombol hapus koordinat cepat jika ingin mengulang.
     - **Integrasi Halaman**:
       - Diterapkan pada Form Tambah Pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart)).
       - Diterapkan pada Form Edit Pelanggan ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart)).
  2. **Aplikasi Web**:
     - **Antarmuka Form ([pelanggan.html](file:///c:/laragon/www/project-billing/pelanggan.html) & [mobile/www/pelanggan.html](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.html))**:
       - Menambahkan tombol aksi cepat: **"📍 Ambil Lokasi Saya"** dan **"🗺️ Pilih di Peta"**.
       - Menyediakan kotak input cepat: **"Tempel link Maps / share loc WA di sini..."** dengan tombol *Tempel* otomatis.
       - Menampilkan status titik koordinat dan tombol preview link **"Lihat di Maps ↗"**.
       - Menambahkan **Modal Map Picker Interaktif** berbasis Leaflet & OpenStreetMap (gratis tanpa API key), memungkinkan pengguna menggeser pin lokasi (*drag & drop*) langsung ke atap rumah pelanggan.
     - **Logika JavaScript ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js) & [mobile/www/pelanggan.js](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.js))**:
       - `initLocationPicker()`: Mengelola event GPS browser (`navigator.geolocation`), event paste/input cerdas, dan interaksi peta Leaflet.
       - `parseLocationInput(text)`: Regex parser untuk mengekstrak latitude dan longitude dari beragam format URL Google Maps dan teks chat.
       - `updateLocationPreview()`: Sinkronisasi tampilan status dan tautan ke Google Maps.
       - Notifikasi toast non-intrusive (`showLocationToast`) memberikan umpan balik langsung tanpa membekukan antarmuka pengguna.
---

## 📥 Perbaikan Import CSV Pelanggan Mobile (1 November 2026)
- **Gejala Masalah**:
  1. Validasi gagal dengan pesan `Data tidak valid: Baris 2: Format email tidak valid` saat mengimpor CSV pelanggan atau CSV template.
  2. Tampilan card upload CSV (*"Tap untuk pilih file CSV"*) terlihat sempit / kecil secara horizontal.
- **Akar Masalah (Root Cause)**:
  1. **Regex Validasi Email Cacat**: Di [csv_import_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/csv_import_page.dart), regex tertulis `r'^[^s@]+@[^s@]+.[^s@]+$'` (kurang backslash `\` pada `\s`). Akibatnya, `[^s@]` menolak seluruh karakter huruf 's', sehingga email yang mengandung huruf 's' (seperti `santoso@...`, `user@...`, `test@...`, atau prefix default pelanggan `cst...@wifi.id`) langsung dianggap tidak valid.
  2. **BOM UTF-8 Menodai Header Pertama**: File CSV yang diexport atau disimpan dengan format UTF-8 dengan BOM menyisipkan karakter tersembunyi `\uFEFF` di awal baris header. Akibatnya header pertama terbaca sebagai `\uFEFFfull_name` atau `\uFEFFemail`, sehingga pengecekan field wajib gagal.
  3. **Lebar Kontainer Upload**: Widget kontainer pada `_buildUploadSection` belum memiliki properti `width: double.infinity` di dalam `Column` dengan crossAxisAlignment start, sehingga kontainernya menyusut (*shrink-to-fit*).
- **Perbaikan yang Diterapkan**:
  1. Mengoreksi Regex validasi email menjadi `RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')` persis seperti logika web di `csv-import.js`.
  2. Membersihkan karakter BOM `\uFEFF` pada pembacaan string CSV dan pemetaan baris header di `_pickFile()`.
  3. Menambahkan `width: double.infinity` pada kontainer `_buildUploadSection` dan `_buildInfoCard` agar membentang proporsional memenuhi lebar layar.
  4. Menambahkan fallback aman untuk nilai `status` jika kosong/bernilai string kosong agar otomatis berstatus `'AKTIF'`.

---

## 📊 Perbaikan Filter Halaman Laporan Mobile (1 November 2026)
- **Gejala Masalah**: Hasil filter laporan pada aplikasi mobile (`admin_reports_page.dart`) tidak akurat dan tidak sinkron dengan data aktual maupun ringkasan kartu.
- **Akar Masalah (Root Cause)**:
  1. **Bocoran Rentang Tanggal**: Rentang periode (`bulan-ini`, `bulan-lalu`, dll.) sebelumnya menggunakan `start.subtract(Duration(days: 1))` dan `end.add(Duration(days: 1))` tanpa jam batas (00:00:00 - 23:59:59). Akibatnya, tagihan dari hari terakhir bulan sebelumnya (misal 30 September) bocor masuk ke dalam laporan "Bulan Ini" (Oktober).
  2. **Tanggal yang Difilter Tidak Konsisten**: Filter tanggal invoice sebelumnya hanya mengecek `created_at`. Padahal dalam laporan keuangan, invoice yang lunas dihitung berdasarkan tanggal pembayaran (`paid_at`), dan tanggal yang ditampilkan pada tabel adalah `paid_at ?? created_at`. Akibatnya, tagihan yang terbit di bulan sebelumnya namun baru dibayar bulan ini hilang dari laporan bulan berjalan.
  3. **Pengeluaran Tetap Muncul Saat Filter Status/Pelanggan/Metode**: Ketika admin memfilter status invoice (Lunas / Belum Bayar / Cicilan), mencari pelanggan tertentu, atau memilih metode pembayaran, daftar `expenses` (pengeluaran) sebelumnya tidak dikosongkan sehingga seluruh pengeluaran tetap muncul di tabel dan total pengeluaran tetap terhitung.
  4. **Status Cicilan**: Status tagihan cicilan di Supabase mencakup `partially_paid` dan `installment`, sebelumnya hanya dicek `partially_paid`.
  5. **Penghitungan Total Pendapatan**: Total pendapatan sebelumnya hanya menjumlahkan `paid` saja dan mengabaikan uang yang sudah masuk dari cicilan (`installment/partially_paid`). Selain itu, jika `total_due` bernilai 0/null, sistem sebelumnya tidak memiliki fallback ke kolom `amount`.
- **Perbaikan yang Diterapkan**:
  1. **Penetapan Batas Waktu Eksak**: Mengatur boundary waktu periode secara presisi dari jam `00:00:00.000` hingga `23:59:59.999` menggunakan helper `isInRange(date)`.
  2. **Konsistensi Tanggal Invoice**: Pengecekan tanggal invoice diselaraskan dengan tanggal transaksi yang tampil: `paid_at ?? created_at`.
  3. **Isolasi Pengeluaran**:
     - Jika admin memfilter status tagihan (Lunas / Belum Bayar / Cicilan), mencari pelanggan, atau memilih metode bayar, pengeluaran otomatis dikosongkan dari tabel dan kartu ringkasan.
     - Menambahkan opsi filter khusus **Pengeluaran** pada dropdown status pembayaran.
  4. **Penyelarasan Status Cicilan**: Mendukung status `partially_paid` dan `installment` secara fleksibel.
  5. **Perhitungan Akurat Total Pendapatan**: `totalPendapatan = totalLunas + totalInstallment`, dengan fallback ke `amount` jika `total_due` kosong.
  6. **Badge & Reset Custom Range**: Filter badge pada AppBar kini ikut mendeteksi `startDate` & `endDate`, serta mereset tanggal kustom jika dropdown periode dialihkan kembali dari 'custom'.

---

## 🔘 Penyelarasan Bentuk Tombol FAB Bulat (1 November 2026)
- **Kebutuhan**: Menyeragamkan bentuk tombol Floating Action Button (FAB) pada halaman **Tagihan** dan **Pengeluaran** (serta Paket dan Metode Pembayaran) agar berbentuk bulat sempurna (*CircleBorder*) persis seperti tombol FAB di halaman Pelanggan.
- **Akar Masalah**: Pada Flutter Material 3, default bentuk `FloatingActionButton` adalah kotak membulat (*squircle / rounded rectangle* dengan radius 16px).
- **Perubahan yang Diterapkan**:
  1. **Global Theme ([app_theme.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/theme/app_theme.dart))**: Menambahkan `shape: const CircleBorder()` ke dalam konfigurasi `floatingActionButtonTheme` sehingga seluruh FAB di aplikasi secara default berbentuk bulat.
  2. **Halaman Tagihan ([admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart))**: Menetapkan `shape: const CircleBorder()` dan `elevation: 4` pada tombol tambah tagihan.
  3. **Halaman Pengeluaran ([admin_expenses_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/expenses/presentation/pages/admin_expenses_page.dart))**: Menetapkan `shape: const CircleBorder()` dan `elevation: 4` pada tombol tambah pengeluaran.
  4. **Halaman Kelola Paket & Metode Pembayaran ([admin_packages_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/packages/presentation/pages/admin_packages_page.dart) & [admin_payment_methods_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/payment_methods/presentation/pages/admin_payment_methods_page.dart))**: Menetapkan `shape: const CircleBorder()` agar seluruh FAB di panel admin seragam bulat sempurna.

---

## 💳 Pemindahan Card Upload QRIS ke Metode Pembayaran (1 November 2026)
- **Kebutuhan**: Memindahkan kartu konfigurasi & upload gambar barcode QRIS dari halaman **Pengaturan Aplikasi** ke halaman **Metode Pembayaran** pada aplikasi **Mobile** dan **Web** agar tata letak menu konsisten, intuitif, terintegrasi, dan rapi sesuai alur transaksi keuangan.
- **Perubahan pada Mobile**:
  1. **Halaman Pengaturan Aplikasi ([admin_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/settings/presentation/pages/admin_settings_page.dart))**:
     - Menghapus section *"QRIS Payment"* dari antarmuka halaman sehingga menu Pengaturan Aplikasi kini fokus pada identitas ISP, branding, kontak CS, dan notifikasi.
     - Menyimpan nilai `qris_image_url` dan `show_qris` yang sudah ada agar tidak terhapus saat admin menyimpan pengaturan umum.
  2. **Halaman Metode Pembayaran ([admin_payment_methods_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/payment_methods/presentation/pages/admin_payment_methods_page.dart))**:
     - Menambahkan kartu **Pembayaran QRIS** di bagian atas daftar metode pembayaran.
     - Menyediakan toggle Switch untuk mengaktifkan/menonaktifkan pembayaran QRIS (`show_qris`).
     - Menyediakan preview box barcode QRIS yang responsif (preview gambar dari server atau file baru).
     - Menyediakan tombol upload gambar/barcode QRIS (`image_picker`) yang langsung mengunggah file ke Supabase Storage (bucket `avatars` folder `qris/`) dan memperbarui kolom `qris_image_url` pada tabel `app_settings`.
     - Menyinkronkan perubahan secara otomatis dengan feedback SnackBar informatif.
- **Perubahan pada Web**:
  1. **Halaman Pengaturan Aplikasi ([app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html) & [app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js))**:
     - Menghapus section card *"QRIS Payment"* (`#qris-upload`, `#qris-preview`, `#show-qris-input`) dari form pengaturan.
     - Memperbarui `saveSettings()` agar mempertahankan nilai `qris_image_url` dan `show_qris` yang tersimpan di database tanpa mereset atau menghapusnya.
  2. **Halaman Metode Pembayaran ([payment-methods.html](file:///c:/laragon/www/project-billing/payment-methods.html) & [payment-methods.js](file:///c:/laragon/www/project-billing/payment-methods.js))**:
     - Menambahkan card **Pembayaran QRIS** di bagian atas daftar metode pembayaran bank/e-wallet dengan desain modern Tailwind CSS.
     - Toggle switch `#show-qris-input` yang langsung terhubung ke database `app_settings` (`show_qris`) secara realtime dengan notifikasi toast.
     - Input file `#qris-upload` dengan preview `#qris-preview` yang otomatis mengunggah gambar ke Supabase Storage (bucket `avatars` / `qris/`) dan mengupdate kolom `qris_image_url` di `app_settings`.
  3. **Penyelarasan View Profil ([profile.html](file:///c:/laragon/www/project-billing/profile.html))**:
     - Menyelaraskan inline view `#payment-methods-view` dan `#app-settings-view` agar kartu QRIS berada di Metode Pembayaran.

   4. **Perbaikan Tampilan QRIS Web ([payment-methods.js](file:///c:/laragon/www/project-billing/payment-methods.js))**:
      - Menambahkan proteksi autentikasi `await requireRole('ADMIN')` saat inisialisasi agar session token JWT aktif sebelum query `app_settings` dieksekusi (mencegah query dijalankan sebagai `anon` yang dibatasi oleh RLS).
      - Menambahkan pembacaan `localStorage` saat start agar preview QRIS langsung tampil tanpa jeda (*zero-flicker*).
      - Menambahkan listener event `settings-loaded` dari `apply-settings.js` untuk auto-sinkronisasi data QRIS.
      - Menambahkan cache-busting query parameter `?v=2` pada pemanggilan script `payment-methods.js` di [payment-methods.html](file:///c:/laragon/www/project-billing/payment-methods.html) dan [profile.html](file:///c:/laragon/www/project-billing/profile.html).

---

## 🎧 Penyelarasan Halaman Pusat Bantuan Pelanggan Web (1 November 2026)
- **Kebutuhan**: Mengubah halaman [pelanggan_info.html](file:///c:/laragon/www/project-billing/pelanggan_info.html) dan [pelanggan_info.js](file:///c:/laragon/www/project-billing/pelanggan_info.js) pada portal pelanggan web dari yang sebelumnya berisi *"Informasi Pembayaran"* menjadi **"Pusat Bantuan"** agar seragam 100% dengan aplikasi mobile ([help_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/help/presentation/pages/help_page.dart)).
- **Perubahan yang Diterapkan**:
  1. **Tampilan Antarmuka ([pelanggan_info.html](file:///c:/laragon/www/project-billing/pelanggan_info.html))**:
     - **Header**: Berjudul *"Pusat Bantuan"* dengan tombol kembali ke dasbor pelanggan.
     - **Banner Info (Gradient Ungu)**: Banner gradasi `from-[#683fe4] to-[#8b5cf6]` dengan icon headset customer service, judul *"Layanan Pelanggan"*, dan teks info *"Ada kendala dengan koneksi internet atau tagihan Anda? Tim kami siap membantu."*.
     - **Card Pilihan Kontak**:
       - **Live Chat**: Icon WhatsApp hijau, keterangan nomor CS, dan tombol hijau *"Mulai Chat"*.
       - **Panggilan Telepon**: Icon telepon biru, nomor telepon CS, dan tombol biru *"Panggil"*.
  2. **Logika & Integrasi ([pelanggan_info.js](file:///c:/laragon/www/project-billing/pelanggan_info.js))**:
     - Mengambil kontak CS (`whatsapp_number`) secara realtime dari `app_settings` / `apply-settings.js` dengan fallback ke cache lokal.
     - **Live Chat via WhatsApp**: Membuka `https://wa.me/` dengan nomor terformat internasional dan pesan otomatis terpersonalisasi memuat nama dan ID Pelanggan (`idpl`).
     - **Panggilan Telepon**: Menghubungi langsung via `tel:` dengan nomor CS admin.
  3. **Penyelarasan Navigasi Bawah (Bottom Navigation)**:
     - Memperbarui tab ketiga pada seluruh halaman portal pelanggan ([pelanggan_dashboard.html](file:///c:/laragon/www/project-billing/pelanggan_dashboard.html), [pelanggan_riwayat_lunas.html](file:///c:/laragon/www/project-billing/pelanggan_riwayat_lunas.html), [pelanggan_info.html](file:///c:/laragon/www/project-billing/pelanggan_info.html), dan [pelanggan_profile.html](file:///c:/laragon/www/project-billing/pelanggan_profile.html)) dari *"Info Bayar"* menjadi **"Bantuan"** dengan icon bantuan lingkaran tanda tanya.
  4. **Penyelarasan Title**:
     - Memperbarui mapping judul halaman di [apply-settings.js](file:///c:/laragon/www/project-billing/apply-settings.js) menjadi `'pelanggan_info': 'Pusat Bantuan'`.

---

## 🔒 Proteksi Readonly pada Email Akun Profil (1 November 2026)
- **Kebutuhan**: Mengunci field Email pada modal/form **Edit Profile** agar berstatus `readonly` (tidak dapat diubah) baik pada aplikasi **Web** maupun **Mobile**, karena email digunakan sebagai pengenal akun dan kredensial login utama pada sistem multi-tenant.
- **Perubahan pada Web ([profile.html](file:///c:/laragon/www/project-billing/profile.html) & [profile.js](file:///c:/laragon/www/project-billing/profile.js))**:
  - Menetapkan atribut `readonly` dan styling terkunci (`bg-gray-100 text-gray-500 cursor-not-allowed select-none`) pada input `#edit-user`.
  - Mengubah keterangan teks bantuan menjadi: *"Email akun tidak dapat diubah (digunakan sebagai identitas login)."*.
  - Menyesuaikan fungsi `saveChanges()` di `profile.js` agar hanya memproses pembaruan Nama Lengkap dan Password baru tanpa memicu permintaan ubah email ke Supabase Auth.
- **Perubahan pada Mobile ([admin_profile_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/profile/presentation/pages/admin_profile_page.dart))**:
  - Menetapkan `readOnly: true`, `enabled: false`, dan background `filled: true` (abu-abu muda) pada TextField email profil admin.
  - Memperbarui teks keterangan bantuan di bawah field email.
  - Menyesuaikan `_saveProfile()` agar hanya memvalidasi nama serta memproses pembaruan password jika diisi.

---

## ⚙️ Penyelarasan Pengaturan Aplikasi (App Settings) Web & Mobile (1 November 2026)
- **Kebutuhan**:
  1. Menghilangkan kartu **"Pembayaran Offline"** pada pengaturan aplikasi web ([app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html) dan [app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js)), karena informasi pembayaran tunai/offline tidak lagi dipakai oleh portal pelanggan (sudah digantikan oleh menu **Pusat Bantuan** via Live Chat & Panggilan).
  2. Menyelaraskan struktur template **Notifikasi WhatsApp** di web agar identik 100% dengan aplikasi mobile:
     - Memperluas form pengaturan notifikasi WhatsApp dari yang sebelumnya hanya 1 template menjadi 3 template terstruktur:
       1. **Template Pembayaran Lunas** (`template_payment_full`)
       2. **Template Pembayaran Cicilan** (`template_payment_installment`)
       3. **Template Tagihan / Pesan Manual** (`template_custom_message`)
     - Menyediakan nilai default dan fungsi reset ke format standar untuk ketiga template.
     - Menyimpan dan memuat ketiga template dari tabel `whatsapp_settings` di Supabase serta sinkronisasi instan melalui `localStorage`.
  3. Memperbarui handler pengiriman notifikasi otomatis di [whatsapp-notification.js](file:///c:/laragon/www/project-billing/whatsapp-notification.js) agar menggunakan `template_payment_installment` untuk cicilan dan `template_payment_full` untuk pelunasan.
- **Perubahan yang Diterapkan**:
  - **[app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html)**:
    - Menghapus card "Pembayaran Offline" (`#offline-name-input`, `#offline-address-input`).
    - Memperbarui card "Notifikasi WhatsApp" dengan 3 section template:
      - Template Pembayaran Lunas (`#template-payment-full`) dengan indikator badge hijau.
      - Template Pembayaran Cicilan (`#template-payment-installment`) dengan indikator badge kuning/amber.
      - Template Tagihan / Pesan Manual (`#template-custom-message`) dengan indikator badge ungu.
    - Menambahkan petunjuk daftar variabel yang dapat digunakan pada masing-masing template.
    - Tombol "Reset Semua Template ke Default".
  - **[app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js)**:
    - Menambahkan fungsi template default: `getDefaultTemplatePaymentFull()`, `getDefaultTemplateInstallment()`, dan `getDefaultWhatsAppTemplate()`.
    - Menyesuaikan `populateWhatsAppForm`, `loadWhatsAppSettings`, `saveWhatsAppSettings`, dan `resetWhatsAppTemplates` untuk menangani `template_payment_full`, `template_payment_installment`, dan `template_custom_message`.
    - Mengamankan referensi elemen `offline-name-input` dan `offline-address-input` pada `populateForm` dan `saveSettings` menggunakan safe navigation (`?.`) dan fallback nilai eksisting.
  - **[whatsapp-notification.js](file:///c:/laragon/www/project-billing/whatsapp-notification.js)**:
    - Menyesuaikan fungsi `sendCustomerPaymentNotification` agar memilih template yang tepat sesuai status pembayaran (`template_payment_installment` jika terdapat sisa tagihan > 0, atau `template_payment_full` jika tagihan lunas).

---

## 📶 Penyelarasan Form Ganti WiFi Mobile & Web: Eliminasi Konfirmasi Password (1 November 2026)
- **Kebutuhan**: Menyeragamkan form ganti password WiFi antara aplikasi **Mobile** dan **Web** dengan menghapus input field *"Konfirmasi Password"* / *"Ketik ulang password"* pada aplikasi mobile ([wifi_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/wifi/presentation/pages/wifi_settings_page.dart)) sehingga pelanggan hanya perlu menginput Nama WiFi Baru (SSID) dan/atau Password WiFi Baru (minimal 8 karakter) dengan dukungan tombol toggle visibility intip mata.
- **Perubahan yang Diterapkan**:
  - **[wifi_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/customer/wifi/presentation/pages/wifi_settings_page.dart)**:
    - Menghapus controller `_confirmPasswordController` dan state flag `_passwordMismatch`.
    - Menghapus listener pencocokan password pada `initState()` dan pembersihan controller pada `dispose()`.
    - Menghapus TextFormField *"Konfirmasi Password"* dari card form ganti WiFi (`_buildChangeWifiForm()`).
    - Menyederhanakan validasi di `_handleSubmit()` agar langsung memvalidasi panjang password baru minimal 8 karakter tanpa membandingkan ke konfirmasi password.
    - Menghapus pembersihan `_confirmPasswordController.clear()` pasca submit sukses.

---

## 🔒 Penyembunyian Tombol Login Super Admin pada Halaman Login Utama (1 November 2026)
- **Kebutuhan**: Menghilangkan tombol link *"👑 Login Khusus Super Admin (Owner)"* pada halaman login utama ([index.html](file:///c:/laragon/www/project-billing/index.html)) untuk menjaga privasi, estetika antarmuka publik, serta keamanan portal Super Admin platform SaaS.
- **Perubahan yang Diterapkan**:
  - Menghapus link `superadmin-login.html` dari bagian bawah card login di [index.html](file:///c:/laragon/www/project-billing/index.html).
  - Halaman login Super Admin tetap aktif dan aman, dapat diakses langsung oleh Owner melalui URL `superadmin-login.html`.

---

## 📊 Implementasi Export PDF & Excel Riil pada Laporan Mobile (2 November 2026)
- **Kebutuhan**: Memperbaiki fungsi tombol **Export PDF** dan **Export Excel** pada halaman Laporan aplikasi mobile ([admin_reports_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/reports/presentation/pages/admin_reports_page.dart)) yang sebelumnya hanya menyalin teks mentah ke papan klip (*clipboard*), agar benar-benar mengunduh dan menghasilkan file dokumen asli (PDF dan Excel/CSV) ke penyimpanan perangkat pengguna serta dapat langsung dibuka.
- **Perubahan yang Diterapkan**:
  1. **Penambahan Dependensi ([pubspec.yaml](file:///c:/laragon/www/project-billing/mobile/pubspec.yaml))**:
     - Menambahkan paket `pdf: ^3.13.1` untuk membuat dokumen PDF multi-halaman berformat A4 dengan tata letak profesional.
     - Menambahkan paket `open_filex: ^5.0.0` untuk membuka langsung file dokumen yang telah diunduh menggunakan aplikasi default pada perangkat (PDF Viewer, Microsoft Excel, Google Sheets, WPS Office).
  2. **Pengembangan File Helper ([csv_file_helper.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/utils/csv_file_helper.dart))**:
     - Menambahkan method `saveBytes` dan `savePdf` untuk menyimpan file biner (PDF/dokumen) ke folder *Download* perangkat via `FilePicker.platform.saveFile` dengan fallback ke direktori `/storage/emulated/0/Download` dan `getDownloadsDirectory()`.
     - Menambahkan method `openFile` untuk membuka file secara instan menggunakan `OpenFilex`.
  3. **Layanan Pembuatan Dokumen PDF ([report_pdf_service.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/services/report_pdf_service.dart))**:
     - Membuat dokumen PDF A4 formal dan rapi mencakup:
       - Header ISP dengan nama aplikasi/toko dinamis dari `app_settings` dan waktu cetak.
       - Kotak kartu ringkasan keuangan (Total Pendapatan Lunas, Total Pengeluaran, Pendapatan Bersih, Total Belum Bayar, Total Cicilan).
       - Tabel rincian seluruh data transaksi (No, Tanggal, Nama/Keterangan, Tipe, Metode, Status, Nominal) bergaris dan berbayang rapi dengan penomoran halaman otomatis.
  4. **Pembaruan Halaman Laporan ([admin_reports_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/reports/presentation/pages/admin_reports_page.dart))**:
     - **Export PDF (`_exportToPDF`)**: Mengambil nama tenant/bisnis secara dinamis via query `app_settings` / `tenants`, menghasilkan dokumen PDF nyata berheader nama tenant melalui `ReportPdfService`, menyimpannya ke folder *Download* dengan nama file `Laporan_Keuangan_{NamaTenant}_{Tanggal}.pdf`, menampilkan notifikasi SnackBar hijau dengan tombol aksi *"BUKA"*, dan otomatis membuka file PDF tersebut.
     - **Export Excel (`_exportToExcel`)**: Mengambil nama tenant secara dinamis, menghasilkan file Excel/CSV berstandar UTF-8 BOM (`\uFEFF`) lengkap dengan nama tenant, kolom header, dan ringkasan keuangan di bagian bawah, menyimpannya ke folder *Download* dengan nama file `Laporan_Keuangan_{NamaTenant}_{Tanggal}.csv`, menampilkan SnackBar dengan tombol *"BUKA"*, serta otomatis membukanya di aplikasi spreadsheet.

---

## 🌐 Penyesuaian Nama Tenant & Perbaikan Filter Laporan Web (2 November 2026)
- **Kebutuhan**: Memastikan laporan pada versi web ([laporan.html](file:///c:/laragon/www/project-billing/laporan.html) & [laporan.js](file:///c:/laragon/www/project-billing/laporan.js)) aman, filter berfungsi presisi dan seragam dengan aplikasi mobile, serta nama file dan header unduhan PDF/Excel mencantumkan nama tenant secara dinamis.
- **Masalah yang Ditemukan & Diperbaiki**:
  1. **Nama Tenant Dinamis pada Export PDF & Excel**:
     - Sebelumnya nama file unduhan masih generik (`Laporan_Keuangan_YYYY-MM-DD.pdf / .xlsx`) dan kop PDF belum memuat nama usaha tenant.
     - Ditambahkan helper `fetchTenantName()` yang mengambil identitas tenant dari cache `localStorage` (`app_settings`), tabel `app_settings` (Supabase), atau tabel `tenants`.
     - Nama file unduhan PDF & Excel kini menjadi: `Laporan_Keuangan_{NamaTenant}_{Tanggal}.pdf` dan `Laporan_Keuangan_{NamaTenant}_{Tanggal}.xlsx`.
     - Dokumen PDF kini memiliki kop resmi dengan nama tenant, subjudul *"LAPORAN KEUANGAN & ARUS KAS"*, serta waktu cetak.
     - File Excel memuat baris identitas Nama ISP/Tenant dan Waktu Cetak pada lembar *"Ringkasan"*.
  2. **Presisi Filter Periode & Tanggal**:
     - Filter periode pada tagihan kini memeriksa tanggal pembayaran riil (`paid_at`) atau tanggal dibuat (`created_at`) sehingga arus kas uang masuk pada bulan bersangkutan tercatat akurat.
     - Perhitungan batas tanggal (3 bulan, 6 bulan, bulan lalu) diperbaiki agar tidak memutasi objek `Date` acuan secara *in-place*.
  3. **Penyesuaian Pengeluaran saat Filter Spesifik Aktif**:
     - Saat pengguna memfilter status tagihan tertentu (misal: "Belum Bayar", "Lunas", "Cicilan"), metode pembayaran ("Cash/Transfer"), atau mencari nama pelanggan tertentu, pengeluaran operasional otomatis disembunyikan (`filteredExpenses = []`) agar tidak mengacaukan rincian dan perhitungan tagihan spesifik (seragam dengan aplikasi mobile).
     - Tombol *Reset Filter* kini mengembalikan `filteredExpenses` ke kondisi utuh.
  4. **Perbaikan Urutan Inisialisasi Ringkasan**:
     - Memperbaiki deklarasi `totalInstallmentValue` sebelum `totalPendapatanValue` di fungsi `updateSummary()` untuk mencegah potensi error *Temporal Dead Zone (TDZ)* pada JavaScript ES module.

---

## 🖨️ Perbaikan Struk Kasir Thermal (Header Tenant, Status Lunas/Cicilan & Footer Dinamis) (2 November 2026)
- **Kebutuhan**:
  1. Header struk masih default *"WIFI BILLING SYSTEM"* dan ukuran teks terlalu besar sehingga terpotong menjadi 2 baris canggung (`WIFI BILLING SYS` / `TEM`).
  2. Status tagihan pada struk tercetak *"BELUM BAYAR"* padahal tagihan baru saja dilunasi atau dibayar cicilan.
  3. Menyediakan pengaturan Catatan/Pesan Footer Struk yang dinamis di sistem (misal jika ada gangguan hubungi nomor tertentu) baik di aplikasi Mobile maupun Web.
- **Perubahan yang Diterapkan**:
  1. **Proporsionalitas Header Nama Tenant ([thermal_printer_service.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/services/thermal_printer_service.dart) & [receipt-printer.js](file:///c:/laragon/www/project-billing/receipt-printer.js))**:
     - Mengubah ukuran font nama tenant pada kertas 58mm menjadi normal-width bold (`PosTextSize.size1`), sehingga dapat memuat hingga 32 karakter dalam satu baris tanpa terpotong atau membungkus canggung.
     - Menyediakan penyesuaian otomatis untuk kertas 80mm.
     - Pada Web ESC/POS, menghilangkan flag double-width (`GS ! 0x00`) agar cetakan Bluetooth dari browser rapi dan tidak meluber.
  2. **Resolusi Status Pembayaran & Sisa Tagihan**:
     - **Penyebab Masalah**: Pada [admin_invoices_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/invoices/presentation/pages/admin_invoices_page.dart), objek `invoice` yang dikirim ke fungsi cetak setelah dialog konfirmasi pembayaran masih memuat status lama (`unpaid`). Selain itu, `ispName`, `ispPhone`, dan `ispAddress` sebelumnya tidak diteruskan ke service printer.
     - **Perbaikan**:
       - Di `_confirmPayment`: Membuat objek `updatedInvoice` yang sudah terisi status baru (`paid` atau `partially_paid`), nominal bayar baru, dan metode bayar, lalu meneruskannya ke `_printReceipt`.
       - Di `_printReceipt`: Mengambil identitas nama brand tenant (`app_settings` / `tenants`), nomor WhatsApp, alamat kantor, serta footer struk secara dinamis dari database, lalu mengirimkannya ke `printerService.printInvoiceReceipt`.
       - Di `thermal_printer_service.dart` & `receipt-printer.js`: Menambahkan logika perlindungan matematis otomatis (`actualPaid >= totalAmount` => `LUNAS`, `actualPaid > 0 && actualPaid < totalAmount` => `CICILAN` beserta pencetakan baris *Sisa Tagihan*).
  3. **Pesan Footer Struk Dinamis (Mobile & Web)**:
     - **Mobile ([printer_settings_modal.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/printer_settings_modal.dart))**:
       - Menambahkan Card *"Pesan Footer Struk"* lengkap dengan form input dan tombol *"Simpan Footer"*.
       - Tersimpan secara lokal di `SharedPreferences` (`thermal_printer_receipt_footer`) dan otomatis tersinkronisasi ke database Supabase `whatsapp_settings` (`setting_key = 'receipt_footer'`).
     - **Web ([app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html), [app-settings.js](file:///c:/laragon/www/project-billing/app-settings.js), [receipt-printer.js](file:///c:/laragon/www/project-billing/receipt-printer.js))**:
       - Menambahkan Section *"Pengaturan Struk Kasir (Printer Thermal)"* dengan input textarea *"Catatan / Pesan Footer Struk"*.
       - Tersimpan ke `whatsapp_settings` (`receipt_footer`) dan cache `localStorage`.
       - Preview modal, cetak standar PC/browser iframe, cetak Bluetooth Web ESC/POS, dan salin nota WhatsApp kini mencetak teks footer dinamis multi-baris secara rapi.---

## 📍 Otomasi Lokasi Pelanggan (GPS 1-Klik, Smart Parser & Interactive Map Picker) (2 November 2026)
- **Kebutuhan**: Di lapangan, menginput angka Latitude dan Longitude secara manual sangat sulit dan merepotkan bagi teknisi/admin (rawan salah ketik angka desimal atau tanda minus). Dibutuhkan solusi otomatis yang praktis untuk teknisi saat di rumah pelanggan maupun admin saat di kantor menerima share-loc WhatsApp.
- **Solusi & Perubahan yang Diterapkan**:
  1. **Aplikasi Mobile (Flutter)**:
     - **Komponen Khusus ([customer_location_picker_widget.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/widgets/customer_location_picker_widget.dart))**:
       - **Tombol "📍 Lokasi Saya (GPS)"**: Menggunakan sensor perangkat via `geolocator`. Melakukan pengecekan aktifasi GPS, izin lokasi (*runtime permissions*), dan mengambil koordinat dengan presisi tinggi (*LocationAccuracy.high*) dalam 1 klik. Menampilkan badge akurasi (misal: `±3.5 m`).
       - **Tombol "📋 Tempel WA/Maps" (Smart Parser)**: Otomatis membaca teks/link dari Clipboard atau dialog modal. Mampu mengekstrak koordinat dari link Google Maps (`https://maps.google.com/?q=...` atau `@lat,lng`), chat WhatsApp, hingga teks koordinat mentah.
       - **Aksi "🗺️ Lihat Maps"**: Jika koordinat sudah terisi, tombol cepat ini membuka Google Maps via `url_launcher` (`geo:lat,lng` atau URL browser) agar teknisi dapat memverifikasi visual satelit posisi rumah secara instan.
       - Menyediakan tombol hapus koordinat cepat jika ingin mengulang.
     - **Integrasi Halaman**:
       - Diterapkan pada Form Tambah Pelanggan ([customer_form_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_form_page.dart)).
       - Diterapkan pada Form Edit Pelanggan ([customer_edit_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/customers/presentation/pages/customer_edit_page.dart)).
  2. **Aplikasi Web**:
     - **Antarmuka Form ([pelanggan.html](file:///c:/laragon/www/project-billing/pelanggan.html) & [mobile/www/pelanggan.html](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.html))**:
       - Menambahkan tombol aksi cepat: **"📍 Ambil Lokasi Saya"** dan **"🗺️ Pilih di Peta"**.
       - Menyediakan kotak input cepat: **"Tempel link Maps / share loc WA di sini..."** dengan tombol *Tempel* otomatis.
       - Menampilkan status titik koordinat dan tombol preview link **"Lihat di Maps ↗"**.
       - Menambahkan **Modal Map Picker Interaktif** berbasis Leaflet & OpenStreetMap (gratis tanpa API key), memungkinkan pengguna menggeser pin lokasi (*drag & drop*) langsung ke atap rumah pelanggan.
     - **Logika JavaScript ([pelanggan.js](file:///c:/laragon/www/project-billing/pelanggan.js) & [mobile/www/pelanggan.js](file:///c:/laragon/www/project-billing/mobile/www/pelanggan.js))**:
       - `initLocationPicker()`: Mengelola event GPS browser (`navigator.geolocation`), event paste/input cerdas, dan interaksi peta Leaflet.
       - `parseLocationInput(text)`: Regex parser untuk mengekstrak latitude dan longitude dari beragam format URL Google Maps dan teks chat.
       - `updateLocationPreview()`: Sinkronisasi tampilan status dan tautan ke Google Maps.
       - Notifikasi toast non-intrusive (`showLocationToast`) memberikan umpan balik langsung tanpa membekukan antarmuka pengguna.
---


---

## 🚀 Implementasi Landing Page Registrasi Tenant & Relokasi Halaman Login (2 November 2026)
- **Kebutuhan**:
  1. Membuat Landing Page publik yang modern, responsif di semua perangkat (Desktop, Tablet, Mobile), dan informatif untuk memperkenalkan produk WiFi Billing System serta memfasilitasi registrasi calon tenant baru.
  2. Menyediakan 4 tingkatan paket harga yang realistis dan terjangkau untuk pengusaha RT/RW Net: Free Trial (Rp 0), Starter (Rp 25.000/bln), Pro (Rp 50.000/bln), dan Unlimited (Rp 99.000/bln).
  3. Mengakomodasi alur pembayaran langganan manual via QRIS dan transfer DANA (089609497390 a.n. Taufiq Aziz) dengan konfirmasi otomatis via WhatsApp ke 6281914170701 untuk persetujuan Super Admin.
  4. Menyediakan tombol unduh langsung 1-klik file APK Android ([wifibilling.apk](file:///c:/laragon/www/project-billing/wifibilling.apk)) berukuran 77 MB di root direktori tanpa pihak ketiga.
  5. Menampilkan panduan onboarding 4 langkah awal penggunaan bagi tenant baru.
  6. Memindahkan form login utama dari index.html ke [login.html](file:///c:/laragon/www/project-billing/login.html).
- **Perubahan yang Diterapkan**:
  1. **Relokasi Halaman Login ([login.html](file:///c:/laragon/www/project-billing/login.html))**:
     - Form login dari index.html dipindahkan secara utuh ke login.html, lengkap dengan tombol intip password dan dukungan login via Email maupun ID Pelanggan.
     - Menyelaraskan seluruh fungsi redirect autentikasi ([auth.js](file:///c:/laragon/www/project-billing/auth.js), [profile.js](file:///c:/laragon/www/project-billing/profile.js), [pelanggan_profile.js](file:///c:/laragon/www/project-billing/pelanggan_profile.js), [register.html](file:///c:/laragon/www/project-billing/register.html), [superadmin-login.html](file:///c:/laragon/www/project-billing/superadmin-login.html)) ke login.html.
  2. **Pengembangan Landing Page Baru ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - **Navbar Responsif**: Dilengkapi tombol pintas menu, tombol unduh APK, tombol Masuk, dan Daftar Baru.
     - **Hero Section & Showcase Interaktif**:
       - Menampilkan headline jujur dan ramah: *"Kelola Tagihan WiFi RT/RW Net Jadi Mudah, Tinggalkan Catatan Excel yang Ribet"*.
       - Dilengkapi tab interaktif frame smartphone untuk menampilkan screenshot aplikasi asli ([ss_dashboard.webp](file:///c:/laragon/www/project-billing/assets/ss_dashboard.webp), [ss_tagihan.webp](file:///c:/laragon/www/project-billing/assets/ss_tagihan.webp), [ss_pelanggan.webp](file:///c:/laragon/www/project-billing/assets/ss_pelanggan.webp)), serta mockup struk thermal digital berbasis CSS murni berstatus LUNAS.
     - **Problem vs Solution**: Perbandingan jelas antara cara manual (buku/Excel) vs otomasi WiFi Billing System.
     - **Fitur Unggulan**: Kartu penjelasan cetak struk Bluetooth, GPS 1-klik, nota WhatsApp, portal pelanggan, dan laporan keuangan.
     - **Panduan 4 Langkah Awal**: Alur terstruktur (Buat Paket -> Atur Pembayaran -> Input Pelanggan -> Tagih & Cetak).
     - **Tabel Harga 4 Paket**: Kartu pilihan paket lengkap dengan tombol pendaftaran modal terintegrasi Supabase Auth.
     - **Modal Registrasi & Pembayaran**:
       - Form registrasi instan yang terhubung langsung dengan Supabase Trigger `handle_new_user` untuk pembuatan tenant otomatis.
       - Modal pembayaran menampilkan barcode [qris_owner.jpg](file:///c:/laragon/www/project-billing/assets/qris_owner.jpg), tombol salin nomor DANA, dan tombol konfirmasi instan WhatsApp berpesan dinamis.
     - **Download Banner**: Tombol download instan file APK rilis [wifibilling.apk](file:///c:/laragon/www/project-billing/wifibilling.apk).


---

## ⚡ Monitoring Jatuh Tempo, Otomasi WhatsApp Gateway Fonnte, & Pembaruan Super Admin (2 November 2026)
- **Kebutuhan**:
  1. Pemilik (Super Admin) membutuhkan visibilitas cepat untuk memantau masa aktif langganan seluruh tenant (klien RT/RW Net), terutama mitra yang mendekati jatuh tempo (H-7) atau sudah kedaluwarsa (expired).
  2. Implementasi pengiriman notifikasi WhatsApp otomatis terintegrasi menggunakan WhatsApp Gateway Fonnte API (`token: q3yqhiRwa2UXzpwGydZ2`) saat persetujuan akun baru, perpanjangan langganan, maupun pengingat jatuh tempo.
  3. Memastikan URL login tenant yang di-generate oleh sistem otomatis mengarah ke `login.html?t=slug` (bukan `index.html`), serta bersifat dinamis mengikuti domain hosting/custom domain (misal `https://wifibilling.my.id/login.html?t=...` atau `http://localhost/project-billing/login.html?t=...`).
  4. Menyediakan antarmuka perpanjangan masa aktif (renewal) yang praktis dengan tombol pintas durasi (`+1 Bulan`, `+3 Bulan`, `+1 Tahun`, `Lifetime`, atau custom Datepicker).
- **Perubahan yang Diterapkan**:
  1. **Kartu Statistik & Filter Status Jatuh Tempo ([superadmin.html](file:///c:/laragon/www/project-billing/superadmin.html) & [superadmin.js](file:///c:/laragon/www/project-billing/superadmin.js))**:
     - Mengubah kartu statistik ke-4 menjadi **"Jatuh Tempo (H-7)"** dengan penanda jumlah mitra yang mendekati jatuh tempo dan badge kedaluwarsa (`X expired`). Kartu ini dapat diklik langsung untuk memfilter daftar tenant secara instan.
     - Menambahkan opsi filter status: `⏳ Mau Jatuh Tempo (≤ 7 Hari)` dan `🔴 Sudah Kedaluwarsa` pada dropdown filter.
     - Fungsi kalkulasi sisa hari `getExpiryInfo(isoStr)` yang menghitung selisih tanggal secara presisi, membedakan status: *Lifetime*, *Kedaluwarsa*, *Habis Hari Ini*, *Sisa ≤ 3 hari (Kritis)*, *Sisa ≤ 7 hari (Peringatan)*, dan *Aktif Normal*.
  2. **Tabel & Kartu Mobile dengan Aksi Cepat**:
     - Menampilkan badge visual status masa aktif yang informatif dan berwarna pada kolom Status & Masa Aktif.
     - Menambahkan tombol aksi baru pada setiap baris desktop dan kartu mobile:
       - **[ ➕ Perpanjang ]**: Membuka modal perpanjangan masa aktif langganan.
       - **[ 📲 Ingatkan WA ]**: Membuka modal pengingat tagihan langganan via WhatsApp.
       - **[ ⚙️ Edit ]**: Mengubah konfigurasi kuota dan data tenant.
       - **[ 📋 Salin ]**: Menyalin kredensial lengkap mitra beserta tautan login dinamis `login.html?t=slug`.
       - **[ 🗑️ Hapus ]**: Menghapus mitra beserta auth user.
  3. **Modal Perpanjangan Langganan (`#modal-renew-tenant`)**:
     - Dilengkapi informasi paket aktif dan masa aktif saat ini.
     - Tombol pintas durasi 1-klik: `+1 Bulan`, `+3 Bulan`, `+1 Tahun`, dan `♾️ Lifetime` yang secara otomatis mengakumulasi tanggal kedaluwarsa baru dari sisa hari yang masih ada.
     - Input nomor WhatsApp mitra untuk pengiriman konfirmasi perpanjangan.
     - Checkbox otomatisasi pengiriman pesan WhatsApp via Fonnte API (`sendFonnteMessage`) yang mengirimkan konfirmasi pembayaran, masa aktif baru, dan link login aplikasi secara instan ke WhatsApp mitra.
  4. **Modal Pengingat Jatuh Tempo WhatsApp (`#modal-remind-wa`)**:
     - Menyediakan template pesan WhatsApp sopan dan profesional yang memuat sisa hari aktif, tanggal jatuh tempo, rincian nomor pembayaran DANA (`089609497390 a.n. Taufiq Aziz`), dan kontak konfirmasi (`0819-1417-0701`).
     - Teks pesan dapat disunting langsung sebelum dikirim.
     - Tombol aksi: **"🚀 Kirim via Fonnte"** untuk pengiriman API instan, dan opsi cadangan **"💬 Buka WhatsApp Web"** via `wa.me`.
  5. **Integrasi Notifikasi WhatsApp pada Pendaftaran & Edit Mitra**:
     - Form Tambah Mitra Baru (`form-add-tenant`) dan Edit Mitra (`form-edit-tenant`) kini dilengkapi input nomor WhatsApp mitra dan opsi pengiriman notifikasi otomatis via Fonnte saat akun pertama kali diaktifkan atau statusnya diubah.
  6. **Perbaikan Tipografi Headline Landing Page ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - Memperbaiki pembagian pemotongan kata judul *"Harga Murah, Pas untuk Kantong <span class="whitespace-nowrap">RT/RW Net</span>"* agar kata "Net" tidak turun sendirian ke baris baru pada semua resolusi layar.
  7. **Perbaikan Scroll Modal Super Admin ([superadmin.html](file:///c:/laragon/www/project-billing/superadmin.html))**:
     - Memperbaiki layout dialog pada seluruh modal (`modal-edit-tenant`, `modal-add-tenant`, `modal-renew-tenant`, `modal-remind-wa`):
       - Menetapkan tinggi maksimal `max-h-[90vh]` dan `overflow-y-auto` pada form body agar dapat di-scroll lancar pada resolusi layar apa pun.
       - Memasang header tetap (*flex-shrink-0*) dan tombol footer aksi (*sticky bottom-0*) sehingga tombol "Batal" dan "Simpan Perubahan" selalu terlihat dan mudah diakses tanpa terpotong.
  8. **Perbaikan Scroll Modal Pembayaran & Registrasi Landing Page ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - Memperbaiki layout dialog pada `#modal-payment` (QRIS & DANA) dan `#modal-register`:
       - Mengatur `max-h-[90vh]` dan `overflow-y-auto` pada body modal sehingga QRIS, DANA, dan detail tagihan dapat di-scroll dengan sangat leluasa tanpa terpotong di layar laptop maupun smartphone.
       - Header judul terkunci di atas (*flex-shrink-0*), dan tombol aksi "Konfirmasi Pembayaran via WhatsApp" dibuat melayang (*sticky bottom-0*) di bagian bawah agar selalu terlihat dan mudah ditekan.
       - Menambahkan event klik backdrop untuk menutup modal secara instan.


---

## 🚀 Perbaikan Registrasi Paket SaaS & Otomasi Dual Notifikasi WhatsApp Fonnte (2 November 2026)
- **Kebutuhan**:
  1. Memperbaiki masalah saat calon mitra mendaftar memilih paket Starter (atau paket berbayar lainnya seperti Pro dan Unlimited) di halaman depan ([index.html](file:///c:/laragon/www/project-billing/index.html)), tetapi pada database dan dasbor Super Admin akun yang terbentuk malah masuk ke paket *Free Trial* (kuota 25 pelanggan).
  2. Mengimplementasikan pengiriman notifikasi WhatsApp otomatis dua arah (dual automated notification) menggunakan API Fonnte (`token: q3yqhiRwa2UXzpwGydZ2`):
     - **Ke Calon Mitra / Klien** (pada nomor WhatsApp yang didaftarkan): Memberikan konfirmasi pendaftaran berhasil, rincian paket yang dipilih, email login, dan URL login langsung tenant `login.html?t=slug`.
     - **Ke Owner / Super Admin** (pada nomor WhatsApp `6281914170701`): Memberikan pemberitahuan secara *realtime* setiap ada mitra baru yang mendaftar, memuat nama usaha, nama pemilik, nomor WhatsApp, email login, paket SaaS yang dipilih, tanggal daftar, dan link langsung ke dasbor Super Admin.
- **Penyebab Masalah (Root Cause)**:
  - Pada trigger database PostgreSQL `public.handle_new_user()`, query pemilihan paket sebelumnya di-hardcode:
    ```sql
    SELECT id, COALESCE((features ->> 'trial_days')::int, 14)
      INTO v_plan_id, v_trial_days
    FROM public.saas_plans
    WHERE slug = 'free-trial'
    LIMIT 1;
    ```
    Sehingga paket apa pun yang dipilih klien saat registrasi diabaikan dan selalu dipaksa ke `free-trial`.
- **Perubahan yang Diterapkan**:
  1. **Pembaruan Trigger Database PostgreSQL ([supabase/migrations/2026110201_fix_handle_new_user_plan_selection.sql](file:///c:/laragon/www/project-billing/supabase/migrations/2026110201_fix_handle_new_user_plan_selection.sql) & [Database.sql](file:///c:/laragon/www/project-billing/Database.sql))**:
     - Memperbarui fungsi `public.handle_new_user()` untuk membaca parameter `plan_slug` atau `plan_name` dari `raw_user_meta_data`.
     - Melakukan normalisasi slug paket (`starter`, `pro`, `unlimited`, dengan default fallback `free-trial`).
     - Menyimpan `plan_id` yang sesuai ke dalam tabel `tenants` (Starter kuota 100, Pro kuota 500, Unlimited tanpa batas).
     - Menyimpan nomor telepon WhatsApp pendaftar ke `tenants.company_phone` dan `profiles.whatsapp_number`.
     - Memperbarui tenant `Selinggonet` yang sebelumnya terdaftar dengan paket Free Trial menjadi paket `Starter` (kuota 100 pelanggan).
  2. **Pembaruan Alur Pendaftaran Landing Page ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - Menambahkan atribut `data-plan-slug` pada seluruh tombol pilihan paket di tabel harga (`free-trial`, `starter`, `pro`, `unlimited`).
     - Menambahkan field tersembunyi `#reg-plan-slug` pada form pendaftaran.
     - Mengirimkan `plan_slug` dan `phone` bersama dengan `plan_name` pada saat `supabase.auth.signUp()`.
     - Mengambil `slug` tenant yang baru saja dibuat dari database untuk menghasilkan tautan login langsung (`login.html?t=slug`).
     - Mengirimkan notifikasi pesan WhatsApp otomatis ke **Calon Mitra** dan ke **Owner (`6281914170701`)** secara paralel melalui API Fonnte via `Promise.allSettled`.
     - Memperbarui tautan tombol konfirmasi WhatsApp di modal pembayaran agar secara dinamis menyertakan rincian lengkap pendaftaran.

  3. **Penyempurnaan Modal Dialog (Solid Docked Footer & Anti-Bolong)**:
     - Merestrukturisasi container modal edit tenant di Super Admin (`#modal-edit-tenant`) dan modal pembayaran di Landing Page (`#modal-payment`) menjadi tata letak flex bertingkat:
       - Kontainer luar: `max-h-[90vh] flex flex-col overflow-hidden rounded-3xl`.
       - Kontainer body: `flex-1 min-h-0 overflow-y-auto p-6 space-y-4` (scrollable penuh dan lancar di mobile/laptop).
       - Kontainer footer: `px-6 py-4 bg-slate-50 border-t border-slate-100 flex-shrink-0` yang terpasang kokoh di bagian bawah (*docked*), mengeliminasi celah tembus pandang ("footer bolong") yang sebelumnya tampak saat di-scroll.
  4. **Konfigurasi Autentikasi Instan Tanpa Verifikasi Email (Instant Sign-in)**:
     - Menonaktifkan fitur `Confirm email` pada konfigurasi Supabase Auth (`Sign In / Providers -> User Signups`).
     - Calon mitra yang mendaftar dapat langsung login seketika tanpa harus menunggu atau membuka tautan verifikasi email, sementara kredensial login (Email, Password, Tenant Slug, dan Link Login Khusus Mitra) langsung terkirim otomatis ke WhatsApp klien dan WhatsApp Owner.


---

## 🔒 Sistem Masa Tenggang (Grace Period 3 Hari) & Penguncian Total Hari ke-4 SaaS (2 November 2026)
- **Kebutuhan**:
  1. Mencegah kerugian platform SaaS di mana mitra RT/RW Net yang masa aktifnya telah habis tetap menggunakan sistem secara gratis tanpa memperpanjang langganan bulanan.
  2. Memberikan toleransi manusiawi (**Masa Tenggang / Grace Period**) selama 3 hari pertama setelah jatuh tempo agar mitra memiliki kesempatan untuk mentransfer pembayaran.
  3. Mengunci sistem secara total (**Hard Lock**) mulai **Hari ke-4** setelah jatuh tempo atau jika status tenant diubah menjadi `suspended` oleh Super Admin.
- **Perubahan yang Diterapkan**:
  1. **Tingkat Database PostgreSQL ([supabase/migrations/2026110202_update_grace_period_is_tenant_active.sql](file:///c:/laragon/www/project-billing/supabase/migrations/2026110202_update_grace_period_is_tenant_active.sql) & [Database.sql](file:///c:/laragon/www/project-billing/Database.sql))**:
     - Memperbarui fungsi `public.is_tenant_active(check_tenant_id UUID)`:
       ```sql
       t.subscription_expires_at IS NULL OR t.subscription_expires_at > (NOW() - INTERVAL '3 days')
       ```
     - Selama hari 1 s/d 3 lewat jatuh tempo, tenant masih berstatus aktif untuk penegakan kuota dasar.
     - Mulai hari ke-4 (`> NOW() - INTERVAL '3 days'`), `is_tenant_active()` bernilai `FALSE`, otomatis memblokir penambahan pelanggan (`profiles_check_tenant_quota`) dan pembuatan tagihan bulanan (`generate_monthly_invoices`).
  2. **Tingkat Frontend Aplikasi Tenant ([auth.js](file:///c:/laragon/www/project-billing/auth.js))**:
     - Menambahkan fungsi pemantau langganan `enforceTenantSubscription(tenantId, user)` yang otomatis dieksekusi setiap kali admin tenant membuka halaman aplikasi apa pun via `requireRole('ADMIN')`.
     - **Masa Tenggang (Hari H s/d Hari ke-3)**:
       - Memunculkan banner peringatan dinamis di bagian paling atas layar (`#saas-grace-period-banner`):
         - Menghitung sisa hari masa tenggang (contoh: *"Masa tenggang tersisa X hari lagi sebelum sistem terkunci total pada hari ke-4"*).
         - Tombol pintas **`[ 💳 Perpanjang Sekarang ]`** yang membuka pop-up rincian pembayaran QRIS BCA/e-wallet, nomor DANA `089609497390 a.n. Taufiq Aziz`, dan tombol konfirmasi otomatis WhatsApp.
     - **Penguncian Total / Hard Lock (Hari ke-4 ke atas atau Status 'Suspended')**:
       - Mengunci scroll halaman (`document.body.style.overflow = 'hidden'`) dan menampilkan layar penuh tak dapat ditutup (`#saas-hard-lock-overlay`, `z-[999999]`) berlatar belakang gelap dengan efek blur.
       - Membekukan seluruh navigasi dan tombol operasional.
       - Menyajikan kartu informasi tagihan perpanjangan, instruksi scan QRIS, tombol salin nomor DANA, tombol konfirmasi instan via WhatsApp ke nomor Owner (`0819-1417-0701`), serta opsi keluar akun (*logout*).


---

## 💰 Penyesuaian Harga Paket SaaS Ekonomis & Terjangkau (2 November 2026)
- **Kebutuhan**:
  - Menyesuaikan harga paket langganan SaaS RT/RW Net ke skema harga yang jauh lebih murah dan terjangkau (*entry barrier* sangat rendah) agar calon mitra RT/RW Net di daerah/kampung tertarik langsung mendaftar tanpa beban biaya awal.
- **Perubahan Harga Paket**:
  1. **Paket Starter (Maks 100 Pelanggan)**:
     - Dari sebelumnya Rp 25.000/bln ➡️ **Rp 10.000 / bulan** (hanya Rp 100 per pelanggan jika penuh).
  2. **Paket Pro (Maks 300–500 Pelanggan)**:
     - Dari sebelumnya Rp 50.000/bln ➡️ **Rp 25.000 / bulan**.
  3. **Paket Unlimited (Tanpa Batas Pelanggan)**:
     - Dari sebelumnya Rp 99.000/bln ➡️ **Rp 50.000 / bulan**.
- **Perubahan yang Diterapkan**:
  1. **Database PostgreSQL ([supabase/migrations/2026110203_update_saas_plan_prices_super_cheap.sql](file:///c:/laragon/www/project-billing/supabase/migrations/2026110203_update_saas_plan_prices_super_cheap.sql) & [Database.sql](file:///c:/laragon/www/project-billing/Database.sql))**:
     - Mengubah nilai `price_monthly` pada tabel `saas_plans` untuk seluruh baris paket (`starter` = 10000, `pro` = 25000, `unlimited` = 50000).
  2. **Landing Page ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - Memperbarui teks kartu harga dan atribut `data-price` pada tombol `.btn-select-plan`:
       - Starter: `Rp 10.000`, `data-price="10000"`
       - Pro: `Rp 25.000`, `data-price="25000"`
       - Unlimited: `Rp 50.000`, `data-price="50000"`
     - Menghasilkan perhitungan total tagihan dan teks template pesan WhatsApp konfirmasi transfer yang otomatis mengikuti harga baru.
  3. **Frontend Enforcement ([auth.js](file:///c:/laragon/www/project-billing/auth.js))**:
     - Memperbarui fallback nominal perpanjangan langganan menjadi Rp 10.000.


---

## 📝 Penambahan Teks Petunjuk Otomasi WhatsApp pada Template Pembayaran Web & Mobile (2 November 2026)
- **Kebutuhan**:
  - Menambahkan informasi petunjuk yang jelas dan komunikatif pada form **Template Pembayaran Lunas** dan **Template Pembayaran Cicilan** di halaman Pengaturan Aplikasi agar admin mitra memahami bahwa pesan tersebut akan otomatis dikirimkan ke nomor WhatsApp pelanggan hanya jika toggle *Notifikasi Otomatis* aktif dan *Fonnte API Token* telah diisi.
- **Bahasa Petunjuk yang Digunakan**:
  > 💡 **Info Pengiriman:** Pesan ini akan terkirim otomatis ke WhatsApp pelanggan saat status tagihan dicatat **Lunas** (atau **Cicilan**), asalkan tombol *Notifikasi Otomatis* aktif dan *Fonnte API Token* telah diisi.
- **Perubahan yang Diterapkan**:
  1. **Aplikasi Web ([app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html))**:
     - Menambahkan badge alert info box berwarna hijau lembut (`bg-emerald-50 border-emerald-200`) di bawah textarea Template Pembayaran Lunas.
     - Menambahkan badge alert info box berwarna amber lembut (`bg-amber-50 border-amber-200`) di bawah textarea Template Pembayaran Cicilan.
  2. **Aplikasi Mobile Flutter ([admin_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/settings/presentation/pages/admin_settings_page.dart))**:
     - Menambahkan kartu visual info box berlatar belakang `0xFFF0FDF4` (hijau) dan `0xFFFFFBEB` (amber) lengkap dengan icon petunjuk 💡 di bawah field input masing-masing template.


---

## 🖨️ Penyelarasan Pengaturan Catatan / Pesan Footer Struk Kasir di Mobile (2 November 2026)
- **Kebutuhan**:
  - Menyelaraskan form **Pengaturan Struk Kasir (Printer Thermal)** pada aplikasi **Mobile Android** ([admin_settings_page.dart](file:///c:/laragon/www/project-billing/mobile/lib/features/admin/settings/presentation/pages/admin_settings_page.dart)) agar identik 100% dengan tampilan dan fungsi yang ada pada aplikasi Web ([app-settings.html](file:///c:/laragon/www/project-billing/app-settings.html)).
- **Fitur yang Ditambahkan**:
  1. **Section Struk Kasir di Mobile**:
     - Menambahkan kartu section baru: **`Pengaturan Struk Kasir (Printer Thermal)`** berikon `Icons.receipt_long`.
     - Input textarea: **Catatan / Pesan Footer Struk** (`_receiptFooterController`).
     - Teks petunjuk: *"Pesan ini akan dicetak di bagian paling bawah struk thermal (kasir/Bluetooth) pada aplikasi web dan mobile."*.
  2. **Integrasi Data & Sinkronisasi Dua Arah**:
     - Terhubung ke database Supabase tabel `whatsapp_settings` dengan `setting_key: 'receipt_footer'`.
     - Otomatis memperbarui konfigurasi lokal perangkat melalui `ThermalPrinterService().setReceiptFooter(...)` saat tombol simpan ditekan, sehingga cetakan struk printer thermal Bluetooth langsung menggunakan pesan footer terbaru.


---

## 📱 Perbaikan Auto-Close Menu Hamburger Mobile Landing Page (2 November 2026)
- **Kebutuhan**:
  - Pada tampilan mobile di Landing Page ([index.html](file:///c:/laragon/www/project-billing/index.html)), ketika menu hamburger dibuka lalu salah satu menu diklik (seperti *"Tampilan"*, *"Fitur"*, *"Cara Memulai"*, *"Harga Paket"*, atau *"Daftar Tenant Baru"*), menu dropdown sebelumnya tidak menutup otomatis sehingga tetap menutupi layar dan menghalangi konten yang sedang dituju.
- **Perubahan yang Diterapkan**:
  1. **Event Listener Auto-Close ([index.html](file:///c:/laragon/www/project-billing/index.html))**:
     - Menambahkan handler klik pada seluruh tautan navigasi di dalam `#mobile-menu` agar secara otomatis menambahkan class `hidden` ke dropdown saat link diklik.
     - Dengan begitu, dropdown menu langsung menutup seketika saat diklik dan layar langsung menampilkan section yang dituju tanpa terhalang.
  2. **Smooth Scrolling**:
     - Menambahkan CSS `html { scroll-behavior: smooth; }` agar saat pengguna mengklik menu, halaman bergulir dengan animasi halus ke bagian yang dituju.


---

## 🔒 Penerapan Sistem Masa Tenggang (Grace Period 3 Hari) & Kunci Total (Hard Lock Hari ke-4) pada Aplikasi Mobile Flutter (2 November 2026)
- **Kebutuhan**:
  - Menyelaraskan sistem penegakan masa aktif langganan SaaS multi-tenant pada aplikasi Android Mobile ([mobile/](file:///c:/laragon/www/project-billing/mobile)) agar memiliki proteksi yang identik dengan aplikasi Web ([auth.js](file:///c:/laragon/www/project-billing/auth.js)).
  - Mencegah admin mitra/tenant yang belum memperpanjang langganan (melebihi masa tenggang toleransi) mengakses halaman tagihan, pelanggan, dan melakukan update lunas di aplikasi mobile.
- **Logika Penegakan (Sama Persis dengan Web & DB `is_tenant_active()`)**:
  - **Hari Normal**: `subscription_expires_at` masih berlaku atau `subscription_status == 'active'` tanpa tanggal berakhir (seumur hidup) $\rightarrow$ Seluruh fitur aplikasi dapat diakses secara normal.
  - **Masa Tenggang (Grace Period - Hari H s/d Hari ke-3 Jatuh Tempo)**:
    - Muncul banner peringatan mencolok (gradasi amber-merah) di bagian atas layar admin ([subscription_grace_banner.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/subscription_grace_banner.dart)).
    - Memberitahukan sisa hari toleransi sebelum akun dibekukan total pada hari ke-4.
    - Dilengkapi tombol `[ Perpanjang ]` yang membuka modal rincian pembayaran (QRIS Owner, nomor DANA `089609497390` a.n. Taufiq Aziz dengan tombol salin, dan tombol konfirmasi otomatis ke WhatsApp `6281914170701`).
  - **Kunci Total (Hard Lock - Hari ke-4 Jatuh Tempo ke Atas ATAU Status `suspended`)**:
    - Seluruh tampilan aplikasi digantikan dengan layar kunci penuh yang tidak dapat ditutup ([subscription_lock_overlay.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/subscription_lock_overlay.dart)).
    - Navigasi bawah (bottom navigation) disembunyikan/dinonaktifkan sepenuhnya.
    - Proteksi tombol kembali fisik Android via `PopScope(canPop: false)`.
    - Menampilkan informasi rincian tagihan paket (Starter Rp 10.000/bln, Pro Rp 25.000/bln, Unlimited Rp 50.000/bln), gambar QRIS Owner ([qris_owner.jpg](file:///c:/laragon/www/project-billing/mobile/assets/images/qris_owner.jpg)), transfer DANA, tombol konfirmasi WhatsApp langsung terisi pesan template, tombol `Cek Status Perpanjangan` (instant re-check tanpa perlu login ulang), serta tombol `Keluar Akun`.
- **Komponen & Arsitektur yang Dibuat**:
  1. **`TenantSubscriptionModel` ([tenant_subscription_model.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/models/tenant_subscription_model.dart))**:
     - Model representasi status langganan tenant, perhitungan `daysOverdue`, `isHardLocked`, `isGracePeriod`, dan `daysRemainingGrace`.
  2. **`tenantSubscriptionProvider` ([tenant_subscription_provider.dart](file:///c:/laragon/www/project-billing/mobile/lib/data/providers/tenant_subscription_provider.dart))**:
     - Riverpod `FutureProvider` yang secara real-time memeriksa profil admin, mencocokkan `tenant_id` ke tabel `tenants` dan tabel `saas_plans`.
  3. **`AdminScaffold` Integration ([admin_scaffold.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/widgets/admin_scaffold.dart))**:
     - Mengubah `AdminScaffold` menjadi `ConsumerWidget` yang memantau `tenantSubscriptionProvider`.
     - Jika `isHardLocked` $\rightarrow$ langsung merender `SubscriptionLockOverlay`.
     - Jika `isGracePeriod` $\rightarrow$ menyisipkan `SubscriptionGraceBanner` di atas body dengan `Column` dan `Expanded`.
  4. **Data Owner Global ([app_constants.dart](file:///c:/laragon/www/project-billing/mobile/lib/core/constants/app_constants.dart))**:
     - Menambahkan konfigurasi konstanta: `ownerDanaNumber = '089609497390'`, `ownerDanaName = 'Taufiq Aziz'`, dan `ownerWhatsApp = '6281914170701'`.


---

## 📲 Penyelarasan PWA & Perbaikan Tampilan Tagline Login (2 November 2026)
- **Status PWA (Progressive Web App)**:
  - PWA **tidak dihilangkan**; tetap aktif dengan `manifest.json`, `sw.js`, dan `pwa-installer.js`.
  - **Penyebab tombol install sebelumnya tidak muncul**:
    1. `sw.js` gagal meng-cache file karena ada referensi file lama yang sudah dihapus (`/assets/yourisp.png`), menyebabkan event `install` ditolak browser sehingga PWA dianggap invalid.
    2. Event `beforeinstallprompt` browser hanya terpicu jika aplikasi belum pernah di-install pada perangkat bersangkutan dan dibuka via HTTPS / localhost.
  - **Perbaikan yang Dilakukan**:
    1. Memperbarui cache versi `wifibilling-pwa-v2.0.0` pada [sw.js](file:///c:/laragon\www\project-billing\sw.js) menggunakan `Promise.allSettled` yang toleran.
    2. Menambahkan tombol eksplisit **`📲 Pasang Aplikasi (PWA)`** tepat di dalam kartu login ([login.html](file:///c:/laragon\www\project-billing\login.html)).
    3. Jika prompt otomatis browser belum siap atau di iPhone (Safari), tombol otomatis membuka modal panduan instalasi langkah demi langkah.
- **Tampilan Tagline di Halaman Login**:
  - Kolom **Tagline** pada *Pengaturan Aplikasi* (`app-settings.html`) bertuliskan *"Muncul di halaman login"*.
  - Sebelumnya elemen HTML dan renderer JavaScript-nya belum disambungkan ke halaman login.
  - Sekarang telah ditambahkan elemen `<p id="login-app-tagline">` pada [login.html](file:///c:/laragon\www\project-billing\login.html) dan disinkronkan otomatis oleh [apply-settings.js](file:///c:/laragon\www\project-billing\apply-settings.js). Tagline (seperti *"Internet Cepat & Tanpa Batas"*) kini langsung tampil tepat di bawah nama tenant di halaman login.


---

## 🏷️ Penyederhanaan Istilah "PWA" Menjadi Ramah Pengguna Awam (2 November 2026)
- Menghapus istilah teknis "PWA" dari seluruh antarmuka yang terlihat oleh pengguna biasa/admin:
  - Tombol pada [login.html](file:///c:/laragon\www\project-billing\login.html) diubah menjadi: **`📲 Install Aplikasi ke HP`**.
  - Judul modal dan pesan sukses pada [pwa-installer.js](file:///c:/laragon\www\project-billing\pwa-installer.js) diubah menjadi: *"Install Aplikasi ke HP"* dan *"Aplikasi berhasil dipasang di HP!"*.
  - Petunjuk di form pengaturan aplikasi ([app-settings.html](file:///c:/laragon\www\project-billing\app-settings.html) & [profile.html](file:///c:/laragon\www\project-billing\profile.html)) diubah dari *"Nama lengkap untuk title & PWA"* menjadi *"Nama lengkap untuk judul browser & aplikasi"*.


---

## 👑 PWA Standalone Khusus Portal Super Admin (2 November 2026)
- **Kebutuhan**:
  - Menyediakan kemampuan instalasi PWA khusus untuk Super Admin (Owner SaaS) agar dapat di-install terpisah menjadi aplikasi mandiri di HP atau Laptop/PC tanpa harus repot membuka browser dan mengetik alamat URL setiap saat.
- **Implementasi yang Diterapkan**:
  1. **Manifest PWA Khusus ([manifest-superadmin.json](file:///c:/laragon\www\project-billing\manifest-superadmin.json))**:
     - Nama: `Super Admin - WiFi Billing SaaS`
     - Short Name: `SuperAdmin`
     - Start URL: `superadmin-login.html`
     - Theme Color: `#090d16` (Dark Cyber Premium) & Background: `#070a12`.
     - Display: `standalone` (Tampil layaknya aplikasi native tanpa bar browser).
  2. **Dukungan Caching Service Worker ([sw.js](file:///c:/laragon\www\project-billing\sw.js))**:
     - Menambahkan rute `superadmin-login.html`, `superadmin-login.js`, `superadmin.html`, `superadmin.js`, dan `manifest-superadmin.json` ke daftar cache offline.
  3. **Tombol Install Cepat**:
     - Pada form login Super Admin ([superadmin-login.html](file:///c:/laragon\www\project-billing\superadmin-login.html)): tombol **`📲 Install Super Admin ke HP / Laptop`**.
     - Pada header dashboard Super Admin ([superadmin.html](file:///c:/laragon\www\project-billing\superadmin.html)): tombol **`📲 Install App`** di bilah navigasi atas.


---

## 📦 Build Ulang APK Rilis Android (2 November 2026)
- **Status Build**: Sukses 100% (`flutter build apk --release` via Gradle).
- **Hasil File**:
  - Lokasi: [wifibilling.apk](file:///c:/laragon\www\project-billing\wifibilling.apk) (Root direktori).
  - Ukuran: ~77.5 MB (81.234.344 bytes).
  - Waktu Build: 249.8 detik.
- **Fitur Baru yang Terpasang di APK Terbaru**:
  1. **Sistem Masa Tenggang & Kunci Total (Hard Lock)**:
     - Banner Masa Tenggang Hari 0–3 dengan tombol perpanjang, rincian biaya (Rp 10rb, 25rb, 50rb), QRIS, DANA `089609497390`, dan konfirmasi WhatsApp `6281914170701`.
     - Kunci Total Hari ke-4 ke atas dengan overlay penuh, tombol back dinonaktifkan, dan bottom navigation disembunyikan.
  2. **Pengaturan Struk Kasir (Printer Thermal)**:
     - Input pesan footer struk kasir yang tersinkronisasi ke printer Bluetooth & database `whatsapp_settings`.
  3. **Info Pengiriman Otomatis WhatsApp**:
     - Petunjuk Fonnte API Token & toggle notifikasi otomatis pada template lunas & cicilan.
