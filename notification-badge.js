// notification-badge.js
// Script universal untuk mengelola badge angka notifikasi di semua halaman admin

import { getUnreadNotificationCount } from './notification-service.js';

let badgeIntervalId = null;

/**
 * Inisialisasi badge notifikasi untuk user yang sedang login
 */
export function initNotificationBadge(userId) {
    if (!userId) return;

    // Update badge saat halaman pertama kali siap
    updateNotificationBadge(userId);
    
    // Clear interval sebelumnya jika ada agar tidak double
    if (badgeIntervalId) clearInterval(badgeIntervalId);

    // Update badge berkala setiap 30 detik
    badgeIntervalId = setInterval(() => {
        updateNotificationBadge(userId);
    }, 30000);
    
    // Update badge saat window focus (misal admin kembali ke tab ini)
    window.addEventListener('focus', () => {
        updateNotificationBadge(userId);
    });
}

/**
 * Update tampilan badge notifikasi di seluruh elemen (desktop & mobile)
 */
export async function updateNotificationBadge(userId) {
    // Cari semua elemen badge notifikasi di halaman (desktop top bar maupun mobile header)
    const badges = document.querySelectorAll('.notification-badge-count, #notification-badge');
    if (!badges || badges.length === 0) return;

    try {
        const unreadCount = await getUnreadNotificationCount(userId);
        
        badges.forEach(badge => {
            if (unreadCount > 0) {
                const displayText = unreadCount > 99 ? '99+' : String(unreadCount);
                badge.textContent = displayText;
                badge.classList.remove('hidden');
                
                // Pastikan styling pill merah menyala terlihat jelas
                badge.className = 'notification-badge-count absolute -top-1 -right-1 min-w-[1.25rem] h-5 px-1 bg-rose-600 text-white text-[10px] font-extrabold rounded-full flex items-center justify-center border-2 border-white shadow-xs';
            } else {
                badge.textContent = '0';
                badge.classList.add('hidden');
            }
        });
    } catch (error) {
        console.error('Error updating notification badge:', error);
        badges.forEach(badge => badge.classList.add('hidden'));
    }
}

/**
 * Kompatibilitas mundur jika ada modul yang memanggil addNotificationIconToHeader
 */
export function addNotificationIconToHeader() {
    // Ikon notifikasi sudah tertanam secara native di desktop navbar dan mobile header HTML
}
