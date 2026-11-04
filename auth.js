// auth.js (Supabase version)
import { supabase } from './supabase-client.js';

// Konfigurasi Pembayaran & CS SaaS
const OWNER_DANA_NUMBER = '089609497390';
const OWNER_DANA_NAME = 'Taufiq Aziz';
const OWNER_WA_PHONE = '6281914170701';

const escapeHtml = (str) => {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
};

// --- Session Check ---
// Checks for an active session. If none, redirects to login.
// Returns the user object if a session exists.
export async function checkAuth() {
    const { data: { session }, error } = await supabase.auth.getSession();

    if (error) {
        console.error('Error getting session:', error.message);
        window.location.href = 'login.html';
        return null;
    }

    if (!session) {
        alert('Anda harus login untuk mengakses halaman ini.');
        window.location.href = 'login.html';
        return null;
    }

    return session.user;
}

// --- Role-specific Access Control ---
// Checks if the logged-in user has the required role.
export async function requireRole(requiredRole) {
    const user = await checkAuth();
    if (!user) return null; // Stop if not authenticated

    try {
        const { data: profile, error } = await supabase
            .from('profiles')
            .select('role, tenant_id')
            .eq('id', user.id)
            .single();

        if (error || !profile) {
            throw new Error('Gagal memverifikasi peran pengguna.');
        }

        const rawRole = (profile.role || '').toLowerCase();
        const isSuperAdmin = rawRole === 'super_admin' || rawRole === 'superadmin';

        // Super Admin memiliki portal tersendiri (superadmin.html)
        // Tidak diizinkan masuk ke dashboard operasional klien/mitra
        if (isSuperAdmin) {
            window.location.replace('superadmin.html');
            return null;
        }

        const isAdmin = rawRole === 'admin';
        const isUser = rawRole === 'user' || rawRole === 'pelanggan' || rawRole === 'customer';

        if (requiredRole === 'ADMIN' && !isAdmin) {
            alert('Akses ditolak. Halaman ini khusus untuk Admin Mitra RT/RW Net.');
            window.location.href = isUser ? 'pelanggan_dashboard.html' : 'login.html';
            return null;
        }

        if (requiredRole === 'USER' && !isUser) {
            alert('Akses ditolak. Halaman ini khusus untuk Pelanggan.');
            window.location.href = isAdmin ? 'dashboard.html' : 'login.html';
            return null;
        }

        // Jika user adalah Admin Tenant, periksa masa tenggang (grace period) & penguncian langganan
        if (isAdmin && profile.tenant_id) {
            await enforceTenantSubscription(profile.tenant_id, user);
        }

        // Inisialisasi otomatis badge notifikasi di seluruh halaman admin
        if (isAdmin) {
            import('./notification-badge.js').then(({ initNotificationBadge }) => {
                initNotificationBadge(user.id);
            }).catch(err => console.warn('Could not initialize notification badge:', err));
        }

        return user; // Return user object if authorized
    } catch (error) {
        console.error('Authorization Error:', error.message);
        await supabase.auth.signOut();
        window.location.href = 'login.html';
        return null;
    }
}

// --- Penegakan Masa Aktif & Masa Tenggang Langganan SaaS ---
// Aturan:
// - Hari H s/d Hari ke-3: Masa Tenggang (Grace Period) -> Banner peringatan + tombol bayar
// - Hari ke-4 ke atas ATAU status 'suspended': Kunci Total (Hard Lock) -> Layar terkunci
export async function enforceTenantSubscription(tenantId, user) {
    if (!tenantId) return;

    try {
        const { data: tenant, error } = await supabase
            .from('tenants')
            .select('id, name, slug, subscription_status, subscription_expires_at, plan_id, saas_plans(name, price_monthly)')
            .eq('id', tenantId)
            .maybeSingle();

        if (error || !tenant) return;

        const status = tenant.subscription_status || 'trial';
        const expiresAt = tenant.subscription_expires_at ? new Date(tenant.subscription_expires_at) : null;
        
        // Jika status aktif dan tidak memiliki tanggal kedaluwarsa (null) => Lifetime (aktif selamanya)
        if (!expiresAt && status === 'active') return;

        let daysOverdue = -999;
        if (expiresAt) {
            const now = new Date();
            const dNow = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            const dExp = new Date(expiresAt.getFullYear(), expiresAt.getMonth(), expiresAt.getDate());
            const diffMs = dNow.getTime() - dExp.getTime();
            daysOverdue = Math.round(diffMs / (1000 * 60 * 60 * 24));
        }

        const isSuspended = status === 'suspended';
        // Kunci total pada hari ke-4 (daysOverdue >= 4) atau jika status disuspend admin
        const isHardLocked = isSuspended || daysOverdue >= 4;
        // Masa tenggang dari Hari H (0) sampai Hari ke-3
        const isGracePeriod = !isHardLocked && daysOverdue >= 0 && daysOverdue <= 3;

        if (isHardLocked) {
            showHardLockOverlay(tenant, daysOverdue, isSuspended);
        } else if (isGracePeriod) {
            showGracePeriodBanner(tenant, daysOverdue);
        }
    } catch (err) {
        console.warn('[auth.js] Error checking tenant subscription:', err);
    }
}

