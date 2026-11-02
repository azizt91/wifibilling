// pelanggan_dashboard.js - Customer Dashboard (Orange Theme Adapted)
import { supabase } from './supabase-client.js';
import { checkAuth, requireRole, initLogout } from './auth.js';
import { getWhatsAppNumber, getQRISInfo, getAppSettings } from './apply-settings.js';

let currentUser = null;
let currentProfile = null;

document.addEventListener('DOMContentLoaded', async function () {
    const loadingOverlay = document.getElementById('loading-overlay');
    if (loadingOverlay) loadingOverlay.style.display = 'flex';

    currentUser = await requireRole('USER');
    if (!currentUser) return; // Stop if not authenticated or not USER role

    initLogout('customer-logout-btn');

    await fetchAndDisplayData();
    initializeModalEventListeners();
    await loadPaymentMethods();
    applyQRISInfo();
});

async function fetchAndDisplayData() {
    const loadingOverlay = document.getElementById('loading-overlay');
    const mainContent = document.querySelector('main');

    try {
        // Fetch profile with package name, unpaid bills, and recent paid bills in parallel
        const [profileRes, unpaidRes, paidRes] = await Promise.all([
            supabase.from('profiles').select('*, packages(package_name)').eq('id', currentUser.id).single(),
            supabase.from('invoices').select('*').eq('customer_id', currentUser.id).eq('status', 'unpaid').order('due_date', { ascending: false }),
            supabase.from('invoices').select('*').eq('customer_id', currentUser.id).eq('status', 'paid').order('paid_at', { ascending: false }).limit(4)
        ]);

        const { data: profile, error: profileError } = profileRes;
        if (profileError) throw profileError;
        if (!profile) throw new Error("Profil pelanggan tidak ditemukan.");
        currentProfile = profile; 

        const { data: unpaidBills, error: unpaidError } = unpaidRes;
        if (unpaidError) throw unpaidError;

        const { data: paidBills, error: paidError } = paidRes;
        if (paidError) throw paidError;

        displayHeader(profile);
        renderBerlanggananCard(profile);
        renderTagihanCard(unpaidBills, paidBills);
        renderPaketAktifCard(profile);
        renderRiwayatPembayaran(paidBills);

    } catch (error) {
        console.error('Error loading dashboard data:', error);
        if (mainContent) {
            mainContent.innerHTML = `
                <div class="p-4 text-center text-red-600 bg-red-50 rounded-xl">
                    <p>Gagal memuat data dashboard.</p>
                    <p class="text-sm">${error.message}</p>
                    <button onclick="location.reload()" class="mt-4 px-4 py-2 bg-[#683fe4] text-white rounded-lg">Coba Lagi</button>
                </div>`;
        }
    } finally {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
    }
}

function displayHeader(profile) {
    const welcomeText = document.getElementById('welcome-text');
    const customerEmail = document.getElementById('customer-email');
    const userAvatar = document.getElementById('user-avatar');

    if (welcomeText) welcomeText.textContent = `Hallo, ${profile.full_name || 'Pelanggan'}`;
    if (customerEmail) customerEmail.textContent = currentUser.email;

    if (userAvatar) {
        const defaultAvatar = 'assets/avatar_male.svg';
        const avatarUrl = (profile.photo_url && !profile.photo_url.includes('sb-admin-pro.startbootstrap.com'))
            ? profile.photo_url
            : defaultAvatar;
        userAvatar.style.backgroundImage = 'none';
        userAvatar.innerHTML = `<img id="user-avatar-img" src="${avatarUrl}" alt="Avatar" class="w-full h-full object-cover" onerror="this.onerror=null; this.src='${defaultAvatar}';">`;
    }
}

