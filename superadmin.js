import { supabase } from './supabase-client.js';

// Konfigurasi Notifikasi & Owner
const OWNER_DANA = '089609497390 (a.n. Taufiq Aziz)';
const OWNER_WA = '0819-1417-0701';

// State global
let allTenants = [];
let availablePlans = [];
let currentUser = null;
let currentProfile = null;

// Helper DOM
const $ = (id) => document.getElementById(id);

// Format helper
const escapeHtml = (str) => {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
};

const formatDate = (isoStr) => {
    if (!isoStr) return '♾️ Lifetime (Selamanya)';
    const d = new Date(isoStr);
    if (isNaN(d.getTime())) return '-';
    return d.toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
    });
};

const normalizePhone = (phone) => {
    if (!phone) return '';
    let cleaned = String(phone).replace(/\D/g, '');
    if (cleaned.startsWith('0')) {
        cleaned = '62' + cleaned.substring(1);
    } else if (cleaned.startsWith('8')) {
        cleaned = '62' + cleaned;
    }
    return cleaned;
};

// Generate URL login tenant yang dinamis terhadap domain (misal wifibilling.my.id atau localhost)
const getTenantLoginUrl = (slug) => {
    const slugParam = slug ? `?t=${encodeURIComponent(slug)}` : '';
    const currentOrigin = window.location.origin;
    // Mengarahkan ke login.html di root atau subpath hosting
    let pathname = window.location.pathname.replace(/(superadmin|index)\.html$/i, 'login.html');
    if (!pathname.endsWith('login.html')) {
        pathname = pathname.replace(/\/+$/, '') + '/login.html';
    }
    return `${currentOrigin}${pathname}${slugParam}`;
};

// Hitung sisa hari & status masa aktif
const getExpiryInfo = (isoStr) => {
    if (!isoStr) {
        return {
            status: 'lifetime',
            label: '♾️ Lifetime',
            subLabel: 'Aktif Selamanya',
            badgeClass: 'bg-purple-100 text-purple-800 border-purple-200',
            daysLeft: Infinity,
            isExpiringSoon: false,
            isExpired: false
        };
    }

    const expDate = new Date(isoStr);
    if (isNaN(expDate.getTime())) {
        return {
            status: 'unknown',
            label: '-',
            subLabel: '-',
            badgeClass: 'bg-slate-100 text-slate-700 border-slate-200',
            daysLeft: 0,
            isExpiringSoon: false,
            isExpired: false
        };
    }

    const now = new Date();
    const dExp = new Date(expDate.getFullYear(), expDate.getMonth(), expDate.getDate());
    const dNow = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diffMs = dExp.getTime() - dNow.getTime();
    const daysLeft = Math.round(diffMs / (1000 * 60 * 60 * 24));

    if (daysLeft < 0) {
        return {
            status: 'expired',
            label: '🔴 Kedaluwarsa',
            subLabel: `Lewat ${Math.abs(daysLeft)} hari`,
            badgeClass: 'bg-rose-100 text-rose-800 border-rose-300 font-bold',
            daysLeft,
            isExpiringSoon: false,
            isExpired: true
        };
    } else if (daysLeft === 0) {
        return {
            status: 'critical',
            label: '⚠️ Habis Hari Ini',
            subLabel: 'Segera perpanjang hari ini',
            badgeClass: 'bg-rose-100 text-rose-800 border-rose-300 font-bold animate-pulse',
            daysLeft,
            isExpiringSoon: true,
            isExpired: false
        };
    } else if (daysLeft <= 3) {
        return {
            status: 'critical',
            label: `⚠️ Sisa ${daysLeft} hari`,
            subLabel: 'Mendesak perpanjangan',
            badgeClass: 'bg-rose-50 text-rose-700 border-rose-200 font-bold',
            daysLeft,
            isExpiringSoon: true,
            isExpired: false
        };
    } else if (daysLeft <= 7) {
        return {
            status: 'warning',
            label: `⏳ Sisa ${daysLeft} hari`,
            subLabel: 'Mendekati jatuh tempo',
            badgeClass: 'bg-amber-50 text-amber-800 border-amber-300 font-bold',
            daysLeft,
            isExpiringSoon: true,
            isExpired: false
        };
    } else {
        return {
            status: 'active',
            label: `🟢 Sisa ${daysLeft} hari`,
            subLabel: 'Aktif normal',
            badgeClass: 'bg-emerald-50 text-emerald-700 border-emerald-200 font-medium',
            daysLeft,
            isExpiringSoon: false,
            isExpired: false
        };
    }
};

// Kirim WhatsApp via Backend API Serverless
async function sendFonnteMessage(targetPhone, message) {
    const cleanPhone = normalizePhone(targetPhone);
    if (!cleanPhone || cleanPhone.length < 9) {
        throw new Error('Nomor WhatsApp tujuan tidak valid. Masukkan nomor minimal 9 digit (contoh: 08123456789 atau 628123456789).');
    }

    const res = await fetch('/api/send-wa', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            target: cleanPhone,
            message: message
        })
    });

    const data = await res.json();
    if (!res.ok || (data.status === false)) {
        throw new Error(data.reason || data.message || data.error || 'Gagal mengirim pesan via WhatsApp Gateway.');
    }

    return data;
}

// -----------------------------------------------------------------------------
// 1. Inisialisasi & Verifikasi Hak Akses Super Admin
// -----------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', async () => {
    try {
        await checkSuperAdminAccess();
        setupEventListeners();
        await Promise.all([
            loadPlans(),
            loadTenants()
        ]);
    } catch (err) {
        console.error('Inisialisasi Super Admin gagal:', err);
    }
});

async function checkSuperAdminAccess() {
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !session?.user) {
        window.location.replace('superadmin-login.html');
        return;
    }

    currentUser = session.user;

    // Ambil data profil
    const { data: profile, error: profError } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', currentUser.id)
        .maybeSingle();

    if (profError || !profile) {
        console.error('Gagal mengambil profil user:', profError);
        window.location.replace('superadmin-login.html');
        return;
    }

    currentProfile = profile;
    const rawRole = (profile.role || '').toLowerCase();
    const isSuperAdmin = rawRole === 'super_admin' || rawRole === 'superadmin';

    if (!isSuperAdmin) {
        alert('Akses Ditolak: Halaman ini khusus untuk Super Admin (Owner).');
        window.location.replace('superadmin-login.html');
        return;
    }

    // Set nama user di header jika ada
    const userDisplay = $('user-display-name');
    if (userDisplay) {
        userDisplay.textContent = profile.full_name || currentUser.email;
    }
}

// -----------------------------------------------------------------------------
// 2. Load Plans (saas_plans)
// -----------------------------------------------------------------------------
async function loadPlans() {
    try {
        const { data, error } = await supabase
            .from('saas_plans')
            .select('*')
            .order('price_monthly', { ascending: true });

        if (error) throw error;
        availablePlans = data || [];

        // Isi dropdown di Modal Tambah Mitra & Edit Mitra
        const addPlanSelect = $('add-plan-id');
        const editPlanSelect = $('edit-plan-id');
        const filterPlanSelect = $('filter-plan');

        if (addPlanSelect) {
            addPlanSelect.innerHTML = availablePlans.map(p => {
                const maxLabel = p.max_customers === null ? 'Unlimited Pelanggan' : `Maks ${p.max_customers} Pelanggan`;
                return `<option value="${p.id}">${escapeHtml(p.name)} (${maxLabel})</option>`;
            }).join('');
        }

        if (editPlanSelect) {
            editPlanSelect.innerHTML = availablePlans.map(p => {
                const maxLabel = p.max_customers === null ? 'Unlimited Pelanggan' : `Maks ${p.max_customers} Pelanggan`;
                return `<option value="${p.id}">${escapeHtml(p.name)} (${maxLabel})</option>`;
            }).join('');
        }

        if (filterPlanSelect) {
            filterPlanSelect.innerHTML = `<option value="all">Semua Paket</option>` + 
                availablePlans.map(p => `<option value="${p.slug}">${escapeHtml(p.name)}</option>`).join('');
        }

    } catch (err) {
        console.error('Gagal memuat saas_plans:', err);
    }
}

