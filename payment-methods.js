// payment-methods.js - Payment Methods Management (CRUD)
import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';

export default class PaymentMethodsManager {
    constructor() {
        this.currentMethod = null; // For edit mode
        this.appSettingsId = null;
        this.init();
    }

    init() {
        initLogout('desktop-logout-btn');
        this.initializeEventListeners();
        this.loadQrisSettings();
        this.loadPaymentMethods(); // Load immediately on page load
    }

    initializeEventListeners() {
        // Back button from list view - go to app-settings.html
        document.getElementById('payment-methods-back-btn')?.addEventListener('click', () => {
            window.location.href = 'app-settings.html';
        });

        // Back button from form view - go back to list view
        document.getElementById('payment-form-back-btn')?.addEventListener('click', () => {
            this.hideFormView();
        });
        document.getElementById('desktop-payment-form-back-btn')?.addEventListener('click', () => {
            this.hideFormView();
        });

        // Add new payment method
        document.getElementById('add-payment-btn')?.addEventListener('click', () => {
            this.showAddForm();
        });
        document.getElementById('desktop-add-payment-btn')?.addEventListener('click', () => {
            this.showAddForm();
        });

        // Save button
        document.getElementById('pm-save-btn')?.addEventListener('click', () => {
            this.savePaymentMethod();
        });

        // Cancel button
        document.getElementById('pm-cancel-btn')?.addEventListener('click', () => {
            this.hideFormView();
        });

        // Delete button
        document.getElementById('pm-delete-btn')?.addEventListener('click', () => {
            this.deletePaymentMethod();
        });

        // QRIS Toggle
        document.getElementById('show-qris-input')?.addEventListener('change', (e) => {
            this.toggleQris(e.target.checked);
        });

        // QRIS Upload
        document.getElementById('qris-upload')?.addEventListener('change', (e) => {
            this.handleQrisUpload(e);
        });

        // Listen for settings loaded from apply-settings.js (sync)
        window.addEventListener('settings-loaded', (e) => {
            const settings = e.detail;
            if (settings) {
                if (settings.id) this.appSettingsId = settings.id;
                this.renderQrisPreview(settings.qris_image_url, settings.show_qris);
            }
        });
    }

    // ===============================================
    // View Management
    // ===============================================
    // View management for separate page
    showPaymentMethodsView() {
        document.getElementById('payment-methods-view')?.classList.remove('hidden');
        document.getElementById('payment-method-form-view')?.classList.add('hidden');
        // Toggle headers
        document.getElementById('payment-methods-header')?.classList.remove('hidden');
        document.getElementById('payment-form-header')?.classList.add('hidden');
    }

    hidePaymentMethodsView() {
        // Not needed on separate page - just navigate
        window.location.href = 'app-settings.html';
    }

    showAddForm() {
        // Reset form
        this.resetForm();
        
        // Set title to "Tambah"
        const titleMobile = document.getElementById('payment-form-title');
        const titleDesktop = document.getElementById('desktop-payment-form-title');
        if (titleMobile) titleMobile.textContent = 'Tambah Bank Baru';
        if (titleDesktop) titleDesktop.textContent = 'Tambah Bank Baru';
        
        // Hide delete button (add mode)
        document.getElementById('pm-delete-btn')?.classList.add('hidden');
        
        // Hide list view, show form view
        document.getElementById('payment-methods-view')?.classList.add('hidden');
        document.getElementById('payment-method-form-view')?.classList.remove('hidden');
        // Toggle headers
        document.getElementById('payment-methods-header')?.classList.add('hidden');
        document.getElementById('payment-form-header')?.classList.remove('hidden');
    }