function renderBerlanggananCard(profile) {
    const dateEl = document.getElementById('berlangganan-date');
    if (!dateEl) return;

    if (profile.installation_date) {
        try {
            const date = new Date(profile.installation_date);
            if (isNaN(date.getTime())) {
                dateEl.textContent = 'Tidak diketahui';
            } else {
                dateEl.textContent = date.toLocaleDateString('id-ID', {
                    day: 'numeric',
                    month: 'long',
                    year: 'numeric'
                });
            }
        } catch(e) {
            dateEl.textContent = 'Tidak diketahui';
        }
    } else {
        dateEl.textContent = 'Tidak diketahui';
    }
}

function renderTagihanCard(unpaidBills, paidBills) {
    const tagihanCard = document.getElementById('tagihan-card');
    if (!tagihanCard) return;
    
    const formatter = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 });

    if (unpaidBills && unpaidBills.length > 0) {
        const totalTunggakan = unpaidBills.reduce((sum, bill) => sum + bill.amount, 0);
        tagihanCard.innerHTML = `
            <div class="flex flex-col">
                <p class="text-[#625095] text-sm font-medium">Total Tagihan Belum Dibayar</p>
                <p class="text-[#110e1b] text-3xl font-bold mt-1">${formatter.format(totalTunggakan)}</p>
                <p class="text-red-600 text-sm font-medium mt-1">${unpaidBills.length} tagihan belum dibayar</p>
            </div>
            <div class="flex flex-col gap-3 mt-4">
                ${unpaidBills.slice(0, 2).map(bill => `
                    <div class="flex items-center justify-between rounded-lg bg-blue-50 border border-[#eae7f3] p-3">
                        <div class="flex items-center gap-3">
                            <div class="flex items-center justify-center rounded-md w-10 h-10 bg-red-100 text-xl">
                                📄
                            </div>
                            <div class="flex flex-col justify-center">
                                <p class="font-bold text-[#110e1b] text-sm">Tagihan ${bill.invoice_period}</p>
                                <p class="text-red-500 text-xs font-semibold">Belum Dibayar</p>
                            </div>
                        </div>
                        <p class="font-semibold text-[#110e1b] text-sm">${formatter.format(bill.amount)}</p>
                    </div>
                `).join('')}
            </div>
            <button id="bayar-sekarang-btn" class="flex min-w-[84px] cursor-pointer items-center justify-center overflow-hidden rounded-lg h-12 px-4 bg-[#683fe4] text-white text-base font-bold shadow-lg shadow-[#683fe4]/30 mt-5 hover:bg-[#5324e0] transition-colors">
                <span class="truncate">Bayar Sekarang</span>
            </button>
        `;

        document.getElementById('bayar-sekarang-btn').addEventListener('click', () => {
            const periods = unpaidBills.map(b => b.invoice_period).join(', ');
            const totalAmount = unpaidBills.reduce((sum, b) => sum + b.amount, 0);
            showPaymentModal(periods, totalAmount, formatter.format(totalAmount));
        });
    } else if (paidBills && paidBills.length > 0) {
        const latestBill = paidBills[0];
        tagihanCard.innerHTML = `
            <p class="text-[#625095] text-sm font-medium">Total Pembayaran Terakhir</p>
            <p class="text-[#110e1b] text-3xl font-bold mt-1">${formatter.format(latestBill.amount_paid)}</p>
            <div class="flex items-center justify-between mt-4">
                <div class="inline-flex items-center gap-2 rounded-full bg-green-100 px-3 py-1">
                    <div class="w-2 h-2 rounded-full bg-green-500"></div>
                    <p class="text-green-700 text-sm font-semibold">Sudah Dibayar</p>
                </div>
                <button id="lihat-detail-btn" class="flex min-w-[84px] cursor-pointer items-center justify-center overflow-hidden rounded-lg h-10 px-4 bg-[#683fe4] text-white text-sm font-bold hover:bg-[#5324e0] transition-colors">
                    <span class="truncate">Riwayat</span>
                </button>
            </div>
        `;

        document.getElementById('lihat-detail-btn').addEventListener('click', () => {
            sessionStorage.setItem('activeTab', 'paid');
            window.location.href = 'pelanggan_riwayat_lunas.html';
        });
    } else {
        tagihanCard.innerHTML = `
            <p class="text-[#625095] text-sm font-medium">Total Tagihan Bulan Ini</p>
            <p class="text-[#110e1b] text-3xl font-bold mt-1">Rp 0</p>
            <div class="flex items-center justify-between mt-4">
                <div class="inline-flex items-center gap-2 rounded-full bg-gray-100 px-3 py-1">
                    <div class="w-2 h-2 rounded-full bg-gray-500"></div>
                    <p class="text-gray-700 text-sm font-semibold">Tidak Ada Tagihan</p>
                </div>
            </div>
        `;
    }
}

