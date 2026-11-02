# Execution Plan: Transformasi Database ke SaaS Multi-Tenant (Billing RT/RW Net)

## 1. Konteks & Tujuan Proyek
Proyek ini adalah aplikasi Web/PWA manajemen Billing ISP / RT-RW Net berbasis **Vanilla JS + Supabase (PostgreSQL, Auth, Storage, Edge Functions)**. Saat ini, database masih menggunakan arsitektur **Single-Tenant** (satu pemilik usaha).

**Tujuan Utama:**
Merombak dan memigrasikan arsitektur database menjadi **SaaS Multi-Tenant** menggunakan pendekatan **Shared Database, Shared Schema** dengan isolasi `tenant_id` dan **Row Level Security (RLS)** ketat di PostgreSQL.

---

## 2. Instruksi Awal untuk AI Agent (Tahap Observasi)
Sebelum menulis atau mengubah kode apa pun, **BACA dan ANALISIS** file-file berikut di dalam repositori untuk memahami nama tabel, kolom, relasi, dan *trigger* yang sudah ada:
1. `Database.sql`
2. `skema_tabel.md`
3. `solusi.md`
4. Seluruh file di dalam `supabase/migrations/`:
   - `20250117_auto_create_profile.sql`
   - `20250118_whatsapp_settings.sql`
   - `20250121_genieacs_integration.sql`
   - `20261024_create_avatars_storage.sql`
   - `20261024_fix_whatsapp_settings.sql`
5. Seluruh kode di `supabase/functions/*/index.ts` untuk melihat bagaimana *service role* mengakses tabel.

---

## 3. Prinsip & Aturan Migrasi (Guardrails)
- **Zero Data Loss (Backward Compatibility):** Jangan menghapus data yang sudah ada. Buat satu *Default Tenant* (misal: `"Rivamnet Default"`) saat migrasi berjalan, lalu isi seluruh baris data lama yang belum memiliki `tenant_id` dengan ID dari *Default Tenant* tersebut sebelum memasang constraint `NOT NULL`.
- **Auto-Fill `tenant_id`:** Buat fungsi database `public.current_tenant_id()` yang mengambil nilai `tenant_id` dari JWT user atau tabel profil. Gunakan fungsi ini sebagai `DEFAULT public.current_tenant_id()` pada kolom `tenant_id` di setiap tabel operasional agar kueri `INSERT` dari *frontend* tidak mudah gagal jika belum menyertakan `tenant_id`.
- **Idempotent SQL:** Gunakan `IF NOT EXISTS`, `DROP POLICY IF EXISTS`, dan `CREATE OR REPLACE FUNCTION` agar skrip migrasi aman dijalankan berulang kali.
- **Indexing:** Wajib menambahkan `INDEX` pada setiap kolom `tenant_id` di semua tabel untuk menjaga performa kueri.

---

## 4. Tahapan Eksekusi Migrasi Database

### Fase 1: Pembuatan Tabel Inti SaaS (Core Multi-Tenant Tables)
Buat file migrasi baru `supabase/migrations/2026102701_create_saas_core_tables.sql` yang mencakup:

1. **Tabel `saas_plans` (Paket Langganan untuk Mitra RT/RW Net):**
   - `id` (UUID, Primary Key)
   - `name` (VARCHAR) — contoh: *Free Trial, Basic, Pro, Enterprise*
   - `slug` (VARCHAR, Unique)
   - `price_monthly` (NUMERIC)
   - `max_customers` (INTEGER) — batas maksimal pelanggan WiFi per tenant
   - `features` (JSONB) — flag fitur seperti `{"whatsapp_gateway": true, "genieacs": false, "custom_receipt": true}`
   - `is_active` (BOOLEAN)
   - `created_at`, `updated_at` (TIMESTAMPTZ)

