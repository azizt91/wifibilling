import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';
import { updateNotificationBadge } from './notification-badge.js';

document.addEventListener('DOMContentLoaded', async () => {
    // Pastikan hanya admin yang bisa mengakses halaman ini
    const user = await requireRole('ADMIN');
    if (!user) return;

    initLogout('desktop-logout-btn');

    const notificationList = document.getElementById('notification-list');
    const clearButton = document.getElementById('clear-notifications');
    const desktopClearButton = document.getElementById('desktop-clear-notifications');
    const markAllReadButton = document.getElementById('mark-all-read');
    const desktopMarkAllReadButton = document.getElementById('desktop-mark-all-read');

    const loadingSpinner = document.createElement('div');
    loadingSpinner.className = 'text-center p-12 bg-white rounded-2xl border border-slate-200/80 shadow-xs';
    loadingSpinner.innerHTML = `
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-600 mx-auto"></div>
        <p class="text-xs text-slate-500 font-semibold mt-3">Memuat notifikasi...</p>
    `;

    // Helper function untuk mark as read
    async function markAsRead(notificationId, userId) {
        try {
            const { error } = await supabase.from('notification_reads').upsert({
                notification_id: notificationId,
                user_id: userId
            }, {
                onConflict: 'notification_id,user_id',
                ignoreDuplicates: true
            });

            if (error) {
                console.error('Gagal menandai notifikasi:', error);
                return false;
            }
            return true;
        } catch (error) {
            console.error('Error marking notification as read:', error);
            return false;
        }
    }

    // Helper function untuk delete notification
    async function deleteNotification(notificationId) {
        try {
            // Hapus dari notification_reads terlebih dahulu (jika ada)
            await supabase
                .from('notification_reads')
                .delete()
                .eq('notification_id', notificationId);

            // Kemudian hapus notifikasi utama
            const { error } = await supabase
                .from('notifications')
                .delete()
                .eq('id', notificationId);

            if (error) {
                console.error('Gagal menghapus notifikasi:', error);
                alert('Gagal menghapus notifikasi: ' + error.message);
                return false;
            }
            return true;
        } catch (error) {
            console.error('Error deleting notification:', error);
            alert('Error menghapus notifikasi: ' + error.message);
            return false;
        }
    }

    async function renderNotifications() {
        notificationList.innerHTML = '';
        notificationList.appendChild(loadingSpinner);

        try {
            // Panggil fungsi SQL dengan parameter user ID yang jelas
            const { data: notifications, error } = await supabase.rpc('get_user_notifications', {
                user_id_param: user.id
            });

            if (error) throw error;
            
            notificationList.innerHTML = ''; // Hapus spinner

            if (!notifications || notifications.length === 0) {
                notificationList.innerHTML = `
                    <div class="text-center p-12 bg-white rounded-2xl border border-slate-200/80 shadow-xs">
                        <div class="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 mx-auto mb-3">
                            <svg xmlns="http://www.w3.org/2000/svg" width="28px" height="28px" fill="currentColor" viewBox="0 0 256 256">
                                <path d="M221.8,175.94C216.25,166.38,208,139.33,208,104a80,80,0,1,0-160,0c0,35.34-8.26,62.38-13.81,71.94A16,16,0,0,0,48,200H88.81a40,40,0,0,0,78.38,0H208a16,16,0,0,0,13.8-24.06ZM128,216a24,24,0,0,1-22.62-16h45.24A24,24,0,0,1,128,216ZM48,184c7.7-13.24,16-43.92,16-80a64,64,0,1,1,128,0c0,36.05,8.28,66.73,16,80Z"></path>
                            </svg>
                        </div>
                        <h4 class="font-bold text-slate-800 text-sm mb-1">Tidak Ada Notifikasi</h4>
                        <p class="text-xs text-slate-500 max-w-sm mx-auto">Semua notifikasi dan log aktivitas sistem terbaru akan ditampilkan di sini.</p>
                    </div>
                `;
                return;
            }

            notifications.forEach(notif => {
                const item = document.createElement('div');
                const isUnread = !notif.is_read;

                item.className = `p-4 sm:p-5 rounded-2xl border transition-all duration-200 ${
                    isUnread 
                        ? 'bg-white border-l-4 border-l-brand-600 border-slate-200/80 shadow-xs hover:shadow-md' 
                        : 'bg-white/80 border-slate-200/70 opacity-85 hover:opacity-100'
                }`;

                // Simpan data notifikasi di elemen itu sendiri
                item.dataset.id = notif.id;
                item.dataset.url = notif.url || '#';
                item.dataset.isRead = notif.is_read;

                const dateStr = new Date(notif.created_at).toLocaleString('id-ID', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });

                item.innerHTML = `
                    <div class="flex items-start gap-3.5">
                        <div class="flex-shrink-0 w-10 h-10 rounded-xl ${isUnread ? 'bg-brand-50 text-brand-600' : 'bg-slate-100 text-slate-400'} flex items-center justify-center">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20px" height="20px" fill="currentColor" viewBox="0 0 256 256">
                                <path d="M221.8,175.94C216.25,166.38,208,139.33,208,104a80,80,0,1,0-160,0c0,35.34-8.26,62.38-13.81,71.94A16,16,0,0,0,48,200H88.81a40,40,0,0,0,78.38,0H208a16,16,0,0,0,13.8-24.06ZM128,216a24,24,0,0,1-22.62-16h45.24A24,24,0,0,1,128,216ZM48,184c7.7-13.24,16-43.92,16-80a64,64,0,1,1,128,0c0,36.05,8.28,66.73,16,80Z"></path>
                            </svg>
                        </div>
                        <div class="flex-1 min-w-0 cursor-pointer notification-content">
                            <div class="flex items-center gap-2 mb-1">
                                <h4 class="text-sm font-bold text-slate-900 leading-snug truncate">${notif.title}</h4>
                                ${isUnread ? '<span class="inline-block w-2 h-2 rounded-full bg-brand-600 flex-shrink-0"></span>' : ''}
                            </div>
                            <p class="text-xs text-slate-600 leading-relaxed">${notif.body}</p>
                            <p class="text-[11px] text-slate-400 mt-2 font-medium flex items-center gap-1">
                                <svg xmlns="http://www.w3.org/2000/svg" width="12px" height="12px" fill="currentColor" viewBox="0 0 256 256"><path d="M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm64-88a8,8,0,0,1-8,8H128a8,8,0,0,1-8-8V72a8,8,0,0,1,16,0v48h48A8,8,0,0,1,192,128Z"></path></svg>
                                ${dateStr}
                            </p>
                        </div>
                        <div class="flex items-center gap-1.5 ml-2 flex-shrink-0">
                            ${isUnread ? `
                                <button class="mark-read-btn w-8 h-8 rounded-lg bg-brand-50 hover:bg-brand-100 text-brand-700 flex items-center justify-center transition-colors" title="Tandai sudah dibaca">
                                    <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
                                        <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
                                    </svg>
                                </button>
                            ` : ''}
                            <button class="delete-btn w-8 h-8 rounded-lg bg-slate-100 hover:bg-rose-50 hover:text-rose-600 text-slate-500 flex items-center justify-center transition-colors" title="Hapus notifikasi">
                                <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/>
                                </svg>
                            </button>
                        </div>
                    </div>
                `;

                // Event listener untuk konten notifikasi (navigasi)
                const content = item.querySelector('.notification-content');
                content.addEventListener('click', async () => {
                    if (item.dataset.isRead === 'false') {
                        await markAsRead(item.dataset.id, user.id);
                    }
                    if (item.dataset.url && item.dataset.url !== '#') {
                        window.location.href = item.dataset.url;
                    }
                });

                // Event listener untuk tombol mark as read
                const markReadBtn = item.querySelector('.mark-read-btn');
                if (markReadBtn) {
                    markReadBtn.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        await markAsRead(item.dataset.id, user.id);
                        renderNotifications();
                    });
                }

                // Event listener untuk tombol delete
                const deleteBtn = item.querySelector('.delete-btn');
                deleteBtn.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    if (confirm('Hapus notifikasi ini?')) {
                        await deleteNotification(item.dataset.id);
                        renderNotifications();
                    }
                });

                notificationList.appendChild(item);
            });

            // Sinkronkan badge angka notifikasi secara realtime
            updateNotificationBadge(user.id);

        } catch (error) {
            notificationList.innerHTML = `<div class="text-center p-8 bg-rose-50 text-rose-700 rounded-2xl border border-rose-200 text-xs font-bold">Gagal memuat notifikasi: ${error.message}</div>`;
            console.error(error);
        }
    }

    // Handler untuk tombol "Tandai Semua Sudah Dibaca"
    async function handleMarkAllRead() {
        if (confirm('Tandai semua notifikasi sebagai sudah dibaca?')) {
            try {
                const { data: unreadNotifications, error: fetchError } = await supabase.rpc('get_user_notifications', {
                    user_id_param: user.id
                });

                if (fetchError) throw fetchError;

                const unreadIds = unreadNotifications
                    .filter(notif => !notif.is_read)
                    .map(notif => notif.id);

                if (unreadIds.length > 0) {
                    const readRecords = unreadIds.map(notificationId => ({
                        notification_id: notificationId,
                        user_id: user.id
                    }));

                    const { error: insertError } = await supabase
                        .from('notification_reads')
                        .upsert(readRecords, {
                            onConflict: 'notification_id,user_id',
                            ignoreDuplicates: true
                        });

                    if (insertError) throw insertError;

                    renderNotifications();
                    alert('Semua notifikasi telah ditandai sebagai sudah dibaca.');
                } else {
                    alert('Tidak ada notifikasi yang belum dibaca.');
                }
            } catch (error) {
                console.error('Error marking all as read:', error);
                alert('Gagal menandai semua sebagai dibaca: ' + error.message);
            }
        }
    }

    // Handler untuk tombol "Hapus Semua Notifikasi"
    async function handleClearAll() {
        if (confirm('PERHATIAN: Ini akan menghapus SEMUA notifikasi Anda secara permanen. Lanjutkan?')) {
            try {
                const { data: userNotifications, error: fetchError } = await supabase.rpc('get_user_notifications', {
                    user_id_param: user.id
                });

                if (fetchError) throw fetchError;

                if (userNotifications.length > 0) {
                    const notificationIds = userNotifications.map(notif => notif.id);

                    await supabase
                        .from('notification_reads')
                        .delete()
                        .in('notification_id', notificationIds);

                    const { error: deleteError } = await supabase
                        .from('notifications')
                        .delete()
                        .or(`recipient_user_id.eq.${user.id},and(recipient_role.eq.ADMIN,recipient_user_id.is.null)`);

                    if (deleteError) throw deleteError;

                    renderNotifications();
                    alert('Semua notifikasi telah dihapus.');
                } else {
                    alert('Tidak ada notifikasi untuk dihapus.');
                }
            } catch (error) {
                console.error('Error deleting all notifications:', error);
                alert('Gagal menghapus semua notifikasi: ' + error.message);
            }
        }
    }

    markAllReadButton?.addEventListener('click', handleMarkAllRead);
    desktopMarkAllReadButton?.addEventListener('click', handleMarkAllRead);

    clearButton?.addEventListener('click', handleClearAll);
    desktopClearButton?.addEventListener('click', handleClearAll);

    // Render notifikasi saat halaman dimuat
    renderNotifications();
});