function renderPaketAktifCard(profile) {
    const paketAktifCard = document.getElementById('paket-aktif-card');
    if (!paketAktifCard) return;

    const speed = profile.packages ? profile.packages.package_name : 'Tidak ada paket';
    const status = profile.status === 'AKTIF' ? 'Terhubung' : 'Nonaktif';
    const statusColor = profile.status === 'AKTIF' ? 'text-green-600' : 'text-red-500';
    const icon = profile.status === 'AKTIF' ? '📶' : '⚠️';

    paketAktifCard.innerHTML = `
        <div class="flex items-center justify-between">
            <p class="text-[#110e1b] text-base font-bold">Paket Aktif</p>
            <div class="flex items-center gap-1.5 ${statusColor}">
                <span class="text-xl">${icon}</span>
                <p class="text-sm font-bold">${status}</p>
            </div>
        </div>
        <div class="mt-3 border-t border-[#eae7f3] pt-3">
            <p class="text-[#110e1b] text-lg font-bold">${speed}</p>
        </div>
    `;
}

function renderRiwayatPembayaran(paidBills) {
    const riwayatList = document.getElementById('riwayat-pembayaran-list');
    if (!riwayatList) return;
    
    const formatter = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 });

    if (!paidBills || paidBills.length === 0) {
        riwayatList.innerHTML = `
            <div class="flex flex-col items-center justify-center py-8 px-4 text-center">
                <span class="text-4xl mb-3 opacity-50">🕒</span>
                <p class="text-[#625095] text-sm">Belum ada riwayat pembayaran.</p>
            </div>
        `;
        return;
    }

    riwayatList.innerHTML = paidBills.map((bill, index) => `
        <div class="flex items-center justify-between p-4 ${index < paidBills.length - 1 ? 'border-b border-[#eae7f3]' : ''}">
            <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 rounded-full bg-green-100 text-green-600 text-lg">
                    ✅
                </div>
                <div>
                    <p class="font-bold text-[#110e1b] text-sm">Pembayaran ${bill.invoice_period}</p>
                    <p class="text-[#625095] text-xs">${new Date(bill.paid_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}</p>
                </div>
            </div>
            <p class="font-semibold text-[#110e1b] text-sm">${formatter.format(bill.amount_paid)}</p>
        </div>
    `).join('');
}


// ===============================================
// Modal and Payment Logic
// ===============================================

function initializeModalEventListeners() {
    const paymentModal = document.getElementById('payment-modal');
    const closeModalBtn = document.getElementById('close-modal-btn');
    const qrisTab = document.getElementById('qris-tab');
    const transferTab = document.getElementById('transfer-tab');
    const confirmPaymentBtn = document.getElementById('confirm-payment-btn');

    if (closeModalBtn) closeModalBtn.addEventListener('click', hidePaymentModal);
    if (paymentModal) paymentModal.addEventListener('click', (e) => {
        if (e.target === paymentModal) {
            hidePaymentModal();
        }
    });

    if (qrisTab) qrisTab.addEventListener('click', () => switchPaymentTab('qris'));
    if (transferTab) transferTab.addEventListener('click', () => switchPaymentTab('transfer'));
    if (confirmPaymentBtn) confirmPaymentBtn.addEventListener('click', handlePaymentConfirmation);
}