2. **Tabel `tenants` (Data Mitra ISP / RT-RW Net):**
   - `id` (UUID, Primary Key)
   - `name` (VARCHAR, NOT NULL) — nama usaha WiFi
   - `slug` (VARCHAR, Unique, NOT NULL) — untuk identifikasi URL/kode unik mitra
   - `owner_id` (UUID, References `auth.users(id)`)
   - `plan_id` (UUID, References `saas_plans(id)`)
   - `subscription_status` (VARCHAR) — `'trial'`, `'active'`, `'past_due'`, `'suspended'`
   - `subscription_expires_at` (TIMESTAMPTZ)
   - `logo_url` (TEXT)
   - `qris_url` (TEXT)
   - `company_address` (TEXT)
   - `company_phone` (VARCHAR)
   - `created_at`, `updated_at` (TIMESTAMPTZ)

3. **Seed Data Awal:**
   - Masukkan 3 paket default ke `saas_plans` (*Starter*, *Pro*, *Unlimited*).
   - Masukkan 1 *Default Tenant* ke tabel `tenants` untuk menampung seluruh data eksisting di database saat ini.

---

### Fase 2: Injeksi `tenant_id` ke Seluruh Tabel Eksisting
Buat file migrasi `supabase/migrations/2026102702_add_tenant_id_to_existing_tables.sql`:

1. **Daftar Tabel yang Wajib Ditambahkan `tenant_id`:**
   Periksa nama tabel aktual di `Database.sql` dan `skema_tabel.md` (sesuaikan nama tabel dengan yang ada di skema asli), meliputi:
   - Tabel Profil / Users (`profiles` / `pelanggan`)
   - Tabel Paket Layanan Internet (`packages` / `paket`)
   - Tabel Tagihan (`invoices` / `tagihan`)
   - Tabel Pengeluaran (`expenses` / `pengeluaran`)
   - Tabel Metode Pembayaran (`payment_methods`)
   - Tabel Notifikasi (`notifications`)
   - Tabel Pengaturan Aplikasi (`app_settings`)
   - Tabel Pengaturan WhatsApp (`whatsapp_settings`)
   - Tabel Pengaturan GenieACS (`genieacs_settings`)

2. **Langkah Perubahan per Tabel:**
   - Tambahkan kolom `tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE`.
   - Update semua baris yang `tenant_id IS NULL` menjadi ID dari *Default Tenant*.
   - Ubah kolom `tenant_id` menjadi `NOT NULL` (kecuali pada tabel `profiles` jika user tersebut memiliki role `super_admin`).
   - Buat index: `CREATE INDEX IF NOT EXISTS idx_<nama_tabel>_tenant_id ON public.<nama_tabel>(tenant_id);`

3. **Penyesuaian Unique Constraint pada Tabel Pengaturan & Master:**
   - Pada tabel `app_settings`, `whatsapp_settings`, dan `genieacs_settings`, ubah constraint yang tadinya *singleton* (hanya 1 baris global) menjadi `UNIQUE (tenant_id)` sehingga setiap tenant memiliki tepat 1 baris konfigurasi masing-masing.
   - Jika ada kode pelanggan (`customer_code` / `id_pelanggan`) atau nama paket yang sebelumnya `UNIQUE` secara global, ubah menjadi *composite unique* `UNIQUE (tenant_id, customer_code)`.

---

### Fase 3: Fungsi Helper Auth, Role, & Trigger Otomatis
Buat file migrasi `supabase/migrations/2026102703_auth_helpers_and_triggers.sql`:

1. **Standarisasi Role:**
   Pastikan sistem mendukung 3 role utama:
   - `'super_admin'`: Pemilik platform SaaS (bisa melihat & mengelola semua `tenants`).
   - `'admin'` (atau `'tenant_admin'`): Pemilik/pengelola RT-RW Net (hanya mengelola data di dalam `tenant_id`-nya).
   - `'pelanggan'` (atau `'customer'`): Pelanggan WiFi akhir (hanya melihat data miliknya sendiri di dalam `tenant_id`-nya).