    showEditForm(method) {
        // Store current method for editing
        this.currentMethod = method;
        
        // Populate form
        document.getElementById('pm-id').value = method.id;
        document.getElementById('pm-bank-name').value = method.bank_name;
        document.getElementById('pm-account-number').value = method.account_number;
        document.getElementById('pm-account-holder').value = method.account_holder;
        document.getElementById('pm-sort-order').value = method.sort_order || '';
        document.getElementById('pm-is-active').checked = method.is_active;
        
        // Set title to "Edit"
        const titleMobile = document.getElementById('payment-form-title');
        const titleDesktop = document.getElementById('desktop-payment-form-title');
        if (titleMobile) titleMobile.textContent = 'Edit Rekening Bank';
        if (titleDesktop) titleDesktop.textContent = 'Edit Rekening Bank';
        
        // Show delete button (edit mode)
        document.getElementById('pm-delete-btn')?.classList.remove('hidden');
        
        // Hide list view, show form view
        document.getElementById('payment-methods-view').classList.add('hidden');
        document.getElementById('payment-method-form-view').classList.remove('hidden');
        // Toggle headers
        document.getElementById('payment-methods-header')?.classList.add('hidden');
        document.getElementById('payment-form-header')?.classList.remove('hidden');
    }

    hideFormView() {
        // Hide form, show list
        document.getElementById('payment-method-form-view').classList.add('hidden');
        document.getElementById('payment-methods-view').classList.remove('hidden');
        // Toggle headers
        document.getElementById('payment-methods-header')?.classList.remove('hidden');
        document.getElementById('payment-form-header')?.classList.add('hidden');
        
        // Reset form
        this.resetForm();
    }

    resetForm() {
        document.getElementById('pm-id').value = '';
        document.getElementById('pm-bank-name').value = '';
        document.getElementById('pm-account-number').value = '';
        document.getElementById('pm-account-holder').value = '';
        document.getElementById('pm-sort-order').value = '';
        document.getElementById('pm-is-active').checked = true;
        this.currentMethod = null;
    }

    // ===============================================
    // CRUD Operations
    // ===============================================
    async loadPaymentMethods() {
        try {
            // Fetch all payment methods (including inactive for admin)
            const { data, error } = await supabase
                .from('payment_methods')
                .select('*')
                .order('sort_order', { ascending: true });

            if (error) throw error;

            // Render list
            this.renderPaymentMethodsList(data || []);
        } catch (error) {
            console.error('Error loading payment methods:', error);
            this.showToast('Gagal memuat data payment methods', 'error');
        }
    }

    renderPaymentMethodsList(methods) {
        const container = document.getElementById('payment-methods-list');
        
        if (methods.length === 0) {
            container.innerHTML = `
                <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 text-center">
                    <svg class="mx-auto mb-3 text-gray-400" xmlns="http://www.w3.org/2000/svg" width="48px" height="48px" fill="currentColor" viewBox="0 0 256 256"><path d="M224,48H32A16,16,0,0,0,16,64V192a16,16,0,0,0,16,16H224a16,16,0,0,0,16-16V64A16,16,0,0,0,224,48Zm0,16V88H32V64Zm0,128H32V104H224v88Z"></path></svg>
                    <p class="text-gray-600 font-medium">Belum ada metode pembayaran</p>
                    <p class="text-gray-500 text-sm mt-1">Klik "Tambah Bank Baru" untuk menambahkan</p>
                </div>
            `;
            return;
        }

        container.innerHTML = methods.map(method => `
            <div class="flex items-center gap-3.5 bg-white p-4 rounded-xl border ${method.is_active ? 'border-slate-200/80 hover:border-brand-300 shadow-xs' : 'border-slate-200 bg-slate-50/60 opacity-75'} cursor-pointer hover:shadow-md transition-all group" onclick="window.paymentMethodsManager.showEditForm(${JSON.stringify(method).replace(/"/g, '&quot;')})">
                <div class="text-brand-600 flex items-center justify-center rounded-xl bg-brand-50 shrink-0 size-11 group-hover:scale-105 transition-transform">
                    <svg xmlns="http://www.w3.org/2000/svg" width="22px" height="22px" fill="currentColor" viewBox="0 0 256 256">
                        <path d="M224,48H32A16,16,0,0,0,16,64V192a16,16,0,0,0,16,16H224a16,16,0,0,0,16-16V64A16,16,0,0,0,224,48Zm0,16V88H32V64Zm0,128H32V104H224v88Z"></path>
                    </svg>
                </div>
                <div class="flex flex-col flex-1 min-w-0">
                    <div class="flex items-center gap-2 mb-0.5">
                        <p class="text-slate-900 text-sm font-bold truncate group-hover:text-brand-600 transition-colors">${method.bank_name}</p>
                        ${method.is_active 
                            ? '<span class="text-[10px] font-bold bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-full border border-emerald-200">Aktif</span>'
                            : '<span class="text-[10px] font-bold bg-slate-100 text-slate-500 px-2 py-0.5 rounded-full border border-slate-200">Nonaktif</span>'
                        }
                    </div>
                    <p class="text-slate-900 text-sm font-mono font-bold tracking-tight">${method.account_number}</p>
                    <p class="text-slate-500 text-xs mt-0.5 truncate">A/N: ${method.account_holder} <span class="text-slate-300">|</span> Urutan: ${method.sort_order || '-'}</p>
                </div>
                <svg class="text-slate-400 group-hover:text-brand-600 group-hover:translate-x-1 transition-all" xmlns="http://www.w3.org/2000/svg" width="20px" height="20px" fill="currentColor" viewBox="0 0 256 256">
                    <path d="M181.66,133.66l-80,80a8,8,0,0,1-11.32-11.32L164.69,128,90.34,53.66a8,8,0,0,1,11.32-11.32l80,80A8,8,0,0,1,181.66,133.66Z"></path>
                </svg>
            </div>
        `).join('');
    }