// -----------------------------------------------------------------------------
// 3. Load Daftar Tenant & Kuota
// -----------------------------------------------------------------------------
async function loadTenants() {
    showLoading(true);

    try {
        const { data, error } = await supabase.rpc('get_superadmin_tenants');

        if (error) {
            console.warn('RPC get_superadmin_tenants error, mencoba fallback query tenants:', error);
            await loadTenantsFallback();
            return;
        }

        allTenants = data || [];
        updateStats();
        renderTenantsList();

    } catch (err) {
        console.error('Error saat load data tenants:', err);
        await loadTenantsFallback();
    } finally {
        showLoading(false);
    }
}

// Fallback jika RPC belum dieksekusi di database
async function loadTenantsFallback() {
    try {
        const { data, error } = await supabase
            .from('tenants')
            .select(`
                *,
                saas_plans (name, slug, max_customers),
                profiles:owner_id (full_name)
            `)
            .order('created_at', { ascending: false });

        if (error) throw error;

        // Hitung manual used_customers per tenant
        const { data: customerCounts, error: countErr } = await supabase
            .from('profiles')
            .select('tenant_id, role, status')
            .eq('status', 'AKTIF');

        const countMap = {};
        if (!countErr && customerCounts) {
            customerCounts.forEach(c => {
                const role = (c.role || '').toLowerCase();
                if (role === 'user' || role === 'pelanggan') {
                    countMap[c.tenant_id] = (countMap[c.tenant_id] || 0) + 1;
                }
            });
        }

        allTenants = (data || []).map(t => {
            const planMax = t.saas_plans?.max_customers ?? null;
            let effMax = planMax;
            if (t.custom_max_customers === -1) {
                effMax = null; // unlimited
            } else if (t.custom_max_customers !== null && t.custom_max_customers !== undefined) {
                effMax = Number(t.custom_max_customers);
            }

            return {
                id: t.id,
                name: t.name,
                slug: t.slug,
                owner_id: t.owner_id,
                owner_name: t.profiles?.full_name || 'Admin',
                owner_email: '',
                plan_id: t.plan_id,
                plan_name: t.saas_plans?.name || 'Tanpa Paket',
                plan_slug: t.saas_plans?.slug || '',
                plan_max_customers: planMax,
                custom_max_customers: t.custom_max_customers,
                effective_max_customers: effMax,
                used_customers: countMap[t.id] || 0,
                subscription_status: t.subscription_status,
                subscription_expires_at: t.subscription_expires_at,
                company_address: t.company_address,
                company_phone: t.company_phone,
                created_at: t.created_at
            };
        });

        updateStats();
        renderTenantsList();
    } catch (fallbackErr) {
        console.error('Fallback query tenants gagal:', fallbackErr);
        alert('Gagal mengambil daftar mitra: ' + (fallbackErr.message || fallbackErr));
    }
}

// -----------------------------------------------------------------------------
// 4. Update Metric Stat Cards
// -----------------------------------------------------------------------------
function updateStats() {
    const totalTenants = allTenants.length;
    let totalCustomers = 0;
    let activeTenants = 0;
    let expiringTenants = 0;
    let expiredTenants = 0;

    allTenants.forEach(t => {
        totalCustomers += Number(t.used_customers || 0);
        if (t.subscription_status === 'active') {
            activeTenants++;
        }

        const expInfo = getExpiryInfo(t.subscription_expires_at);
        if (expInfo.isExpiringSoon) {
            expiringTenants++;
        }
        if (expInfo.isExpired) {
            expiredTenants++;
        }
    });

    if ($('stat-total-tenants')) $('stat-total-tenants').textContent = totalTenants.toLocaleString('id-ID');
    if ($('stat-total-customers')) $('stat-total-customers').textContent = totalCustomers.toLocaleString('id-ID');
    if ($('stat-active-tenants')) $('stat-active-tenants').textContent = activeTenants.toLocaleString('id-ID');
    if ($('stat-expiring-tenants')) $('stat-expiring-tenants').textContent = expiringTenants.toLocaleString('id-ID');

    const expiredBadge = $('stat-expired-badge');
    if (expiredBadge) {
        if (expiredTenants > 0) {
            expiredBadge.textContent = `${expiredTenants} expired`;
            expiredBadge.classList.remove('hidden');
        } else {
            expiredBadge.classList.add('hidden');
        }
    }

    // Muat metrik analitik aplikasi mobile (unduhan & instalasi)
    loadAppStats();
}

// -----------------------------------------------------------------------------
// 4.1. Mobile App Stats (Downloads, Installs, Conversion Rate)
// -----------------------------------------------------------------------------
async function loadAppStats() {
    try {
        const { data, error } = await supabase.rpc('get_superadmin_app_stats');
        if (!error && data) {
            const downloads = Number(data.total_downloads || 0);
            const installs = Number(data.total_installs || 0);
            const conversion = data.conversion_rate !== undefined ? data.conversion_rate : (downloads > 0 ? Math.round((installs / downloads) * 100) : 0);

            if ($('stat-app-downloads')) $('stat-app-downloads').textContent = downloads.toLocaleString('id-ID');
            if ($('stat-app-installs')) $('stat-app-installs').textContent = installs.toLocaleString('id-ID');
            if ($('stat-app-conversion')) $('stat-app-conversion').textContent = `${conversion}%`;

            renderRecentInstalls(data.recent_installs || []);
        } else if (error) {
            console.warn('RPC get_superadmin_app_stats info:', error.message);
        }
    } catch (e) {
        console.warn('Load app stats exception:', e);
    }
}

function renderRecentInstalls(installs) {
    const tbody = $('app-installs-tbody');
    if (!tbody) return;

    if (!installs || installs.length === 0) {
        tbody.innerHTML = `<tr><td colspan="5" class="p-3 text-center text-slate-400">Belum ada perangkat HP yang mengaktifkan APK</td></tr>`;
        return;
    }

    tbody.innerHTML = installs.map(i => {
        const dateStr = i.first_installed_at ? new Date(i.first_installed_at).toLocaleDateString('id-ID', {
            day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
        }) : '-';
        return `
            <tr class="hover:bg-slate-50 transition">
                <td class="p-2 font-medium text-slate-900 flex items-center gap-1.5">
                    <span class="text-xs">📱</span>
                    <span>${escapeHtml(i.device_model || 'Android Device')}</span>
                </td>
                <td class="p-2 text-slate-600">${escapeHtml(i.os_version || 'Android')}</td>
                <td class="p-2">
                    <span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-700">${escapeHtml(i.app_version || 'v1.0.0')}</span>
                </td>
                <td class="p-2 text-slate-600">${escapeHtml(i.tenant_name || 'Umum / Publik')}</td>
                <td class="p-2 text-slate-500 whitespace-nowrap text-[11px]">${dateStr}</td>
            </tr>
        `;
    }).join('');
}

