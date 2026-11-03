// pelanggan.js (Supabase Version - FINAL & COMPLETE with Event Delegation)
import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';
import { initializeCSVImport } from './csv-import.js?v=2.1';

document.addEventListener('DOMContentLoaded', async () => {
    await requireRole('ADMIN');
    initLogout('desktop-logout-btn');

    // State Management
    let allPackages = [];
    let currentEditingProfileId = null;
    let currentAddIdpl = null;
    let lastView = 'list';
    let currentFilter = 'all';

    // DOM Selectors
    const views = { list: document.getElementById('list-view'), detail: document.getElementById('detail-view'), form: document.getElementById('form-view') };
    const customerList = document.getElementById('customer-list');
    const searchInput = document.getElementById('search-input');
    const clearSearchBtn = document.getElementById('clear-search-btn');
    const filterButtons = { all: document.getElementById('filter-all'), active: document.getElementById('filter-active'), inactive: document.getElementById('filter-inactive') };
    const customerForm = document.getElementById('customer-form');
    const modalTitle = document.getElementById('modal-title');
    const saveBtnText = document.getElementById('save-btn-text');
    const newUserFields = document.getElementById('new-user-fields');
    const editUserFields = document.getElementById('edit-user-fields');

    // Initial Setup
    initializeEventListeners();
    initializeStickyHeader(); // Initialize sticky header behavior
    initLocationPicker();
    checkURLParameters(); // Check for URL parameters first
    fetchInitialData();

    // Initialize CSV Import
    initializeCSVImport(fetchData);

    // URL Parameter Handler
    function checkURLParameters() {
        const urlParams = new URLSearchParams(window.location.search);
        const statusParam = urlParams.get('status');

        if (statusParam) {
            // Map status parameter to filter
            if (statusParam === 'AKTIF') {
                currentFilter = 'active';
                setActiveFilterButton('active');
            } else if (statusParam === 'NONAKTIF') {
                currentFilter = 'inactive';
                setActiveFilterButton('inactive');
            }

            // Remove URL parameter after processing (optional)
            // window.history.replaceState({}, document.title, window.location.pathname);
        }
    }

    // Helper function to set active filter button
    function setActiveFilterButton(filterType) {
        // Reset all buttons first
        Object.values(filterButtons).forEach(btn => {
            btn.classList.remove('bg-[#683fe4]');
            btn.classList.add('bg-[#eae8f3]');
            const btnText = btn.querySelector('p');
            if (btnText) {
                btnText.classList.remove('text-white');
                btnText.classList.add('text-[#110e1b]');
            }
        });

        // Set active button
        const activeButton = filterButtons[filterType];
        if (activeButton) {
            activeButton.classList.remove('bg-[#eae8f3]');
            activeButton.classList.add('bg-[#683fe4]');
            const activeButtonText = activeButton.querySelector('p');
            if (activeButtonText) {
                activeButtonText.classList.remove('text-[#110e1b]');
                activeButtonText.classList.add('text-white');
            }
        }
    }

    // Sticky Header Management
    function initializeStickyHeader() {
        const stickyElement = document.querySelector('.search-filter-sticky');
        if (!stickyElement) return;

        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.intersectionRatio < 1) {
                    stickyElement.classList.add('is-sticky');
                } else {
                    stickyElement.classList.remove('is-sticky');
                }
            },
            { threshold: [1], rootMargin: '-1px 0px 0px 0px' }
        );

        observer.observe(stickyElement);
    }

    // View Management
    function switchView(viewName) {
        Object.values(views).forEach(view => view.classList.add('hidden'));
        if (views[viewName]) views[viewName].classList.remove('hidden');
        window.scrollTo(0, 0);
    }

    // FAB Menu Toggle
    function toggleFABMenu() {
        const fabExpandedMenu = document.getElementById('fab-expanded-menu');
        const fabBackdrop = document.getElementById('fab-backdrop');
        const fabInfoIcon = document.getElementById('fab-info-icon');
        const fabCloseIcon = document.getElementById('fab-close-icon');
        const fabMainBtn = document.getElementById('fab-main-btn');

        if (!fabExpandedMenu || !fabBackdrop || !fabInfoIcon || !fabCloseIcon || !fabMainBtn) {
            console.error('FAB Menu elements not found!');
            return;
        }

        const isExpanded = !fabExpandedMenu.classList.contains('hidden');

        if (isExpanded) {
            // Collapse menu
            fabExpandedMenu.classList.add('hidden');
            fabBackdrop.classList.add('hidden');
            fabInfoIcon.style.display = 'block';
            fabCloseIcon.style.display = 'none';
            // HAPUS BARIS INI: fabMainBtn.classList.remove('rotate-45');
        } else {
            // Expand menu
            fabExpandedMenu.classList.remove('hidden');
            fabBackdrop.classList.remove('hidden');
            fabInfoIcon.style.display = 'none';
            fabCloseIcon.style.display = 'block';
            // HAPUS BARIS INI: fabMainBtn.classList.add('rotate-45');
        }
    }

    // Helper: Close FAB Menu
    function closeFABMenu() {
        const fabExpandedMenu = document.getElementById('fab-expanded-menu');
        const fabBackdrop = document.getElementById('fab-backdrop');
        const fabInfoIcon = document.getElementById('fab-info-icon');
        const fabCloseIcon = document.getElementById('fab-close-icon');
        const fabMainBtn = document.getElementById('fab-main-btn');

        if (!fabExpandedMenu || fabExpandedMenu.classList.contains('hidden')) return;

        fabExpandedMenu.classList.add('hidden');
        fabBackdrop.classList.add('hidden');
        fabInfoIcon.style.display = 'block';
        fabCloseIcon.style.display = 'none';
        // HAPUS BARIS INI: fabMainBtn.classList.remove('rotate-45');
    }


    // Event Listeners using Event Delegation
    function initializeEventListeners() {
        document.body.addEventListener('click', (event) => {
            const button = event.target.closest('button');
            if (!button) return;

            const id = button.id;

            if (id === 'back-from-form' || id === 'cancel-btn' || id === 'back-from-detail') {
                if (id !== 'back-from-detail' && confirm('Yakin ingin kembali? Perubahan yang belum disimpan akan hilang.')) {
                    switchView(lastView);
                } else if (id === 'back-from-detail') {
                    switchView('list');
                }
                return;
            }

            if (id === 'edit-customer-icon-btn') {
                handleEditFromDetailView();
                return;
            }

            if (id === 'delete-customer-icon-btn') {
                handleDeleteCustomer();
                return;
            }

            if (id === 'add-customer-btn' || id === 'desktop-add-customer-btn') {
                closeFABMenu(); // Close FAB menu if open
                openAddForm();
                return;
            }

            if (id === 'import-csv-btn' || id === 'desktop-import-csv-btn') {
                closeFABMenu(); // Close FAB menu if open
                const modal = document.getElementById('csv-import-modal');
                if (modal) modal.classList.remove('hidden');
                return;
            }

            if (id === 'export-csv-btn' || id === 'desktop-export-csv-btn') {
                closeFABMenu(); // Close FAB menu if open
                handleExportCSV();
                return;
            }

            if (id === 'fab-main-btn') {
                toggleFABMenu();
                return;
            }

            if (id === 'fab-backdrop') {
                toggleFABMenu();
                return;
            }
        });

        // Listeners for non-button elements or form submissions
        searchInput.addEventListener('input', () => fetchData());
        clearSearchBtn.addEventListener('click', () => {
            searchInput.value = ''; // Kosongkan input
            fetchData();            // Panggil ulang fetchData untuk mereset daftar
            searchInput.focus();    // (Opsional) Fokuskan kembali ke input
        });
        customerForm.addEventListener('submit', handleFormSubmit);

        // Churn Date Logic - Show/Hide based on status
        document.getElementById('customer-status').addEventListener('change', function () {
            const churnDateContainer = document.getElementById('churn-date-container');
            if (this.value === 'NONAKTIF') {
                churnDateContainer.classList.remove('hidden');
            } else {
                churnDateContainer.classList.add('hidden');
            }
        });
        document.getElementById('customer-package').addEventListener('change', handlePaketChange);


        // Filter buttons
        Object.keys(filterButtons).forEach(key => {
            filterButtons[key].addEventListener('click', () => {
                currentFilter = key; // Set filter yang sedang aktif

                // Loop ke semua tombol filter untuk mereset tampilannya
                Object.values(filterButtons).forEach(btn => {
                    btn.classList.remove('bg-[#683fe4]', 'text-white'); // Hapus kelas aktif
                    btn.classList.add('bg-[#eae8f3]'); // Kembalikan warna latar non-aktif

                    // Ambil elemen <p> di dalam tombol
                    const textElement = btn.querySelector('p');
                    if (textElement) {
                        textElement.classList.remove('text-white'); // Hapus warna teks aktif
                        textElement.classList.add('text-[#110e1b]'); // Kembalikan warna teks non-aktif
                    }
                });

                const activeButton = filterButtons[key];
                // Terapkan kelas aktif pada tombol yang baru diklik
                activeButton.classList.remove('bg-[#eae8f3]');
                activeButton.classList.add('bg-[#683fe4]', 'text-white');

                // Terapkan warna teks aktif pada elemen <p> di dalamnya
                const activeText = activeButton.querySelector('p');
                if (activeText) {
                    activeText.classList.remove('text-[#110e1b]');
                    activeText.classList.add('text-white'); // Menggunakan 'text-white' yang lebih standar di Tailwind
                }

                fetchData(); // Muat ulang data sesuai filter baru
            });
        });

    }

    // Data Fetching
    async function fetchInitialData() {
        showLoading();
        await fetchPackages();
        await fetchData();

        // Only set "Semua" as active if no URL parameter was processed
        if (currentFilter === 'all') {
            setActiveFilterButton('all');
        }
    }

    async function fetchPackages() {
        const { data, error } = await supabase.from('packages').select('*').order('price', { ascending: true });
        if (error) {
            console.error('Error fetching packages:', error);
            return;
        }
        allPackages = data;
        populatePaketDropdown();
    }

    async function fetchData() {
        showLoading();

        // Tambahkan logika ini di awal fungsi fetchData
        if (searchInput.value.length > 0) {
            clearSearchBtn.classList.remove('hidden');
        } else {
            clearSearchBtn.classList.add('hidden');
        }

        const { data, error } = await supabase.rpc('get_all_customers', {
            p_filter: currentFilter,
            p_search_term: searchInput.value
        });

        if (error) {
            console.error('Error fetching profiles:', error);
            customerList.innerHTML = `<p class="text-center text-red-500 p-4">Gagal memuat data: ${error.message}</p>`;
            return;
        }
        renderCustomerList(data);
    }

    function getCustomerAvatar(profile) {
        if (!profile) return 'assets/avatar_male.svg';
        const url = profile.photo_url;
        if (url && (url.startsWith('data:') || url.startsWith('assets/') || (url.startsWith('http') && !url.includes('sb-admin-pro.startbootstrap.com')))) {
            return url;
        }
        return 'assets/avatar_male.svg';
    }

    function renderCustomerList(data) {
        const desktopBadge = document.getElementById('desktop-customer-count-badge');
        if (desktopBadge) {
            desktopBadge.textContent = `${(data || []).length} Pelanggan`;
        }

        customerList.innerHTML = '';
        if (!data || data.length === 0) {
            customerList.innerHTML = `
                <div class="col-span-full flex flex-col items-center justify-center py-12 px-4 bg-white rounded-2xl border border-slate-200/80 shadow-xs">
                    <img src="assets/no_data.svg" alt="No Data" class="w-48 h-48 mb-4 opacity-80">
                    <p class="text-center text-slate-700 text-base font-bold">Tidak ada pelanggan ditemukan</p>
                    <p class="text-center text-slate-400 text-xs mt-1">Coba ubah filter atau kata kunci pencarian</p>
                </div>
            `;
            return;
        }
        data.forEach(profile => {
            const isAktif = profile.status === 'AKTIF';
            const statusBadge = isAktif
                ? '<span class="px-2.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-[11px] font-bold">Aktif</span>'
                : '<span class="px-2.5 py-0.5 rounded-full bg-rose-50 text-rose-700 border border-rose-200 text-[11px] font-bold">Cabut</span>';

            let dateInfo;
            if (!isAktif) {
                const churnDate = profile.churn_date
                    ? new Date(profile.churn_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
                    : 'Belum diatur';
                dateInfo = `Cabut: ${churnDate}`;
            } else {
                const installDate = profile.installation_date
                    ? new Date(profile.installation_date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })
                    : 'N/A';
                dateInfo = `Pasang: ${installDate}`;
            }

            const avatarUrl = getCustomerAvatar(profile);
            const customerItem = document.createElement('div');
            customerItem.className = "group flex items-center gap-3.5 bg-white p-3.5 sm:p-4 rounded-xl md:rounded-2xl border border-slate-200/80 hover:border-brand-300 hover:shadow-md transition-all duration-150 cursor-pointer";
            customerItem.innerHTML = `
                <div class="relative shrink-0">
                    <div class="bg-center bg-no-repeat aspect-square bg-cover rounded-full h-12 w-12 sm:h-13 sm:w-13 border border-slate-100 shadow-xs" style="background-image: url('${avatarUrl}');"></div>
                    <span class="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-white ${isAktif ? 'bg-emerald-500' : 'bg-rose-500'}"></span>
                </div>
                <div class="flex flex-col justify-center min-w-0 flex-1">
                    <div class="flex items-center justify-between gap-2">
                        <p class="text-slate-900 text-sm sm:text-base font-bold truncate group-hover:text-brand-600 transition-colors">${profile.full_name}</p>
                        <div class="shrink-0">${statusBadge}</div>
                    </div>
                    <div class="flex items-center gap-2 text-xs text-slate-500 mt-0.5">
                        <span class="font-mono font-bold text-slate-700 bg-slate-100 px-1.5 py-0.5 rounded text-[10px] tracking-wide">${profile.idpl || '-'}</span>
                        <span class="text-slate-300">•</span>
                        <span class="truncate text-[11px]">${dateInfo}</span>
                    </div>
                    ${profile.address ? `
                    <p class="text-[11px] text-slate-400 truncate mt-1 flex items-center gap-1">
                        <svg class="w-3 h-3 shrink-0 text-slate-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        </svg>
                        <span class="truncate">${profile.address}</span>
                    </p>` : ''}
                </div>`;
            customerItem.addEventListener('click', () => openDetailView(profile.id));
            customerList.appendChild(customerItem);
        });
    }

    // Form & Detail View Logic
    function populatePaketDropdown() {
        const paketSelect = document.getElementById('customer-package');
        paketSelect.innerHTML = '<option value="">-- Pilih Paket --</option>';
        allPackages.forEach(pkg => {
            paketSelect.innerHTML += `<option value="${pkg.id}" data-price="${pkg.price}">${pkg.package_name} - ${pkg.speed_mbps} Mbps</option>`;
        });
    }

    function handlePaketChange(event) {
        const selectedOption = event.target.options[event.target.selectedIndex];
        const price = selectedOption.dataset.price || '0';
        document.getElementById('customer-bill').value = price;
    }

    // function openAddForm() {
    //     customerForm.reset();
    //     currentEditingProfileId = null;
    //     modalTitle.textContent = 'Tambah Pelanggan';
    //     saveBtnText.textContent = 'Simpan';
    //     newUserFields.classList.remove('hidden');
    //     editUserFields.classList.add('hidden');
    //     document.getElementById('customer-email').required = true;
    //     document.getElementById('customer-password').required = true;
    //     lastView = 'list';
    //     switchView('form');
    // }

    /**
     * Generator ID Pelanggan Acak 5 Karakter: 2 Huruf Kapital + 3 Angka (contoh: UD417)
     */
    async function generateCustomerIdpl() {
        const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // 24 huruf tanpa I & O
        const getRandomCode = () => {
            const l1 = letters.charAt(Math.floor(Math.random() * letters.length));
            const l2 = letters.charAt(Math.floor(Math.random() * letters.length));
            const num = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
            return `${l1}${l2}${num}`;
        };

        try {
            const { data: existingProfiles, error } = await supabase
                .from('profiles')
                .select('idpl');

            const existingSet = new Set((existingProfiles || []).map(p => p.idpl).filter(Boolean));

            for (let i = 0; i < 50; i++) {
                const candidate = getRandomCode();
                if (!existingSet.has(candidate)) {
                    return candidate;
                }
            }
        } catch (err) {
            console.warn('Gagal cek keunikan IDPL, gunakan generator acak langsung:', err);
        }

        return getRandomCode();
    }

    async function openAddForm() {
        customerForm.reset();
        currentEditingProfileId = null;
        modalTitle.textContent = 'Tambah Pelanggan';
        saveBtnText.textContent = 'Simpan';
        newUserFields.classList.remove('hidden');
        editUserFields.classList.add('hidden');

        const emailInput = document.getElementById('customer-email');
        const passInput = document.getElementById('customer-password');
        emailInput.required = true;
        passInput.required = true;

        // Reset location input & preview
        const quickInput = document.getElementById('quick-location-input');
        if (quickInput) quickInput.value = '';
        const smartFeedback = document.getElementById('smart-loc-feedback');
        if (smartFeedback) smartFeedback.className = 'text-[11px] mt-1 hidden font-medium';
        updateLocationPreview();

        lastView = 'list';
        switchView('form');

        emailInput.placeholder = 'Memuat...';
        passInput.placeholder = 'Memuat...';

        // Auto-generate email unik berbasis ID Pelanggan dan password
        try {
            currentAddIdpl = await generateCustomerIdpl();
            emailInput.value = `${currentAddIdpl.toLowerCase()}@wifi.id`;
            passInput.value = '123456';
        } catch (e) {
            console.error('Error auto-generating credentials:', e);
            currentAddIdpl = await generateCustomerIdpl();
            emailInput.value = `${currentAddIdpl.toLowerCase()}@wifi.id`;
            passInput.value = '123456';
        }
    }


    async function openEditForm(profile) {
        customerForm.reset();
        currentEditingProfileId = profile.id;
        modalTitle.textContent = 'Edit Pelanggan';
        saveBtnText.textContent = 'Update';
        newUserFields.classList.add('hidden');
        editUserFields.classList.remove('hidden');
        document.getElementById('customer-email').required = false;
        document.getElementById('customer-password').required = false;

        // Get user email for editing
        const { data: userEmail } = await supabase.rpc('get_user_email', { user_id: profile.id });

        document.getElementById('customer-name').value = profile.full_name || '';
        document.getElementById('customer-address').value = profile.address || '';
        document.getElementById('customer-whatsapp').value = profile.whatsapp_number || '';
        document.getElementById('customer-status').value = profile.status || 'AKTIF';
        document.getElementById('customer-device').value = profile.device_type || '';
        document.getElementById('customer-ip').value = profile.ip_static_pppoe || '';

        // Populate installation date (convert ISO string to YYYY-MM-DD)
        if (profile.installation_date) {
            const installDate = new Date(profile.installation_date);
            const formattedDate = installDate.toISOString().split('T')[0];
            document.getElementById('customer-installation-date').value = formattedDate;
        } else {
            document.getElementById('customer-installation-date').value = '';
        }

        document.getElementById('customer-latitude').value = profile.latitude || '';
        document.getElementById('customer-longitude').value = profile.longitude || '';
        document.getElementById('edit-customer-email').value = userEmail || '';
        document.getElementById('edit-customer-password').value = '';

        // Reset quick input & update location preview
        const quickInput = document.getElementById('quick-location-input');
        if (quickInput) quickInput.value = '';
        const smartFeedback = document.getElementById('smart-loc-feedback');
        if (smartFeedback) smartFeedback.className = 'text-[11px] mt-1 hidden font-medium';
        updateLocationPreview();

        // Churn Date Logic - Show/Hide and populate based on status
        const churnDateContainer = document.getElementById('churn-date-container');
        const churnDateInput = document.getElementById('customer-churn-date');

        if (profile.status === 'NONAKTIF') {
            churnDateContainer.classList.remove('hidden');
        } else {
            churnDateContainer.classList.add('hidden');
        }

        // Fill churn_date if exists
        churnDateInput.value = profile.churn_date || '';

        const { data: invoice } = await supabase.from('invoices').select('package_id, packages(price)').eq('customer_id', profile.id).order('invoice_period', { ascending: false }).limit(1).single();
        if (invoice) {
            document.getElementById('customer-package').value = invoice.package_id;
            document.getElementById('customer-bill').value = invoice.packages ? invoice.packages.price : '0';
        }

        lastView = 'detail';
        switchView('form');
    }

    async function handleEditFromDetailView() {
        const { data: profile } = await supabase.from('profiles').select('*').eq('id', currentEditingProfileId).single();
        if (profile) openEditForm(profile);
    }

    async function handleDeleteCustomer() {
        if (!currentEditingProfileId) {
            alert('Data pelanggan tidak ditemukan');
            return;
        }

        // Fetch customer data for confirmation
        const { data: profile, error: fetchError } = await supabase
            .from('profiles')
            .select('full_name, idpl')
            .eq('id', currentEditingProfileId)
            .single();

        if (fetchError || !profile) {
            alert('Gagal mengambil data pelanggan');
            return;
        }

        // Confirmation dialog
        const confirmMessage = `⚠️ PERHATIAN: Hapus Pelanggan\n\n` +
            `Nama: ${profile.full_name}\n` +
            `ID: ${profile.idpl}\n\n` +
            `Tindakan ini akan menghapus:\n` +
            `✓ Akun login (Supabase Auth)\n` +
            `✓ Data profil pelanggan\n` +
            `✓ Semua riwayat tagihan\n\n` +
            `Data yang dihapus TIDAK DAPAT dikembalikan!\n\n` +
            `Apakah Anda yakin ingin menghapus pelanggan ini?`;

        if (!confirm(confirmMessage)) {
            return;
        }

        // Double confirmation for safety
        const finalConfirm = confirm('Konfirmasi terakhir: Yakin ingin melanjutkan penghapusan?');
        if (!finalConfirm) {
            return;
        }

        try {
            // Show loading state
            const deleteBtn = document.getElementById('delete-customer-icon-btn');
            if (deleteBtn) deleteBtn.disabled = true;

            // Step 1: Delete all invoices (cascade)
            const { error: invoicesError } = await supabase
                .from('invoices')
                .delete()
                .eq('customer_id', currentEditingProfileId);

            if (invoicesError) {
                throw new Error(`Gagal menghapus tagihan: ${invoicesError.message}`);
            }

            // Step 2: Delete profile
            const { error: profileError } = await supabase
                .from('profiles')
                .delete()
                .eq('id', currentEditingProfileId);

            if (profileError) {
                throw new Error(`Gagal menghapus profil: ${profileError.message}`);
            }

            // Step 3: Delete from Supabase Auth (using Edge Function)
            try {
                const { error: authError } = await supabase.functions.invoke('delete-user', {
                    body: { user_id: currentEditingProfileId }
                });

                if (authError) {
                    console.warn('Warning: Gagal menghapus dari Auth (user mungkin sudah terhapus):', authError);
                }
            } catch (authDeleteError) {
                console.warn('Warning: Auth delete error (continuing):', authDeleteError);
                // Continue even if auth delete fails (user might not exist)
            }

            // Success notification
            alert(`✅ Pelanggan "${profile.full_name}" berhasil dihapus!\n\nData yang dihapus:\n- Akun login\n- Profil pelanggan\n- Riwayat tagihan`);

            // Reset state and refresh
            currentEditingProfileId = null;
            await fetchData();
            switchView('list');

        } catch (error) {
            console.error('Error deleting customer:', error);
            alert(`❌ Gagal menghapus pelanggan:\n${error.message}`);

            // Re-enable button
            const deleteBtn = document.getElementById('delete-customer-icon-btn');
            if (deleteBtn) deleteBtn.disabled = false;
        }
    }

    async function openDetailView(profileId) {
        lastView = 'list';
        switchView('detail');

        // Tampilkan status loading
        const profileImage = document.getElementById('detail-profile-image');
        const customerName = document.getElementById('detail-customer-name');
        const customerId = document.getElementById('detail-customer-id');

        if (customerName) customerName.textContent = 'Memuat...';
        if (customerId) customerId.textContent = 'Memuat...';

        // 1. Ambil data profil pelanggan
        const { data: profile, error } = await supabase.from('profiles').select('*').eq('id', profileId).single();

        if (error || !profile) {
            console.error('Error fetching profile detail:', error);
            if (customerName) customerName.textContent = 'Gagal memuat data';
            if (customerId) customerId.textContent = 'Error';
            return;
        }

        currentEditingProfileId = profile.id;

        // ==========================================================
        // === PERBAIKAN DIMULAI DI SINI ===
        // ==========================================================

        // 2. Ambil data paket berdasarkan 'package_id' dari profil (SUMBER DATA YANG BENAR)
        let customerPackage = null;
        if (profile.package_id) {
            const { data: packageData, error: packageError } = await supabase
                .from('packages')
                .select('*')
                .eq('id', profile.package_id)
                .single();
            if (!packageError) {
                customerPackage = packageData;
            } else {
                console.error('Error fetching package details:', packageError);
            }
        }

        // 3. Ambil email pengguna
        const { data: userEmail, error: emailError } = await supabase.rpc('get_user_email', { user_id: profile.id });
        if (emailError) console.error('Gagal mengambil email:', emailError);

        // ==========================================================
        // === PERBAIKAN SELESAI ===
        // ==========================================================

        // Update UI dengan data yang sudah benar
        if (profileImage) {
            profileImage.style.backgroundImage = `url('${getCustomerAvatar(profile)}')`;
        }
        if (customerName) customerName.textContent = profile.full_name || '-';
        if (customerId) customerId.textContent = profile.idpl || '-';

        // Update detail elemen menggunakan data paket dari profil
        const detailElements = {
            'detail-idpl': profile.idpl,
            'detail-nama': profile.full_name,
            'detail-alamat': profile.address,
            'detail-whatsapp': profile.whatsapp_number,
            'detail-email': userEmail || '-',
            'detail-paket': customerPackage ? customerPackage.package_name : 'Belum diatur',
            'detail-tagihan': customerPackage ?
                new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' }).format(customerPackage.price) :
                'N/A',
            'detail-status': profile.status,
            'detail-tanggal-pasang': (() => {
                if (profile.status === 'NONAKTIF') {
                    return profile.churn_date ? new Date(profile.churn_date).toLocaleDateString('id-ID') : 'Belum diset';
                } else {
                    return profile.installation_date ? new Date(profile.installation_date).toLocaleDateString('id-ID') : '-';
                }
            })(),
            'detail-jenis-perangkat': profile.device_type,
            'detail-ip-static': profile.ip_static_pppoe
        };

        Object.entries(detailElements).forEach(([elementId, value]) => {
            const element = document.getElementById(elementId);
            if (element) {
                element.textContent = value || '-';
            }
        });

        // Handle Location Section
        const locationSection = document.getElementById('location-section');
        const detailLocation = document.getElementById('detail-location');
        const openMapsBtn = document.getElementById('open-maps-btn');

        if (profile.latitude && profile.longitude) {
            locationSection?.classList.remove('hidden');
            if (detailLocation) {
                detailLocation.textContent = `${profile.latitude}, ${profile.longitude}`;
            }
            if (openMapsBtn) {
                const mapsUrl = `https://www.google.com/maps?q=${profile.latitude},${profile.longitude}`;
                openMapsBtn.href = mapsUrl;
                openMapsBtn.classList.remove('hidden');
            }
        } else {
            locationSection?.classList.add('hidden');
        }

        // Update label tanggal (tetap sama)
        const tanggalPasangLabel = document.evaluate("//p[contains(text(), 'TANGGAL PASANG') or contains(text(), 'TANGGAL CABUT')]", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
        if (tanggalPasangLabel) {
            tanggalPasangLabel.textContent = profile.status === 'NONAKTIF' ? 'TANGGAL CABUT' : 'TANGGAL PASANG';
        }

        // Load tagihan belum lunas (tetap sama)
        const unpaidBillsSection = document.getElementById('unpaid-bills-section');
        if (unpaidBillsSection) {
            unpaidBillsSection.classList.remove('hidden');
        }

        loadUnpaidBills(profile.id);
    }

    async function handleFormSubmit(event) {
        event.preventDefault();
        const saveBtn = document.getElementById('save-customer-btn');
        const isEditing = !!currentEditingProfileId;

        if (isEditing) {
            if (!confirm('Yakin ingin menyimpan perubahan?')) return;
            setButtonLoading(saveBtn, true, 'Update');

            const statusValue = document.getElementById('customer-status').value;
            const churnDateValue = document.getElementById('customer-churn-date').value;
            const gender = 'LAKI-LAKI';
            const photoUrl = 'assets/avatar_male.svg';

            // Get latitude/longitude
            const latitudeValue = document.getElementById('customer-latitude').value.trim();
            const longitudeValue = document.getElementById('customer-longitude').value.trim();

            // Get installation date
            const installationDateInput = document.getElementById('customer-installation-date').value;
            let installationDate = null;
            if (installationDateInput) {
                installationDate = new Date(installationDateInput).toISOString();
            }

            const profileData = {
                full_name: document.getElementById('customer-name').value,
                address: document.getElementById('customer-address').value,
                whatsapp_number: document.getElementById('customer-whatsapp').value,
                gender: gender,
                status: statusValue,
                device_type: document.getElementById('customer-device').value,
                ip_static_pppoe: document.getElementById('customer-ip').value,
                photo_url: photoUrl,
                installation_date: installationDate,
                latitude: latitudeValue ? parseFloat(latitudeValue) : null,
                longitude: longitudeValue ? parseFloat(longitudeValue) : null,
                // Churn Date Logic sesuai saran Gemini AI
                churn_date: statusValue === 'NONAKTIF' ? (churnDateValue || new Date().toISOString().split('T')[0]) : null
            };

            // Update profile data
            const { error: profileError } = await supabase.from('profiles').update(profileData).eq('id', currentEditingProfileId);

            if (profileError) {
                showErrorNotification(profileError.message);
                setButtonLoading(saveBtn, false, 'Update');
                return;
            }

            // Update package if changed
            const newPackageId = document.getElementById('customer-package').value;
            const newAmount = document.getElementById('customer-bill').value;

            // if (newPackageId && newAmount) {
            //     // Get current month invoice period
            //     const now = new Date();
            //     const currentMonthName = new Intl.DateTimeFormat('id-ID', { month: 'long' }).format(now);
            //     const currentYear = now.getFullYear();
            //     const currentPeriod = `${currentMonthName} ${currentYear}`;

            //     // Update current month invoice if exists, or create new one
            //     const { data: existingInvoice } = await supabase
            //         .from('invoices')
            //         .select('id')
            //         .eq('customer_id', currentEditingProfileId)
            //         .eq('invoice_period', currentPeriod)
            //         .single();

            //     if (existingInvoice) {
            //         // Update existing invoice
            //         const { error: invoiceUpdateError } = await supabase
            //             .from('invoices')
            //             .update({
            //                 package_id: parseInt(newPackageId),
            //                 amount: parseFloat(newAmount),
            //                 total_due: parseFloat(newAmount) // TAMBAHAN: total_due sama dengan amount
            //             })
            //             .eq('id', existingInvoice.id);

            //         if (invoiceUpdateError) {
            //             console.error('Error updating invoice:', invoiceUpdateError);
            //         }
            //     } else {
            //         // Create new invoice for current month
            //         const { error: invoiceCreateError } = await supabase
            //             .from('invoices')
            //             .insert({
            //                 customer_id: currentEditingProfileId,
            //                 package_id: parseInt(newPackageId),
            //                 invoice_period: currentPeriod,
            //                 amount: parseFloat(newAmount),
            //                 total_due: parseFloat(newAmount), // TAMBAHAN: total_due sama dengan amount
            //                 status: 'unpaid'
            //             });

            //         if (invoiceCreateError) {
            //             console.error('Error creating invoice:', invoiceCreateError);
            //         }
            //     }
            // }

            if (newPackageId && newAmount) {
                // 1. Update package_id di tabel profiles
                const { error: packageUpdateError } = await supabase
                    .from('profiles')
                    .update({ package_id: parseInt(newPackageId) })
                    .eq('id', currentEditingProfileId);

                if (packageUpdateError) {
                    console.error('Error updating package in profile:', packageUpdateError);
                    showErrorNotification('Gagal memperbarui paket pelanggan: ' + packageUpdateError.message);
                    // Lanjutkan proses meskipun gagal update di profile, karena update invoice lebih penting
                }

                // 2. Update tagihan bulan ini (jika ada)
                const now = new Date();
                const currentMonthName = new Intl.DateTimeFormat('id-ID', { month: 'long' }).format(now);
                const currentYear = now.getFullYear();
                const currentPeriod = `${currentMonthName} ${currentYear}`;

                const { error: invoiceUpdateError } = await supabase
                    .from('invoices')
                    .update({
                        package_id: parseInt(newPackageId),
                        amount: parseFloat(newAmount), // Sisa tagihan
                        total_due: parseFloat(newAmount) // Total tagihan
                    })
                    .eq('customer_id', currentEditingProfileId)
                    .eq('invoice_period', currentPeriod)
                    .eq('status', 'unpaid'); // Hanya update jika belum dibayar

                if (invoiceUpdateError) {
                    console.error('Error updating this month invoice:', invoiceUpdateError);
                    // Tidak perlu menampilkan error jika invoice bulan ini tidak ada
                }
            }

            // Update email and password if provided
            const newEmail = document.getElementById('edit-customer-email').value;
            const newPassword = document.getElementById('edit-customer-password').value;

            if (newEmail || newPassword) {
                const updateData = {};
                if (newEmail) updateData.email = newEmail;
                if (newPassword) updateData.password = newPassword;

                const { data, error: functionError } = await supabase.functions.invoke('update-user-auth', {
                    body: {
                        user_id: currentEditingProfileId,
                        update_data: updateData
                    }
                });

                if (functionError) {
                    showErrorNotification('Data pelanggan diperbarui, tapi gagal mengubah email/password: ' + functionError.message);
                } else if (data && !data.success) {
                    showErrorNotification('Gagal mengubah email/password: ' + data.message);
                } else {
                    showSuccessNotification('Data pelanggan dan kredensial berhasil diperbarui!');
                }
            } else {
                showSuccessNotification('Data pelanggan berhasil diperbarui!');
            }

            await fetchData();
            openDetailView(currentEditingProfileId);
            setButtonLoading(saveBtn, false, 'Update');

        } else {
            // Add Logic
            const gender = 'LAKI-LAKI';
            const photoUrl = 'assets/avatar_male.svg';

            // Gunakan ID Pelanggan yang sinkron dengan email, atau generate baru
            let idpl = currentAddIdpl;
            const emailVal = document.getElementById('customer-email').value.trim();
            const matchWifi = emailVal.match(/^([a-z0-9]+)@wifi\.id$/i);
            if (matchWifi) {
                idpl = matchWifi[1].toUpperCase();
            } else if (!idpl) {
                idpl = await generateCustomerIdpl();
            }
            currentAddIdpl = null;
            console.log('Final IDPL for Customer:', idpl);

            // Get latitude/longitude
            const latitudeValue = document.getElementById('customer-latitude').value.trim();
            const longitudeValue = document.getElementById('customer-longitude').value.trim();

            // Get installation date (use input value or default to today)
            const installationDateInput = document.getElementById('customer-installation-date').value;
            let installationDate;
            if (installationDateInput) {
                // Convert from YYYY-MM-DD to ISO string
                installationDate = new Date(installationDateInput).toISOString();
            } else {
                // Default to today
                installationDate = new Date().toISOString();
            }

            const customerData = {
                email: document.getElementById('customer-email').value,
                password: document.getElementById('customer-password').value,
                full_name: document.getElementById('customer-name').value,
                address: document.getElementById('customer-address').value,
                whatsapp_number: document.getElementById('customer-whatsapp').value,
                gender: gender,
                status: document.getElementById('customer-status').value,
                device_type: document.getElementById('customer-device').value,
                ip_static_pppoe: document.getElementById('customer-ip').value,
                photo_url: photoUrl,
                idpl: idpl,
                installation_date: installationDate,
                package_id: parseInt(document.getElementById('customer-package').value),
                amount: parseFloat(document.getElementById('customer-bill').value),
                latitude: latitudeValue ? parseFloat(latitudeValue) : null,
                longitude: longitudeValue ? parseFloat(longitudeValue) : null
            };

            if (!customerData.email || !customerData.password || !customerData.package_id) {
                showErrorNotification("Email, Password, dan Paket harus diisi.");
                return;
            }
            if (isNaN(customerData.package_id) || customerData.package_id <= 0) {
                showErrorNotification("Paket harus dipilih dengan benar.");
                return;
            }
            if (isNaN(customerData.amount) || customerData.amount <= 0) {
                showErrorNotification("Tagihan bulanan harus berupa angka yang valid.");
                return;
            }
            if (customerData.password.length < 6) {
                showErrorNotification("Password harus terdiri dari minimal 6 karakter.");
                return;
            }

            setButtonLoading(saveBtn, true, 'Simpan');

            // Debug: Log data yang akan dikirim
            console.log('Customer data to be sent:', customerData);

            const { data, error } = await supabase.functions.invoke('create-customer', { body: customerData });

            // Debug: Log response
            console.log('Supabase function response:', { data, error });

            if (error) {
                console.error('Supabase function error:', error);
                showErrorNotification(`Error: ${error.message}`);
            } else if (data && data.error) {
                console.error('Function returned error:', data.error);
                showErrorNotification(`Error: ${data.error}`);
            } else {
                showSuccessNotification(data?.message || 'Pelanggan berhasil ditambahkan!');
                await fetchData();
                switchView('list');
            }
            setButtonLoading(saveBtn, false, 'Simpan');
        }
    }

    // UI Helpers
    function showLoading() {
        customerList.innerHTML = Array(10).fill('').map(() => `<div class="skeleton-item flex items-center gap-4 bg-white px-4 min-h-[72px] py-2 justify-between border-b border-gray-100 animate-pulse"><div class="flex items-center gap-4 w-full"><div class="bg-gray-200 rounded-full h-14 w-14 shrink-0"></div><div class="flex flex-col justify-center gap-2 overflow-hidden flex-1"><div class="bg-gray-200 h-4 w-3/4 rounded"></div><div class="bg-gray-200 h-3 w-1/2 rounded"></div></div><div class="shrink-0 ml-auto"><div class="bg-gray-200 h-6 w-16 rounded-full"></div></div></div></div>`).join('');
    }

    async function loadUnpaidBills(profileId) {
        const unpaidBillsList = document.getElementById('unpaid-bills-list');
        unpaidBillsList.innerHTML = '<p class="text-sm text-gray-500 px-4">Memuat tagihan...</p>';

        // const { data, error } = await supabase.from('invoices').select('*').eq('customer_id', profileId).eq('status', 'unpaid');
        const { data, error } = await supabase.from('invoices').select('*, profiles!inner(*), packages(price)').eq('customer_id', profileId).eq('status', 'unpaid');

        if (error) {
            unpaidBillsList.innerHTML = `<p class="text-sm text-red-500 px-4">Gagal memuat tagihan.</p>`;
            return;
        }

        if (data.length > 0) {
            unpaidBillsList.innerHTML = '';
            data.forEach(bill => {
                unpaidBillsList.innerHTML += `
                    <div class="flex items-center gap-4 bg-[#f0eff3] px-4 min-h-[72px] py-2 justify-between rounded-lg mb-2">
                        <div class="flex flex-col justify-center">
                            <p class="text-[#110e1b] text-base font-medium">${bill.profiles.full_name || '-'}</p>
                            <p class="text-[#625095] text-sm">${bill.invoice_period || '-'}</p>
                        </div>
                        <div class="shrink-0"><p class="text-yellow-600 text-sm font-bold">${new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' }).format(bill.packages ? bill.packages.price : bill.amount)}</p></div>
                    </div>`;
            });
        } else {
            unpaidBillsList.innerHTML = '<p class="text-sm text-gray-500 px-4">Tidak ada tagihan yang belum dibayar.</p>';
        }
    }

    function setButtonLoading(button, isLoading, originalText) {
        const span = button.querySelector('span');
        if (span) {
            button.disabled = isLoading;
            span.textContent = isLoading ? 'Memproses...' : originalText;
        }
    }

    function showSuccessNotification(message) { alert(message); }
    function showErrorNotification(message) { alert(message); }

    async function handleExportCSV() {
        try {
            // 1. Fetch all customer profiles with package details
            const { data: profiles, error } = await supabase
                .from('profiles')
                .select('*, packages(price)')
                .eq('role', 'USER')
                .order('created_at', { ascending: true });

            if (error) throw error;

            if (!profiles || profiles.length === 0) {
                alert('Tidak ada data pelanggan untuk diexport.');
                return;
            }

            // 2. Fetch user emails gracefully with Promise.allSettled
            const emailResults = await Promise.allSettled(
                profiles.map(p =>
                    supabase.rpc('get_user_email', { user_id: p.id })
                        .then(res => res.data || '')
                        .catch(() => '')
                )
            );
            const emails = emailResults.map(r => (r.status === 'fulfilled' && r.value) ? r.value : '');

            // 3. Header columns (tanpa gender)
            const headers = [
                'email', 'password', 'full_name', 'address', 'whatsapp_number',
                'status', 'package_id', 'amount', 'installation_date',
                'latitude', 'longitude', 'device_type', 'ip_static_pppoe'
            ];

            // 4. Map profiles to rows
            const rows = profiles.map((p, idx) => {
                const email = emails[idx] || '';
                const password = ''; // Passwords stored as hashes in DB, exported as empty string
                const fullName = p.full_name || '';
                const address = p.address || '';
                const whatsapp = p.whatsapp_number || '';
                const status = p.status || 'AKTIF';
                const packageId = p.package_id || '';
                const amount = p.packages ? p.packages.price : (p.amount || '');
                const installDate = p.installation_date ? new Date(p.installation_date).toISOString().split('T')[0] : '';
                const lat = p.latitude || '';
                const lng = p.longitude || '';
                const device = p.device_type || '';
                const ip = p.ip_static_pppoe || '';

                return [
                    email, password, fullName, address, whatsapp,
                    status, packageId, amount, installDate,
                    lat, lng, device, ip
                ];
            });

            // 5. Build CSV text with proper escaping
            const csvRows = [
                headers.join(','),
                ...rows.map(row =>
                    row.map(field => {
                        const str = String(field ?? '');
                        if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
                            return `"${str.replace(/"/g, '""')}"`;
                        }
                        return str;
                    }).join(',')
                )
            ];

            const csvString = csvRows.join('\r\n');

            // 6. Download CSV file with UTF-8 BOM
            const blob = new Blob(['\uFEFF' + csvString], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            const now = new Date();
            const dateStr = now.toISOString().split('T')[0];

            link.href = url;
            link.download = `data_pelanggan_${dateStr}.csv`;
            document.body.appendChild(link);
            link.click();
            setTimeout(() => {
                document.body.removeChild(link);
                URL.revokeObjectURL(url);
            }, 200);

        } catch (err) {
            console.error('Error exporting CSV:', err);
            alert('Gagal mengeksport data CSV: ' + err.message);
        }
    }

    // ==========================================
    // Fitur Lokasi Otomatis & Interactive Map Picker
    // ==========================================
    let leafletMap = null;
    let mapMarker = null;

    function showLocationToast(message, type = 'success') {
        let toast = document.getElementById('location-toast');
        if (!toast) {
            toast = document.createElement('div');
            toast.id = 'location-toast';
            document.body.appendChild(toast);
        }
        const bg = type === 'success' ? 'bg-emerald-600' : (type === 'error' ? 'bg-red-600' : 'bg-gray-800');
        toast.className = `fixed bottom-20 left-1/2 -translate-x-1/2 z-50 px-4 py-2.5 rounded-xl shadow-xl text-xs font-semibold text-white flex items-center gap-2 transition-all duration-300 ${bg}`;
        toast.textContent = message;
        clearTimeout(toast.timeoutId);
        toast.timeoutId = setTimeout(() => {
            toast.className = 'hidden';
        }, 3200);
    }

    function parseLocationInput(text) {
        if (!text || typeof text !== 'string') return null;
        text = text.trim();
        if (!text) return null;

        // 1. Format @lat,lng (contoh URL desktop Google Maps)
        const atMatch = text.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
        if (atMatch) return { lat: parseFloat(atMatch[1]), lng: parseFloat(atMatch[2]) };

        // 2. Query parameter q=lat,lng atau ll=lat,lng
        const qMatch = text.match(/[?&](?:q|ll|query)=(-?\d+\.\d+),(-?\d+\.\d+)/);
        if (qMatch) return { lat: parseFloat(qMatch[1]), lng: parseFloat(qMatch[2]) };

        // 3. Format koordinat biasa: "-6.9174639, 107.6191228" atau "-6.9174639 107.6191228"
        const coordMatch = text.match(/(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)/);
        if (coordMatch) return { lat: parseFloat(coordMatch[1]), lng: parseFloat(coordMatch[2]) };

        return null;
    }

    function updateLocationPreview() {
        const latInput = document.getElementById('customer-latitude');
        const lngInput = document.getElementById('customer-longitude');
        const previewLink = document.getElementById('btn-view-gmaps');
        const statusText = document.getElementById('loc-status-text');

        const latVal = latInput?.value?.trim();
        const lngVal = lngInput?.value?.trim();

        if (latVal && lngVal && !isNaN(parseFloat(latVal)) && !isNaN(parseFloat(lngVal))) {
            const url = `https://www.google.com/maps?q=${latVal},${lngVal}`;
            if (previewLink) {
                previewLink.href = url;
                previewLink.classList.remove('hidden');
            }
            if (statusText) {
                statusText.textContent = `📍 Titik: ${parseFloat(latVal).toFixed(5)}, ${parseFloat(lngVal).toFixed(5)}`;
                statusText.className = 'text-xs text-emerald-600 font-semibold';
            }
        } else {
            if (previewLink) previewLink.classList.add('hidden');
            if (statusText) {
                statusText.textContent = 'Otomatis GPS atau ketik manual';
                statusText.className = 'text-xs text-gray-500';
            }
        }
    }

    function initLocationPicker() {
        const btnGetLoc = document.getElementById('btn-get-current-loc');
        const btnOpenMap = document.getElementById('btn-open-map-picker');
        const quickInput = document.getElementById('quick-location-input');
        const btnPaste = document.getElementById('btn-paste-smart-loc');
        const feedback = document.getElementById('smart-loc-feedback');
        const latInput = document.getElementById('customer-latitude');
        const lngInput = document.getElementById('customer-longitude');

        // Listener input lat/lng manual
        latInput?.addEventListener('input', updateLocationPreview);
        lngInput?.addEventListener('input', updateLocationPreview);

        // 1. Ambil Lokasi GPS (1-Klik)
        btnGetLoc?.addEventListener('click', () => {
            if (!navigator.geolocation) {
                showLocationToast('Browser tidak mendukung GPS Geolocation.', 'error');
                return;
            }

            const btnText = document.getElementById('btn-get-loc-text');
            const originalText = btnText ? btnText.textContent : '';
            if (btnText) btnText.textContent = 'Mencari GPS...';
            btnGetLoc.disabled = true;

            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    btnGetLoc.disabled = false;
                    if (btnText) btnText.textContent = originalText;

                    const lat = pos.coords.latitude.toFixed(7);
                    const lng = pos.coords.longitude.toFixed(7);
                    if (latInput) latInput.value = lat;
                    if (lngInput) lngInput.value = lng;
                    updateLocationPreview();

                    showLocationToast(`📍 Lokasi GPS berhasil didapatkan! (Akurasi: ±${pos.coords.accuracy.toFixed(1)}m)`, 'success');
                },
                (err) => {
                    btnGetLoc.disabled = false;
                    if (btnText) btnText.textContent = originalText;
                    let msg = 'Gagal mengakses GPS: ' + err.message;
                    if (err.code === 1) msg = 'Izin akses lokasi ditolak oleh browser/pengguna.';
                    else if (err.code === 2) msg = 'Posisi GPS tidak ditemukan. Pastikan GPS aktif.';
                    else if (err.code === 3) msg = 'Waktu permintaan GPS habis (timeout).';
                    showLocationToast(msg, 'error');
                },
                { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
            );
        });

        // 2. Smart Paste Handler
        function handleSmartParse(text) {
            const result = parseLocationInput(text);
            if (result) {
                if (latInput) latInput.value = result.lat.toFixed(7);
                if (lngInput) lngInput.value = result.lng.toFixed(7);
                updateLocationPreview();

                if (feedback) {
                    feedback.textContent = `✓ Koordinat berhasil dideteksi: ${result.lat}, ${result.lng}`;
                    feedback.className = 'text-[11px] mt-1 text-emerald-600 font-semibold block';
                }
                showLocationToast('Koordinat berhasil diekstrak!', 'success');
                return true;
            } else {
                if (feedback) {
                    feedback.textContent = '✗ Format link / koordinat tidak dikenali';
                    feedback.className = 'text-[11px] mt-1 text-red-500 font-medium block';
                }
                return false;
            }
        }

        quickInput?.addEventListener('input', (e) => {
            const val = e.target.value.trim();
            if (val.length > 5) handleSmartParse(val);
        });

        quickInput?.addEventListener('paste', (e) => {
            setTimeout(() => {
                const val = quickInput.value.trim();
                if (val) handleSmartParse(val);
            }, 50);
        });

        btnPaste?.addEventListener('click', async () => {
            try {
                if (navigator.clipboard && navigator.clipboard.readText) {
                    const text = await navigator.clipboard.readText();
                    if (text) {
                        if (quickInput) quickInput.value = text;
                        handleSmartParse(text);
                        return;
                    }
                }
            } catch (_) {}

            const val = quickInput?.value?.trim();
            if (val) {
                handleSmartParse(val);
            } else {
                showLocationToast('Silakan ketik atau tempel link/koordinat di kotak.', 'info');
                quickInput?.focus();
            }
        });

        // 3. Map Picker Modal (Leaflet)
        const mapModal = document.getElementById('map-picker-modal');
        const btnCloseMap = document.getElementById('btn-close-map-modal');
        const btnConfirmMap = document.getElementById('btn-confirm-map-loc');
        const btnModalMyLoc = document.getElementById('btn-modal-my-loc');
        const modalCoordsDisplay = document.getElementById('modal-coords-display');

        let selectedLat = null;
        let selectedLng = null;

        function setMapSelection(lat, lng, updateMap = false) {
            selectedLat = lat;
            selectedLng = lng;

            if (modalCoordsDisplay) {
                modalCoordsDisplay.textContent = `📍 ${lat.toFixed(6)}, ${lng.toFixed(6)}`;
            }

            if (window.L && leafletMap) {
                if (!mapMarker) {
                    mapMarker = L.marker([lat, lng], { draggable: true }).addTo(leafletMap);
                    mapMarker.on('dragend', (e) => {
                        const pos = e.target.getLatLng();
                        setMapSelection(pos.lat, pos.lng, false);
                    });
                } else {
                    mapMarker.setLatLng([lat, lng]);
                }

                if (updateMap) {
                    leafletMap.setView([lat, lng], 16);
                }
            }
        }

        btnOpenMap?.addEventListener('click', () => {
            if (!mapModal) return;
            mapModal.classList.remove('hidden');

            const currentLat = parseFloat(latInput?.value);
            const currentLng = parseFloat(lngInput?.value);

            const hasValidCoords = !isNaN(currentLat) && !isNaN(currentLng);
            const initLat = hasValidCoords ? currentLat : -6.2088;
            const initLng = hasValidCoords ? currentLng : 106.8456;
            const initZoom = hasValidCoords ? 16 : 12;

            setTimeout(() => {
                if (window.L) {
                    if (!leafletMap) {
                        leafletMap = L.map('leaflet-map-container').setView([initLat, initLng], initZoom);
                        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                            maxZoom: 19,
                            attribution: '© OpenStreetMap contributors'
                        }).addTo(leafletMap);

                        leafletMap.on('click', (e) => {
                            setMapSelection(e.latlng.lat, e.latlng.lng, false);
                        });
                    } else {
                        leafletMap.invalidateSize();
                        leafletMap.setView([initLat, initLng], initZoom);
                    }

                    if (hasValidCoords) {
                        setMapSelection(initLat, initLng, true);
                    } else {
                        // Coba ambil GPS user untuk memusatkan peta
                        if (navigator.geolocation) {
                            navigator.geolocation.getCurrentPosition(
                                (pos) => {
                                    setMapSelection(pos.coords.latitude, pos.coords.longitude, true);
                                },
                                () => {
                                    setMapSelection(initLat, initLng, false);
                                },
                                { timeout: 5000 }
                            );
                        } else {
                            setMapSelection(initLat, initLng, false);
                        }
                    }
                } else {
                    showLocationToast('Library Peta sedang dimuat, mohon tunggu sebentar...', 'info');
                }
            }, 150);
        });

        btnCloseMap?.addEventListener('click', () => {
            mapModal?.classList.add('hidden');
        });

        btnModalMyLoc?.addEventListener('click', () => {
            if (!navigator.geolocation) return;
            btnModalMyLoc.textContent = 'Mencari...';
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    btnModalMyLoc.textContent = '📍 Lokasi Saya';
                    setMapSelection(pos.coords.latitude, pos.coords.longitude, true);
                },
                (err) => {
                    btnModalMyLoc.textContent = '📍 Lokasi Saya';
                    showLocationToast('Gagal mengambil lokasi GPS: ' + err.message, 'error');
                },
                { enableHighAccuracy: true, timeout: 10000 }
            );
        });

        btnConfirmMap?.addEventListener('click', () => {
            if (selectedLat != null && selectedLng != null) {
                if (latInput) latInput.value = selectedLat.toFixed(7);
                if (lngInput) lngInput.value = selectedLng.toFixed(7);
                updateLocationPreview();
                mapModal?.classList.add('hidden');
                showLocationToast('Titik lokasi berhasil diterapkan!', 'success');
            } else {
                showLocationToast('Silakan klik di peta terlebih dahulu untuk memilih titik.', 'error');
            }
        });
    }
});