function showPaymentModal(period, amount, amountFormatted) {
    const modal = document.getElementById('payment-modal');
    const modalContent = document.getElementById('modal-content');
    
    const periodEl = document.getElementById('modal-invoice-period');
    const amountEl = document.getElementById('modal-invoice-amount');
    
    if (periodEl) periodEl.textContent = period;
    if (amountEl) amountEl.textContent = amountFormatted;

    const confirmBtn = document.getElementById('confirm-payment-btn');
    if (confirmBtn) {
        confirmBtn.dataset.period = period;
        confirmBtn.dataset.amountFormatted = amountFormatted;
    }

    if (modal) {
        modal.classList.remove('hidden');
        setTimeout(() => {
            modal.classList.add('opacity-100');
            if (modalContent) modalContent.classList.remove('scale-95', 'opacity-0');
            if (modalContent) modalContent.classList.add('scale-100', 'opacity-100');
        }, 10);
    }
}

function hidePaymentModal() {
    const modal = document.getElementById('payment-modal');
    const modalContent = document.getElementById('modal-content');
    
    if (modalContent) modalContent.classList.remove('scale-100', 'opacity-100');
    if (modalContent) modalContent.classList.add('scale-95', 'opacity-0');
    setTimeout(() => {
        if (modal) {
            modal.classList.add('hidden');
            modal.classList.remove('opacity-100');
        }
    }, 300);
}

function switchPaymentTab(tab) {
    const qrisTab = document.getElementById('qris-tab');
    const transferTab = document.getElementById('transfer-tab');
    const qrisContent = document.getElementById('qris-content');
    const transferContent = document.getElementById('transfer-content');

    if (tab === 'qris') {
        if (qrisTab) qrisTab.classList.add('active', 'text-[#5324e0]', 'border-[#5324e0]', 'border-b-2');
        if (qrisTab) qrisTab.classList.remove('text-gray-500');
        if (transferTab) transferTab.classList.remove('active', 'text-[#5324e0]', 'border-[#5324e0]', 'border-b-2');
        if (transferTab) transferTab.classList.add('text-gray-500');
        if (qrisContent) qrisContent.classList.remove('hidden');
        if (transferContent) transferContent.classList.add('hidden');
    } else {
        if (transferTab) transferTab.classList.add('active', 'text-[#5324e0]', 'border-[#5324e0]', 'border-b-2');
        if (transferTab) transferTab.classList.remove('text-gray-500');
        if (qrisTab) qrisTab.classList.remove('active', 'text-[#5324e0]', 'border-[#5324e0]', 'border-b-2');
        if (qrisTab) qrisTab.classList.add('text-gray-500');
        if (transferContent) transferContent.classList.remove('hidden');
        if (qrisContent) qrisContent.classList.add('hidden');
    }
}

async function handlePaymentConfirmation() {
    const confirmBtn = document.getElementById('confirm-payment-btn');
    if (!confirmBtn) return;
    
    const period = confirmBtn.dataset.period;
    const amount = confirmBtn.dataset.amountFormatted;

    const customerName = currentProfile ? currentProfile.full_name : currentUser.email;
    const customerIdpl = currentProfile ? currentProfile.idpl : 'N/A';

    const appName = getAppSettings()?.app_name || 'WiFi Billing System';
    const message = `Halo Admin ${appName}, saya ingin mengkonfirmasi pembayaran tagihan:

- *Nama:* ${customerName}
- *ID Pelanggan:* ${customerIdpl}
- *Periode:* ${period}
- *Jumlah:* ${amount}

Saya sudah melakukan pembayaran. Mohon untuk diverifikasi. Terima kasih.`;

    const whatsappNumber = getWhatsAppNumber();
    if (!whatsappNumber) {
        alert('Nomor WhatsApp Admin belum diatur. Silakan hubungi pihak pengelola/admin.');
        return;
    }
    const encodedMessage = encodeURIComponent(message);
    const whatsappUrl = `https://wa.me/${whatsappNumber}?text=${encodedMessage}`;

    window.open(whatsappUrl, '_blank');
}