// -----------------------------------------------------------------------------
// 5. Render Daftar Tenant (Desktop & Mobile)
// -----------------------------------------------------------------------------
function renderTenantsList() {
    const searchVal = ($('search-input')?.value || '').toLowerCase().trim();
    const planVal = $('filter-plan')?.value || 'all';
    const statusVal = $('filter-status')?.value || 'all';

    const filtered = allTenants.filter(t => {
        // Filter Pencarian
        if (searchVal) {
            const matchName = (t.name || '').toLowerCase().includes(searchVal);
            const matchOwner = (t.owner_name || '').toLowerCase().includes(searchVal);
            const matchEmail = (t.owner_email || '').toLowerCase().includes(searchVal);
            const matchSlug = (t.slug || '').toLowerCase().includes(searchVal);
            const matchPhone = (t.company_phone || '').toLowerCase().includes(searchVal);
            if (!matchName && !matchOwner && !matchEmail && !matchSlug && !matchPhone) return false;
        }

        // Filter Paket
        if (planVal !== 'all') {
            if (t.plan_slug !== planVal) return false;
        }

        // Filter Status
        if (statusVal !== 'all') {
            if (statusVal === 'expiring') {
                const exp = getExpiryInfo(t.subscription_expires_at);
                if (!exp.isExpiringSoon) return false;
            } else if (statusVal === 'expired') {
                const exp = getExpiryInfo(t.subscription_expires_at);
                if (!exp.isExpired) return false;
            } else {
                if (t.subscription_status !== statusVal) return false;
            }
        }

        return true;
    });

    // Update label counter
    const countLabel = $('tenant-count-label');
    if (countLabel) {
        countLabel.textContent = `Menampilkan ${filtered.length} dari ${allTenants.length} mitra`;
    }

    const tableBody = $('tenants-table-body');
    const mobileCards = $('tenants-mobile-cards');
    const emptyState = $('empty-state');

    if (!filtered || filtered.length === 0) {
        if (tableBody) tableBody.innerHTML = '';
        if (mobileCards) mobileCards.innerHTML = '';
        if (emptyState) emptyState.classList.remove('hidden');
        return;
    }

    if (emptyState) emptyState.classList.add('hidden');

    // Render Desktop Table Rows
    if (tableBody) {
        tableBody.innerHTML = filtered.map(t => renderDesktopRow(t)).join('');
    }

    // Render Mobile Cards
    if (mobileCards) {
        mobileCards.innerHTML = filtered.map(t => renderMobileCard(t)).join('');
    }

    // Attach Event Listeners to Buttons
    attachTenantActionEvents();
}

// Template Desktop Row
function renderDesktopRow(t) {
    const quotaInfo = formatQuotaDisplay(t);
    const planBadge = formatPlanBadge(t);
    const expiryDisplay = formatExpiryDisplay(t);

    return `
        <tr class="hover:bg-slate-50/80 transition duration-150">
            <!-- Nama Usaha & Pemilik -->
            <td class="px-5 py-4">
                <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-500 to-indigo-600 text-white font-black flex items-center justify-center text-sm shadow-sm flex-shrink-0">
                        ${escapeHtml((t.name || 'W').substring(0, 2).toUpperCase())}
                    </div>
                    <div>
                        <div class="font-bold text-slate-900 text-sm flex items-center gap-2">
                            <span>${escapeHtml(t.name)}</span>
                            <span class="text-[10px] font-mono text-slate-400 bg-slate-100 px-1.5 py-0.5 rounded">/${escapeHtml(t.slug)}</span>
                        </div>
                        <div class="text-xs text-slate-500 flex items-center gap-1.5 mt-0.5 flex-wrap">
                            <span class="font-medium text-slate-700">${escapeHtml(t.owner_name || 'Admin')}</span>
                            ${t.owner_email ? `<span class="text-slate-300">•</span><span class="text-slate-400 font-mono text-[11px]">${escapeHtml(t.owner_email)}</span>` : ''}
                            ${t.company_phone ? `<span class="text-slate-300">•</span><span class="text-emerald-600 font-mono text-[11px] font-medium">📞 ${escapeHtml(t.company_phone)}</span>` : ''}
                        </div>
                    </div>
                </div>
            </td>

            <!-- Paket SaaS -->
            <td class="px-5 py-4">
                ${planBadge}
            </td>

            <!-- Kuota Pelanggan -->
            <td class="px-5 py-4 min-w-[200px]">
                ${quotaInfo.html}
            </td>

            <!-- Status & Masa Aktif -->
            <td class="px-5 py-4">
                ${expiryDisplay}
            </td>

            <!-- Aksi -->
            <td class="px-5 py-4 text-right">
                <div class="inline-flex items-center gap-1.5 flex-wrap justify-end">
                    <!-- Tombol Perpanjang -->
                    <button 
                        type="button" 
                        class="btn-renew-tenant px-2.5 py-1.5 text-xs font-bold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition inline-flex items-center gap-1"
                        data-tenant-id="${t.id}"
                        title="Perpanjang Langganan & Masa Aktif"
                    >
                        <span>➕</span>
                        <span>Perpanjang</span>
                    </button>

                    <!-- Tombol Ingatkan WA -->
                    <button 
                        type="button" 
                        class="btn-remind-wa px-2.5 py-1.5 text-xs font-bold text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-lg transition inline-flex items-center gap-1"
                        data-tenant-id="${t.id}"
                        title="Kirim Pengingat Jatuh Tempo WhatsApp"
                    >
                        <span>📲</span>
                        <span>Ingatkan WA</span>
                    </button>

                    <!-- Tombol Edit -->
                    <button 
                        type="button" 
                        class="btn-edit-tenant p-1.5 text-slate-500 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition"
                        data-tenant-id="${t.id}"
                        title="Edit Data & Kuota Mitra"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                    </button>

                    <!-- Tombol Salin Data Akun -->
                    <button 
                        type="button" 
                        class="btn-copy-info p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                        title="Salin Data Akun Mitra (URL Login)"
                        data-name="${escapeHtml(t.name)}"
                        data-email="${escapeHtml(t.owner_email)}"
                        data-slug="${escapeHtml(t.slug)}"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" />
                        </svg>
                    </button>

                    <!-- Tombol Hapus Mitra -->
                    <button 
                        type="button" 
                        class="btn-delete-tenant p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        data-tenant-id="${t.id}"
                        data-name="${escapeHtml(t.name)}"
                        title="Hapus Mitra Ini"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                    </button>
                </div>
            </td>
        </tr>
    `;
}