    async savePaymentMethod() {
        try {
            // Validate inputs
            const bankName = document.getElementById('pm-bank-name').value.trim();
            const accountNumber = document.getElementById('pm-account-number').value.trim();
            const accountHolder = document.getElementById('pm-account-holder').value.trim();
            const sortOrder = parseInt(document.getElementById('pm-sort-order').value) || 0;
            const isActive = document.getElementById('pm-is-active').checked;
            const methodId = document.getElementById('pm-id').value;

            if (!bankName || !accountNumber || !accountHolder) {
                this.showToast('Mohon lengkapi semua field yang diperlukan', 'error');
                return;
            }

            // Show loading
            const saveBtn = document.getElementById('pm-save-btn');
            const originalText = saveBtn.textContent;
            saveBtn.textContent = 'MENYIMPAN...';
            saveBtn.disabled = true;

            const paymentData = {
                bank_name: bankName,
                account_number: accountNumber,
                account_holder: accountHolder,
                sort_order: sortOrder,
                is_active: isActive,
                updated_at: new Date().toISOString()
            };

            let result;
            if (methodId) {
                // Update existing
                result = await supabase
                    .from('payment_methods')
                    .update(paymentData)
                    .eq('id', methodId);
            } else {
                // Insert new
                result = await supabase
                    .from('payment_methods')
                    .insert([paymentData]);
            }

            if (result.error) throw result.error;

            this.showToast(`✅ Payment method berhasil ${methodId ? 'diupdate' : 'ditambahkan'}!`, 'success');
            
            // Back to list and reload
            this.hideFormView();
            await this.loadPaymentMethods();

        } catch (error) {
            console.error('Error saving payment method:', error);
            this.showToast('❌ Gagal menyimpan: ' + error.message, 'error');
        } finally {
            // Reset button
            const saveBtn = document.getElementById('pm-save-btn');
            saveBtn.textContent = 'SIMPAN';
            saveBtn.disabled = false;
        }
    }

    async deletePaymentMethod() {
        if (!this.currentMethod) return;

        const confirmDelete = confirm(
            `Hapus ${this.currentMethod.bank_name}?\n\n` +
            `Nomor: ${this.currentMethod.account_number}\n` +
            `Pemilik: ${this.currentMethod.account_holder}\n\n` +
            `Data akan dihapus permanen!`
        );

        if (!confirmDelete) return;

        try {
            // Show loading
            const deleteBtn = document.getElementById('pm-delete-btn');
            const originalText = deleteBtn.textContent;
            deleteBtn.textContent = 'MENGHAPUS...';
            deleteBtn.disabled = true;

            const { error } = await supabase
                .from('payment_methods')
                .delete()
                .eq('id', this.currentMethod.id);

            if (error) throw error;

            this.showToast('✅ Payment method berhasil dihapus!', 'success');
            
            // Back to list and reload
            this.hideFormView();
            await this.loadPaymentMethods();

        } catch (error) {
            console.error('Error deleting payment method:', error);
            this.showToast('❌ Gagal menghapus: ' + error.message, 'error');
            
            // Reset button
            const deleteBtn = document.getElementById('pm-delete-btn');
            deleteBtn.textContent = 'HAPUS BANK';
            deleteBtn.disabled = false;
        }
    }