// Tampilkan Banner Peringatan Masa Tenggang (Hari 1 s/d 3)
function showGracePeriodBanner(tenant, daysOverdue) {
    if (document.getElementById('saas-grace-period-banner')) return;

    const banner = document.createElement('div');
    banner.id = 'saas-grace-period-banner';
    banner.className = 'sticky top-0 z-[9999] bg-gradient-to-r from-amber-600 via-rose-600 to-red-600 text-white px-4 py-2.5 shadow-lg flex flex-wrap items-center justify-between gap-3 text-xs';

    let message = '';
    if (daysOverdue === 0) {
        message = '⏳ <strong>Masa aktif langganan Anda BERAKHIR HARI INI.</strong> Harap lakukan perpanjangan dalam 3 hari ke depan sebelum sistem terkunci otomatis pada hari ke-4.';
    } else {
        const sisaHari = 4 - daysOverdue;
        message = `⚠️ <strong>Peringatan:</strong> Masa aktif langganan telah habis (lewat ${daysOverdue} hari). Masa tenggang tersisa <strong>${sisaHari} hari lagi</strong> sebelum sistem terkunci total pada hari ke-4.`;
    }

    banner.innerHTML = `
        <div class="flex items-center gap-2.5 flex-1 min-w-[280px]">
            <span class="text-base flex-shrink-0 animate-pulse">⚠️</span>
            <div class="leading-snug">${message}</div>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
            <button type="button" id="btn-open-grace-pay" class="px-3.5 py-1.5 rounded-lg bg-white text-rose-700 font-extrabold hover:bg-rose-50 shadow-sm transition active:scale-95 flex items-center gap-1.5 text-xs">
                <span>💳</span> Perpanjang Sekarang
            </button>
            <button type="button" id="btn-close-grace-banner" class="p-1 hover:bg-white/20 rounded-md text-white/80 hover:text-white text-sm leading-none" title="Tutup pesan">
                &times;
            </button>
        </div>
    `;

    document.body.prepend(banner);

    document.getElementById('btn-close-grace-banner')?.addEventListener('click', () => {
        banner.remove();
    });

    document.getElementById('btn-open-grace-pay')?.addEventListener('click', () => {
        showPaymentModal(tenant);
    });
}

