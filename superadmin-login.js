// superadmin-login.js - Logika Login Khusus Super Admin SaaS
import { supabase } from './supabase-client.js';

document.addEventListener('DOMContentLoaded', async () => {
    const form = document.getElementById('form-superadmin-login');
    const emailInput = document.getElementById('superadmin-email');
    const passwordInput = document.getElementById('superadmin-password');
    const btnTogglePassword = document.getElementById('btn-toggle-password');
    const submitBtn = document.getElementById('btn-login-submit');
    const submitText = document.getElementById('btn-login-text');
    const submitSpinner = document.getElementById('btn-login-spinner');
    const alertBox = document.getElementById('login-alert');
    const alertText = document.getElementById('login-alert-text');

    // 1. Cek jika sudah memiliki sesi login aktif
    try {
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user) {
            const { data: profile } = await supabase
                .from('profiles')
                .select('role')
                .eq('id', session.user.id)
                .maybeSingle();

            const rawRole = (profile?.role || '').toLowerCase();
            if (rawRole === 'super_admin' || rawRole === 'superadmin') {
                window.location.replace('superadmin.html');
                return;
            }
        }
    } catch (e) {
        console.warn('Gagal mengecek sesi:', e);
    }

    // Toggle view password
    btnTogglePassword?.addEventListener('click', () => {
        if (!passwordInput) return;
        if (passwordInput.type === 'password') {
            passwordInput.type = 'text';
            btnTogglePassword.classList.add('text-indigo-400');
        } else {
            passwordInput.type = 'password';
            btnTogglePassword.classList.remove('text-indigo-400');
        }
    });

    // Helper showAlert
    function showAlert(msg, isError = true) {
        if (!alertBox || !alertText) return;
        alertText.textContent = msg;
        if (isError) {
            alertBox.className = 'mb-5 p-3.5 rounded-xl text-xs font-semibold flex items-start gap-2.5 bg-rose-500/10 border border-rose-500/20 text-rose-300 animate-in fade-in';
        } else {
            alertBox.className = 'mb-5 p-3.5 rounded-xl text-xs font-semibold flex items-start gap-2.5 bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 animate-in fade-in';
        }
        alertBox.classList.remove('hidden');
    }

    function hideAlert() {
        alertBox?.classList.add('hidden');
    }

    function setLoading(isLoading) {
        if (submitBtn) submitBtn.disabled = isLoading;
        if (isLoading) {
            submitSpinner?.classList.remove('hidden');
            if (submitText) submitText.textContent = 'Memverifikasi Akses...';
        } else {
            submitSpinner?.classList.add('hidden');
            if (submitText) submitText.textContent = 'Masuk ke Panel Super Admin';
        }
    }

    // 2. Submit Handler
    form?.addEventListener('submit', async (e) => {
        e.preventDefault();
        hideAlert();

        const email = emailInput?.value?.trim();
        const password = passwordInput?.value;

        if (!email || !password) {
            showAlert('Email dan password wajib diisi.');
            return;
        }

        setLoading(true);

        try {
            // Step 1: Login via Supabase Auth
            const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
                email,
                password
            });

            if (authError) {
                throw new Error('Email atau password salah. Silakan coba lagi.');
            }

            if (!authData?.user) {
                throw new Error('Gagal login. Data user tidak ditemukan.');
            }

            // Step 2: Cek Role di tabel profiles
            const { data: profile, error: profError } = await supabase
                .from('profiles')
                .select('*')
                .eq('id', authData.user.id)
                .maybeSingle();

            if (profError || !profile) {
                // Sign out demi keamanan
                await supabase.auth.signOut();
                throw new Error('Profil user belum terdaftar di database.');
            }

            const rawRole = (profile.role || '').toLowerCase();
            const isSuperAdmin = rawRole === 'super_admin' || rawRole === 'superadmin';

            if (!isSuperAdmin) {
                // Logout akun non-superadmin dari portal ini
                await supabase.auth.signOut();
                throw new Error('Akses Ditolak: Akun ini terdaftar sebagai ' + (profile.role || 'Admin Mitra') + ', bukan Super Admin. Silakan login melalui portal utama.');
            }

            // Step 3: Berhasil - Langsung buka superadmin.html
            showAlert('Login Super Admin berhasil! Mengalihkan ke panel...', false);
            if (submitText) submitText.textContent = 'Membuka Panel Super Admin...';

            setTimeout(() => {
                window.location.replace('superadmin.html');
            }, 500);

        } catch (err) {
            console.error('Super Admin Login Error:', err);
            showAlert(err.message || 'Terjadi kesalahan saat login.');
            setLoading(false);
        }
    });
});