    // ===============================================
    // QRIS Management
    // ===============================================
    renderQrisPreview(imageUrl, showQris) {
        const defaultQris = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='300' height='300' viewBox='0 0 300 300'><rect width='300' height='300' fill='%23f8f9fa' rx='16'/><rect x='20' y='20' width='260' height='260' fill='none' stroke='%23cbd5e1' stroke-width='4' stroke-dasharray='8 8' rx='12'/><path d='M70 70h50v50H70zm20 20h10v10H90zm90-20h50v50h-50zm20 20h10v10h-10zm-110 90h50v50H70zm20 20h10v10H90zm70-40h20v20h-20zm30 0h20v20h-20zm-30 30h20v20h-20zm30 30h20v20h-20zm-30 0h20v20h-20z' fill='%2364748b'/><text x='50%' y='62%' text-anchor='middle' fill='%23475569' font-size='14' font-weight='bold' font-family='sans-serif'>BELUM ADA QRIS</text><text x='50%' y='70%' text-anchor='middle' fill='%2394a3b8' font-size='11' font-family='sans-serif'>Klik untuk upload QRIS</text></svg>";
        const isOldQris = !imageUrl || imageUrl === 'assets/qris.jpeg';
        const previewEl = document.getElementById('qris-preview');
        if (previewEl) {
            previewEl.src = isOldQris ? defaultQris : imageUrl;
        }

        const showInput = document.getElementById('show-qris-input');
        if (showInput && showQris !== undefined) {
            showInput.checked = showQris !== false;
        }
    }

    async loadQrisSettings() {
        // 1. Coba muat dari localStorage terlebih dahulu (instant zero-flicker)
        try {
            const cached = JSON.parse(localStorage.getItem('app_settings') || '{}');
            if (cached && (cached.qris_image_url || cached.show_qris !== undefined)) {
                if (cached.id) this.appSettingsId = cached.id;
                this.renderQrisPreview(cached.qris_image_url, cached.show_qris);
            }
        } catch (e) {}

        // 2. Ambil data terbaru dari Supabase
        try {
            const { data, error } = await supabase
                .from('app_settings')
                .select('id, qris_image_url, show_qris')
                .limit(1)
                .maybeSingle();

            if (error) {
                console.error('[PaymentMethods] Error loading QRIS settings:', error);
                return;
            }

            if (data) {
                this.appSettingsId = data.id;
                this.renderQrisPreview(data.qris_image_url, data.show_qris);

                // Sinkronkan ke cache localStorage
                try {
                    const local = JSON.parse(localStorage.getItem('app_settings') || '{}');
                    local.id = data.id;
                    local.qris_image_url = data.qris_image_url;
                    local.show_qris = data.show_qris;
                    localStorage.setItem('app_settings', JSON.stringify(local));
                } catch (e) {}
            }
        } catch (e) {
            console.error('[PaymentMethods] Failed to load QRIS settings:', e);
        }
    }

    async toggleQris(enabled) {
        try {
            const updatePayload = {
                show_qris: enabled,
                updated_at: new Date().toISOString()
            };

            let res;
            if (this.appSettingsId) {
                res = await supabase
                    .from('app_settings')
                    .update(updatePayload)
                    .eq('id', this.appSettingsId);
            } else {
                res = await supabase
                    .from('app_settings')
                    .upsert([updatePayload]);
            }

            if (res.error) throw res.error;

            // Update local storage
            try {
                const local = JSON.parse(localStorage.getItem('app_settings') || '{}');
                local.show_qris = enabled;
                localStorage.setItem('app_settings', JSON.stringify(local));
            } catch (e) {}

            this.showToast(`QRIS ${enabled ? 'diaktifkan' : 'dinonaktifkan'}`, 'success');
        } catch (err) {
            console.error('Error updating QRIS toggle:', err);
            this.showToast('Gagal mengubah status QRIS', 'error');
            const showInput = document.getElementById('show-qris-input');
            if (showInput) showInput.checked = !enabled;
        }
    }