function applyQRISInfo() {
    try {
        const qrisInfo = getQRISInfo();
        const qrisImage = document.getElementById('qris-image');
        const qrisContent = document.getElementById('qris-content');
        
        if (qrisInfo && qrisImage) {
            if (qrisInfo.imageUrl) {
                qrisImage.src = qrisInfo.imageUrl;
            }
        }
        
        if (qrisInfo && qrisInfo.showQRIS === false && qrisContent) {
            qrisContent.classList.add('hidden');
        }
    } catch (error) {
        console.error('Error applying QRIS settings:', error);
    }
}

async function loadPaymentMethods() {
    try {
        const { data, error } = await supabase
            .from('payment_methods')
            .select('*')
            .eq('is_active', true)
            .order('sort_order', { ascending: true });

        if (error) throw error;
        renderPaymentMethods(data || []);
    } catch (error) {
        console.error('Error loading payment methods:', error);
        const container = document.getElementById('payment-methods-container');
        if (container) {
            container.innerHTML = `<p class="text-center text-red-500">Gagal memuat metode transfer.</p>`;
        }
    }
}

function renderPaymentMethods(methods) {
    const container = document.getElementById('payment-methods-container');
    if (!container) return;

    if (methods.length === 0) {
        container.innerHTML = `<p class="text-center text-gray-500 text-sm">Tidak ada metode transfer yang tersedia.</p>`;
        return;
    }

    container.innerHTML = methods.map(method => {
        const uniqueId = `acc-${method.id}`;
        return `
            <div class="flex items-center justify-between bg-gray-50 p-3 rounded-lg border">
                <div>
                    <p class="font-semibold text-gray-800">${method.bank_name}</p>
                    <p id="${uniqueId}" class="font-mono text-gray-700">${method.account_number}</p>
                    <p class="text-xs text-gray-500">a.n. ${method.account_holder}</p>
                </div>
                <button class="copy-btn p-2 rounded-md bg-blue-100 text-[#5324e0] hover:bg-blue-200" onclick="copyToClipboard('${uniqueId}', this)">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20"><path d="M7 3a1 1 0 000 2h6a1 1 0 100-2H7zM4 7a1 1 0 011-1h10a1 1 0 110 2H5a1 1 0 01-1-1zM5 11a1 1 0 100 2h4a1 1 0 100-2H5z"></path><path fill-rule="evenodd" d="M2 5a2 2 0 012-2h12a2 2 0 012 2v10a2 2 0 01-2 2H4a2 2 0 01-2-2V5zm2-1a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1V5a1 1 0 00-1-1H4z" clip-rule="evenodd"></path></svg>
                </button>
            </div>
        `;
    }).join('');
}

window.copyToClipboard = function (elementId, buttonElement) {
    const textElement = document.getElementById(elementId);
    if (!textElement) return;

    const textToCopy = textElement.textContent.trim();
    navigator.clipboard.writeText(textToCopy).then(() => {
        showToast(`Nomor rekening ${textToCopy} berhasil disalin!`);
        const originalIcon = buttonElement.innerHTML;
        buttonElement.innerHTML = `<svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path></svg>`;
        setTimeout(() => {
            buttonElement.innerHTML = originalIcon;
        }, 2000);

    }).catch(err => {
        console.error('Gagal menyalin:', err);
        showToast('Gagal menyalin nomor rekening.', 'error');
    });
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toast-message');
    if (!toast || !toastMessage) return;

    toastMessage.textContent = message;
    toast.classList.remove('bg-green-500', 'bg-red-500', 'opacity-0', 'invisible');

    if (type === 'success') {
        toast.classList.add('bg-green-500');
    } else {
        toast.classList.add('bg-red-500');
    }

    toast.classList.add('opacity-100', 'visible');

    setTimeout(() => {
        toast.classList.remove('opacity-100', 'visible');
        toast.classList.add('opacity-0', 'invisible');
    }, 3000);
}