// Tampilkan Layar Kunci Total (Hari ke-4 ke atas atau Suspended)
function showHardLockOverlay(tenant, daysOverdue, isSuspended) {
    // Hapus banner tenggang jika ada
    document.getElementById('saas-grace-period-banner')?.remove();

    if (document.getElementById('saas-hard-lock-overlay')) return;

    // Kunci scroll halaman
    document.body.style.overflow = 'hidden';

    const planName = tenant.saas_plans?.name || 'Starter';
    const price = tenant.saas_plans?.price_monthly ? parseInt(tenant.saas_plans.price_monthly, 10) : 10000;

    const waMsg = `Halo Admin WiFi Billing, akun saya terkunci karena masa tenggang telah lewat:\n\n` +
                  `• Nama Usaha: ${tenant.name}\n` +
                  `• Paket Langganan: ${planName} (Rp ${price.toLocaleString('id-ID')}/bln)\n` +
                  `• Status: Terkunci (Lewat ${daysOverdue} hari)\n\n` +
                  `Berikut bukti transfer terlampir. Mohon akun saya diaktifkan kembali. Terima kasih!`;
    const waUrl = `https://wa.me/${OWNER_WA_PHONE}?text=${encodeURIComponent(waMsg)}`;

    const overlay = document.createElement('div');
    overlay.id = 'saas-hard-lock-overlay';
    overlay.className = 'fixed inset-0 z-[999999] bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-3 sm:p-4 overflow-y-auto select-none';

    overlay.innerHTML = `
        <div class="bg-white rounded-3xl w-full max-w-lg shadow-2xl border border-slate-200 overflow-hidden my-auto flex flex-col max-h-[92vh] animate-in fade-in zoom-in-95 duration-200">
            <!-- Modal Header Terkunci -->
            <div class="px-6 py-5 bg-gradient-to-r from-rose-600 to-red-700 text-white flex items-center gap-3.5 flex-shrink-0">
                <div class="w-12 h-12 rounded-2xl bg-white/10 flex items-center justify-center text-2xl shadow-inner flex-shrink-0">
                    🔒
                </div>
                <div>
                    <h3 class="font-extrabold text-lg text-white leading-tight">Akses Sistem Terkunci</h3>
                    <p class="text-xs text-rose-100">
                        ${isSuspended ? 'Akun Anda telah ditangguhkan oleh Administrator' : `Masa tenggang 3 hari berakhir (Hari ke-${daysOverdue} jatuh tempo)`}
                    </p>
                </div>
            </div>

            <!-- Scrollable Content Body -->
            <div class="p-6 space-y-4 overflow-y-auto flex-1 text-xs text-slate-700">
                <div class="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-rose-900 leading-relaxed">
                    Halo pengelola <strong>${escapeHtml(tenant.name)}</strong>, masa aktif paket langganan usaha Anda telah habis dan melewati batas toleransi masa tenggang (4 hari).
                    Fitur pembuatan tagihan, pembukuan keuangan, dan cetak struk kasir dibekukan sementara hingga perpanjangan diverifikasi.
                </div>

                <!-- Detail Tagihan Box -->
                <div class="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                    <div class="flex justify-between">
                        <span class="text-slate-500">Nama Usaha:</span>
                        <span class="font-bold text-slate-800">${escapeHtml(tenant.name)}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-slate-500">Paket Langganan:</span>
                        <span class="font-bold text-indigo-600">${escapeHtml(planName)}</span>
                    </div>
                    <div class="flex justify-between items-center pt-2 border-t border-slate-200">
                        <span class="font-bold text-slate-700">Biaya Perpanjangan:</span>
                        <span class="text-base font-extrabold text-emerald-600">Rp ${price.toLocaleString('id-ID')} / bulan</span>
                    </div>
                </div>

                <!-- Metode 1: QRIS -->
                <div class="text-center p-4 rounded-2xl border border-slate-200 bg-white shadow-sm">
                    <p class="font-bold text-slate-800 uppercase tracking-wide mb-2">Metode 1: Scan QRIS (BCA / E-Wallet)</p>
                    <div class="w-44 h-44 mx-auto rounded-xl border border-slate-300 p-1 bg-white overflow-hidden shadow-inner flex items-center justify-center">
                        <img src="assets/qris_owner.jpg" alt="QRIS Pembayaran" class="w-full h-full object-contain">
                    </div>
                    <p class="text-[11px] text-slate-500 mt-2">Dapat di-scan dengan BCA, DANA, GoPay, OVO, ShopeePay, atau m-Banking.</p>
                </div>

                <!-- Metode 2: Transfer DANA -->
                <div class="p-4 rounded-2xl border border-slate-200 bg-slate-50 flex items-center justify-between">
                    <div>
                        <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Metode 2: Transfer DANA</span>
                        <span class="text-sm font-extrabold text-slate-900 block font-mono">${OWNER_DANA_NUMBER}</span>
                        <span class="text-xs text-slate-600 block">a.n. ${OWNER_DANA_NAME}</span>
                    </div>
                    <button type="button" id="btn-copy-dana-lock" class="px-3 py-2 rounded-lg bg-white border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-100 shadow-sm transition active:scale-95">
                        Salin Nomor
                    </button>
                </div>
            </div>

            <!-- Docked Solid Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-100 flex-shrink-0 space-y-2">
                <a href="${waUrl}" target="_blank" class="w-full py-3.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-sm shadow-md flex items-center justify-center gap-2 transition-all">
                    <span>📲</span> Konfirmasi Pembayaran via WhatsApp
                </a>
                <div class="flex items-center justify-between pt-1">
                    <p class="text-[11px] text-slate-500">
                        Akun akan langsung dibuka otomatis oleh admin setelah transfer.
                    </p>
                    <button type="button" id="btn-logout-lock" class="text-xs font-bold text-rose-600 hover:text-rose-800 hover:underline">
                        Keluar Akun
                    </button>
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(overlay);

    // Salin nomor DANA
    document.getElementById('btn-copy-dana-lock')?.addEventListener('click', () => {
        navigator.clipboard.writeText(OWNER_DANA_NUMBER).then(() => {
            const btn = document.getElementById('btn-copy-dana-lock');
            if (btn) {
                btn.textContent = '✓ Tersalin!';
                btn.className = 'px-3 py-2 rounded-lg bg-emerald-100 border border-emerald-300 text-xs font-bold text-emerald-800 shadow-sm transition';
                setTimeout(() => {
                    btn.textContent = 'Salin Nomor';
                    btn.className = 'px-3 py-2 rounded-lg bg-white border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-100 shadow-sm transition active:scale-95';
                }, 2000);
            }
        });
    });

    // Tombol Logout saat terkunci
    document.getElementById('btn-logout-lock')?.addEventListener('click', async () => {
        await supabase.auth.signOut();
        sessionStorage.clear();
        localStorage.clear();
        window.location.href = 'login.html';
    });
}

// Modal Pembayaran saat Klien Klik "Perpanjang Sekarang" di Banner
function showPaymentModal(tenant) {
    if (document.getElementById('saas-payment-modal-dialog')) {
        document.getElementById('saas-payment-modal-dialog').classList.remove('hidden');
        return;
    }

    const planName = tenant.saas_plans?.name || 'Starter';
    const price = tenant.saas_plans?.price_monthly ? parseInt(tenant.saas_plans.price_monthly, 10) : 10000;

    const waMsg = `Halo Admin WiFi Billing, saya ingin melakukan perpanjangan paket langganan:\n\n` +
                  `• Nama Usaha: ${tenant.name}\n` +
                  `• Paket SaaS: ${planName} (Rp ${price.toLocaleString('id-ID')}/bln)\n\n` +
                  `Berikut bukti transfer terlampir. Mohon masa aktif akun saya diperpanjang ya. Terima kasih!`;
    const waUrl = `https://wa.me/${OWNER_WA_PHONE}?text=${encodeURIComponent(waMsg)}`;

    const modal = document.createElement('div');
    modal.id = 'saas-payment-modal-dialog';
    modal.className = 'fixed inset-0 z-[99999] bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-3 sm:p-4 overflow-y-auto';

    modal.innerHTML = `
        <div class="bg-white rounded-3xl w-full max-w-md shadow-2xl border border-slate-100 overflow-hidden my-auto flex flex-col max-h-[90vh] animate-in fade-in zoom-in-95 duration-200">
            <!-- Modal Header -->
            <div class="px-6 py-4 bg-emerald-600 text-white flex items-center justify-between flex-shrink-0">
                <div>
                    <h3 class="font-extrabold text-base text-white">Pembayaran Perpanjangan</h3>
                    <p class="text-xs text-emerald-100">${escapeHtml(planName)} - Rp ${price.toLocaleString('id-ID')}/bulan</p>
                </div>
                <button type="button" id="btn-close-pay-dialog" class="text-white/80 hover:text-white text-2xl font-bold leading-none">&times;</button>
            </div>

            <!-- Scrollable Content Body -->
            <div class="p-6 space-y-4 overflow-y-auto flex-1 text-xs">
                <!-- Detail Tagihan Box -->
                <div class="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-1.5">
                    <div class="flex justify-between">
                        <span class="text-slate-500">Nama Usaha:</span>
                        <span class="font-bold text-slate-800">${escapeHtml(tenant.name)}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-slate-500">Paket Langganan:</span>
                        <span class="font-bold text-indigo-600">${escapeHtml(planName)}</span>
                    </div>
                    <div class="flex justify-between items-center pt-2 border-t border-slate-200">
                        <span class="font-bold text-slate-700">Total Pembayaran:</span>
                        <span class="text-base font-extrabold text-emerald-600">Rp ${price.toLocaleString('id-ID')}</span>
                    </div>
                </div>

                <!-- Metode 1: QRIS -->
                <div class="text-center p-4 rounded-2xl border border-slate-200 bg-white shadow-sm">
                    <p class="font-bold text-slate-800 uppercase tracking-wide mb-2">Metode 1: Scan QRIS (BCA / E-Wallet)</p>
                    <div class="w-44 h-44 mx-auto rounded-xl border border-slate-300 p-1 bg-white overflow-hidden shadow-inner flex items-center justify-center">
                        <img src="assets/qris_owner.jpg" alt="QRIS Pembayaran" class="w-full h-full object-contain">
                    </div>
                    <p class="text-[11px] text-slate-500 mt-2">Dapat di-scan dengan BCA, DANA, GoPay, OVO, ShopeePay, atau m-Banking.</p>
                </div>

                <!-- Metode 2: Transfer DANA -->
                <div class="p-4 rounded-2xl border border-slate-200 bg-slate-50 flex items-center justify-between">
                    <div>
                        <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Metode 2: Transfer DANA</span>
                        <span class="text-sm font-extrabold text-slate-900 block font-mono">${OWNER_DANA_NUMBER}</span>
                        <span class="text-xs text-slate-600 block">a.n. ${OWNER_DANA_NAME}</span>
                    </div>
                    <button type="button" id="btn-copy-dana-dialog" class="px-3 py-2 rounded-lg bg-white border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-100 shadow-sm transition active:scale-95">
                        Salin Nomor
                    </button>
                </div>
            </div>

            <!-- Docked Solid Footer -->
            <div class="px-6 py-4 bg-slate-50 border-t border-slate-100 flex-shrink-0 space-y-2">
                <a href="${waUrl}" target="_blank" class="w-full py-3.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold text-sm shadow-md flex items-center justify-center gap-2 transition-all">
                    <span>📲</span> Konfirmasi Pembayaran via WhatsApp
                </a>
                <p class="text-[11px] text-center text-slate-500">
                    Kirimkan bukti transfer di atas, akun Anda akan langsung diperpanjang oleh admin.
                </p>
            </div>
        </div>
    `;

    document.body.appendChild(modal);

    document.getElementById('btn-close-pay-dialog')?.addEventListener('click', () => {
        modal.classList.add('hidden');
    });

    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.classList.add('hidden');
        }
    });

    document.getElementById('btn-copy-dana-dialog')?.addEventListener('click', () => {
        navigator.clipboard.writeText(OWNER_DANA_NUMBER).then(() => {
            const btn = document.getElementById('btn-copy-dana-dialog');
            if (btn) {
                btn.textContent = '✓ Tersalin!';
                btn.className = 'px-3 py-2 rounded-lg bg-emerald-100 border border-emerald-300 text-xs font-bold text-emerald-800 shadow-sm transition';
                setTimeout(() => {
                    btn.textContent = 'Salin Nomor';
                    btn.className = 'px-3 py-2 rounded-lg bg-white border border-slate-300 text-xs font-bold text-slate-700 hover:bg-slate-100 shadow-sm transition active:scale-95';
                }, 2000);
            }
        });
    });
}

// --- Logout Function ---
// Initializes logout functionality for a given button ID.
export function initLogout(buttonId) {
    const logoutBtn = document.getElementById(buttonId);
    if (logoutBtn) {
        logoutBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            if (confirm('Yakin ingin logout?')) {
                const { error } = await supabase.auth.signOut();
                if (error) {
                    console.error('Error logging out:', error.message);
                    alert('Gagal untuk logout. Silakan coba lagi.');
                } else {
                    sessionStorage.clear();
                    localStorage.removeItem('app_settings');
                    localStorage.removeItem('whatsapp_settings');
                    localStorage.removeItem('pwa_manifest');
                    window.location.href = 'login.html';
                }
            }
        });
    }
}