// Template Mobile Card
function renderMobileCard(t) {
    const quotaInfo = formatQuotaDisplay(t);
    const planBadge = formatPlanBadge(t);
    const expiryDisplay = formatExpiryDisplay(t);

    return `
        <div class="p-3.5 sm:p-4 space-y-3 hover:bg-slate-50/50 transition border-b border-slate-100 last:border-b-0">
            <div class="flex items-start justify-between gap-2.5">
                <div class="flex items-center gap-2.5 min-w-0 flex-1">
                    <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-500 to-indigo-600 text-white font-black flex items-center justify-center text-sm shadow-sm flex-shrink-0">
                        ${escapeHtml((t.name || 'W').substring(0, 2).toUpperCase())}
                    </div>
                    <div class="min-w-0 flex-1">
                        <h4 class="font-bold text-slate-900 text-sm leading-snug truncate" title="${escapeHtml(t.name)}">${escapeHtml(t.name)}</h4>
                        <p class="text-xs text-slate-500 mt-0.5 truncate">${escapeHtml(t.owner_name || 'Admin')} ${t.owner_email ? `• <span class="font-mono text-[11px]">${escapeHtml(t.owner_email)}</span>` : ''}</p>
                        ${t.company_phone ? `<p class="text-[11px] text-emerald-600 font-mono mt-0.5 truncate">📞 ${escapeHtml(t.company_phone)}</p>` : ''}
                    </div>
                </div>
                <div class="flex-shrink-0">
                    ${planBadge}
                </div>
            </div>

            <!-- Kuota Pelanggan -->
            <div class="bg-slate-50 p-2.5 sm:p-3 rounded-lg border border-slate-100 space-y-1.5">
                <div class="flex items-center justify-between text-xs">
                    <span class="text-slate-500 font-medium">Kapasitas Pelanggan:</span>
                    <span class="font-bold text-slate-800">${quotaInfo.text}</span>
                </div>
                ${quotaInfo.bar}
                ${quotaInfo.customBadge}
            </div>

            <!-- Status & Masa Aktif -->
            <div class="pt-1 border-t border-slate-100">
                ${expiryDisplay}
            </div>

            <!-- Actions Bar -->
            <div class="flex items-center justify-between pt-2.5 border-t border-slate-100 gap-1.5 flex-wrap">
                <div class="flex items-center gap-1.5 flex-wrap">
                    <button 
                        type="button" 
                        class="btn-renew-tenant px-2.5 py-1.5 text-xs font-bold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 rounded-lg transition inline-flex items-center gap-1 active:scale-95"
                        data-tenant-id="${t.id}"
                    >
                        <span>➕</span>
                        <span>Perpanjang</span>
                    </button>
                    <button 
                        type="button" 
                        class="btn-remind-wa px-2.5 py-1.5 text-xs font-bold text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-lg transition inline-flex items-center gap-1 active:scale-95"
                        data-tenant-id="${t.id}"
                    >
                        <span>📲</span>
                        <span>Ingatkan WA</span>
                    </button>
                </div>

                <div class="flex items-center gap-0.5 ml-auto">
                    <button 
                        type="button" 
                        class="btn-edit-tenant p-1.5 sm:p-2 text-slate-500 hover:text-brand-600 hover:bg-slate-100 rounded-lg transition"
                        data-tenant-id="${t.id}"
                        title="Edit Mitra"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                    </button>
                    <button 
                        type="button" 
                        class="btn-copy-info p-1.5 sm:p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                        title="Salin Data Mitra"
                        data-name="${escapeHtml(t.name)}"
                        data-email="${escapeHtml(t.owner_email)}"
                        data-slug="${escapeHtml(t.slug)}"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3" />
                        </svg>
                    </button>
                    <button 
                        type="button" 
                        class="btn-delete-tenant p-1.5 sm:p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        data-tenant-id="${t.id}"
                        data-name="${escapeHtml(t.name)}"
                        title="Hapus Mitra"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                    </button>
                </div>
            </div>
        </div>
    `;
}

// -----------------------------------------------------------------------------
// Format Badges & Quota Progress
// -----------------------------------------------------------------------------
function formatPlanBadge(t) {
    const slug = (t.plan_slug || '').toLowerCase();
    let badgeClass = 'bg-slate-100 text-slate-700 border-slate-200';

    if (slug === 'starter') {
        badgeClass = 'bg-blue-50 text-blue-700 border-blue-200';
    } else if (slug === 'pro') {
        badgeClass = 'bg-purple-50 text-purple-700 border-purple-200';
    } else if (slug === 'unlimited') {
        badgeClass = 'bg-emerald-50 text-emerald-700 border-emerald-200';
    } else if (slug === 'free-trial') {
        badgeClass = 'bg-amber-50 text-amber-700 border-amber-200';
    }

    return `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold border ${badgeClass}">
        ${escapeHtml(t.plan_name || 'Tanpa Paket')}
    </span>`;
}

function formatStatusBadge(t) {
    const status = (t.subscription_status || '').toLowerCase();
    if (status === 'active') {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-green-50 text-green-700 border border-green-200">
            <span class="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse"></span>
            Active
        </span>`;
    } else if (status === 'trial') {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-50 text-amber-700 border border-amber-200">
            Trial
        </span>`;
    } else if (status === 'suspended') {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-red-50 text-red-700 border border-red-200">
            Suspended
        </span>`;
    } else {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-bold bg-slate-100 text-slate-700 border border-slate-200">
            ${escapeHtml(status || 'Unknown')}
        </span>`;
    }
}

function formatExpiryDisplay(t) {
    const exp = getExpiryInfo(t.subscription_expires_at);
    const dateFormatted = formatDate(t.subscription_expires_at);

    return `
        <div class="space-y-1">
            <div class="flex items-center gap-1.5 flex-wrap">
                ${formatStatusBadge(t)}
                <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold border ${exp.badgeClass}">
                    ${exp.label}
                </span>
            </div>
            <div class="text-[11px] text-slate-500 flex items-center gap-1">
                <span>Jatuh Tempo:</span>
                <strong class="text-slate-700">${dateFormatted}</strong>
            </div>
        </div>
    `;
}

function formatQuotaDisplay(t) {
    const used = Number(t.used_customers || 0);
    const max = t.effective_max_customers;
    const isCustom = t.custom_max_customers !== null && t.custom_max_customers !== undefined;

    let text = '';
    let barColor = 'bg-brand-600';
    let percent = 0;
    let customBadge = '';

    if (max === null) {
        text = `${used} / ∞ Unlimited`;
        percent = 15; // fixed indicator
        barColor = 'bg-emerald-500';
        if (isCustom && t.custom_max_customers === -1) {
            customBadge = `<span class="text-[10px] font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 px-1.5 py-0.2 rounded">⚡ Custom Unlimited</span>`;
        }
    } else {
        text = `${used} / ${max} Pelanggan`;
        percent = max > 0 ? Math.min(Math.round((used / max) * 100), 100) : 100;
        if (percent >= 90) {
            barColor = 'bg-rose-500';
        } else if (percent >= 70) {
            barColor = 'bg-amber-500';
        } else {
            barColor = 'bg-indigo-600';
        }

        if (isCustom) {
            customBadge = `<span class="text-[10px] font-bold text-indigo-700 bg-indigo-50 border border-indigo-200 px-1.5 py-0.2 rounded">⚡ Custom Limit ${max}</span>`;
        }
    }

    const bar = `
        <div class="w-full bg-slate-100 rounded-full h-1.5 overflow-hidden">
            <div class="${barColor} h-1.5 rounded-full transition-all duration-300" style="width: ${percent}%"></div>
        </div>
    `;

    const html = `
        <div class="space-y-1">
            <div class="flex items-center justify-between text-xs">
                <span class="font-bold text-slate-800">${text}</span>
                ${max !== null ? `<span class="text-[10px] font-semibold text-slate-500">${percent}%</span>` : ''}
            </div>
            ${bar}
            ${customBadge ? `<div class="pt-0.5">${customBadge}</div>` : ''}
        </div>
    `;

    return { html, text, bar, customBadge };
}