2. **Fungsi Helper RLS (Security Definer):**
   - `public.get_my_tenant_id() RETURNS UUID`: Mengambil `tenant_id` dari `(auth.jwt() -> 'app_metadata' ->> 'tenant_id')::uuid`, dengan *fallback* melakukan `SELECT tenant_id FROM public.profiles WHERE id = auth.uid()`.
   - `public.get_my_role() RETURNS TEXT`: Mengambil `role` dari JWT atau tabel `profiles`.
   - `public.is_super_admin() RETURNS BOOLEAN`: Mengembalikan `true` jika role user adalah `'super_admin'`.
   - `public.is_tenant_active(check_tenant_id UUID) RETURNS BOOLEAN`: Mengecek apakah `subscription_status` tenant masih `'active'` atau `'trial'` dan belum melewati `subscription_expires_at`.

3. **Set Default Value `tenant_id`:**
   - Pasang `ALTER TABLE <nama_tabel> ALTER COLUMN tenant_id SET DEFAULT public.get_my_tenant_id();` pada seluruh tabel operasional (paket, tagihan, pengeluaran, metode pembayaran, pengaturan, dll).

4. **Update Trigger `handle_new_user` (Menggantikan `20250117_auto_create_profile.sql`):**
   - Skenario A (Registrasi Mitra/Tenant Baru dari `register.js`): Jika `raw_user_meta_data->>'is_new_tenant' = 'true'`, trigger otomatis:
     1. Membuat baris baru di tabel `tenants` (menggunakan `company_name` dari metadata, paket *Free Trial*).
     2. Membuat baris di `profiles` dengan `role = 'admin'` dan `tenant_id` baru tersebut.
     3. Menginisialisasi baris default di `app_settings` dan `whatsapp_settings` untuk `tenant_id` baru tersebut.
     4. Menyimpan `tenant_id` dan `role` ke dalam `auth.users.raw_app_meta_data`.
   - Skenario B (Pembuatan Pelanggan dari Edge Function `create-customer`): Jika `raw_user_meta_data` atau `raw_app_meta_data` sudah membawa `tenant_id`, gunakan `tenant_id` tersebut untuk dimasukkan ke tabel `profiles` dengan `role = 'pelanggan'`.

---

### Fase 4: Isolasi Row Level Security (RLS) Multi-Tenant
Buat file migrasi `supabase/migrations/2026102704_multi_tenant_rls_policies.sql`:

Hapus *policy* RLS lama yang bersifat global, lalu terapkan *policy* baru pada setiap tabel:

1. **Tabel `tenants`:**
   - `super_admin` dapat melakukan `ALL` (`SELECT, INSERT, UPDATE, DELETE`).
   - `admin` dapat melakukan `SELECT` dan `UPDATE` hanya pada baris di mana `id = public.get_my_tenant_id()`.
   - `pelanggan` dapat melakukan `SELECT` terbatas (nama usaha, logo, QRIS, kontak) pada baris di mana `id = public.get_my_tenant_id()`.

2. **Tabel Operasional (`paket`, `tagihan`, `pengeluaran`, `payment_methods`, `notifications`):**
   - `super_admin`: Akses penuh (`public.is_super_admin()`).
   - `admin`: Akses penuh (`ALL`) untuk baris dengan `tenant_id = public.get_my_tenant_id()`.
   - `pelanggan`:
     - Pada `paket` dan `payment_methods`: Hanya `SELECT` di mana `tenant_id = public.get_my_tenant_id()`.
     - Pada `tagihan` dan `notifications`: Hanya `SELECT` di mana `tenant_id = public.get_my_tenant_id()` DAN milik `user_id` / `pelanggan_id` yang bersangkutan (`auth.uid()`).
     - Pada `pengeluaran`: Tidak ada akses sama sekali untuk `pelanggan`.

3. **Tabel Kredensial Sensitif (`whatsapp_settings`, `genieacs_settings`, `app_settings`):**
   - `admin`: `ALL` hanya jika `tenant_id = public.get_my_tenant_id()`.
   - `pelanggan`: Hanya boleh `SELECT` pada `app_settings` di mana `tenant_id = public.get_my_tenant_id()` (untuk menampilkan nama aplikasi/tema). **DILARANG** memberi akses `SELECT` kepada `pelanggan` untuk `whatsapp_settings` dan `genieacs_settings` karena menyimpan API Token & password server.

---

