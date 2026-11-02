import { supabase } from './supabase-client.js';
import { getCurrentAdminName, showNotificationResult, sendCustomerPaymentNotification } from './whatsapp-notification.js'; // Pastikan `sendCustomerPaymentNotification` ada di sini
import { receiptPrinter } from './receipt-printer.js';


document.addEventListener('DOMContentLoaded', () => {

    // ===============================================
    // State Management & Global Variables
    // ===============================================
    let unpaidData = [];
    let installmentData = [];
    let paidData = [];
    let allPaidData = []; // Store all paid data for filtering
    let filteredPaidData = []; // Store filtered paid data
    let currentTab = 'unpaid'; // Default tab
    let currentDetailData = null; // For storing detail view data

    // ===============================================
    // DOM Element Selectors
    // ===============================================
    // Views will be initialized when needed
    let views = {};
    const invoiceList = document.getElementById('invoice-list');
    const searchInput = document.getElementById('search-input');
    const clearSearchBtn = document.getElementById('clear-search-btn');
    const unpaidTab = document.getElementById('unpaid-tab');
    const installmentTab = document.getElementById('installment-tab');
    const paidTab = document.getElementById('paid-tab');
    const addInvoiceBtn = document.getElementById('add-invoice-btn');

    // Filter Elements
    const filterBtn = document.getElementById('filter-btn');
    const filterModal = document.getElementById('filter-modal');
    const closeFilterModalBtn = document.getElementById('close-filter-modal-btn');
    const customerNameInput = document.getElementById('customer-name-input');
    const startDateInput = document.getElementById('start-date-input');
    const endDateInput = document.getElementById('end-date-input');
    const applyFilterBtn = document.getElementById('apply-filter-btn');
    const resetFilterBtn = document.getElementById('reset-filter-btn');
    const totalContainer = document.getElementById('total-container');
    const totalDisplay = document.getElementById('total-display');
    const filterInfo = document.getElementById('filter-info');

    // Detail view elements - akan diinisialisasi saat dibutuhkan
    let detailCustomerName, detailCustomerId, detailCustomerWhatsapp,
        detailInvoicePeriod, detailInvoiceAmount, detailPaidDate,
        detailPaymentMethod, detailAdminName;

    // ===============================================
    // View Management
    // ===============================================
    function initializeViews() {
        views = {
            list: document.getElementById('list-view'),
            detail: document.getElementById('detail-view')
        };

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

    function switchView(viewName) {
        // Initialize views if not already done
        if (!views.list || !views.detail) {
            initializeViews();
        }

        // Add null safety
        Object.values(views).forEach(view => {
            if (view) view.classList.add('hidden');
        });

        if (views[viewName]) {
            views[viewName].classList.remove('hidden');
        }

        window.scrollTo(0, 0);
    }

    // Initialize detail view elements
    function initializeDetailElements() {
        detailCustomerName = document.getElementById('detail-customer-name');
        detailCustomerId = document.getElementById('detail-customer-id');
        detailCustomerWhatsapp = document.getElementById('detail-customer-whatsapp');
        detailInvoicePeriod = document.getElementById('detail-invoice-period');
        detailInvoiceAmount = document.getElementById('detail-invoice-amount');
        detailPaidDate = document.getElementById('detail-paid-date');
        detailPaymentMethod = document.getElementById('detail-payment-method');
        detailAdminName = document.getElementById('detail-admin-name');

    }

    // ===============================================
    // Helper Function for Pill Colors
    // ===============================================
    function getMonthPillClass(periodString) {
        const month = (periodString || '').split(' ')[0];
        let bgClass = 'bg-gray-100';
        let textClass = 'text-gray-800';

        switch (month) {
            case 'Januari':
                bgClass = 'bg-sky-100'; textClass = 'text-sky-800';
                break;
            case 'Februari':
                bgClass = 'bg-blue-100'; textClass = 'text-blue-800';
                break;
            case 'Maret':
                bgClass = 'bg-emerald-100'; textClass = 'text-emerald-800';
                break;
            case 'April':
                bgClass = 'bg-green-100'; textClass = 'text-green-800';
                break;
            case 'Mei':
                bgClass = 'bg-lime-100'; textClass = 'text-lime-800';
                break;
            case 'Juni':
                bgClass = 'bg-yellow-100'; textClass = 'text-yellow-800';
                break;
            case 'Juli':
                bgClass = 'bg-amber-100'; textClass = 'text-amber-800';
                break;
            case 'Agustus':
                bgClass = 'bg-orange-100'; textClass = 'text-orange-800';
                break;
            case 'September':
                bgClass = 'bg-red-100'; textClass = 'text-red-800';
                break;
            case 'Oktober':
                bgClass = 'bg-rose-100'; textClass = 'text-rose-800';
                break;
            case 'November':
                bgClass = 'bg-violet-100'; textClass = 'text-violet-800';
                break;
            case 'Desember':
                bgClass = 'bg-indigo-100'; textClass = 'text-indigo-800';
                break;
        }
        return { bg: bgClass, text: textClass };
    }

    // ===============================================
    // Initial Setup
    // ===============================================
    initializeEventListeners();
    initializeStickyHeader(); // Initialize sticky header behavior
    fetchData();

    // ===============================================
    // Event Listeners Setup
    // ===============================================
    function initializeEventListeners() {
        searchInput.addEventListener('input', renderList);
        // Tambahkan ini di dalam fungsi initializeEventListeners()
        clearSearchBtn.addEventListener('click', () => {
            searchInput.value = ''; // Kosongkan input
            renderList();           // Panggil ulang renderList untuk mereset daftar
            searchInput.focus();    // (Opsional) Fokuskan kembali ke input
        });

        unpaidTab.addEventListener('click', () => {
            if (new URLSearchParams(window.location.search).has('bulan')) {
                window.history.pushState({}, document.title, window.location.pathname);
                fetchData();
            } else {
                switchTab('unpaid');
            }
        });
        installmentTab.addEventListener('click', () => {
            if (new URLSearchParams(window.location.search).has('bulan')) {
                window.history.pushState({}, document.title, window.location.pathname);
                fetchData();
            } else {
                switchTab('installment');
            }
        });
        paidTab.addEventListener('click', () => {
            if (new URLSearchParams(window.location.search).has('bulan')) {
                window.history.pushState({}, document.title, window.location.pathname);
                fetchData();
            } else {
                switchTab('paid');
            }
        });

        invoiceList.addEventListener('click', handleInvoiceListClick);

        initCreateInvoiceModal();

        // Back button from detail view
        const backFromDetailBtn = document.getElementById('back-from-detail');
        if (backFromDetailBtn) {
            backFromDetailBtn.addEventListener('click', () => {
                switchView('list');
            });
        }

        // Print receipt button from detail view
        const detailPrintReceiptBtn = document.getElementById('btn-detail-print-receipt');
        if (detailPrintReceiptBtn) {
            detailPrintReceiptBtn.addEventListener('click', () => {
                if (currentDetailData) {
                    receiptPrinter.openReceipt(currentDetailData);
                }
            });
        }

        // Filter Event Listeners
        if (filterBtn) {
            filterBtn.addEventListener('click', () => filterModal.classList.remove('hidden'));
        }
        if (closeFilterModalBtn) {
            closeFilterModalBtn.addEventListener('click', () => filterModal.classList.add('hidden'));
        }
        if (filterModal) {
            filterModal.addEventListener('click', (e) => {
                if (e.target === filterModal) filterModal.classList.add('hidden');
            });
        }
        if (applyFilterBtn) {
            applyFilterBtn.addEventListener('click', handleApplyFilter);
        }
        if (resetFilterBtn) {
            resetFilterBtn.addEventListener('click', handleResetFilter);
        }
    }

    // ===============================================
    // Filter Functions
    // ===============================================
    function handleApplyFilter() {
        const customerName = customerNameInput.value.trim();

        // Get selected payment methods from checkboxes (query di sini agar DOM sudah ready)
        const paymentMethodCheckboxes = document.querySelectorAll('.payment-method-checkbox');
        const selectedPaymentMethods = Array.from(paymentMethodCheckboxes)
            .filter(checkbox => checkbox.checked)
            .map(checkbox => checkbox.value);

        const startDate = startDateInput.value;
        const endDate = endDateInput.value;

        // Apply filter only to paid tab
        if (currentTab === 'paid') {
            applyPaidFilter(customerName, selectedPaymentMethods, startDate, endDate);
            updateFilterInfo(customerName, selectedPaymentMethods, startDate, endDate);
            totalContainer.classList.remove('hidden');
            updateTotal();
        }

        filterModal.classList.add('hidden');
    }

    function handleResetFilter() {
        customerNameInput.value = '';

        // Uncheck all payment method checkboxes (query di sini agar DOM sudah ready)
        const paymentMethodCheckboxes = document.querySelectorAll('.payment-method-checkbox');
        paymentMethodCheckboxes.forEach(checkbox => {
            checkbox.checked = false;
        });

        startDateInput.value = '';
        endDateInput.value = '';

        if (currentTab === 'paid') {
            filteredPaidData = [...allPaidData];
            renderList();
            updateTotal();
        }

        totalContainer.classList.add('hidden');
        filterInfo.textContent = '';
        filterModal.classList.add('hidden');
    }

    function applyPaidFilter(customerName, paymentMethods, startDate, endDate) {
        filteredPaidData = allPaidData.filter(invoice => {
            // Filter by customer name
            if (customerName && !invoice.profiles?.full_name?.toLowerCase().includes(customerName.toLowerCase())) {
                return false;
            }

            // Filter by payment methods (multi-select)
            if (paymentMethods && paymentMethods.length > 0) {
                if (!paymentMethods.includes(invoice.payment_method)) {
                    return false;
                }
            }

            // Filter by date range
            if (startDate || endDate) {
                const paidDate = new Date(invoice.paid_at);
                if (startDate && paidDate < new Date(startDate + 'T00:00:00')) {
                    return false;
                }
                if (endDate && paidDate > new Date(endDate + 'T23:59:59')) {
                    return false;
                }
            }

            return true;
        });

        renderList();
    }

    function updateFilterInfo(customerName, paymentMethods, startDate, endDate) {
        const filters = [];

        if (customerName) filters.push(`Nama: ${customerName}`);
        if (paymentMethods && paymentMethods.length > 0) {
            // Capitalize first letter of each method for display
            const methodsDisplay = paymentMethods.map(m => {
                if (m === 'e-wallet') return 'E-Wallet';
                return m.charAt(0).toUpperCase() + m.slice(1);
            }).join(', ');
            filters.push(`Metode: ${methodsDisplay}`);
        }
        if (startDate || endDate) {
            const start = startDate ? new Date(startDate + 'T00:00:00').toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : '...';
            const end = endDate ? new Date(endDate + 'T00:00:00').toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : '...';
            filters.push(`${start} - ${end}`);
        }

        if (filters.length > 0) {
            filterInfo.textContent = `Filter aktif: ${filters.join(', ')}`;
        } else {
            filterInfo.textContent = '';
        }
    }

    function updateTotal() {
        const dataToCalculate = currentTab === 'paid' ? filteredPaidData : [];
        const total = dataToCalculate.reduce((sum, invoice) => {
            // Use total_due for paid invoices as it represents the full amount
            return sum + (invoice.total_due || invoice.amount_paid || invoice.amount || 0);
        }, 0);

        const formatter = new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        });
        totalDisplay.textContent = formatter.format(total);
    }

    // ===============================================
    // Main Data Fetch & Display Logic (PERBAIKAN FINAL)
    // ===============================================
    async function fetchData() {
        showLoading('Memuat data tagihan...');
        try {
            const urlParams = new URLSearchParams(window.location.search);
            const filterStatus = urlParams.get('status');
            const filterBulan = urlParams.get('bulan');
            const filterTahun = urlParams.get('tahun');
            const isFiltering = filterBulan && filterTahun && filterBulan !== '0';

            // Atur tab aktif berdasarkan parameter URL
            if (filterStatus === 'paid') {
                currentTab = 'paid';
            } else if (filterStatus === 'installment') {
                currentTab = 'installment';
            } else {
                currentTab = 'unpaid';
            }

            if (isFiltering) {
                const namaBulan = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
                const targetPeriode = `${namaBulan[parseInt(filterBulan, 10)]} ${filterTahun}`;

                console.log(`Filtering data for period: ${targetPeriode}`); // Untuk debugging

                searchInput.placeholder = `Disaring: ${targetPeriode}`;
                searchInput.disabled = true;

                // --- LOGIKA FETCH SAAT FILTER AKTIF ---

                // Ambil data Unpaid dengan filter (hanya unpaid, tidak termasuk partially_paid)
                const { data: unpaid, error: unpaidErr } = await supabase
                    .from('invoices')
                    .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                    .eq('status', 'unpaid')
                    .eq('invoice_period', targetPeriode)
                    .order('created_at', { ascending: false });
                if (unpaidErr) throw unpaidErr;
                unpaidData = unpaid;

                // Ambil data Installment dengan filter (dengan error handling untuk enum)
                try {
                    const { data: installment, error: installmentErr } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .eq('status', 'partially_paid')
                        .eq('invoice_period', targetPeriode)
                        .order('created_at', { ascending: false });
                    if (installmentErr) throw installmentErr;
                    installmentData = installment;
                } catch (enumError) {
                    console.warn('Enum partially_paid belum ada, menggunakan fallback query');
                    // Fallback: ambil data berdasarkan kondisi amount_paid > 0 dan status != 'paid'
                    const { data: installmentFallback, error: fallbackErr } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .neq('status', 'paid')
                        .gt('amount_paid', 0)
                        .eq('invoice_period', targetPeriode)
                        .order('created_at', { ascending: false });
                    if (fallbackErr) throw fallbackErr;
                    installmentData = installmentFallback || [];
                }

                // Ambil data Paid dengan filter (dan paginasi)
                let allPaid = [];
                let page = 0;
                const CHUNK_SIZE = 1000;
                while (true) {
                    const { data: paidChunk, error: paidErrChunk } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .eq('status', 'paid')
                        .eq('invoice_period', targetPeriode)
                        .order('paid_at', { ascending: false })
                        .range(page * CHUNK_SIZE, (page + 1) * CHUNK_SIZE - 1);
                    if (paidErrChunk) throw paidErrChunk;
                    if (paidChunk.length > 0) allPaid.push(...paidChunk);
                    if (paidChunk.length < CHUNK_SIZE) break;
                    page++;
                }
                paidData = allPaid;
                allPaidData = [...allPaid]; // Store for filtering
                filteredPaidData = [...allPaid]; // Initialize filtered data

            } else {
                // --- LOGIKA FETCH NORMAL (TANPA FILTER) ---
                searchInput.placeholder = 'Cari tagihan';
                searchInput.disabled = false;

                // Ambil data Unpaid tanpa filter (hanya unpaid, tidak termasuk partially_paid)
                const { data: unpaid, error: unpaidErr } = await supabase
                    .from('invoices')
                    .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                    .eq('status', 'unpaid')
                    .order('created_at', { ascending: false });
                if (unpaidErr) throw unpaidErr;
                unpaidData = unpaid;

                // Ambil data Installment tanpa filter (dengan error handling untuk enum)
                try {
                    const { data: installment, error: installmentErr } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .eq('status', 'partially_paid')
                        .order('created_at', { ascending: false });
                    if (installmentErr) throw installmentErr;
                    installmentData = installment;
                } catch (enumError) {
                    console.warn('Enum partially_paid belum ada, menggunakan fallback query');
                    // Fallback: ambil data berdasarkan kondisi amount_paid > 0 dan status != 'paid'
                    const { data: installmentFallback, error: fallbackErr } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .neq('status', 'paid')
                        .gt('amount_paid', 0)
                        .order('created_at', { ascending: false });
                    if (fallbackErr) throw fallbackErr;
                    installmentData = installmentFallback || [];
                }

                // Ambil data Paid tanpa filter (dan paginasi)
                let allPaid = [];
                let page = 0;
                const CHUNK_SIZE = 1000;
                while (true) {
                    const { data: paidChunk, error: paidErrChunk } = await supabase
                        .from('invoices')
                        .select(`id, customer_id, invoice_period, amount, total_due, amount_paid, status, paid_at, payment_method, broadcast_count, profiles (id, full_name, idpl, whatsapp_number)`)
                        .eq('status', 'paid')
                        .order('paid_at', { ascending: false })
                        .range(page * CHUNK_SIZE, (page + 1) * CHUNK_SIZE - 1);
                    if (paidErrChunk) throw paidErrChunk;
                    if (paidChunk.length > 0) allPaid.push(...paidChunk);
                    if (paidChunk.length < CHUNK_SIZE) break;
                    page++;
                }
                paidData = allPaid;
                allPaidData = [...allPaid]; // Store for filtering
                filteredPaidData = [...allPaid]; // Initialize filtered data
            }

            // Render berdasarkan tab yang sudah ditentukan
            switchTab(currentTab);

        } catch (error) {
            console.error('Error fetching data:', error);
            console.error('Error details:', {
                message: error.message,
                code: error.code,
                details: error.details,
                hint: error.hint
            });

            let errorMessage = 'Gagal memuat data tagihan';
            if (error.message) {
                errorMessage += `: ${error.message}`;
            }
            if (error.code) {
                errorMessage += ` (Code: ${error.code})`;
            }

            invoiceList.innerHTML = `<p class="text-center text-red-500 p-4">${errorMessage}</p>`;
            unpaidData = [];
            installmentData = [];
            paidData = [];
        } finally {
            hideLoading();
        }
    }

    // ... SISA KODE DARI SINI KE BAWAH TETAP SAMA DAN TIDAK PERLU DIUBAH ...
    // Pastikan semua fungsi lainnya (switchTab, renderList, markAsPaid, dll.) tetap ada.

    function switchTab(tab) {
        currentTab = tab;

        // Reset semua tab
        unpaidTab.classList.remove('active');
        installmentTab.classList.remove('active');
        paidTab.classList.remove('active');

        // Aktifkan tab yang dipilih
        if (tab === 'unpaid') {
            unpaidTab.classList.add('active');
            if (addInvoiceBtn) addInvoiceBtn.style.display = 'flex';
        } else if (tab === 'installment') {
            installmentTab.classList.add('active');
            if (addInvoiceBtn) addInvoiceBtn.style.display = 'none';
        } else if (tab === 'paid') {
            paidTab.classList.add('active');
            if (addInvoiceBtn) addInvoiceBtn.style.display = 'none';
            // Show filter button only on paid tab
            if (filterBtn) filterBtn.classList.remove('hidden');
        }

        // Hide filter button on other tabs
        if (tab !== 'paid' && filterBtn) {
            filterBtn.classList.add('hidden');
            // Hide total container when switching away from paid tab
            if (totalContainer) totalContainer.classList.add('hidden');
        }

        renderList();
        invoiceList.addEventListener('change', (event) => {
            if (event.target.classList.contains('broadcast-checkbox')) {
                updateBroadcastActions();
            }
        });

        updateBroadcastActions(); // reset selection state when redrawing
    }

    function updateBroadcastActions() {
        const checkAll = document.getElementById('check-all-broadcast');
        const checkboxes = document.querySelectorAll('.broadcast-checkbox');
        const checkedBoxes = document.querySelectorAll('.broadcast-checkbox:checked');
        const broadcastContainer = document.getElementById('broadcast-actions-container');
        const btnBroadcast = document.getElementById('btn-show-broadcast-modal');
        const selectedCount = document.getElementById('broadcast-selected-count');
        const btnBulkDelete = document.getElementById('btn-bulk-delete');
        const deleteCount = document.getElementById('delete-selected-count');

        if (currentTab === 'unpaid') {
            broadcastContainer?.classList.remove('hidden');
            if (checkboxes.length > 0) {
                if (checkAll) checkAll.checked = checkboxes.length === checkedBoxes.length;
            } else {
                if (checkAll) checkAll.checked = false;
            }

            if (checkedBoxes.length > 0) {
                btnBroadcast?.classList.remove('hidden');
                btnBulkDelete?.classList.remove('hidden');
                if (selectedCount) selectedCount.textContent = checkedBoxes.length;
                if (deleteCount) deleteCount.textContent = checkedBoxes.length;
            } else {
                btnBroadcast?.classList.add('hidden');
                btnBulkDelete?.classList.add('hidden');
            }
        } else {
            broadcastContainer?.classList.add('hidden');
        }
    }

    document.getElementById('check-all-broadcast')?.addEventListener('change', (e) => {
        const checkboxes = document.querySelectorAll('.broadcast-checkbox');
        checkboxes.forEach(cb => cb.checked = e.target.checked);
        updateBroadcastActions();
    });

    async function initBroadcastModal() {
        const btnShowModal = document.getElementById('btn-show-broadcast-modal');
        const modal = document.getElementById('broadcast-modal');
        const btnClose = document.getElementById('close-broadcast-modal');
        const btnCancel = document.getElementById('cancel-broadcast-btn');
        const btnConfirm = document.getElementById('confirm-broadcast-btn');
        const textareaTemplate = document.getElementById('broadcast-message-template');
        const btnReleaseLimit = document.getElementById('btn-release-limit');
        const limitInput = document.getElementById('broadcast-batch-limit');
        const infoCount = document.getElementById('broadcast-info-count');
        const delayModeSelect = document.getElementById('broadcast-delay-mode');
        const customDelayContainer = document.getElementById('custom-delay-container');
        const customDelayInput = document.getElementById('broadcast-custom-delay');

        if (!btnShowModal || !modal) return;

        if (delayModeSelect && customDelayContainer) {
            delayModeSelect.addEventListener('change', () => {
                if (delayModeSelect.value === 'custom') {
                    customDelayContainer.classList.remove('hidden');
                } else {
                    customDelayContainer.classList.add('hidden');
                }
            });
        }

        function calculateBroadcastDelay(mode, customSec) {
            if (mode === 'supersafe') {
                // Acak 10 - 20 detik (10.000 - 20.000 ms)
                return Math.floor(Math.random() * (20000 - 10000 + 1)) + 10000;
            } else if (mode === 'custom') {
                const secs = Math.max(3, parseInt(customSec) || 7);
                return secs * 1000;
            } else {
                // Mode 'safe' (default): Acak 5 - 10 detik (5.000 - 10.000 ms)
                return Math.floor(Math.random() * (10000 - 5000 + 1)) + 5000;
            }
        }

        // Toggle modal
        btnShowModal.addEventListener('click', async () => {
            const checkedBoxes = document.querySelectorAll('.broadcast-checkbox:checked');
            if (checkedBoxes.length === 0) return;

            infoCount.textContent = checkedBoxes.length;

            // Ambil template
            try {
                let foundTemplate = '';
                // 1. Coba dari Supabase
                const { data, error } = await supabase
                    .from('whatsapp_settings')
                    .select('setting_value')
                    .eq('setting_key', 'template_custom_message')
                    .single();

                if (!error && data && data.setting_value) {
                    foundTemplate = data.setting_value;
                } else {
                    // 2. Coba dari LocalStorage fallback
                    try {
                        const localWa = JSON.parse(localStorage.getItem('whatsapp_settings') || '{}');
                        if (localWa && localWa.template_custom_message) {
                            foundTemplate = localWa.template_custom_message;
                        }
                    } catch (e) {}
                }

                if (foundTemplate) {
                    textareaTemplate.value = foundTemplate;
                } else {
                    const payText = await fetchActivePaymentMethodsText();
                    textareaTemplate.value = `Informasi Tagihan WiFi Anda\n\nHai Bapak/Ibu {nama_pelanggan},\nID Pelanggan: {idpl}\n\nInformasi tagihan Bapak/Ibu bulan ini adalah:\nJumlah Tagihan: {total_tagihan}\nPeriode Tagihan: {periode}\n\nMetode Pembayaran:\n${payText}\n\nTerima kasih atas kepercayaan Anda menggunakan layanan kami.\n_____________________________\n*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.`;
                }
            } catch (e) {
                console.error(e);
            }

            modal.classList.remove('hidden');
        });

        const hideModal = () => modal.classList.add('hidden');
        btnClose.addEventListener('click', hideModal);
        btnCancel.addEventListener('click', hideModal);
        modal.addEventListener('click', (e) => {
            if (e.target === modal) hideModal();
        });

        btnReleaseLimit.addEventListener('click', () => {
            const checkedBoxes = document.querySelectorAll('.broadcast-checkbox:checked');
            limitInput.value = checkedBoxes.length;
        });

        // Proses Broadcast
        btnConfirm.addEventListener('click', async () => {
            const template = textareaTemplate.value;
            const limit = parseInt(limitInput.value) || 20;
            const checkedBoxes = Array.from(document.querySelectorAll('.broadcast-checkbox:checked'));
            const totalToProcess = checkedBoxes.length;

            if (totalToProcess === 0) return;
            if (!template) {
                showErrorNotification('Pesan tidak boleh kosong!');
                return;
            }

            // Simpan template
            try {
                try {
                    const localWa = JSON.parse(localStorage.getItem('whatsapp_settings') || '{}');
                    localWa.template_custom_message = template;
                    localStorage.setItem('whatsapp_settings', JSON.stringify(localWa));
                } catch (e) {}

                const { error: upsertErr } = await supabase
                    .from('whatsapp_settings')
                    .upsert({ setting_key: 'template_custom_message', setting_value: template }, { onConflict: 'setting_key' });

                if (upsertErr) {
                    await supabase
                        .from('whatsapp_settings')
                        .update({ setting_value: template, updated_at: new Date().toISOString() })
                        .eq('setting_key', 'template_custom_message');
                }
            } catch (e) {
                console.error('Failed to save template', e);
            }

            // Ambil app_url dari database
            let appUrl = 'http://ai-net-billing.netlify.app/';
            try {
                const { data: urlData } = await supabase
                    .from('whatsapp_settings')
                    .select('setting_value')
                    .eq('setting_key', 'app_url')
                    .single();
                if (urlData && urlData.setting_value) {
                    appUrl = urlData.setting_value;
                }
            } catch (e) {
                console.error('Failed to get app_url:', e);
            }

            // Ambil invoice IDs yang akan diproses batch ini
            const batchIds = checkedBoxes.slice(0, limit).map(cb => cb.value);
            hideModal();

            if (!confirm(`Kirim pesan WhatsApp ke ${batchIds.length} pelanggan (Batch ini)?\n\nTersisa ${totalToProcess - batchIds.length} pelanggan untuk batch selanjutnya jika dilewati limit.`)) {
                return;
            }

            const delayMode = delayModeSelect ? delayModeSelect.value : 'safe';
            const customDelaySec = customDelayInput ? parseInt(customDelayInput.value) || 7 : 7;

            showPaymentLoading(`Memproses Broadcast ke ${batchIds.length} pelanggan...`);
            let sent = 0;
            let skipped = 0;
            let errors = [];

            for (let i = 0; i < batchIds.length; i++) {
                const id = batchIds[i];
                const invoice = unpaidData.find(item => item.id === id);

                if (!invoice || !invoice.profiles || !invoice.profiles.whatsapp_number) {
                    skipped++;
                    continue;
                }

                showPaymentLoading(`[${i + 1}/${batchIds.length}] Mengirim WhatsApp ke ${invoice.profiles.full_name}...`);

                // Ambil email pelanggan
                let customerEmail = '-';
                try {
                    const { data: email } = await supabase.rpc('get_user_email', {
                        user_id: invoice.customer_id || invoice.profiles.id
                    });
                    if (email) customerEmail = email;
                } catch (err) {
                    console.error("Gagal mengambil email pelanggan:", err);
                }

                const formatter = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 });
                let target = String(invoice.profiles.whatsapp_number).replace(/[^0-9]/g, '');
                if (target.startsWith('0')) target = '62' + target.substring(1);

                const message = template
                    .replace(/{nama_pelanggan}/g, invoice.profiles.full_name)
                    .replace(/{idpl}/g, invoice.profiles.idpl)
                    .replace(/{periode}/g, invoice.invoice_period)
                    .replace(/{total_tagihan}/g, formatter.format(invoice.amount))
                    .replace(/{jumlah_dibayar}/g, formatter.format(invoice.amount_paid || 0))
                    .replace(/{sisa_tagihan}/g, formatter.format(Math.max(0, invoice.amount - (invoice.amount_paid || 0))))
                    .replace(/{metode_pembayaran}/g, invoice.payment_method || '-')
                    .replace(/{app_url}/g, appUrl)
                    .replace(/{email_pelanggan}/g, customerEmail)
                    .replace(/{pesan_custom}/g, '');

                try {
                    // Pakai invokeWhatsappFunction jika ada atau fallback panggil supabase invoke
                    const { data, error } = await supabase.functions.invoke('send-whatsapp-notification', {
                        body: { target, message },
                    });

                    if (error || (data && data.success === false)) {
                        errors.push(`${invoice.profiles.full_name}: ${error?.message || data?.message}`);
                        skipped++;
                    } else {
                        sent++;
                        // update broadcast count in database
                        let newCount = (invoice.broadcast_count || 0) + 1;
                        await supabase.from('invoices').update({ broadcast_count: newCount }).eq('id', id);

                        // update local state
                        invoice.broadcast_count = newCount;

                        // update UI
                        const cell = document.getElementById(`broadcast-cell-${id}`);
                        if (cell) {
                            if (newCount >= 1) {
                                const icon1 = cell.querySelector('.broadcast-icon-1');
                                if (icon1) { icon1.classList.remove('text-gray-400'); icon1.classList.add('text-green-500'); icon1.title = 'Broadcast ke-1: Sudah dikirim'; }
                            }
                            if (newCount >= 2) {
                                const icon2 = cell.querySelector('.broadcast-icon-2');
                                if (icon2) { icon2.classList.remove('text-gray-400'); icon2.classList.add('text-green-500'); icon2.title = 'Broadcast ke-2: Sudah dikirim'; }
                            }
                        }

                        // Uncheck the checkbox
                        const cb = document.querySelector(`.broadcast-checkbox[value="${id}"]`);
                        if (cb) cb.checked = false;
                    }
                } catch (err) {
                    errors.push(`${invoice.profiles.full_name}: Error internal`);
                    skipped++;
                }

                // Jeda cerdas anti-banned per pengiriman
                if (i < batchIds.length - 1) {
                    const delayMs = calculateBroadcastDelay(delayMode, customDelaySec);
                    const delaySec = (delayMs / 1000).toFixed(1);
                    showPaymentLoading(`[${i + 1}/${batchIds.length}] Terkirim ke ${invoice.profiles.full_name}.
Menunggu jeda aman ${delaySec} detik sebelum nomor berikutnya...`);
                    await new Promise(r => setTimeout(r, delayMs));
                }
            }

            hidePaymentLoading();
            updateBroadcastActions();

            let resultMsg = `Terkirim: ${sent}, Dilewati: ${skipped}`;
            if (errors.length > 0) {
                resultMsg += `\nBeberapa Error:\n${errors.slice(0, 3).join('\n')}`;
            }
            alert(`Broadcast Selesai!\n\n${resultMsg}`);
        });
    }

    initBroadcastModal();

    function renderList() {
        invoiceList.innerHTML = '';
        const searchTerm = searchInput.value.toLowerCase();
        let data;

        // Logika untuk menampilkan/menyembunyikan tombol close
        if (searchTerm.length > 0) {
            clearSearchBtn.classList.remove('hidden');
        } else {
            clearSearchBtn.classList.add('hidden');
        }

        if (currentTab === 'unpaid') {
            data = unpaidData;
        } else if (currentTab === 'installment') {
            data = installmentData;
        } else {
            data = filteredPaidData; // Use filtered data for paid tab
        }

        if (!Array.isArray(data)) {
            invoiceList.innerHTML = `<p class="text-center text-red-500 p-4">Error: Format data tidak valid</p>`;
            return;
        }

        const filteredData = data.filter(item => {
            if (!item || !item.profiles) return false;
            if (searchInput.disabled) return true;
            return (item.profiles.full_name && item.profiles.full_name.toLowerCase().includes(searchTerm)) ||
                (item.invoice_period && item.invoice_period.toLowerCase().includes(searchTerm));
        });

        if (filteredData.length === 0) {
            let message = 'Tidak ada tagihan ditemukan';
            let submessage = 'Coba ubah filter atau kata kunci pencarian';

            if (currentTab === 'unpaid') {
                message = 'Tidak ada tagihan belum dibayar';
                submessage = searchTerm ? 'Tidak ada hasil untuk pencarian Anda' : 'Semua tagihan sudah dibayar atau belum ada tagihan';
            } else if (currentTab === 'installment') {
                message = 'Tidak ada tagihan cicilan';
                submessage = searchTerm ? 'Tidak ada hasil untuk pencarian Anda' : 'Belum ada pelanggan yang membayar dengan cicilan';
            } else if (currentTab === 'paid') {
                message = 'Tidak ada tagihan yang dibayar';
                submessage = searchTerm ? 'Tidak ada hasil untuk pencarian Anda' : 'Belum ada tagihan yang lunas';
            }

            invoiceList.innerHTML = `
                <div class="flex flex-col items-center justify-center py-12 px-4">
                    <img src="assets/no_data.svg" alt="No Data" class="w-64 h-64 mb-4 opacity-80">
                    <p class="text-center text-gray-500 text-base font-medium">${message}</p>
                    <p class="text-center text-gray-400 text-sm mt-2">${submessage}</p>
                </div>
            `;
            return;
        }

        const formatter = new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        });

        filteredData.forEach(item => {
            const period = item.invoice_period || 'Periode tidak tersedia';
            const customerName = item.profiles?.full_name || 'Nama tidak tersedia';
            const invoiceId = item.id;
            const pillClasses = getMonthPillClass(period);
            const invoiceDiv = document.createElement('div');
            invoiceDiv.id = `invoice-item-${invoiceId}`;
            invoiceDiv.className = 'flex items-center gap-4 bg-[#f9f8fb] px-4 min-h-[72px] py-2 justify-between border-b border-gray-200';

            if (currentTab === 'unpaid') {
                const broadcastCount = item.broadcast_count || 0;
                const icon1Class = broadcastCount >= 1 ? 'text-green-500' : 'text-gray-400';
                const icon1Title = broadcastCount >= 1 ? 'Broadcast ke-1: Sudah dikirim' : 'Broadcast ke-1: Belum dikirim';
                const icon2Class = broadcastCount >= 2 ? 'text-green-500' : 'text-gray-400';
                const icon2Title = broadcastCount >= 2 ? 'Broadcast ke-2: Sudah dikirim' : 'Broadcast ke-2: Belum dikirim';

                const hasValidWhatsapp = item.profiles?.whatsapp_number && String(item.profiles.whatsapp_number).replace(/[^0-9]/g, '').length >= 10;
                const checkboxHtml = `<input type="checkbox" class="broadcast-checkbox w-4 h-4 rounded border-gray-300 text-green-500 focus:ring-green-500" value="${invoiceId}">`;

                const waButtonHtml = hasValidWhatsapp ?
                    `<button class="whatsapp-btn flex items-center justify-center w-7 h-7 bg-green-500 hover:bg-green-600 rounded-lg transition-colors" title="Kirim WhatsApp" data-invoice-id="${invoiceId}">
                        <svg class="w-3.5 h-3.5 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488" /></svg>
                    </button>` : '';

                invoiceDiv.innerHTML = `
                    <div class="flex items-center gap-3">
                        ${checkboxHtml}
                        <div class="flex flex-col justify-center gap-1">
                            <p class="text-[#110e1b] text-base font-medium leading-normal">${customerName}</p>
                            <span class="${pillClasses.bg} ${pillClasses.text} text-xs font-medium w-fit px-2.5 py-0.5 rounded-full">
                                ${period}
                            </span>
                        </div>
                    </div>
                    <div class="shrink-0 flex gap-1.5 items-center">
                        <div class="flex gap-1 mr-1 broadcast-indicators" id="broadcast-cell-${invoiceId}">
                            <svg class="w-4 h-4 ${icon1Class} broadcast-icon-1" title="${icon1Title}" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488" /></svg>
                            <svg class="w-4 h-4 ${icon2Class} broadcast-icon-2" title="${icon2Title}" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488" /></svg>
                        </div>
                        ${waButtonHtml}
                        <button class="mark-paid-btn flex min-w-[60px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-lg h-7 px-3 bg-[#eae8f3] hover:bg-[#dedae9] text-[#110e1b] text-xs font-medium leading-normal w-fit transition-colors" data-invoice-id="${invoiceId}" title="Bayar Lunas Langsung">
                            <span class="truncate">LUNAS</span>
                        </button>
                        <div class="relative action-menu-container">
                            <button class="action-menu-btn flex items-center justify-center w-7 h-7 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition-colors" data-invoice-id="${invoiceId}" title="Opsi Tagihan">
                                <svg class="w-4 h-4 pointer-events-none" fill="currentColor" viewBox="0 0 24 24"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>
                            </button>
                            <div class="action-menu-dropdown hidden absolute right-0 top-8 z-30 w-36 bg-white rounded-lg shadow-xl border border-gray-200 py-1 text-xs">
                                <button class="installment-btn w-full text-left px-3 py-2 text-gray-700 hover:bg-blue-50 hover:text-blue-600 flex items-center gap-2 transition-colors" data-invoice-id="${invoiceId}" data-remaining-amount="${item.amount}" data-customer-name="${customerName}">
                                    <svg class="w-3.5 h-3.5 text-blue-500 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
                                    Bayar Cicilan
                                </button>
                                <button class="delete-invoice-btn w-full text-left px-3 py-2 text-red-600 hover:bg-red-50 flex items-center gap-2 border-t border-gray-100 transition-colors" data-invoice-id="${invoiceId}" data-customer-name="${customerName}" data-period="${period}" data-amount="${item.amount}">
                                    <svg class="w-3.5 h-3.5 text-red-500 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                                    Hapus Tagihan
                                </button>
                            </div>
                        </div>
                    </div>
                `;
            } else if (currentTab === 'installment') {
                const progressPercentage = ((item.amount_paid || 0) / (item.total_due || 1)) * 100;

                invoiceDiv.innerHTML = `
                    <div class="flex flex-col justify-center flex-1 gap-1">
                        <p class="text-[#110e1b] text-base font-medium leading-normal">${customerName}</p>
                        <span class="${pillClasses.bg} ${pillClasses.text} text-xs font-medium w-fit px-2.5 py-0.5 rounded-full">
                            ${period}
                        </span>
                        <div class="mt-2">
                            <div class="flex justify-between text-xs mb-1">
                                <span class="text-orange-600 font-medium">Terbayar: ${formatter.format(item.amount_paid || 0)}</span>
                                <span class="text-red-600 font-medium">Sisa: ${formatter.format(item.amount || 0)}</span>
                            </div>
                            <div class="w-full bg-gray-200 rounded-full h-2">
                                <div class="bg-orange-500 h-2 rounded-full transition-all duration-300" style="width: ${progressPercentage}%"></div>
                            </div>
                            <p class="text-xs text-gray-600 mt-1">Total: ${formatter.format(item.total_due || 0)}</p>
                        </div>
                    </div>
                    <div class="shrink-0 flex gap-1.5 ml-2">
                        <button class="whatsapp-btn flex items-center justify-center w-7 h-7 bg-green-500 hover:bg-green-600 rounded-lg transition-colors" title="Kirim WhatsApp" data-invoice-id="${invoiceId}">
                            <svg class="w-3.5 h-3.5 text-white" fill="currentColor" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0020.885 3.488" /></svg>
                        </button>
                        <button class="installment-btn flex items-center justify-center h-7 px-2 bg-orange-500 hover:bg-orange-600 text-white rounded-lg text-xs transition-colors" title="Bayar Cicilan Lagi" data-invoice-id="${invoiceId}" data-remaining-amount="${item.amount}" data-customer-name="${customerName}">
                            Cicil
                        </button>
                        <button class="mark-paid-btn flex min-w-[50px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-lg h-7 px-2.5 bg-green-500 hover:bg-green-600 text-white text-xs font-medium leading-normal w-fit" data-invoice-id="${invoiceId}">
                            <span class="truncate">Lunas</span>
                        </button>
                    </div>
                `;
            } else { // Tab 'paid'
                // Siapkan variabel untuk tanggal pembayaran
                let paymentDateHtml = '<div class="w-12 shrink-0"></div>'; // Placeholder jika tanggal tidak ada

                // Cek apakah ada data paid_at
                if (item.paid_at) {
                    const paidDate = new Date(item.paid_at);
                    const day = paidDate.getDate().toString().padStart(2, '0');
                    const month = paidDate.toLocaleString('id-ID', { month: 'short' });
                    const year = paidDate.getFullYear();

                    paymentDateHtml = `
            <div class="flex flex-col items-center justify-center w-12 shrink-0 text-center">
                <p class="text-lg font-bold text-gray-800">${day}</p>
                <p class="text-xs text-gray-500">${month}</p>
                <p class="text-xs text-gray-500">${year}</p>
            </div>
        `;
                }

                // Gabungkan semua bagian menjadi satu
                invoiceDiv.innerHTML = `
        ${paymentDateHtml}
        <div class="flex flex-col justify-center gap-1 flex-1 cursor-pointer" data-invoice-id="${invoiceId}" data-click-type="detail">
            <p class="text-[#110e1b] text-base font-medium leading-normal">${customerName}</p>
            <span class="${pillClasses.bg} ${pillClasses.text} text-xs font-medium w-fit px-2.5 py-0.5 rounded-full">
                ${period}
            </span>
        </div>
        <div class="shrink-0 flex items-center gap-1.5">
            <div class="flex flex-col items-end cursor-pointer" data-invoice-id="${invoiceId}" data-click-type="detail">
                <p class="text-green-600 text-sm font-bold leading-normal">LUNAS</p>
                <p class="text-gray-500 text-xs font-medium leading-normal">${item.payment_method || 'Tidak diketahui'}</p>
            </div>
            <button class="print-receipt-btn flex items-center justify-center w-7 h-7 text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors" data-invoice-id="${invoiceId}" title="Cetak Struk Pembayaran">
                <svg xmlns="http://www.w3.org/2000/svg" width="18px" height="18px" fill="currentColor" viewBox="0 0 256 256">
                    <path d="M216,80H184V40a16,16,0,0,0-16-16H88A16,16,0,0,0,72,40V80H40A24,24,0,0,0,16,104v80a24,24,0,0,0,24,24H72v24a16,16,0,0,0,16,16h80a16,16,0,0,0,16-16V208h32a24,24,0,0,0,24-24V104A24,24,0,0,0,216,80ZM88,40h80V80H88ZM168,232H88V184h80Zm48-48a8,8,0,0,1-8,8H184V176a8,8,0,0,0-8-8H80a8,8,0,0,0-8,8v16H40a8,8,0,0,1-8-8V104a8,8,0,0,1,8-8H216a8,8,0,0,1,8,8ZM184,124a12,12,0,1,1-12-12A12,12,0,0,1,184,124Z"></path>
                </svg>
            </button>
            <button class="revert-paid-btn flex items-center justify-center w-7 h-7 text-orange-500 hover:bg-orange-50 rounded-lg transition-colors" data-invoice-id="${invoiceId}" title="Batalkan Pembayaran">
                <svg xmlns="http://www.w3.org/2000/svg" width="18px" height="18px" fill="currentColor" viewBox="0 0 256 256">
                    <path d="M224,128a96,96,0,0,1-94.71,96H128A95.38,95.38,0,0,1,62.1,197.8a8,8,0,0,1,11-11.63A80,80,0,1,0,71.43,71.39a3.07,3.07,0,0,1-.26.25L60.63,81.29l17,17A8,8,0,0,1,72,112H24a8,8,0,0,1-8-8V56A8,8,0,0,1,29.66,50.3L49.31,70,59.78,59.43a96,96,0,0,1,164.2,68.5A8,8,0,0,1,224,128Z"></path>
                </svg>
            </button>
        </div>
    `;
            }
            invoiceList.appendChild(invoiceDiv);
        });
    }

    function handleInvoiceListClick(event) {
        // Check for button click first
        const button = event.target.closest('button');
        if (button) {
            const invoiceId = button.dataset.invoiceId;
            if (!invoiceId) return;

            // Cari data di semua array berdasarkan tab aktif
            let targetItem;
            if (currentTab === 'unpaid') {
                targetItem = unpaidData.find(item => item.id === invoiceId);
            } else if (currentTab === 'installment') {
                targetItem = installmentData.find(item => item.id === invoiceId);
            } else {
                targetItem = paidData.find(item => item.id === invoiceId);
            }

            if (!targetItem) {
                showErrorNotification('Data tagihan tidak ditemukan.');
                return;
            }

            if (button.classList.contains('mark-paid-btn')) {
                markAsPaid(targetItem);
            } else if (button.classList.contains('print-receipt-btn')) {
                receiptPrinter.openReceipt(targetItem);
            } else if (button.classList.contains('whatsapp-btn')) {
                sendWhatsAppMessage(targetItem);
            } else if (button.classList.contains('installment-btn')) {
                closeAllActionMenus();
                handleInstallmentPayment(targetItem);
            } else if (button.classList.contains('revert-paid-btn')) {
                revertPaymentStatus(targetItem);
            } else if (button.classList.contains('delete-invoice-btn')) {
                closeAllActionMenus();
                const custName = button.getAttribute('data-customer-name') || targetItem.profiles?.full_name || 'Pelanggan';
                const invPeriod = button.getAttribute('data-period') || targetItem.invoice_period || '-';
                const invAmount = parseFloat(button.getAttribute('data-amount')) || targetItem.amount || 0;
                handleDeleteSingleInvoice(invoiceId, custName, invPeriod, invAmount);
            } else if (button.classList.contains('action-menu-btn')) {
                toggleActionMenu(button);
            }
            return;
        }

        // Check for detail area click (like pelanggan.js - click anywhere on card)
        const detailArea = event.target.closest('[data-click-type="detail"]');
        if (detailArea && currentTab === 'paid') {
            const invoiceId = detailArea.dataset.invoiceId;
            if (!invoiceId) return;

            const targetItem = paidData.find(item => item.id === invoiceId);
            if (!targetItem) {
                showErrorNotification('Data tagihan tidak ditemukan.');
                return;
            }

            navigateToPaymentDetail(targetItem);
        }
    }

    async function navigateToPaymentDetail(invoice) {
        if (!invoice || !invoice.id) {
            showErrorNotification('Error: Data tagihan tidak lengkap.');
            return;
        }

        // Store current detail data
        currentDetailData = invoice;

        // Ensure DOM is ready with a small delay
        await new Promise(resolve => setTimeout(resolve, 100));

        // Populate detail view
        await displayPaymentDetail(invoice);

        // Switch to detail view
        switchView('detail');
    }

    async function displayPaymentDetail(invoiceData) {
        // Initialize detail elements first
        initializeDetailElements();

        // Format currency
        const formatter = new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        });

        // Format date
        let formattedDate = 'Tidak tersedia';
        if (invoiceData.paid_at) {
            const date = new Date(invoiceData.paid_at);
            formattedDate = date.toLocaleDateString('id-ID', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        }

        // Get current admin name
        const currentAdmin = await getCurrentAdminName();


        // Populate data with null safety
        if (detailCustomerName) detailCustomerName.textContent = invoiceData.profiles?.full_name || 'Tidak tersedia';
        if (detailCustomerId) detailCustomerId.textContent = invoiceData.profiles?.idpl || 'Tidak tersedia';
        if (detailCustomerWhatsapp) detailCustomerWhatsapp.textContent = invoiceData.profiles?.whatsapp_number || 'Tidak tersedia';
        if (detailInvoicePeriod) detailInvoicePeriod.textContent = invoiceData.invoice_period || 'Tidak tersedia';
        // For paid invoices, use total_due or amount_paid instead of amount (which is remaining)
        const displayAmount = invoiceData.status === 'paid'
            ? (invoiceData.total_due || invoiceData.amount_paid || invoiceData.amount)
            : invoiceData.amount;
        if (detailInvoiceAmount) detailInvoiceAmount.textContent = formatter.format(displayAmount || 0);
        if (detailPaidDate) detailPaidDate.textContent = formattedDate;
        if (detailPaymentMethod) detailPaymentMethod.textContent = invoiceData.payment_method || 'Tidak diketahui';
        if (detailAdminName) detailAdminName.textContent = currentAdmin || 'Admin';
    }

    async function handleInstallmentPayment(invoice) {
        if (!invoice || !invoice.id) {
            showErrorNotification('Error: Data tagihan tidak lengkap.');
            return;
        }

        const customerName = invoice.profiles.full_name || 'Pelanggan';
        const remainingAmount = invoice.amount || 0;
        const totalDue = invoice.total_due || remainingAmount;
        const amountPaid = invoice.amount_paid || 0;

        // Buat modal cicilan
        showInstallmentModal({
            invoiceId: invoice.id,
            customerName: customerName,
            totalDue: totalDue,
            amountPaid: amountPaid,
            remainingAmount: remainingAmount,
            invoicePeriod: invoice.invoice_period
        });
    }

    async function markAsPaid(invoice) {
        if (!invoice || !invoice.id) {
            showErrorNotification('Error: Data tagihan tidak lengkap.');
            return;
        }

        const customerName = invoice.profiles.full_name || 'Pelanggan';
        const remainingAmount = invoice.amount || 0;
        const totalDue = invoice.total_due || remainingAmount;
        const amountPaid = invoice.amount_paid || 0;

        // Buat modal pembayaran lunas
        showFullPaymentModal({
            invoiceId: invoice.id,
            customerName: customerName,
            totalDue: totalDue,
            amountPaid: amountPaid,
            remainingAmount: remainingAmount,
            invoicePeriod: invoice.invoice_period
        });
    }

    async function revertPaymentStatus(invoice) {
        if (!invoice || !invoice.id) {
            showErrorNotification('Error: Data tagihan tidak lengkap.');
            return;
        }

        const customerName = invoice.profiles?.full_name || 'Pelanggan';
        const formatter = new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        });
        const totalDue = invoice.total_due || invoice.amount;

        // Confirmation dialog
        const confirmMessage = `⚠️ BATALKAN PEMBAYARAN\n\n` +
            `Pelanggan: ${customerName}\n` +
            `Periode: ${invoice.invoice_period || 'N/A'}\n` +
            `Jumlah: ${formatter.format(totalDue)}\n` +
            `Status: LUNAS ➔ BELUM DIBAYAR\n\n` +
            `Tindakan ini akan mengembalikan status tagihan ke "Belum Dibayar".\n` +
            `Data pembayaran (tanggal & metode) akan dihapus.\n\n` +
            `Apakah Anda yakin ingin membatalkan pembayaran ini?`;

        if (!confirm(confirmMessage)) {
            return;
        }

        try {
            showPaymentLoading('Membatalkan pembayaran...');

            // Revert status to unpaid and reset payment fields
            const { error } = await supabase
                .from('invoices')
                .update({
                    status: 'unpaid',
                    paid_at: null,
                    payment_method: null,
                    amount: totalDue, // Reset to full amount
                    amount_paid: 0 // Reset amount paid
                })
                .eq('id', invoice.id);

            hidePaymentLoading();

            if (error) {
                throw new Error(error.message);
            }

            showSuccessNotification(`✅ Pembayaran berhasil dibatalkan!\nTagihan "${invoice.invoice_period}" kembali ke status belum dibayar.`);

            // Refresh data and switch to unpaid tab
            await fetchData();
            switchTab('unpaid');

        } catch (error) {
            hidePaymentLoading();
            console.error('Error reverting payment:', error);
            showErrorNotification(`❌ Gagal membatalkan pembayaran: ${error.message}`);
        }
    }

    async function fetchActivePaymentMethodsText() {
        try {
            const { data: methods } = await supabase
                .from('payment_methods')
                .select('bank_name, account_number, account_holder')
                .eq('is_active', true)
                .order('sort_order', { ascending: true });
            
            if (methods && methods.length > 0) {
                return methods.map(m => `- ${m.bank_name} ${m.account_number} a.n. ${m.account_holder}`).join('\n');
            }
        } catch (e) {
            console.error('Error fetching payment_methods:', e);
        }
        return 'Silakan cek metode pembayaran yang tersedia di aplikasi.';
    }

    async function sendWhatsAppMessage(rowData) {
        const payText = await fetchActivePaymentMethodsText();
        let customTemplate = `Informasi Tagihan WiFi Anda\n\nHai Bapak/Ibu {nama_pelanggan},\nID Pelanggan: {idpl}\n\nInformasi tagihan Bapak/Ibu bulan ini adalah:\nJumlah Tagihan: {total_tagihan}\nPeriode Tagihan: {periode}\n\nMetode Pembayaran:\n${payText}\n\nTerima kasih atas kepercayaan Anda menggunakan layanan kami.\n_____________________________\n*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.`;
        let appUrl = 'http://ai-net-billing.netlify.app/';
        let customerEmail = '-';
        try {
            const { data: settingsData } = await supabase
                .from('whatsapp_settings')
                .select('setting_key, setting_value')
                .in('setting_key', ['template_custom_message', 'app_url']);
            
            if (settingsData) {
                const templateObj = settingsData.find(s => s.setting_key === 'template_custom_message');
                const urlObj = settingsData.find(s => s.setting_key === 'app_url');
                if (templateObj && templateObj.setting_value) customTemplate = templateObj.setting_value;
                if (urlObj && urlObj.setting_value) appUrl = urlObj.setting_value;
            }

            // Fallback ke localStorage jika di database belum ada
            try {
                const localWa = JSON.parse(localStorage.getItem('whatsapp_settings') || '{}');
                if ((!customTemplate || customTemplate.includes('Informasi Tagihan WiFi Anda')) && localWa.template_custom_message) {
                    customTemplate = localWa.template_custom_message;
                }
                if ((!appUrl || appUrl === 'http://ai-net-billing.netlify.app/') && localWa.app_url) {
                    appUrl = localWa.app_url;
                }
            } catch (e) {}

            if (rowData && rowData.profiles) {
                const { data: email } = await supabase.rpc('get_user_email', {
                    user_id: rowData.customer_id || rowData.profiles.id
                });
                if (email) customerEmail = email;
            }
        } catch (e) {
            console.error('Error fetching settings or customer email:', e);
        }

        if (!rowData || !rowData.profiles) {
            showErrorNotification('Data pelanggan tidak valid untuk mengirim WhatsApp');
            return;
        }
        const customerName = rowData.profiles.full_name || 'Pelanggan';
        const customerId = rowData.profiles.idpl || '';
        const whatsappNumber = rowData.profiles.whatsapp_number || '';
        const billAmount = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(rowData.amount);
        const billPeriod = rowData.invoice_period || '';

        if (!whatsappNumber) {
            alert('Nomor WhatsApp pelanggan tidak tersedia!');
            return;
        }

        let messageTemplate = customTemplate;

        const message = messageTemplate
            .replace(/{nama_pelanggan}/g, customerName)
            .replace(/{idpl}/g, customerId)
            .replace(/{total_tagihan}/g, billAmount)
            .replace(/{periode}/g, billPeriod)
            .replace(/{jumlah_dibayar}/g, new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(rowData.amount_paid || 0))
            .replace(/{sisa_tagihan}/g, new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', minimumFractionDigits: 0 }).format(Math.max(0, rowData.amount - (rowData.amount_paid || 0))))
            .replace(/{metode_pembayaran}/g, rowData.payment_method || '-')
            .replace(/{app_url}/g, appUrl)
            .replace(/{email_pelanggan}/g, customerEmail)
            .replace(/{pesan_custom}/g, '');

        let cleanedNumber = String(whatsappNumber).replace(/[^0-9+]/g, '');
        if (!cleanedNumber.startsWith('+') && !cleanedNumber.startsWith('62')) {
            cleanedNumber = cleanedNumber.startsWith('0') ? '62' + cleanedNumber.substring(1) : '62' + cleanedNumber;
        }

        const encodedMessage = encodeURIComponent(message);
        const whatsappUrl = `https://wa.me/${cleanedNumber}?text=${encodedMessage}`;
        window.open(whatsappUrl, '_blank');
        showSuccessNotification(`Pesan WhatsApp untuk ${customerName} telah dibuka!`);
    }

    function initCreateInvoiceModal() {
        const createInvoiceModal = document.getElementById('create-invoice-modal');
        const closeBtn = document.getElementById('close-create-invoice-modal');
        const cancelBtn = document.getElementById('cancel-create-invoice-btn');
        const confirmBtn = document.getElementById('confirm-create-invoice-btn');
        const monthSelect = document.getElementById('create-invoice-month');
        const yearSelect = document.getElementById('create-invoice-year');

        if (!createInvoiceModal || !addInvoiceBtn) return;

        // Populate year selector (current year - 1 to current year + 3)
        const currentYear = new Date().getFullYear();
        if (yearSelect) {
            yearSelect.innerHTML = '';
            for (let y = currentYear - 1; y <= currentYear + 3; y++) {
                const opt = document.createElement('option');
                opt.value = y;
                opt.textContent = y;
                if (y === currentYear) opt.selected = true;
                yearSelect.appendChild(opt);
            }
        }

        // Show modal on FAB click
        addInvoiceBtn.addEventListener('click', () => {
            const now = new Date();
            if (monthSelect) monthSelect.value = (now.getMonth() + 1).toString();
            if (yearSelect) yearSelect.value = now.getFullYear().toString();
            createInvoiceModal.classList.remove('hidden');
        });

        // Hide modal helper
        const hideModal = () => createInvoiceModal.classList.add('hidden');
        if (closeBtn) closeBtn.addEventListener('click', hideModal);
        if (cancelBtn) cancelBtn.addEventListener('click', hideModal);
        createInvoiceModal.addEventListener('click', (e) => {
            if (e.target === createInvoiceModal) hideModal();
        });

        // Process creation
        if (confirmBtn) {
            confirmBtn.addEventListener('click', async () => {
                const monthIndex = parseInt(monthSelect.value, 10);
                const selectedYear = parseInt(yearSelect.value, 10);

                const monthNames = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
                const targetMonthName = monthNames[monthIndex];

                hideModal();

                const confirmMessage = `Apakah Anda yakin ingin membuat tagihan untuk bulan ${targetMonthName} ${selectedYear}? Proses ini akan dijalankan untuk semua pelanggan aktif yang belum memiliki tagihan pada periode tersebut.`;

                if (!confirm(confirmMessage)) {
                    return;
                }

                await handleCreateInvoicesForPeriod(monthIndex, selectedYear);
            });
        }
    }

    async function handleCreateInvoicesForPeriod(monthIndex, targetYear) {
        const monthNames = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
        const targetMonthName = monthNames[monthIndex];
        const targetPeriod = `${targetMonthName} ${targetYear}`;

        showPaymentLoading(`Membuat tagihan untuk ${targetPeriod}...`);

        try {
            // 1. Ambil semua pelanggan aktif yang punya paket
            const { data: activeProfiles, error: profError } = await supabase
                .from('profiles')
                .select('id, package_id, packages(price)')
                .eq('status', 'AKTIF')
                .in('role', ['USER', 'pelanggan', 'user'])
                .not('package_id', 'is', null);

            if (profError) throw new Error(`Gagal mengambil data pelanggan: ${profError.message}`);

            if (!activeProfiles || activeProfiles.length === 0) {
                hidePaymentLoading();
                showSuccessNotification(`Tidak ada pelanggan aktif yang ditemukan.`);
                return;
            }

            // 2. Cek tagihan yang sudah ada untuk periode ini
            const { data: existingInvoices, error: invError } = await supabase
                .from('invoices')
                .select('customer_id')
                .ilike('invoice_period', targetPeriod);

            if (invError) throw new Error(`Gagal mengecek tagihan yang ada: ${invError.message}`);

            const existingCustomerIds = new Set((existingInvoices || []).map(inv => inv.customer_id));

            // 3. Filter pelanggan yang BELUM punya tagihan di periode tersebut
            const profilesToCreate = activeProfiles.filter(p => !existingCustomerIds.has(p.id));

            if (profilesToCreate.length === 0) {
                hidePaymentLoading();
                showSuccessNotification(`Tidak ada tagihan baru yang dibuat. Semua pelanggan aktif sudah memiliki tagihan untuk periode ${targetPeriod}.`);
                return;
            }

            // 4. Hitung tanggal jatuh tempo (tanggal 10 bulan berikutnya dari targetPeriod)
            const nextMonthDate = new Date(targetYear, monthIndex, 10);
            const yyyy = nextMonthDate.getFullYear();
            const mm = String(nextMonthDate.getMonth() + 1).padStart(2, '0');
            const dd = String(nextMonthDate.getDate()).padStart(2, '0');
            const dueDateStr = `${yyyy}-${mm}-${dd}`;

            // 5. Siapkan data tagihan baru
            const newInvoicesPayload = profilesToCreate.map(profile => {
                const packagePrice = profile.packages ? profile.packages.price : 0;
                return {
                    customer_id: profile.id,
                    package_id: profile.package_id,
                    invoice_period: targetPeriod,
                    amount: packagePrice,
                    total_due: packagePrice,
                    amount_paid: 0,
                    status: 'unpaid',
                    due_date: dueDateStr
                };
            });

            // 6. Insert data ke tabel invoices
            const { data: inserted, error: insertError } = await supabase
                .from('invoices')
                .insert(newInvoicesPayload)
                .select();

            hidePaymentLoading();

            if (insertError) throw new Error(insertError.message);

            const count = inserted ? inserted.length : newInvoicesPayload.length;
            showSuccessNotification(`Berhasil membuat ${count} tagihan baru untuk periode ${targetPeriod}.`);
            fetchData();

        } catch (error) {
            hidePaymentLoading();
            console.error('Error creating invoices:', error);
            showErrorNotification(`Gagal membuat tagihan: ${error.message}`);
        }
    }

    function showLoading() {
        invoiceList.innerHTML = '';
        for (let i = 0; i < 10; i++) {
            const skeletonItem = document.createElement('div');
            skeletonItem.className = 'skeleton-item flex items-center gap-4 bg-[#f9f8fb] px-4 min-h-[72px] py-2 justify-between border-b border-gray-200';
            skeletonItem.innerHTML = `
                <div class="flex flex-col justify-center flex-1 gap-2">
                    <div class="skeleton-line h-4 bg-gray-300 rounded w-3/4"></div>
                    <div class="skeleton-line h-3 bg-gray-300 rounded w-1/2"></div>
                </div>
                <div class="shrink-0 flex gap-2">
                    <div class="skeleton-button w-8 h-8 bg-gray-300 rounded-lg"></div>
                    <div class="skeleton-button w-12 h-8 bg-gray-300 rounded-lg"></div>
                    <div class="skeleton-button w-20 h-8 bg-gray-300 rounded-lg"></div>
                </div>
            `;
            invoiceList.appendChild(skeletonItem);
        }
        if (!document.getElementById('skeleton-styles')) {
            const style = document.createElement('style');
            style.id = 'skeleton-styles';
            style.textContent = `@keyframes skeleton-loading { 0% { background-position: -200px 0; } 100% { background-position: calc(200px + 100%) 0; } } .skeleton-line, .skeleton-button { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200px 100%; animation: skeleton-loading 1.5s infinite; } .skeleton-item { pointer-events: none; }`;
            document.head.appendChild(style);
        }
    }

    function hideLoading() {
        const skeletonItems = document.querySelectorAll('.skeleton-item');
        skeletonItems.forEach(item => item.remove());
    }

    function showPaymentLoading(text = 'Memproses...') {
        const loadingOverlay = document.createElement('div');
        loadingOverlay.id = 'payment-loading-overlay';
        loadingOverlay.style.cssText = `position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.5); display: flex; justify-content: center; align-items: center; z-index: 1000;`;
        loadingOverlay.innerHTML = `<div style="background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);"><div class="loading-spinner" style="border: 4px solid #f3f3f3; border-top: 4px solid #683fe4; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 0 auto 10px;"></div><div>${text}</div></div>`;
        if (!document.getElementById('payment-loading-styles')) {
            const style = document.createElement('style');
            style.id = 'payment-loading-styles';
            style.textContent = `@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }`;
            document.head.appendChild(style);
        }
        document.body.appendChild(loadingOverlay);
    }

    function hidePaymentLoading() {
        const loadingOverlay = document.getElementById('payment-loading-overlay');
        if (loadingOverlay) loadingOverlay.remove();
    }

    function showSuccessNotification(message) {
        showNotification(message, '#28a745', '✅');
    }

    function showErrorNotification(message) {
        showNotification(message, '#dc3545', '❌');
    }

    function showInstallmentModal(invoiceData) {
        // Hapus modal yang sudah ada jika ada
        const existingModal = document.getElementById('installment-modal');
        if (existingModal) existingModal.remove();

        const formatter = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' });

        const modal = document.createElement('div');
        modal.id = 'installment-modal';
        modal.style.cssText = `
            position: fixed; top: 0; left: 0; width: 100%; height: 100%; 
            background-color: rgba(0, 0, 0, 0.5); display: flex; 
            justify-content: center; align-items: center; z-index: 1001;
        `;

        modal.innerHTML = `
            <div class="bg-white rounded-lg p-6 w-full max-w-md mx-4 shadow-xl">
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-semibold text-gray-800">Pembayaran Cicilan</h3>
                    <button id="close-installment-modal" class="text-gray-500 hover:text-gray-700 text-xl">&times;</button>
                </div>
                
                <div class="space-y-3 mb-4">
                    <div class="flex justify-between">
                        <span class="text-gray-600">Pelanggan:</span>
                        <span class="font-medium">${invoiceData.customerName}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Periode:</span>
                        <span class="font-medium">${invoiceData.invoicePeriod}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Total Tagihan:</span>
                        <span class="font-medium">${formatter.format(invoiceData.totalDue)}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Sudah Dibayar:</span>
                        <span class="font-medium text-green-600">${formatter.format(invoiceData.amountPaid)}</span>
                    </div>
                    <div class="flex justify-between border-t pt-2">
                        <span class="text-gray-800 font-semibold">Sisa Tagihan:</span>
                        <span class="font-bold text-red-600">${formatter.format(invoiceData.remainingAmount)}</span>
                    </div>
                </div>
                
                <div class="space-y-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Jumlah Bayar:</label>
                        <input type="number" id="payment-amount" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" 
                               placeholder="Masukkan jumlah" min="1" max="${invoiceData.remainingAmount}">
                    </div>
                    
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Metode Pembayaran:</label>
                        <select id="payment-method" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
                            <option value="cash">Tunai</option>
                            <option value="transfer">Transfer Bank</option>
                            <option value="ewallet">E-Wallet</option>
                            <option value="qris">QRIS</option> </select>
                        </select>
                    </div>
                    
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Catatan (Opsional):</label>
                        <textarea id="payment-note" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500" 
                                  rows="2" placeholder="Catatan pembayaran..."></textarea>
                    </div>
                </div>
                
                <div class="flex gap-3 mt-6">
                    <button id="cancel-payment" class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors">
                        Batal
                    </button>
                    <button id="process-payment" class="flex-1 px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors">
                        Proses Pembayaran
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Event listeners untuk modal
        document.getElementById('close-installment-modal').addEventListener('click', () => modal.remove());
        document.getElementById('cancel-payment').addEventListener('click', () => modal.remove());
        document.getElementById('process-payment').addEventListener('click', () => processInstallmentPayment(invoiceData, modal));

        // Close modal saat klik di luar
        modal.addEventListener('click', (e) => {
            if (e.target === modal) modal.remove();
        });

        // Focus ke input amount
        setTimeout(() => {
            document.getElementById('payment-amount').focus();
        }, 100);
    }

    function showFullPaymentModal(invoiceData) {
        // Hapus modal yang sudah ada jika ada
        const existingModal = document.getElementById('full-payment-modal');
        if (existingModal) existingModal.remove();

        const formatter = new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' });

        const modal = document.createElement('div');
        modal.id = 'full-payment-modal';
        modal.style.cssText = `
            position: fixed; top: 0; left: 0; width: 100%; height: 100%; 
            background-color: rgba(0, 0, 0, 0.5); display: flex; 
            justify-content: center; align-items: center; z-index: 1001;
        `;

        modal.innerHTML = `
            <div class="bg-white rounded-lg p-6 w-full max-w-md mx-4 shadow-xl">
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-semibold text-gray-800">Pembayaran Lunas</h3>
                    <button id="close-full-payment-modal" class="text-gray-500 hover:text-gray-700 text-xl">&times;</button>
                </div>
                
                <div class="space-y-3 mb-4">
                    <div class="flex justify-between">
                        <span class="text-gray-600">Pelanggan:</span>
                        <span class="font-medium">${invoiceData.customerName}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Periode:</span>
                        <span class="font-medium">${invoiceData.invoicePeriod}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Total Tagihan:</span>
                        <span class="font-medium">${formatter.format(invoiceData.totalDue)}</span>
                    </div>
                    <div class="flex justify-between">
                        <span class="text-gray-600">Sudah Dibayar:</span>
                        <span class="font-medium text-green-600">${formatter.format(invoiceData.amountPaid)}</span>
                    </div>
                    <div class="flex justify-between border-t pt-2">
                        <span class="text-gray-800 font-semibold">Sisa Tagihan:</span>
                        <span class="font-bold text-red-600">${formatter.format(invoiceData.remainingAmount)}</span>
                    </div>
                </div>
                
                <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
                    <div class="flex items-center">
                        <div class="flex-shrink-0">
                            <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                            </svg>
                        </div>
                        <div class="ml-3">
                            <p class="text-sm text-green-800">
                                <strong>Pembayaran Lunas</strong><br>
                                Jumlah yang akan dibayar: <strong>${formatter.format(invoiceData.remainingAmount)}</strong>
                            </p>
                        </div>
                    </div>
                </div>
                
                <div class="space-y-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Metode Pembayaran:</label>
                        <select id="full-payment-method" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500">
                            <option value="cash">Tunai</option>
                            <option value="transfer">Transfer Bank</option>
                            <option value="ewallet">E-Wallet</option>
                            <option value="qris">QRIS</option> </select>
                        </select>
                    </div>
                    
                    <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">Catatan (Opsional):</label>
                        <textarea id="full-payment-note" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500" 
                                  rows="2" placeholder="Catatan pembayaran..."></textarea>
                    </div>
                </div>
                
                <div class="flex gap-3 mt-6">
                    <button id="cancel-full-payment" class="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors">
                        Batal
                    </button>
                    <button id="process-full-payment" class="flex-1 px-4 py-2 bg-green-500 text-white rounded-md hover:bg-green-600 transition-colors">
                        Bayar Lunas
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Event listeners untuk modal
        document.getElementById('close-full-payment-modal').addEventListener('click', () => modal.remove());
        document.getElementById('cancel-full-payment').addEventListener('click', () => modal.remove());
        document.getElementById('process-full-payment').addEventListener('click', () => processFullPayment(invoiceData, modal));

        // Close modal saat klik di luar
        modal.addEventListener('click', (e) => {
            if (e.target === modal) modal.remove();
        });

        // Focus ke select method
        setTimeout(() => {
            document.getElementById('full-payment-method').focus();
        }, 100);
    }

    async function processInstallmentPayment(invoiceData, modal) {
        const paymentAmount = parseFloat(document.getElementById('payment-amount').value);
        const paymentMethod = document.getElementById('payment-method').value;
        const paymentNote = document.getElementById('payment-note').value;

        // Validasi input
        if (!paymentAmount || paymentAmount <= 0) {
            showErrorNotification('Masukkan jumlah pembayaran yang valid');
            return;
        }

        if (paymentAmount > invoiceData.remainingAmount) {
            showErrorNotification(`Jumlah pembayaran tidak boleh melebihi sisa tagihan (${new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' }).format(invoiceData.remainingAmount)})`);
            return;
        }

        showPaymentLoading('Memproses pembayaran cicilan...');

        try {
            const adminName = await getCurrentAdminName();

            const { data, error } = await supabase.rpc('process_installment_payment', {
                p_invoice_id: invoiceData.invoiceId,
                p_payment_amount: paymentAmount,
                p_admin_name: adminName,
                p_payment_method: paymentMethod,
                p_note: paymentNote
            });

            if (error) throw error;

            if (!data.success) {
                throw new Error(data.message);
            }

            hidePaymentLoading();
            modal.remove();
            showSuccessNotification(data.message);

            // Send WhatsApp notification untuk cicilan
            try {
                const adminName = await getCurrentAdminName();

                // Ambil data customer dari invoice untuk notifikasi
                const { data: invoiceWithCustomer, error: customerError } = await supabase
                    .from('invoices')
                    .select(
                        `
                        customer_id,
                        profiles!inner (
                            id, full_name, idpl, whatsapp_number
                        )
                    `)
                    .eq('id', invoiceData.invoiceId)
                    .single();

                if (customerError) {
                    console.error('Error fetching customer data:', customerError);
                } else if (invoiceWithCustomer && invoiceWithCustomer.profiles && invoiceWithCustomer.profiles.whatsapp_number) {
                    sendInstallmentWhatsAppNotification({
                        customer: invoiceWithCustomer.profiles,
                        invoiceId: invoiceData.invoiceId,
                        paymentAmount: paymentAmount,
                        remainingAfterPayment: data.data.remaining_amount,
                        totalDue: invoiceData.totalDue,
                        invoicePeriod: invoiceData.invoicePeriod,
                        paymentMethod: paymentMethod,
                        isFullyPaid: data.data.new_status === 'paid'
                    });
                }
            } catch (notificationError) {
                console.error('WhatsApp notification error:', notificationError);
                // Tidak perlu show error karena pembayaran sudah berhasil
            }

            fetchData();

        } catch (error) {
            console.error('Error processing installment payment:', error);
            hidePaymentLoading();
            showErrorNotification(`Error: ${error.message}`);
        }
    }

    async function processFullPayment(invoiceData, modal) {
        const paymentMethod = document.getElementById('full-payment-method').value;
        const paymentNote = document.getElementById('full-payment-note').value;
        const paymentAmount = invoiceData.remainingAmount; // Selalu bayar sisa tagihan

        showPaymentLoading('Memproses pembayaran lunas...');

        try {
            const adminName = await getCurrentAdminName();

            const { data, error } = await supabase.rpc('process_installment_payment', {
                p_invoice_id: invoiceData.invoiceId,
                p_payment_amount: paymentAmount,
                p_admin_name: adminName,
                p_payment_method: paymentMethod,
                p_note: paymentNote || 'Pembayaran lunas langsung'
            });

            if (error) throw error;

            if (!data.success) {
                throw new Error(data.message);
            }

            hidePaymentLoading();
            modal.remove();
            showSuccessNotification(data.message);

            // Tampilkan popup cetak struk otomatis
            try {
                const { data: freshPaidInvoice } = await supabase
                    .from('invoices')
                    .select('*, profiles(*)')
                    .eq('id', invoiceData.invoiceId)
                    .single();
                if (freshPaidInvoice) {
                    receiptPrinter.openReceipt(freshPaidInvoice);
                }
            } catch (receiptErr) {
                console.warn('Gagal memuat invoice untuk struk:', receiptErr);
            }

            // Send WhatsApp notification untuk pembayaran lunas
            try {
                const adminName = await getCurrentAdminName();

                // Ambil data customer dari invoice untuk notifikasi
                const { data: invoiceWithCustomer, error: customerError } = await supabase
                    .from('invoices')
                    .select(
                        `
                        customer_id,
                        profiles!inner (
                            id, full_name, idpl, whatsapp_number
                        )
                    `)
                    .eq('id', invoiceData.invoiceId)
                    .single();

                if (customerError) {
                    console.error('Error fetching customer data:', customerError);
                } else if (invoiceWithCustomer && invoiceWithCustomer.profiles && invoiceWithCustomer.profiles.whatsapp_number) {
                    sendInstallmentWhatsAppNotification({
                        customer: invoiceWithCustomer.profiles,
                        invoiceId: invoiceData.invoiceId,
                        paymentAmount: paymentAmount,
                        remainingAfterPayment: 0, // Lunas, sisa 0
                        totalDue: invoiceData.totalDue,
                        invoicePeriod: invoiceData.invoicePeriod,
                        paymentMethod: paymentMethod,
                        isFullyPaid: true // Selalu true untuk pembayaran lunas
                    });
                }
            } catch (notificationError) {
                console.error('WhatsApp notification error:', notificationError);
                // Tidak perlu show error karena pembayaran sudah berhasil
            }

            fetchData();

        } catch (error) {
            console.error('Error processing full payment:', error);
            hidePaymentLoading();
            showErrorNotification(`Error: ${error.message}`);
        }
    }

    async function sendInstallmentWhatsAppNotification(paymentData) {
        const { customer, paymentAmount, remainingAfterPayment, totalDue, invoicePeriod, paymentMethod, isFullyPaid } = paymentData;

        if (!customer.whatsapp_number) {
            console.warn('Customer WhatsApp number not available');
            return;
        }

        try {
            // Get admin name
            const adminName = await getCurrentAdminName();

            // Prepare customer data for notification
            const customerData = {
                id: customer.id,
                full_name: customer.full_name,
                idpl: customer.idpl,
                whatsapp_number: customer.whatsapp_number
            };

            // Prepare invoice data for notification
            const invoiceData = {
                id: paymentData.invoiceId || 'unknown',
                invoice_period: invoicePeriod,
                amount: isFullyPaid ? totalDue : paymentAmount,
                paid_at: new Date().toISOString(),
                payment_method: paymentMethod,
                remaining_amount: remainingAfterPayment,
                is_fully_paid: isFullyPaid
            };

            let customerNotificationResult = null;
            // Send automatic WhatsApp notification to customer (hanya jika belum lunas)
            if (!isFullyPaid) {
                customerNotificationResult = await sendCustomerPaymentNotification(customerData, invoiceData, paymentMethod);
            }

            // Send notification to all admins using the existing system
            try {
                const adminName = await getCurrentAdminName();
                const { error: notifError } = await supabase.rpc('add_payment_notification', {
                    customer_name: customer.full_name,
                    customer_idpl: customer.idpl,
                    invoice_period: invoicePeriod,
                    amount: isFullyPaid ? totalDue : paymentAmount,
                    admin_name: adminName
                });

                if (notifError) {
                    console.error('Error sending admin payment notification:', notifError);
                    showErrorNotification('❌ Gagal mengirim notifikasi ke admin: ' + notifError.message);
                } else {
                    console.log('✅ Payment notification sent to all admins');
                    showSuccessNotification(`✅ Notifikasi pembayaran berhasil dikirim ke admin`);
                }
            } catch (notifError) {
                console.error('Failed to send admin notification:', notifError);
                showErrorNotification('❌ Error mengirim notifikasi ke admin: ' + notifError.message);
            }

            // Show results for customer notification only if not disabled and if it was sent
            if (!isFullyPaid && customerNotificationResult) {
                if (customerNotificationResult.message !== 'Notifikasi otomatis dinonaktifkan') {
                    if (customerNotificationResult.success) {
                        const statusText = isFullyPaid ? 'LUNAS' : 'CICILAN';
                        showSuccessNotification(`✅ Notifikasi WhatsApp ${statusText} berhasil dikirim ke ${customer.full_name}`);
                    } else {
                        showErrorNotification(`❌ Gagal mengirim notifikasi ke pelanggan: ${customerNotificationResult.message}`);
                    }
                }
            }

        } catch (error) {
            console.error('Error sending WhatsApp notifications:', error);
            showErrorNotification(`❌ Error mengirim notifikasi: ${error.message}`);
        }
    }

    function showNotification(message, bgColor, icon) {
        const notification = document.createElement('div');
        notification.style.cssText = `position: fixed; top: 20px; right: 20px; background-color: ${bgColor}; color: white; padding: 15px 20px; border-radius: 8px; z-index: 1002; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2); animation: slideInRight 0.3s ease;`;
        notification.innerHTML = `<div style="display: flex; align-items: center; gap: 10px;"><span>${icon}</span><span>${message}</span></div>`;
        if (!document.getElementById('notification-styles')) {
            const style = document.createElement('style');
            style.id = 'notification-styles';
            style.textContent = `@keyframes slideInRight { from { transform: translateX(100%); opacity: 0; } to { transform: translateX(0); opacity: 1; } } @keyframes slideOutRight { from { transform: translateX(0); opacity: 1; } to { transform: translateX(100%); opacity: 0; } }`;
            document.head.appendChild(style);
        }
        document.body.appendChild(notification);
        setTimeout(() => {
            if (notification.parentNode) {
                notification.style.animation = 'slideOutRight 0.3s ease forwards';
                notification.addEventListener('animationend', () => notification.remove());
            }
        }, 3000);
    }
    // ===============================================
    // Action Menu & Delete Invoices Functions
    // ===============================================
    function toggleActionMenu(button) {
        const container = button.closest('.action-menu-container');
        if (!container) return;
        const dropdown = container.querySelector('.action-menu-dropdown');
        if (!dropdown) return;

        const isCurrentlyHidden = dropdown.classList.contains('hidden');
        closeAllActionMenus();
        if (isCurrentlyHidden) {
            dropdown.classList.remove('hidden');
        }
    }

    function closeAllActionMenus() {
        document.querySelectorAll('.action-menu-dropdown').forEach(dd => dd.classList.add('hidden'));
    }

    // Global listener untuk tutup dropdown menu saat klik di luar
    document.addEventListener('click', (e) => {
        if (!e.target.closest('.action-menu-container')) {
            closeAllActionMenus();
        }
    });

    async function handleDeleteSingleInvoice(invoiceId, customerName, period, amount) {
        const formattedAmount = formatter.format(amount || 0);
        const confirmMsg = `Apakah Anda YAKIN ingin menghapus tagihan periode ${period} milik "${customerName}" (${formattedAmount})?\n\nTagihan yang dihapus tidak dapat dikembalikan.`;
        if (!confirm(confirmMsg)) return;

        showPaymentLoading('Menghapus tagihan...');
        try {
            const { error } = await supabase
                .from('invoices')
                .delete()
                .eq('id', invoiceId)
                .eq('status', 'unpaid'); // Hanya tagihan unpaid

            if (error) throw error;

            hidePaymentLoading();
            showSuccessNotification(`Tagihan periode ${period} milik ${customerName} berhasil dihapus.`);
            await fetchData();
        } catch (err) {
            hidePaymentLoading();
            console.error('Error deleting invoice:', err);
            showErrorNotification(`Gagal menghapus tagihan: ${err.message}`);
        }
    }

    async function handleBulkDeleteInvoices() {
        const checkedBoxes = Array.from(document.querySelectorAll('.broadcast-checkbox:checked'));
        if (checkedBoxes.length === 0) {
            showErrorNotification('Pilih setidaknya satu tagihan untuk dihapus.');
            return;
        }

        const count = checkedBoxes.length;
        const confirmMsg = `Apakah Anda YAKIN ingin menghapus ${count} tagihan terpilih?\n\nPERINGATAN: Tagihan yang dihapus akan hilang permanen!`;
        if (!confirm(confirmMsg)) return;

        showPaymentLoading(`Menghapus ${count} tagihan...`);
        try {
            const selectedIds = checkedBoxes.map(cb => cb.value);

            const { error } = await supabase
                .from('invoices')
                .delete()
                .in('id', selectedIds)
                .eq('status', 'unpaid'); // Hanya tagihan unpaid

            if (error) throw error;

            hidePaymentLoading();
            showSuccessNotification(`Berhasil menghapus ${count} tagihan.`);
            await fetchData();
        } catch (err) {
            hidePaymentLoading();
            console.error('Error bulk deleting invoices:', err);
            showErrorNotification(`Gagal menghapus tagihan massal: ${err.message}`);
        }
    }

    // Listener tombol Bulk Delete
    document.getElementById('btn-bulk-delete')?.addEventListener('click', () => {
        handleBulkDeleteInvoices();
    });

});