// -----------------------------------------------------------------------------
// 6. Action Listeners (Edit, Copy, Search, Modals, Renewal, WA)
// -----------------------------------------------------------------------------
function setupEventListeners() {
    // Toggle Mobile App Details Drawer
    $('btn-toggle-app-details')?.addEventListener('click', () => {
        const drawer = $('app-details-drawer');
        const text = $('text-toggle-app-details');
        const icon = $('icon-toggle-app-details');
        if (!drawer) return;

        const isHidden = drawer.classList.contains('hidden');
        if (isHidden) {
            drawer.classList.remove('hidden');
            if (text) text.textContent = 'Tutup Rincian';
            if (icon) icon.classList.add('rotate-180');
        } else {
            drawer.classList.add('hidden');
            if (text) text.textContent = 'Lihat Rincian';
            if (icon) icon.classList.remove('rotate-180');
        }
    });

    // Search input
    $('search-input')?.addEventListener('input', () => {
        renderTenantsList();
    });

    // Plan filter
    $('filter-plan')?.addEventListener('change', () => {
        renderTenantsList();
    });

    // Status filter
    $('filter-status')?.addEventListener('change', () => {
        renderTenantsList();
    });

    // Quick trigger card filter: Jatuh Tempo (H-7)
    $('card-filter-expiring')?.addEventListener('click', () => {
        const filterStatus = $('filter-status');
        if (filterStatus) {
            filterStatus.value = 'expiring';
            renderTenantsList();
        }
    });

    // Refresh button
    $('btn-refresh')?.addEventListener('click', () => {
        loadTenants();
    });

    // Logout
    $('btn-logout')?.addEventListener('click', async () => {
        if (confirm('Yakin ingin logout dari Super Admin?')) {
            await supabase.auth.signOut();
            sessionStorage.clear();
            localStorage.removeItem('app_settings');
            localStorage.removeItem('whatsapp_settings');
            localStorage.removeItem('pwa_manifest');
            window.location.replace('superadmin-login.html');
        }
    });

    // Modal Add Tenant Triggers
    $('btn-add-tenant')?.addEventListener('click', () => openAddTenantModal());
    $('btn-empty-add-tenant')?.addEventListener('click', () => openAddTenantModal());

    // Quick preset unlimited on Add Form
    $('btn-set-unlimited-add')?.addEventListener('click', () => {
        const input = $('add-custom-max');
        if (input) input.value = '-1';
    });

    // Preset buttons in Edit Form
    $('btn-set-unlimited-edit')?.addEventListener('click', () => {
        const input = $('edit-custom-max');
        if (input) input.value = '-1';
    });

    $('btn-reset-to-plan')?.addEventListener('click', () => {
        const input = $('edit-custom-max');
        if (input) input.value = '';
    });

    // Close Modals
    document.querySelectorAll('.btn-close-modal').forEach(btn => {
        btn.addEventListener('click', () => {
            $('modal-add-tenant')?.classList.add('hidden');
            $('modal-edit-tenant')?.classList.add('hidden');
            $('modal-renew-tenant')?.classList.add('hidden');
            $('modal-remind-wa')?.classList.add('hidden');
        });
    });

    // Close on backdrop click
    [$('modal-add-tenant'), $('modal-edit-tenant'), $('modal-renew-tenant'), $('modal-remind-wa')].forEach(modal => {
        modal?.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.add('hidden');
            }
        });
    });

    // Expiry type toggle in Edit Modal
    $('edit-expiry-type')?.addEventListener('change', (e) => {
        const container = $('container-custom-expiry');
        if (!container) return;
        if (e.target.value === 'custom') {
            container.classList.remove('hidden');
        } else {
            container.classList.add('hidden');
            if ($('edit-expiry-date')) $('edit-expiry-date').value = '';
        }
    });

    // Form Submit: Tambah Mitra
    $('form-add-tenant')?.addEventListener('submit', handleAddTenantSubmit);

    // Form Submit: Edit Mitra
    $('form-edit-tenant')?.addEventListener('submit', handleEditTenantSubmit);

    // Form Submit: Perpanjang Masa Aktif
    $('form-renew-tenant')?.addEventListener('submit', handleRenewTenantSubmit);

    // Renewal Duration Shortcut Buttons (+1 Bulan, +3 Bulan, +1 Tahun, Lifetime)
    document.querySelectorAll('.btn-add-duration').forEach(btn => {
        btn.addEventListener('click', () => {
            const months = btn.getAttribute('data-months');
            applyRenewalDuration(months);
        });
    });

    // Remind WA Modal Buttons
    $('btn-send-fonnte')?.addEventListener('click', handleSendReminderFonnte);
    $('btn-open-wa-manual')?.addEventListener('click', handleOpenWaManual);
}

function attachTenantActionEvents() {
    // Edit Tenant Button
    document.querySelectorAll('.btn-edit-tenant').forEach(btn => {
        btn.addEventListener('click', () => {
            const tenantId = btn.getAttribute('data-tenant-id');
            openEditTenantModal(tenantId);
        });
    });

    // Renew Tenant Button (Perpanjang)
    document.querySelectorAll('.btn-renew-tenant').forEach(btn => {
        btn.addEventListener('click', () => {
            const tenantId = btn.getAttribute('data-tenant-id');
            openRenewModal(tenantId);
        });
    });

    // Remind WA Button (Ingatkan Jatuh Tempo)
    document.querySelectorAll('.btn-remind-wa').forEach(btn => {
        btn.addEventListener('click', () => {
            const tenantId = btn.getAttribute('data-tenant-id');
            openRemindModal(tenantId);
        });
    });

    // Delete Tenant Button
    document.querySelectorAll('.btn-delete-tenant').forEach(btn => {
        btn.addEventListener('click', () => {
            const tenantId = btn.getAttribute('data-tenant-id');
            const tenantName = btn.getAttribute('data-name');
            handleDeleteTenant(tenantId, tenantName);
        });
    });

    // Copy Info Button (dengan login.html dan URL dinamis)
    document.querySelectorAll('.btn-copy-info').forEach(btn => {
        btn.addEventListener('click', () => {
            const name = btn.getAttribute('data-name');
            const email = btn.getAttribute('data-email');
            const slug = btn.getAttribute('data-slug');
            const loginUrl = getTenantLoginUrl(slug);

            const textToCopy = `*Informasi Akun RT/RW Net*\nNama Usaha: ${name}\nURL Slug: ${slug}\nEmail: ${email || '-'}\nLogin URL: ${loginUrl}`;

            navigator.clipboard.writeText(textToCopy).then(() => {
                alert('✅ Informasi akun berhasil disalin ke clipboard!\n\n' + textToCopy);
            }).catch(err => {
                console.error('Clipboard error:', err);
                prompt('Salin data akun mitra:', textToCopy);
            });
        });
    });
}

// -----------------------------------------------------------------------------
// 7. Modal Handlers: Tambah Mitra Baru (Create Tenant)
// -----------------------------------------------------------------------------
function openAddTenantModal() {
    const form = $('form-add-tenant');
    if (form) form.reset();

    const planSelect = $('add-plan-id');
    if (planSelect && availablePlans.length > 0) {
        const starter = availablePlans.find(p => p.slug === 'starter');
        if (starter) planSelect.value = starter.id;
    }

    $('modal-add-tenant')?.classList.remove('hidden');
}