### Fase 5: Penegakan Kuota Langganan SaaS (Database-Level Quota Enforcement)
Buat file migrasi `supabase/migrations/2026102705_tenant_quota_enforcement.sql`:

1. Buat fungsi trigger `public.check_tenant_customer_quota()`:
   - Dipanggil `BEFORE INSERT` pada tabel pelanggan/`profiles` (ketika `NEW.role = 'pelanggan'`).
   - Hitung jumlah pelanggan aktif milik `NEW.tenant_id`.
   - Bandingkan dengan `max_customers` pada tabel `saas_plans` yang terhubung ke `tenants`.
   - Jika jumlah pelanggan sudah mencapai atau melebihi `max_customers`, lempar exception: `RAISE EXCEPTION 'Kuota pelanggan untuk paket langganan Anda telah penuh. Silakan upgrade paket SaaS Anda.'`.
   - Cek juga apakah `public.is_tenant_active(NEW.tenant_id)` bernilai `false`. Jika masa aktif habis, tolak penambahan data dengan pesan yang jelas.

---

### Fase 6: Multi-Tenant Storage Buckets
Buat file migrasi `supabase/migrations/2026102706_multi_tenant_storage.sql`:

1. Buat bucket baru `tenant-assets` (public read) untuk menyimpan logo usaha dan gambar QRIS masing-masing tenant dengan pola path: `{tenant_id}/logo.png` dan `{tenant_id}/qris.png`.
2. Buat RLS Policy pada `storage.objects`:
   - `INSERT / UPDATE / DELETE` pada bucket `tenant-assets` hanya diizinkan jika folder pertama `(storage.foldername(name))[1]::uuid = public.get_my_tenant_id()` dan user memiliki role `'admin'`.

---

### Fase 7: Sinkronisasi Supabase Edge Functions terhadap Skema Baru
Setelah skema SQL selesai, perbarui Edge Functions di `supabase/functions/` agar patuh pada isolasi `tenant_id`:

1. **`create-customer/index.ts`:**
   - Ambil `tenant_id` milik Admin yang memanggil fungsi ini (dari JWT/tabel `profiles`).
   - Saat memanggil `supabaseAdmin.auth.admin.createUser()`, sertakan `app_metadata: { tenant_id, role: 'pelanggan' }`.
   - Pastikan insert ke tabel profil/pelanggan menyertakan `tenant_id` tersebut.
2. **`delete-user/index.ts` & `update-user-auth/index.ts`:**
   - Validasi bahwa target user yang akan diubah/dihapus memiliki `tenant_id` yang **sama** dengan `tenant_id` milik Admin pemanggil (cegah Cross-Tenant IDOR).
3. **`send-whatsapp-notification/index.ts` & `whatsapp-reminder/index.ts`:**
   - Ambil konfigurasi token WA dari `whatsapp_settings` dengan filter `.eq('tenant_id', tenantId)`.
   - Untuk `whatsapp-reminder`, lakukan iterasi per tenant yang aktif (`subscription_status IN ('active', 'trial')`), lalu kirim tagihan pelanggan milik tenant tersebut menggunakan token WA masing-masing tenant.
4. **`genieacs-proxy/index.ts`:**
   - Identifikasi `tenant_id` dari user yang me-request (baik Admin maupun Pelanggan yang mengganti WiFi di `ganti-wifi.js`).
   - Ambil URL GenieACS dan kredensial dari tabel `genieacs_settings` berdasarkan `.eq('tenant_id', tenantId)`.

---

## 5. Output & Deliverables yang Diharapkan dari Agent
1. Rangkaian file migrasi SQL baru di dalam folder `supabase/migrations/` sesuai urutan Fase 1–6.
2. Pembaruan file `Database.sql` dan dokumentasi `skema_tabel.md` agar mencerminkan skema Multi-Tenant terbaru secara utuh.
3. Pembaruan kode pada 6 Supabase Edge Functions di `supabase/functions/` agar mendukung isolasi `tenant_id`.
4. Ringkasan perubahan (*Changelog*) beserta panduan pengujian RLS untuk memastikan Admin Tenant A tidak dapat membaca atau memodifikasi data milik Tenant B.