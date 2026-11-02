# Skema Database SaaS Multi-Tenant (Billing RT/RW Net)

Dokumen ini mendokumentasikan skema database **SaaS Multi-Tenant** berbasis Supabase (PostgreSQL) menggunakan pendekatan **Shared Database, Shared Schema** dengan isolasi `tenant_id` dan **Row Level Security (RLS)**.

---

## 1. Arsitektur Multi-Tenant

- **Isolasi Data:** Setiap baris data operasional diikat dengan `tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE`.
- **Default Function:** Kolom `tenant_id` memiliki nilai default `public.get_my_tenant_id()` sehingga kueri INSERT dari frontend tetap aman dan otomatis terisi.
- **Standarisasi Role:**
  - `super_admin`: Pemilik platform SaaS (akses lintas tenant).
  - `admin` (disimpan `ADMIN`): Pemilik / pengelola RT-RW Net (hanya data miliknya).
  - `pelanggan` (disimpan `USER`): Pelanggan WiFi akhir (hanya data miliknya).
- **Default Tenant:** `a0000000-0000-4000-8000-000000000001` (*Rivamnet Default*) untuk menampung data single-tenant lama secara backward-compatible.

---

## 2. Tabel Inti SaaS

### 2.1. `saas_plans`
Menyimpan paket langganan untuk mitra RT/RW Net.
| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | UUID (PK) | Default `gen_random_uuid()` |
| `name` | VARCHAR(100) | Nama paket (*Starter*, *Pro*, *Unlimited*, *Free Trial*) |
| `slug` | VARCHAR(100) | Unique slug |
| `price_monthly` | NUMERIC(12,2) | Harga bulanan paket |
| `max_customers` | INTEGER | Batas maksimal pelanggan aktif per tenant (`NULL` = unlimited) |
| `features` | JSONB | Flag fitur (whatsapp_gateway, genieacs, custom_receipt) |
| `is_active` | BOOLEAN | Status paket aktif / nonaktif |
| `created_at`, `updated_at` | TIMESTAMPTZ | Waktu pembuatan / perbaruan |

### 2.2. `tenants`
Menyimpan data mitra ISP / RT-RW Net.
| Kolom | Tipe | Keterangan |
| :--- | :--- | :--- |
| `id` | UUID (PK) | ID unik tenant |
| `name` | VARCHAR(150) | Nama usaha WiFi |
| `slug` | VARCHAR(100) | Slug unik URL / identifikasi |
| `owner_id` | UUID (FK) | Referensi ke `auth.users(id)` |
| `plan_id` | UUID (FK) | Referensi ke `saas_plans(id)` |
| `subscription_status` | VARCHAR(20) | `'trial'`, `'active'`, `'past_due'`, `'suspended'` |
| `subscription_expires_at` | TIMESTAMPTZ | Masa berlaku paket |
| `logo_url`, `qris_url` | TEXT | URL aset tenant di storage |
| `company_address`, `company_phone` | TEXT / VARCHAR | Alamat & kontak usaha |

---

## 3. Tabel Operasional Aplikasi (dengan `tenant_id`)

Setiap tabel berikut memiliki kolom:
`tenant_id UUID NOT NULL DEFAULT public.get_my_tenant_id() REFERENCES public.tenants(id) ON DELETE CASCADE`
serta index performa `idx_<tabel>_tenant_id`.

1. **`profiles`**: Pengguna & Pelanggan (FK `auth.users.id`). Constraint `UNIQUE (tenant_id, idpl)` untuk kode pelanggan per tenant.
2. **`packages`**: Paket langganan WiFi yang dijual mitra ke pelanggannya.
3. **`invoices`**: Tagihan internet pelanggan.
4. **`expenses`**: Pengeluaran operasional usaha WiFi.
5. **`payment_methods`**: Rekening bank / e-wallet mitra.
6. **`notifications`**: Notifikasi sistem per tenant.
7. **`notification_reads`**: Status baca notifikasi per user.
8. **`app_settings`**: Pengaturan nama aplikasi, logo, tema (Constraint `UNIQUE (tenant_id)`).
9. **`whatsapp_settings`**: Token API Fonnte & template pesan (Constraint `UNIQUE (tenant_id, setting_key)`).
10. **`genieacs_settings`**: Kredensial ACS & URL server (Constraint `UNIQUE (tenant_id, setting_key)`).
11. **`wifi_change_logs`**: Log pergantian SSID/Password pelanggan via TR-069.

---

## 4. Helper Stored Functions & Triggers

- `public.get_my_tenant_id()`: Mengambil `tenant_id` dari JWT `app_metadata` dengan fallback tabel `profiles`.
- `public.get_my_role()`: Mengambil role kanonik (`super_admin`, `admin`, `pelanggan`).
- `public.is_tenant_active(tenant_id)`: Mengecek status `active`/`trial` dan tanggal kedaluwarsa.
- `public.get_tenant_quota(tenant_id)`: Mengembalikan ringkasan kuota terpakai, batas paket, dan boolean `can_add_customer`.
- `public.check_tenant_customer_quota()`: Trigger `BEFORE INSERT/UPDATE` pada `profiles` yang menolak penambahan pelanggan bila kuota paket habis atau tenant disuspend.
- `public.handle_new_user()`: Trigger `AFTER INSERT` pada `auth.users` yang otomatis:
  - Membuat tenant baru + trial saat pendaftaran dari `register.html`.
  - Mengikat pelanggan baru ke tenant pembuatnya saat dipanggil dari Edge Function.

---

## 5. Storage Buckets

1. **`avatars`** (Public): Foto profil pengguna.
2. **`tenant-assets`** (Public read, tenant write): Logo usaha dan gambar QRIS dengan struktur folder `{tenant_id}/logo.png` dan `{tenant_id}/qris.png`.