async function handleAddTenantSubmit(e) {
    e.preventDefault();

    const companyName = $('add-company-name')?.value?.trim();
    const ownerName = $('add-owner-name')?.value?.trim();
    const email = $('add-email')?.value?.trim();
    const password = $('add-password')?.value?.trim();
    const planId = $('add-plan-id')?.value;
    const customMaxVal = $('add-custom-max')?.value?.trim();
    const subscriptionType = $('add-subscription-type')?.value;
    const phoneInput = $('add-company-phone')?.value?.trim();
    const sendWa = $('add-send-wa')?.checked;

    if (!companyName || !email || !password) {
        alert('Mohon lengkapi Nama Usaha WiFi, Email, dan Password.');
        return;
    }

    if (password.length < 6) {
        alert('Password minimal 6 karakter.');
        return;
    }

    const saveBtn = $('btn-save-new-tenant');
    const saveLabel = $('label-save-new-tenant');
    const originalText = saveLabel?.textContent || 'Simpan & Buat Akun';

    try {
        if (saveBtn) saveBtn.disabled = true;
        if (saveLabel) saveLabel.textContent = 'Membuat Akun & Tenant...';

        let status = 'active';
        let expiresAt = null;

        if (subscriptionType === 'trial') {
            status = 'trial';
            const expDate = new Date();
            expDate.setDate(expDate.getDate() + 14);
            expiresAt = expDate.toISOString();
        }

        let customMax = null;
        if (customMaxVal !== '' && customMaxVal !== undefined) {
            customMax = Number(customMaxVal);
        }

        // Panggil Edge Function create-tenant
        const { data, error } = await supabase.functions.invoke('create-tenant', {
            body: {
                email,
                password,
                owner_name: ownerName || companyName,
                company_name: companyName,
                plan_id: planId,
                custom_max_customers: customMax,
                subscription_status: status,
                subscription_expires_at: expiresAt
            }
        });

        if (error) throw error;
        if (data?.error) throw new Error(data.error);

        const newTenantId = data?.tenant?.id || data?.tenant_id || data?.id;
        const newSlug = data?.tenant?.slug || data?.slug || '';

        // Simpan nomor telepon jika ada
        if (newTenantId && phoneInput) {
            await supabase.from('tenants').update({ company_phone: phoneInput }).eq('id', newTenantId);
        }

        // Kirim WhatsApp via Fonnte jika dicentang dan nomor diisi
        let waNotice = '';
        if (sendWa && phoneInput) {
            try {
                if (saveLabel) saveLabel.textContent = 'Mengirim Notifikasi WhatsApp...';
                const planObj = availablePlans.find(p => p.id === planId);
                const loginUrl = getTenantLoginUrl(newSlug);
                const expiryLabel = status === 'trial' ? '14 Hari Free Trial' : 'Seumur Hidup (Lifetime)';

                const welcomeMsg = 
`*INFORMASI AKUN RT/RW NET BARU*
Halo *${escapeHtml(companyName)}* / *${escapeHtml(ownerName || 'Pemilik')}*,
Selamat! Akun Billing RT/RW Net Anda telah berhasil dibuat dan aktif.

📋 *Detail Akun:*
- Nama Usaha: ${companyName}
- URL Slug: ${newSlug}
- Email Login: ${email}
- Password: ${password}
- Paket: ${planObj?.name || 'Paket Pilihan'}
- Masa Aktif: ${expiryLabel}

🔗 *Link Login Langsung:*
${loginUrl}

Silakan buka link login di atas menggunakan browser Google Chrome di HP atau Laptop Anda. Simpan pesan ini sebagai bukti akun resmi Anda.

Terima kasih atas kepercayaannya!`;

                await sendFonnteMessage(phoneInput, welcomeMsg);
                waNotice = '\n📲 Notifikasi akun berhasil dikirimkan ke WhatsApp mitra!';
            } catch (waErr) {
                console.warn('Gagal kirim WA via Fonnte:', waErr);
                waNotice = '\n⚠️ Akun dibuat, namun WhatsApp gagal terkirim: ' + (waErr.message || waErr);
            }
        }

        alert(`✅ Sukses! Akun mitra "${companyName}" berhasil dibuat.\nEmail: ${email}${waNotice}`);

        $('modal-add-tenant')?.classList.add('hidden');
        await loadTenants();

    } catch (err) {
        console.error('Gagal membuat mitra baru:', err);
        alert('Gagal membuat mitra: ' + (err.message || err));
    } finally {
        if (saveBtn) saveBtn.disabled = false;
        if (saveLabel) saveLabel.textContent = originalText;
    }
}

// -----------------------------------------------------------------------------
// 8. Modal Handlers: Edit Tenant & Kuota
// -----------------------------------------------------------------------------
function openEditTenantModal(tenantId) {
    const tenant = allTenants.find(t => t.id === tenantId);
    if (!tenant) return;

    if ($('edit-tenant-id')) $('edit-tenant-id').value = tenant.id;
    if ($('edit-company-name')) $('edit-company-name').value = tenant.name || '';
    if ($('edit-company-phone')) $('edit-company-phone').value = tenant.company_phone || '';
    if ($('edit-new-password')) $('edit-new-password').value = '';
    if ($('edit-plan-id')) $('edit-plan-id').value = tenant.plan_id || '';
    if ($('edit-status')) $('edit-status').value = tenant.subscription_status || 'active';

    if ($('badge-current-used')) {
        $('badge-current-used').textContent = `Terpakai: ${tenant.used_customers || 0} Pelanggan`;
    }

    const customMaxInput = $('edit-custom-max');
    if (customMaxInput) {
        if (tenant.custom_max_customers === -1) {
            customMaxInput.value = '-1';
        } else if (tenant.custom_max_customers !== null && tenant.custom_max_customers !== undefined) {
            customMaxInput.value = tenant.custom_max_customers;
        } else {
            customMaxInput.value = '';
        }
    }

    const expirySelect = $('edit-expiry-type');
    const expiryContainer = $('container-custom-expiry');
    const expiryDateInput = $('edit-expiry-date');

    if (tenant.subscription_expires_at) {
        if (expirySelect) expirySelect.value = 'custom';
        if (expiryContainer) expiryContainer.classList.remove('hidden');
        if (expiryDateInput) {
            const d = new Date(tenant.subscription_expires_at);
            expiryDateInput.value = d.toISOString().split('T')[0];
        }
    } else {
        if (expirySelect) expirySelect.value = 'lifetime';
        if (expiryContainer) expiryContainer.classList.add('hidden');
        if (expiryDateInput) expiryDateInput.value = '';
    }

    $('modal-edit-tenant')?.classList.remove('hidden');
}

