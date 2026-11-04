// profile.js (Supabase Version - Unified SaaS Profile)
import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';

document.addEventListener('DOMContentLoaded', async () => {
    console.log('Profile page loaded, checking authentication...');
    initLogout('desktop-logout-btn');
    
    // --- Global Variables ---
    let currentAdminData = null;
    let currentUser = null;

    // --- DOM Element Selectors ---
    const profileAvatar = document.getElementById('profileAvatar');
    const adminName = document.getElementById('adminName');
    const adminEmail = document.getElementById('adminEmail');
    const saveBtn = document.getElementById('save-btn');
    const editNama = document.getElementById('edit-nama');
    const editUser = document.getElementById('edit-user');
    const editPassword = document.getElementById('edit-password');
    const logoutBtn = document.getElementById('logout-btn');
    const mobileLogoutBtn = document.getElementById('mobile-logout-btn');
    const togglePasswordBtn = document.getElementById('toggle-password-btn');

    // --- Authentication Check ---
    try {
        const user = await requireRole('ADMIN');
        if (!user) {
            console.log('Authentication failed, user will be redirected');
            return;
        }
        currentUser = user;
        console.log('Authentication successful for user:', currentUser.id);
    } catch (error) {
        console.error('Authentication error:', error);
        return;
    }

    // --- Core Functions ---

    /**
     * Fetches the complete user profile and populates the UI.
     */
    async function loadUserProfile() {
        showSkeletonLoading();
        try {
            if (!currentUser) throw new Error('User not authenticated.');

            const { data: profile, error } = await supabase
                .from('profiles')
                .select('*')
                .eq('id', currentUser.id)
                .single();

            if (error) throw new Error(error.message);
            if (!profile) throw new Error('Profil tidak ditemukan');

            currentAdminData = profile;
            populateProfileData(currentAdminData);

        } catch (error) {
            console.error('Error loading profile:', error);
            if (adminName) adminName.textContent = 'Gagal Memuat';
            if (adminEmail) adminEmail.textContent = 'Silakan coba lagi';
        } finally {
            hideSkeletonLoading();
        }
    }

    /**
     * Populates data into hero card and integrated edit form.
     */
    function populateProfileData(data) {
        if (adminName) adminName.textContent = data.full_name || 'Administrator';
        if (adminEmail) adminEmail.textContent = currentUser?.email || 'admin@wifibilling.id';
        
        if (editNama) editNama.value = data.full_name || '';
        if (editUser) editUser.value = currentUser?.email || '';
        if (editPassword) editPassword.value = '';

        const photoUrl = data.photo_url;
        const validPhoto = (photoUrl && !photoUrl.includes('sb-admin-pro.startbootstrap.com'))
            ? photoUrl 
            : 'assets/avatar_male.svg';

        if (profileAvatar) {
            profileAvatar.style.backgroundColor = 'transparent';
            profileAvatar.style.backgroundImage = 'none';
            profileAvatar.innerHTML = `<img id="profileAvatarImg" src="${validPhoto}" alt="Avatar" class="w-full h-full object-cover rounded-full" onerror="this.onerror=null; this.src='assets/avatar_male.svg';">`;
        }
    }

    /**
     * Compresses image file to thumbnail dimension before upload.
     */
    function compressImageFile(file, maxDimension = 300) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    let w = img.width;
                    let h = img.height;
                    if (w > h) {
                        if (w > maxDimension) {
                            h = Math.round((h * maxDimension) / w);
                            w = maxDimension;
                        }
                    } else {
                        if (h > maxDimension) {
                            w = Math.round((w * maxDimension) / h);
                            h = maxDimension;
                        }
                    }
                    canvas.width = w;
                    canvas.height = h;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, w, h);
                    resolve(canvas.toDataURL('image/jpeg', 0.85));
                };
                img.onerror = reject;
                img.src = e.target.result;
            };
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    /**
     * Handles the file selection and upload process for the avatar.
     */
    async function handlePhotoUpload(event) {
        const file = event.target.files[0];
        if (!file || !currentUser) return;

        try {
            let finalPhotoUrl = null;

            // 1. Coba upload ke Supabase Storage (bucket avatars)
            try {
                const fileExt = file.name.split('.').pop();
                const fileName = `${currentUser.id}-${Date.now()}.${fileExt}`;
                const { error: uploadError } = await supabase.storage
                    .from('avatars')
                    .upload(fileName, file, {
                        cacheControl: '3600',
                        upsert: true
                    });

                if (!uploadError) {
                    const { data } = supabase.storage
                        .from('avatars')
                        .getPublicUrl(fileName);
                    if (data?.publicUrl) finalPhotoUrl = data.publicUrl;
                }
            } catch (storageErr) {
                console.warn('Storage upload error, fallback to compressed image:', storageErr);
            }

            // 2. Fallback kompresi langsung (data URL) jika storage bucket belum aktif
            if (!finalPhotoUrl) {
                finalPhotoUrl = await compressImageFile(file, 256);
            }

            // 3. Update the photo_url in the profiles table
            const { error: updateError } = await supabase
                .from('profiles')
                .update({ photo_url: finalPhotoUrl })
                .eq('id', currentUser.id);
            if (updateError) throw updateError;

            alert('Foto profil berhasil diperbarui!');
            await loadUserProfile();

        } catch (error) {
            console.error('Error uploading photo:', error);
            alert(`Gagal mengunggah foto: ${error.message}`);
        }
    }

    /**
     * Saves changes made in the edit profile form.
     */
    async function saveChanges() {
        if (!currentAdminData || !currentUser) {
            alert('Error: Data admin belum siap untuk disimpan.');
            return;
        }

        const newNama = editNama.value.trim();
        const newPassword = editPassword.value.trim();

        if (!newNama) {
            alert('Nama Lengkap tidak boleh kosong.');
            return;
        }

        if (newPassword && newPassword.length < 6) {
            alert('Password baru harus minimal 6 karakter.');
            return;
        }

        const originalText = saveBtn.innerHTML;
        saveBtn.innerHTML = `
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline-block" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path>
            </svg>
            Menyimpan...
        `;
        saveBtn.disabled = true;

        try {
            // Update nama di database profile
            const { error: profileError } = await supabase
                .from('profiles')
                .update({ full_name: newNama })
                .eq('id', currentUser.id);
            if (profileError) throw profileError;

            // Update password jika diisi
            if (newPassword) {
                const { error: authError } = await supabase.auth.updateUser({ password: newPassword });
                if (authError) {
                    await supabase.from('profiles').update({ full_name: currentAdminData.full_name }).eq('id', currentUser.id);
                    throw new Error(`Gagal memperbarui password: ${authError.message}`);
                }
            }

            alert('Data profil dan keamanan berhasil disimpan!');
            await loadUserProfile();
            if (editPassword) editPassword.value = '';

        } catch (error) {
            console.error('Error saving profile:', error);
            alert(`Gagal menyimpan: ${error.message}`);
        } finally {
            saveBtn.innerHTML = originalText;
            saveBtn.disabled = false;
        }
    }

    function showSkeletonLoading() {
        if (adminName) {
            adminName.className = 'h-6 bg-slate-200 rounded animate-pulse w-36 mx-auto mb-2';
            adminName.textContent = '';
        }
        if (adminEmail) {
            adminEmail.className = 'h-4 bg-slate-200 rounded animate-pulse w-44 mx-auto';
            adminEmail.textContent = '';
        }
        if (profileAvatar) profileAvatar.classList.add('animate-pulse');
    }

    function hideSkeletonLoading() {
        if (adminName) {
            adminName.className = 'text-xl font-extrabold text-slate-900 leading-tight';
        }
        if (adminEmail) {
            adminEmail.className = 'text-xs sm:text-sm text-slate-500 font-medium mt-1';
        }
        if (profileAvatar) profileAvatar.classList.remove('animate-pulse');
    }

    async function handleLogout() {
        if (confirm('Yakin ingin keluar dari akun?')) {
            try {
                const { error } = await supabase.auth.signOut();
                if (error) console.error('Logout error:', error);
            } catch (error) {
                console.error('Logout error:', error);
            } finally {
                sessionStorage.clear();
                localStorage.removeItem('app_settings');
                localStorage.removeItem('whatsapp_settings');
                localStorage.removeItem('pwa_manifest');
                window.location.href = 'login.html';
            }
        }
    }

    // --- Initialize Event Listeners ---
    if (saveBtn) saveBtn.addEventListener('click', saveChanges);
    if (logoutBtn) logoutBtn.addEventListener('click', handleLogout);
    if (mobileLogoutBtn) mobileLogoutBtn.addEventListener('click', handleLogout);
    
    // Toggle show/hide password
    if (togglePasswordBtn && editPassword) {
        togglePasswordBtn.addEventListener('click', () => {
            const isPassword = editPassword.type === 'password';
            editPassword.type = isPassword ? 'text' : 'password';
            togglePasswordBtn.innerHTML = isPassword ? `
                <svg class="w-4 h-4 text-brand-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l18 18" />
                </svg>
            ` : `
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
            `;
        });
    }

    // Event listeners untuk upload foto
    const avatarContainer = document.getElementById('avatarContainer');
    const avatarUploadInput = document.getElementById('avatarUpload');
    if (avatarContainer && avatarUploadInput) {
        avatarContainer.addEventListener('click', () => {
            avatarUploadInput.click();
        });
        avatarUploadInput.addEventListener('change', handlePhotoUpload);
    }
    
    // --- Initial Load ---
    await loadUserProfile();
});