    async handleQrisUpload(event) {
        const file = event.target?.files?.[0];
        if (!file) return;

        const validTypes = ['image/png', 'image/jpeg', 'image/jpg'];
        if (!validTypes.includes(file.type)) {
            this.showToast('Format file tidak valid. Gunakan PNG atau JPG', 'error');
            return;
        }

        if (file.size > 2 * 1024 * 1024) {
            this.showToast('Ukuran file terlalu besar. Maksimal 2MB', 'error');
            return;
        }

        // Preview immediately
        const reader = new FileReader();
        reader.onload = (e) => {
            const previewEl = document.getElementById('qris-preview');
            if (previewEl) previewEl.src = e.target.result;
        };
        reader.readAsDataURL(file);

        this.showToast('Mengupload QRIS...', 'info');

        try {
            const fileExt = file.name.split('.').pop();
            const fileName = `qris-${Date.now()}.${fileExt}`;
            const filePath = `qris/${fileName}`;

            const { error: uploadError } = await supabase.storage
                .from('avatars')
                .upload(filePath, file, {
                    cacheControl: '3600',
                    upsert: false
                });

            if (uploadError) throw uploadError;

            const { data: urlData } = supabase.storage
                .from('avatars')
                .getPublicUrl(filePath);

            const publicUrl = urlData.publicUrl;

            const updatePayload = {
                qris_image_url: publicUrl,
                updated_at: new Date().toISOString()
            };

            let res;
            if (this.appSettingsId) {
                res = await supabase
                    .from('app_settings')
                    .update(updatePayload)
                    .eq('id', this.appSettingsId);
            } else {
                res = await supabase
                    .from('app_settings')
                    .upsert([updatePayload]);
            }

            if (res.error) throw res.error;

            // Update local storage
            try {
                const local = JSON.parse(localStorage.getItem('app_settings') || '{}');
                local.qris_image_url = publicUrl;
                local.show_qris = document.getElementById('show-qris-input')?.checked !== false;
                localStorage.setItem('app_settings', JSON.stringify(local));
            } catch (e) {}

            this.showToast('QRIS berhasil diupload dan disimpan!', 'success');
        } catch (err) {
            console.error('Error uploading QRIS:', err);
            this.showToast('Gagal upload QRIS: ' + err.message, 'error');
            this.loadQrisSettings();
        }
    }

    // ===============================================
    // Helper Functions
    // ===============================================
    showToast(message, type = 'info') {
        // Create toast if doesn't exist
        let toast = document.getElementById('pm-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'pm-toast';
            toast.className = 'fixed top-5 right-5 px-4 py-3 rounded-lg shadow-lg opacity-0 invisible transition-all duration-300 ease-in-out z-[150] max-w-sm';
            document.body.appendChild(toast);
        }

        // Set color based on type
        const colors = {
            success: 'bg-green-500 text-white',
            error: 'bg-red-500 text-white',
            info: 'bg-blue-500 text-white'
        };
        
        toast.className = `fixed top-5 right-5 px-4 py-3 rounded-lg shadow-lg transition-all duration-300 ease-in-out z-[150] max-w-sm ${colors[type]}`;
        toast.textContent = message;

        // Show toast
        setTimeout(() => {
            toast.classList.remove('opacity-0', 'invisible');
        }, 10);

        // Hide after 3 seconds
        setTimeout(() => {
            toast.classList.add('opacity-0', 'invisible');
        }, 3000);
    }
}

// Initialize Payment Methods Manager on page load
document.addEventListener('DOMContentLoaded', async () => {
    console.log('[PaymentMethods] Initializing on payment-methods.html');
    try {
        await requireRole('ADMIN');
    } catch (e) {
        console.warn('[PaymentMethods] requireRole check error:', e);
    }
    window.paymentMethodsManager = new PaymentMethodsManager();
});