async function handleEditTenantSubmit(e) {
    e.preventDefault();

    const tenantId = $('edit-tenant-id')?.value;
    const name = $('edit-company-name')?.value?.trim();
    const phoneInput = $('edit-company-phone')?.value?.trim();
    const planId = $('edit-plan-id')?.value;
    const status = $('edit-status')?.value || 'active';
    const expiryType = $('edit-expiry-type')?.value;
    const expiryDate = $('edit-expiry-date')?.value;
    const customMaxVal = $('edit-custom-max')?.value?.trim();
    const sendWa = $('edit-send-wa')?.checked;

    if (!tenantId || !name) {
        alert('Nama Usaha WiFi wajib diisi.');
        return;
    }

    const saveBtn = $('btn-save-edit-tenant');
    const saveLabel = $('label-save-edit-tenant');
    const originalText = saveLabel?.textContent || 'Simpan Perubahan';

    try {
        if (saveBtn) saveBtn.disabled = true;
        if (saveLabel) saveLabel.textContent = 'Menyimpan...';

        let expiresAt = null;
        if (expiryType === 'custom' && expiryDate) {
            expiresAt = new Date(expiryDate).toISOString();
        }

        let customMax = null;
        if (customMaxVal !== '' && customMaxVal !== undefined) {
            customMax = Number(customMaxVal);
        }

        // Panggil RPC update_tenant_by_superadmin
        const { error } = await supabase.rpc('update_tenant_by_superadmin', {
            p_tenant_id: tenantId,
            p_name: name,
            p_plan_id: planId || null,
            p_custom_max_customers: customMax,
            p_subscription_status: status,
            p_subscription_expires_at: expiresAt
        });

        if (error) {
            console.warn('RPC update_tenant_by_superadmin error, mencoba direct update:', error);
            const { error: directErr } = await supabase
                .from('tenants')
                .update({
                    name,
                    plan_id: planId || null,
                    custom_max_customers: customMax,
                    subscription_status: status,
                    subscription_expires_at: expiresAt,
                    updated_at: new Date().toISOString()
                })
                .eq('id', tenantId);

            if (directErr) throw directErr;
        }

        // Simpan company_phone di tabel tenants
        await supabase
            .from('tenants')
            .update({ company_phone: phoneInput || null })
            .eq('id', tenantId);

        // Reset password jika diisi
        const newPassword = $('edit-new-password')?.value?.trim();
        let passMsg = '';
        if (newPassword) {
            if (newPassword.length < 6) {
                throw new Error('Password baru minimal 6 karakter.');
            }
            const targetTenant = allTenants.find(t => t.id === tenantId);
            if (targetTenant?.owner_id) {
                const { data: authUpdateData, error: authUpdateErr } = await supabase.functions.invoke('update-user-auth', {
                    body: {
                        user_id: targetTenant.owner_id,
                        update_data: { password: newPassword }
                    }
                });
                if (authUpdateErr || (authUpdateData && authUpdateData.success === false)) {
                    passMsg = '\n(Catatan: Data tenant disimpan, namun password gagal diupdate: ' + (authUpdateErr?.message || authUpdateData?.error || 'Error') + ')';
                } else {
                    passMsg = '\nPassword login mitra berhasil diperbarui!';
                }
            }
        }

        // Kirim WhatsApp via Fonnte jika dipilih
        let waMsg = '';
        if (sendWa && phoneInput) {
            try {
                if (saveLabel) saveLabel.textContent = 'Mengirim Notifikasi WhatsApp...';
                const targetTenant = allTenants.find(t => t.id === tenantId);
                const planObj = availablePlans.find(p => p.id === planId);
                const loginUrl = getTenantLoginUrl(targetTenant?.slug);
                const expiryLabel = expiresAt ? formatDate(expiresAt) : 'Seumur Hidup (Lifetime)';

                const updateMsg = 
`*PEMBERITAHUAN PEMBARUAN AKUN WIFI BILLING*
Halo *${escapeHtml(name)}*,
Status dan data akun billing Anda telah diperbarui oleh Administrator:

📋 *Rincian Terbaru:*
- Status Akun: ${status.toUpperCase()}
- Paket SaaS: ${planObj?.name || targetTenant?.plan_name || '-'}
- Masa Berlaku: ${expiryLabel}

🔗 *Login URL:*
${loginUrl}

Jika ada pertanyaan, silakan hubungi kami. Terima kasih!`;

                await sendFonnteMessage(phoneInput, updateMsg);
                waMsg = '\n📲 Notifikasi berhasil dikirimkan ke WhatsApp mitra!';
            } catch (waErr) {
                console.warn('Gagal kirim update WA:', waErr);
                waMsg = '\n⚠️ WhatsApp gagal terkirim: ' + (waErr.message || waErr);
            }
        }

        alert('✅ Perubahan data mitra berhasil disimpan!' + passMsg + waMsg);
        $('modal-edit-tenant')?.classList.add('hidden');
        await loadTenants();

    } catch (err) {
        console.error('Gagal memperbarui data tenant:', err);
        alert('Gagal menyimpan perubahan: ' + (err.message || err));
    } finally {
        if (saveBtn) saveBtn.disabled = false;
        if (saveLabel) saveLabel.textContent = originalText;
    }
}

// -----------------------------------------------------------------------------
// 9. Modal Handlers: Perpanjangan Langganan (Renewal)
// -----------------------------------------------------------------------------
function openRenewModal(tenantId) {
    const tenant = allTenants.find(t => t.id === tenantId);
    if (!tenant) return;

    if ($('renew-tenant-id')) $('renew-tenant-id').value = tenant.id;
    if ($('renew-tenant-name')) $('renew-tenant-name').textContent = tenant.name;
    if ($('renew-tenant-plan')) $('renew-tenant-plan').textContent = tenant.plan_name || 'Standar';
    if ($('renew-current-expiry')) $('renew-current-expiry').textContent = formatDate(tenant.subscription_expires_at);
    if ($('renew-phone')) $('renew-phone').value = tenant.company_phone || '';

    // Default +1 bulan dari masa aktif saat ini (atau hari ini jika sudah expired/kosong)
    applyRenewalDuration('1', tenant.subscription_expires_at);

    $('modal-renew-tenant')?.classList.remove('hidden');
}

function applyRenewalDuration(durationStr, baseIsoStr = null) {
    const dateInput = $('renew-expiry-date');
    const lifetimeTag = $('renew-lifetime-tag');

    if (durationStr === 'lifetime') {
        if (dateInput) {
            dateInput.value = '';
            dateInput.classList.add('hidden');
        }
        if (lifetimeTag) lifetimeTag.classList.remove('hidden');
        return;
    }

    if (dateInput) dateInput.classList.remove('hidden');
    if (lifetimeTag) lifetimeTag.classList.add('hidden');

    const months = parseInt(durationStr, 10) || 1;
    
    // Hitung tanggal acuan: jika baseIsoStr ada dan masih di masa depan, tambahkan dari sana
    let baseDate = new Date();
    if (!baseIsoStr) {
        const tenantId = $('renew-tenant-id')?.value;
        const tenant = allTenants.find(t => t.id === tenantId);
        baseIsoStr = tenant?.subscription_expires_at;
    }

    if (baseIsoStr) {
        const parsedBase = new Date(baseIsoStr);
        if (!isNaN(parsedBase.getTime()) && parsedBase.getTime() > baseDate.getTime()) {
            baseDate = parsedBase;
        }
    }

    const newDate = new Date(baseDate);
    newDate.setMonth(newDate.getMonth() + months);

    if (dateInput) {
        dateInput.value = newDate.toISOString().split('T')[0];
    }
}

async function handleRenewTenantSubmit(e) {
    e.preventDefault();

    const tenantId = $('renew-tenant-id')?.value;
    const dateVal = $('renew-expiry-date')?.value;
    const isLifetime = $('renew-expiry-date')?.classList.contains('hidden');
    const phoneInput = $('renew-phone')?.value?.trim();
    const sendWa = $('renew-send-wa')?.checked;

    const tenant = allTenants.find(t => t.id === tenantId);
    if (!tenant) return;

    let expiresAt = null;
    if (!isLifetime) {
        if (!dateVal) {
            alert('Mohon tentukan tanggal jatuh tempo baru atau pilih tombol Lifetime.');
            return;
        }
        expiresAt = new Date(dateVal).toISOString();
    }

    const saveBtn = $('btn-save-renew');
    const saveLabel = $('label-save-renew');
    const originalText = saveLabel?.textContent || 'Simpan & Perpanjang';

    try {
        if (saveBtn) saveBtn.disabled = true;
        if (saveLabel) saveLabel.textContent = 'Memproses Perpanjangan...';

        // 1. Update status tenant menjadi active dan tanggal baru
        const { error: rpcErr } = await supabase.rpc('update_tenant_by_superadmin', {
            p_tenant_id: tenantId,
            p_name: tenant.name,
            p_plan_id: tenant.plan_id || null,
            p_custom_max_customers: tenant.custom_max_customers,
            p_subscription_status: 'active',
            p_subscription_expires_at: expiresAt
        });

        if (rpcErr) {
            console.warn('RPC perpanjang error, fallback table update:', rpcErr);
            const { error: tableErr } = await supabase
                .from('tenants')
                .update({
                    subscription_status: 'active',
                    subscription_expires_at: expiresAt,
                    updated_at: new Date().toISOString()
                })
                .eq('id', tenantId);

            if (tableErr) throw tableErr;
        }

        // 2. Simpan company_phone jika diisi
        if (phoneInput) {
            await supabase
                .from('tenants')
                .update({ company_phone: phoneInput })
                .eq('id', tenantId);
        }

        // 3. Kirim notifikasi WA Fonnte jika dicentang
        let waResultNotice = '';
        if (sendWa && phoneInput) {
            try {
                if (saveLabel) saveLabel.textContent = 'Mengirim Notifikasi WhatsApp via Fonnte...';
                const newExpiryDisplay = expiresAt ? formatDate(expiresAt) : 'Seumur Hidup (Lifetime)';
                const loginUrl = getTenantLoginUrl(tenant.slug);

                const confirmMsg = 
`*KONFIRMASI PERPANJANGAN AKUN WIFI BILLING*
Halo *${escapeHtml(tenant.name)}* / *${escapeHtml(tenant.owner_name || 'Admin')}*,
Pembayaran perpanjangan langganan Anda telah berhasil diverifikasi oleh Admin.

📋 *Detail Pembaruan:*
- Nama Usaha: ${tenant.name}
- Paket SaaS: ${tenant.plan_name || 'Aktif'}
- Status: AKTIF
- Masa Berlaku Baru: *${newExpiryDisplay}*

🔗 *Login URL Aplikasi:*
${loginUrl}

Terima kasih atas kerja samanya! Semoga operasional RT/RW Net Anda berjalan lancar dan sukses selalu.`;

                await sendFonnteMessage(phoneInput, confirmMsg);
                waResultNotice = '\n📲 Konfirmasi perpanjangan berhasil dikirim otomatis ke WhatsApp mitra!';
            } catch (waErr) {
                console.warn('Gagal kirim WA konfirmasi perpanjangan:', waErr);
                waResultNotice = '\n⚠️ Perpanjangan disimpan, namun pesan WA gagal terkirim: ' + (waErr.message || waErr);
            }
        }

        alert(`✅ Langganan mitra "${tenant.name}" berhasil diperpanjang!${waResultNotice}`);
        $('modal-renew-tenant')?.classList.add('hidden');
        await loadTenants();

    } catch (err) {
        console.error('Gagal memperpanjang langganan:', err);
        alert('Gagal memproses perpanjangan: ' + (err.message || err));
    } finally {
        if (saveBtn) saveBtn.disabled = false;
        if (saveLabel) saveLabel.textContent = originalText;
    }
}

