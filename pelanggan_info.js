// pelanggan_info.js - Customer Help Center (Pusat Bantuan)
import { supabase } from './supabase-client.js';
import { requireRole } from './auth.js';
import { getWhatsAppNumber, getAppSettings } from './apply-settings.js';

let currentUser = null;
let currentProfile = null;
let csNumber = '';

document.addEventListener('DOMContentLoaded', async function () {
    // Check authentication and require USER role
    try {
        currentUser = await requireRole('USER');
    } catch (e) {
        console.warn('[HelpCenter] Auth check error:', e);
    }
    if (!currentUser) return;

    // Fetch current user profile
    await fetchCurrentProfile();

    // Load contact info
    await loadContactInfo();

    // Initialize event listeners
    initializeEventListeners();
});

// ===============================================
// Event Listeners Setup
// ===============================================
function initializeEventListeners() {
    const liveChatBtn = document.getElementById('live-chat-btn');
    const liveChatItem = document.getElementById('live-chat-item');
    const callPhoneBtn = document.getElementById('call-phone-btn');
    const phoneCallItem = document.getElementById('phone-call-item');

    // Live Chat triggers
    liveChatBtn?.addEventListener('click', (e) => {
        e.stopPropagation();
        handleLiveChat();
    });
    liveChatItem?.addEventListener('click', handleLiveChat);

    // Phone Call triggers
    callPhoneBtn?.addEventListener('click', (e) => {
        e.stopPropagation();
        handlePhoneCall();
    });
    phoneCallItem?.addEventListener('click', handlePhoneCall);

    // Listen for settings loaded from apply-settings.js
    window.addEventListener('settings-loaded', (e) => {
        const settings = e.detail;
        if (settings?.whatsapp_number) {
            csNumber = settings.whatsapp_number;
            updateContactDisplay();
        }
    });
}

// ===============================================
// Data Loading
// ===============================================
async function fetchCurrentProfile() {
    try {
        const { data: profile, error } = await supabase
            .from('profiles')
            .select('id, full_name, idpl, email, phone')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (error) {
            console.warn('[HelpCenter] Error fetching profile:', error.message);
            return;
        }

        currentProfile = profile;
    } catch (err) {
        console.error('[HelpCenter] Profile load failed:', err);
    }
}

async function loadContactInfo() {
    // 1. Try local settings first (instant)
    const localNumber = getWhatsAppNumber();
    if (localNumber) {
        csNumber = localNumber;
        updateContactDisplay();
    }

    // 2. Fetch fresh data from Supabase app_settings
    try {
        const { data, error } = await supabase
            .from('app_settings')
            .select('whatsapp_number, app_name')
            .limit(1)
            .maybeSingle();

        if (!error && data?.whatsapp_number) {
            csNumber = data.whatsapp_number;
            updateContactDisplay();
        }
    } catch (e) {
        console.warn('[HelpCenter] Error loading CS number:', e);
    }
}

function updateContactDisplay() {
    const waSubtitle = document.getElementById('whatsapp-subtitle');
    const phoneSubtitle = document.getElementById('phone-subtitle');

    if (csNumber && csNumber.trim()) {
        if (waSubtitle) waSubtitle.textContent = `WhatsApp (${csNumber})`;
        if (phoneSubtitle) phoneSubtitle.textContent = csNumber;
    } else {
        if (waSubtitle) waSubtitle.textContent = 'Hubungi via WhatsApp';
        if (phoneSubtitle) phoneSubtitle.textContent = 'Hubungi layanan telepon';
    }
}

// ===============================================
// Action Handlers
// ===============================================
function handleLiveChat() {
    if (!csNumber || !csNumber.trim()) {
        showToast('Nomor WhatsApp admin belum dikonfigurasi.', 'error');
        return;
    }

    // Format phone number to international WhatsApp format (62...)
    let cleanNumber = csNumber.replace(/[^\d+]/g, '');
    if (cleanNumber.startsWith('0')) {
        cleanNumber = '62' + cleanNumber.substring(1);
    } else if (cleanNumber.startsWith('+')) {
        cleanNumber = cleanNumber.substring(1);
    }

    const appName = getAppSettings()?.app_name || 'Layanan Internet';
    const customerName = currentProfile?.full_name || currentUser?.email || 'Pelanggan';
    const customerIdpl = currentProfile?.idpl ? ` (ID: ${currentProfile.idpl})` : '';

    const message = `Halo Admin ${appName}, saya ${customerName}${customerIdpl}. Saya butuh bantuan terkait layanan internet saya.`;
    const whatsappUrl = `https://wa.me/${cleanNumber}?text=${encodeURIComponent(message)}`;

    showToast('Membuka WhatsApp...', 'info');
    window.open(whatsappUrl, '_blank');
}

function handlePhoneCall() {
    if (!csNumber || !csNumber.trim()) {
        showToast('Nomor telepon admin belum dikonfigurasi.', 'error');
        return;
    }

    const cleanNumber = csNumber.replace(/[^\d+]/g, '');
    showToast(`Menghubungi ${cleanNumber}...`, 'info');
    window.location.href = `tel:${cleanNumber}`;
}

// ===============================================
// Toast Notification
// ===============================================
function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toast-message');

    if (!toast || !toastMessage) {
        alert(message);
        return;
    }

    const bgColors = {
        success: 'bg-green-600',
        error: 'bg-red-600',
        info: 'bg-gray-900'
    };

    toast.className = `fixed bottom-20 left-1/2 transform -translate-x-1/2 ${bgColors[type] || 'bg-gray-900'} text-white px-4 py-2.5 rounded-xl shadow-lg transition-all duration-300 z-50 text-xs font-medium pointer-events-none`;
    toastMessage.textContent = message;

    toast.classList.remove('opacity-0', 'invisible');
    setTimeout(() => {
        toast.classList.add('opacity-0', 'invisible');
    }, 3000);
}
