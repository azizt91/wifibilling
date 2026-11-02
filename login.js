// login.js (Supabase version)
import { supabase } from './supabase-client.js';

document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('login-form');
    const errorMessage = document.getElementById('error-message');

    // Check if a user is already logged in and redirect them
    supabase.auth.getSession().then(({ data: { session } }) => {
        if (session) {
            handleRedirect(session.user);
        } 
    });

    // Toggle intip/lihat password
    const passwordInput = document.getElementById('password');
    const btnTogglePassword = document.getElementById('btn-toggle-password');
    btnTogglePassword?.addEventListener('click', () => {
        if (!passwordInput) return;
        if (passwordInput.type === 'password') {
            passwordInput.type = 'text';
            btnTogglePassword.classList.add('text-white');
            btnTogglePassword.classList.remove('text-white/60');
        } else {
            passwordInput.type = 'password';
            btnTogglePassword.classList.remove('text-white');
            btnTogglePassword.classList.add('text-white/60');
        }
    });

    loginForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        const submitButton = event.target.querySelector('button[type="submit"]');
        errorMessage.textContent = '';
        errorMessage.classList.add('hidden');

        let email = (document.getElementById('email')?.value || '').trim();
        // Jika pelanggan mengetik IDPL saja (misal: gj782 atau GJ782 tanpa @), otomatis lengkapi @wifi.id
        if (email && !email.includes('@')) {
            email = `${email.toLowerCase()}@wifi.id`;
        }
        const password = document.getElementById('password')?.value || '';

        setButtonLoading(submitButton, true);

        try {
            const { data, error } = await supabase.auth.signInWithPassword({
                email: email,
                password: password,
            });

            if (error) {
                throw error;
            }

            if (data.user) {
                await handleRedirect(data.user);
            }

        } catch (error) {
            console.error("DEBUG: Detail error saat login:", error);
            const msg = (error?.message || '').toLowerCase();
            if (msg.includes('email not confirmed')) {
                errorMessage.textContent = 'Email belum dikonfirmasi! Silakan cek inbox/spam email Anda, atau matikan opsi "Confirm email" di pengaturan Supabase Authentication.';
            } else if (msg.includes('invalid login credentials')) {
                errorMessage.textContent = 'Email atau password salah. Pastikan password sudah benar dan perhatikan huruf besar/kecil.';
            } else if (msg.includes('user not found')) {
                errorMessage.textContent = 'Akun dengan email ini belum terdaftar.';
            } else if (msg.includes('too many requests')) {
                errorMessage.textContent = 'Terlalu banyak percobaan login yang gagal. Silakan tunggu beberapa saat lagi.';
            } else {
                errorMessage.textContent = error.message || 'Email atau password salah. Silakan coba lagi.';
            }
            errorMessage.classList.remove('hidden');
        } finally {
            setButtonLoading(submitButton, false);
        }
    });

    async function handleRedirect(user) {
        console.log("DEBUG: Attempting to fetch profile for user ID:", user.id);

        try {
            // TEMPORARY DEBUGGING: Fetch profile without .single() to see what happens
            const { data: profiles, error } = await supabase
                .from('profiles')
                .select('*') // Select all columns for more info
                .eq('id', user.id);

            console.log("DEBUG: Query result data:", profiles);
            console.log("DEBUG: Query error object:", error);

            if (error) {
                throw new Error(`Supabase query failed: ${error.message}`);
            }

            if (!profiles || profiles.length === 0) {
                throw new Error('KRITIS: Login berhasil, tapi tidak ada profil yang cocok di database untuk pengguna ini.');
            }
            
            if (profiles.length > 1) {
                 throw new Error('KRITIS: Ditemukan lebih dari satu profil untuk ID pengguna yang sama. Data tidak konsisten.');
            }

            const profile = profiles[0];
            console.log("DEBUG: Found profile:", profile);

            // Bersihkan cache settings lama dari browser agar tidak terjadi kebocoran tampilan antar tenant
            localStorage.removeItem('app_settings');
            localStorage.removeItem('whatsapp_settings');
            localStorage.removeItem('pwa_manifest');

            // Redirect based on the role from the profiles table
            const rawRole = (profile.role || '').toLowerCase();
            if (rawRole === 'super_admin' || rawRole === 'superadmin') {
                window.location.href = 'superadmin.html';
            } else if (rawRole === 'admin') {
                window.location.href = 'dashboard.html';
            } else if (rawRole === 'user' || rawRole === 'pelanggan' || rawRole === 'customer') {
                window.location.href = 'pelanggan_dashboard.html';
            } else {
                errorMessage.textContent = `Peran pengguna (${profile.role}) tidak dikenali.`;
                errorMessage.classList.remove('hidden');
            }
        } catch (error) {
            errorMessage.textContent = error.message;
            errorMessage.classList.remove('hidden');
            console.error("DEBUG: Error during handleRedirect:", error);
            // If fetching profile fails, sign the user out to be safe
            await supabase.auth.signOut();
        }
    }

    function setButtonLoading(button, loading) {
        const span = button.querySelector('span');
        if (!span) return;

        if (loading) {
            button.disabled = true;
            span.innerHTML = 'Memproses...';
            button.classList.add('opacity-75', 'cursor-not-allowed');
        } else {
            button.disabled = false;
            span.innerHTML = `
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/>
                </svg>
                Masuk
            `;
            button.classList.remove('opacity-75', 'cursor-not-allowed');
        }
    }
});