// -----------------------------------------------------------------------------
// 10. Modal Handlers: Pengingat WhatsApp Fonnte (Remind WA)
// -----------------------------------------------------------------------------
function openRemindModal(tenantId) {
    const tenant = allTenants.find(t => t.id === tenantId);
    if (!tenant) return;

    if ($('remind-tenant-id')) $('remind-tenant-id').value = tenant.id;
    if ($('remind-phone')) $('remind-phone').value = tenant.company_phone || '';

    const expInfo = getExpiryInfo(tenant.subscription_expires_at);
    const dateFormatted = formatDate(tenant.subscription_expires_at);

    // Template pesan sopan pengingat jatuh tempo
    const templateMsg = 
`*PENGINGAT JATUH TEMPO WIFI BILLING*
Halo *${tenant.name}* / *${tenant.owner_name || 'Admin'}*,

Masa aktif akun WiFi Billing Anda akan segera berakhir pada:
📅 *${dateFormatted}* (${expInfo.subLabel})

Agar pencatatan tagihan warga, pembukuan keuangan, dan cetak struk thermal kasir tetap berjalan tanpa terputus, mohon lakukan perpanjangan langganan.

💳 *Rincian Pembayaran:*
- DANA: ${OWNER_DANA}
- WhatsApp Konfirmasi: ${OWNER_WA}

Setelah melakukan transfer, silakan kirimkan bukti pembayaran ke nomor ini agar kami perpanjang segera. Terima kasih!`;

    if ($('remind-message')) $('remind-message').value = templateMsg;

    $('modal-remind-wa')?.classList.remove('hidden');
}

async function handleSendReminderFonnte() {
    const phone = $('remind-phone')?.value?.trim();
    const message = $('remind-message')?.value?.trim();
    const tenantId = $('remind-tenant-id')?.value;

    if (!phone) {
        alert('Mohon masukkan nomor WhatsApp tujuan.');
        return;
    }
    if (!message) {
        alert('Teks pesan tidak boleh kosong.');
        return;
    }

    const btn = $('btn-send-fonnte');
    const label = $('label-send-fonnte');
    const originalText = label?.textContent || '🚀 Kirim via Fonnte';

    try {
        if (btn) btn.disabled = true;
        if (label) label.textContent = 'Mengirim via Fonnte...';

        await sendFonnteMessage(phone, message);

        // Update company_phone jika belum tersimpan
        if (tenantId) {
            await supabase.from('tenants').update({ company_phone: phone }).eq('id', tenantId);
        }

        alert('✅ Pengingat WhatsApp berhasil dikirim otomatis via Fonnte API!');
        $('modal-remind-wa')?.classList.add('hidden');
        await loadTenants();

    } catch (err) {
        console.error('Kirim Fonnte error:', err);
        alert('Gagal mengirim WhatsApp via Fonnte: ' + (err.message || err) + '\n\nAnda bisa menggunakan tombol "Buka WhatsApp Web" sebagai alternatif.');
    } finally {
        if (btn) btn.disabled = false;
        if (label) label.textContent = originalText;
    }
}

function handleOpenWaManual() {
    const phone = $('remind-phone')?.value?.trim();
    const message = $('remind-message')?.value?.trim();

    if (!phone) {
        alert('Mohon masukkan nomor WhatsApp tujuan terlebih dahulu.');
        return;
    }

    const clean = normalizePhone(phone);
    const waUrl = `https://wa.me/${clean}?text=${encodeURIComponent(message || '')}`;
    window.open(waUrl, '_blank');
}

// -----------------------------------------------------------------------------
// 11. Hapus Tenant & Auth User
// -----------------------------------------------------------------------------
async function handleDeleteTenant(tenantId, tenantName) {
    const confirmed = confirm(
        `Apakah Anda YAKIN ingin menghapus mitra "${tenantName}"?\n\n` +
        `PERINGATAN:\nSemua data tagihan, pelanggan WiFi, paket, dan akun login miliknya akan terhapus secara permanen!`
    );

    if (!confirmed) return;

    try {
        const targetTenant = allTenants.find(t => t.id === tenantId);
        const ownerId = targetTenant?.owner_id;
        const ownerEmail = targetTenant?.owner_email;

        // Panggil RPC delete_tenant_by_superadmin
        const { data: rpcData, error: rpcError } = await supabase.rpc('delete_tenant_by_superadmin', {
            p_tenant_id: tenantId
        });

        if (rpcError) {
            console.warn('RPC delete_tenant_by_superadmin error, menggunakan fallback Edge Function + Table Delete:', rpcError);
            
            if (ownerId) {
                try {
                    await supabase.functions.invoke('delete-user', { body: { user_id: ownerId } });
                } catch (delUserErr) {
                    console.warn('Fallback delete auth user warning:', delUserErr);
                }
            }

            const { error: delError } = await supabase.from('tenants').delete().eq('id', tenantId);
            if (delError) throw delError;
        } else if (rpcData && rpcData.success === false) {
            throw new Error(rpcData.message || 'Gagal menghapus mitra');
        }

        if (ownerEmail) {
            await supabase.rpc('cleanup_orphan_auth_user', { p_email: ownerEmail }).catch(() => {});
        }

        alert(`✅ Mitra "${tenantName}" beserta akun login Authentication berhasil dihapus!`);
        await loadTenants();
    } catch (err) {
        console.error('Gagal menghapus mitra:', err);
        alert('Gagal menghapus mitra: ' + (err.message || 'Terjadi kesalahan sistem'));
    }
}

// -----------------------------------------------------------------------------
// 12. UI Loading Helper
// -----------------------------------------------------------------------------
function showLoading(show) {
    const spinner = $('loading-spinner');
    if (spinner) {
        if (show) {
            spinner.classList.remove('hidden');
        } else {
            spinner.classList.add('hidden');
        }
    }
}
