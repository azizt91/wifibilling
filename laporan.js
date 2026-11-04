// laporan.js - Comprehensive Reports Module
import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';

document.addEventListener('DOMContentLoaded', async () => {
    console.log('Laporan page loaded');

    // Check authentication
    try {
        const user = await requireRole('ADMIN');
        initLogout('desktop-logout-btn');
        if (!user) {
            console.log('Authentication failed');
            return;
        }
    } catch (error) {
        console.error('Authentication error:', error);
        return;
    }

    // Global variables
    let allInvoices = [];
    let allExpenses = [];
    let filteredInvoices = [];
    let filteredExpenses = [];
    let combinedData = []; // Gabungan invoices dan expenses untuk display
    let currentTenantName = 'WiFi Billing System';
    let currentFilters = {
        periode: 'all',
        status: 'all',
        paymentMethod: 'all',
        customerSearch: '',
        startDate: null,
        endDate: null,
        includeExpenses: true // Toggle untuk include/exclude expenses
    };

    // DOM Elements
    const backBtn = document.getElementById('back-btn');
    const filterBtn = document.getElementById('filter-btn');
    const filterModal = document.getElementById('filter-modal');
    const closeFilterModal = document.getElementById('close-filter-modal');
    const periodeFilter = document.getElementById('periode-filter');
    const customDateRange = document.getElementById('custom-date-range');
    const startDateInput = document.getElementById('start-date');
    const endDateInput = document.getElementById('end-date');
    const statusFilter = document.getElementById('status-filter');
    const paymentMethodFilter = document.getElementById('payment-method-filter');
    const customerSearch = document.getElementById('customer-search');
    const resetFilterBtn = document.getElementById('reset-filter-btn');
    const applyFilterBtn = document.getElementById('apply-filter-btn');
    const filterBadge = document.getElementById('filter-badge');
    const exportPdfBtn = document.getElementById('export-pdf-btn');
    const exportExcelBtn = document.getElementById('export-excel-btn');
    const loadingState = document.getElementById('loading-state');
    const tableContainer = document.getElementById('table-container');
    const tableBody = document.getElementById('table-body');
    const emptyState = document.getElementById('empty-state');
    const dataCount = document.getElementById('data-count');

    // Summary elements
    const totalPendapatan = document.getElementById('total-pendapatan');
    const totalTransaksi = document.getElementById('total-transaksi');
    const totalLunas = document.getElementById('total-lunas');
    const countLunas = document.getElementById('count-lunas');
    const totalUnpaid = document.getElementById('total-unpaid');
    const countUnpaid = document.getElementById('count-unpaid');
    const totalInstallment = document.getElementById('total-installment');
    const countInstallment = document.getElementById('count-installment');
    const totalPengeluaran = document.getElementById('total-pengeluaran');
    const countPengeluaran = document.getElementById('count-pengeluaran');

    // Currency formatter
    const formatter = new Intl.NumberFormat('id-ID', {
        style: 'currency',
        currency: 'IDR',
        minimumFractionDigits: 0
    });

    // ============================================
    // Event Listeners
    // ============================================

    backBtn?.addEventListener('click', () => {
        window.history.back();
    });

    const openFilterModal = () => {
        filterModal.classList.remove('hidden');
    };

    filterBtn?.addEventListener('click', openFilterModal);
    document.getElementById('desktop-filter-btn')?.addEventListener('click', openFilterModal);

    closeFilterModal?.addEventListener('click', () => {
        filterModal.classList.add('hidden');
    });

    // Close modal when clicking outside
    filterModal?.addEventListener('click', (e) => {
        if (e.target === filterModal) {
            filterModal.classList.add('hidden');
        }
    });

    periodeFilter?.addEventListener('change', () => {
        if (periodeFilter.value === 'custom') {
            customDateRange.classList.remove('hidden');
        } else {
            customDateRange.classList.add('hidden');
        }
    });

    resetFilterBtn?.addEventListener('click', () => {
        resetFilters();
    });

    applyFilterBtn?.addEventListener('click', () => {
        applyFilters();
        filterModal.classList.add('hidden');
    });

    exportPdfBtn?.addEventListener('click', () => {
        exportToPDF();
    });
    document.getElementById('desktop-export-pdf-btn')?.addEventListener('click', () => {
        exportToPDF();
    });

    exportExcelBtn?.addEventListener('click', () => {
        exportToExcel();
    });
    document.getElementById('desktop-export-excel-btn')?.addEventListener('click', () => {
        exportToExcel();
    });

    // ============================================
    // Tenant & Branding Helper
    // ============================================

    async function fetchTenantName() {
        try {
            // 1. Coba ambil dari localStorage app_settings (di-cache oleh apply-settings.js)
            const localSettings = localStorage.getItem('app_settings');
            if (localSettings) {
                try {
                    const parsed = JSON.parse(localSettings);
                    if (parsed.app_name && parsed.app_name.trim() !== '' && parsed.app_name.trim() !== 'WiFi Billing System') {
                        currentTenantName = parsed.app_name.trim();
                        return currentTenantName;
                    }
                } catch (e) {}
            }

            // 2. Coba ambil dari tabel app_settings (Supabase)
            const { data: settings } = await supabase
                .from('app_settings')
                .select('app_name')
                .limit(1)
                .maybeSingle();

            if (settings?.app_name && settings.app_name.trim() !== '' && settings.app_name.trim() !== 'WiFi Billing System') {
                currentTenantName = settings.app_name.trim();
                return currentTenantName;
            }

            // 3. Coba ambil dari tabel tenants
            const { data: tenant } = await supabase
                .from('tenants')
                .select('name')
                .limit(1)
                .maybeSingle();

            if (tenant?.name && tenant.name.trim() !== '') {
                currentTenantName = tenant.name.trim();
                return currentTenantName;
            }

            if (settings?.app_name && settings.app_name.trim() !== '') {
                currentTenantName = settings.app_name.trim();
                return currentTenantName;
            }
        } catch (e) {
            console.warn('Gagal memuat nama tenant untuk laporan:', e);
        }
        return currentTenantName;
    }

    // ============================================
    // Data Fetching
    // ============================================

    async function fetchData() {
        try {
            showLoading();

            // Fetch all invoices with customer profiles
            const { data: invoices, error: invoiceError } = await supabase
                .from('invoices')
                .select(`
                    *,
                    profiles:customer_id (
                        full_name,
                        idpl
                    )
                `)
                .order('created_at', { ascending: false });

            if (invoiceError) throw invoiceError;

            // Fetch all expenses
            const { data: expenses, error: expenseError } = await supabase
                .from('expenses')
                .select('*')
                .order('expense_date', { ascending: false });

            if (expenseError) throw expenseError;

            allInvoices = invoices || [];
            allExpenses = expenses || [];
            filteredInvoices = [...allInvoices];
            filteredExpenses = [...allExpenses];

            console.log(`Loaded ${allInvoices.length} invoices and ${allExpenses.length} expenses`);

            updateDisplay();
            hideLoading();

        } catch (error) {
            console.error('Error fetching data:', error);
            hideLoading();
            showError('Gagal memuat data: ' + error.message);
        }
    }

    // ============================================
    // Filtering Functions
    // ============================================

    function applyFilters() {
        // Get filter values
        currentFilters.periode = periodeFilter.value;
        currentFilters.status = statusFilter.value;
        currentFilters.paymentMethod = paymentMethodFilter.value;
        currentFilters.customerSearch = customerSearch.value.trim().toLowerCase();
        currentFilters.startDate = startDateInput.value;
        currentFilters.endDate = endDateInput.value;

        // Calculate date boundaries
        const now = new Date();
        let startDate = null;
        let endDate = null;

        switch (currentFilters.periode) {
            case 'bulan-ini':
                startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
                endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
                break;
            case 'bulan-lalu':
                startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
                endDate = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
                break;
            case '3-bulan':
                startDate = new Date(now.getFullYear(), now.getMonth() - 3, now.getDate(), 0, 0, 0, 0);
                endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
                break;
            case '6-bulan':
                startDate = new Date(now.getFullYear(), now.getMonth() - 6, now.getDate(), 0, 0, 0, 0);
                endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
                break;
            case 'tahun-ini':
                startDate = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
                endDate = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
                break;
            case 'custom':
                if (currentFilters.startDate) {
                    startDate = new Date(currentFilters.startDate + 'T00:00:00');
                }
                if (currentFilters.endDate) {
                    endDate = new Date(currentFilters.endDate + 'T23:59:59.999');
                }
                break;
        }

        const isInRange = (d) => {
            if (!d || isNaN(d.getTime())) return false;
            if (startDate && d < startDate) return false;
            if (endDate && d > endDate) return false;
            return true;
        };

        // Start with all invoices
        filteredInvoices = [...allInvoices];

        // Apply periode filter (berdasarkan tanggal bayar atau tanggal dibuat)
        if (currentFilters.periode !== 'all') {
            filteredInvoices = filteredInvoices.filter(invoice => {
                const targetDate = new Date(invoice.paid_at || invoice.created_at);
                return isInRange(targetDate);
            });
        }

        // Apply status filter
        if (currentFilters.status !== 'all') {
            filteredInvoices = filteredInvoices.filter(invoice => {
                if (currentFilters.status === 'installment' || currentFilters.status === 'partially_paid') {
                    return invoice.status === 'partially_paid' || invoice.status === 'installment';
                }
                return invoice.status === currentFilters.status;
            });
        }

        // Apply payment method filter
        if (currentFilters.paymentMethod !== 'all') {
            filteredInvoices = filteredInvoices.filter(invoice => {
                if (invoice.status === 'paid' || invoice.status === 'partially_paid' || invoice.status === 'installment') {
                    const method = invoice.payment_method?.toLowerCase() || '';
                    return method.includes(currentFilters.paymentMethod.toLowerCase());
                }
                return false;
            });
        }

        // Apply customer search filter
        if (currentFilters.customerSearch) {
            filteredInvoices = filteredInvoices.filter(invoice => {
                const customerName = invoice.profiles?.full_name?.toLowerCase() || '';
                const customerIdpl = invoice.profiles?.idpl?.toLowerCase() || '';
                return customerName.includes(currentFilters.customerSearch) || 
                       customerIdpl.includes(currentFilters.customerSearch);
            });
        }

        // ============================================
        // Filter expenses
        // ============================================
        // Jika filter status, metode bayar, atau nama pelanggan aktif, sembunyikan pengeluaran operasional
        if (currentFilters.status !== 'all' || currentFilters.paymentMethod !== 'all' || currentFilters.customerSearch !== '') {
            filteredExpenses = [];
        } else {
            filteredExpenses = [...allExpenses];
            if (currentFilters.periode !== 'all') {
                filteredExpenses = filteredExpenses.filter(expense => {
                    const expenseDate = new Date(expense.expense_date);
                    return isInRange(expenseDate);
                });
            }
        }

        updateDisplay();
        updateFilterBadge();
    }

    function resetFilters() {
        periodeFilter.value = 'all';
        statusFilter.value = 'all';
        paymentMethodFilter.value = 'all';
        customerSearch.value = '';
        startDateInput.value = '';
        endDateInput.value = '';
        customDateRange.classList.add('hidden');

        currentFilters = {
            periode: 'all',
            status: 'all',
            paymentMethod: 'all',
            customerSearch: '',
            startDate: null,
            endDate: null
        };

        filteredInvoices = [...allInvoices];
        filteredExpenses = [...allExpenses];
        updateDisplay();
        updateFilterBadge();
    }

    function updateFilterBadge() {
        const activeFilters = Object.values(currentFilters).filter(val => 
            val && val !== 'all' && val !== ''
        ).length;

        const desktopFilterBadge = document.getElementById('desktop-filter-badge');
        if (activeFilters > 0) {
            filterBadge.textContent = activeFilters;
            filterBadge.classList.remove('hidden');
            if (desktopFilterBadge) {
                desktopFilterBadge.textContent = `${activeFilters} Filter Aktif`;
                desktopFilterBadge.classList.remove('hidden');
            }
        } else {
            filterBadge.classList.add('hidden');
            if (desktopFilterBadge) {
                desktopFilterBadge.classList.add('hidden');
            }
        }
    }

    // ============================================
    // Display Functions
    // ============================================

    function updateDisplay() {
        updateSummary();
        updateTable();
    }

    function updateSummary() {
        // Calculate totals for invoices
        const paid = filteredInvoices.filter(inv => inv.status === 'paid');
        const unpaid = filteredInvoices.filter(inv => inv.status === 'unpaid');
        const installment = filteredInvoices.filter(inv => inv.status === 'partially_paid' || inv.status === 'installment');

        const totalLunasValue = paid.reduce((sum, inv) => sum + (inv.total_due || 0), 0);
        const totalInstallmentValue = installment.reduce((sum, inv) => sum + (inv.amount_paid || 0), 0);
        const totalPendapatanValue = totalLunasValue + totalInstallmentValue;
        const totalUnpaidValue = unpaid.reduce((sum, inv) => sum + (inv.amount || 0), 0);

        // Calculate totals for expenses
        const totalPengeluaranValue = filteredExpenses.reduce((sum, exp) => sum + (parseFloat(exp.amount) || 0), 0);

        // Update DOM
        totalPendapatan.textContent = formatter.format(totalPendapatanValue);
        totalTransaksi.textContent = `${paid.length} Transaksi`;

        totalLunas.textContent = formatter.format(totalLunasValue);
        countLunas.textContent = `${paid.length} Tagihan`;

        totalUnpaid.textContent = formatter.format(totalUnpaidValue);
        countUnpaid.textContent = `${unpaid.length} Tagihan`;

        totalInstallment.textContent = formatter.format(totalInstallmentValue);
        countInstallment.textContent = `${installment.length} Tagihan`;

        totalPengeluaran.textContent = formatter.format(totalPengeluaranValue);
        countPengeluaran.textContent = `${filteredExpenses.length} Pengeluaran`;
    }

    function updateTable() {
        // Combine invoices and expenses
        combinedData = [];

        // Add invoices with type 'income'
        filteredInvoices.forEach(invoice => {
            combinedData.push({
                type: 'income',
                date: invoice.paid_at || invoice.created_at,
                customerName: invoice.profiles?.full_name || 'N/A',
                customerIdpl: invoice.profiles?.idpl || 'N/A',
                description: invoice.invoice_period || '-',
                amount: (invoice.status === 'paid') ? (invoice.total_due || invoice.amount || 0) : ((invoice.status === 'partially_paid' || invoice.status === 'installment') ? (invoice.amount_paid || 0) : (invoice.amount || invoice.total_due || 0)),
                status: invoice.status,
                paymentMethod: invoice.payment_method || '-',
                data: invoice
            });
        });

        // Add expenses with type 'expense'
        filteredExpenses.forEach(expense => {
            combinedData.push({
                type: 'expense',
                date: expense.expense_date,
                customerName: '-',
                customerIdpl: '-',
                description: expense.description || '-',
                amount: parseFloat(expense.amount) || 0,
                status: 'expense',
                paymentMethod: '-',
                data: expense
            });
        });

        // Sort by date (newest first)
        combinedData.sort((a, b) => new Date(b.date) - new Date(a.date));

        if (combinedData.length === 0) {
            showEmptyState();
            return;
        }

        tableContainer.classList.remove('hidden');
        emptyState.classList.add('hidden');
        dataCount.textContent = `Menampilkan ${combinedData.length} data (${filteredInvoices.length} pendapatan, ${filteredExpenses.length} pengeluaran)`;

        tableBody.innerHTML = '';

        combinedData.forEach((item, index) => {
            const row = document.createElement('tr');
            row.className = 'hover:bg-slate-50/80 transition-colors border-b border-slate-100 last:border-none';

            const statusBadge = item.type === 'expense' ? 
                '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-purple-50 text-purple-700 border border-purple-200">Pengeluaran</span>' : 
                getStatusBadge(item.status);

            const displayDate = new Date(item.date).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });
            const amountText = item.type === 'expense' ? 
                `<span class="font-bold text-purple-600">-${formatter.format(item.amount)}</span>` : 
                `<span class="font-bold text-emerald-600">+${formatter.format(item.amount)}</span>`;

            row.innerHTML = `
                <td class="px-4 py-3.5 whitespace-nowrap text-slate-500 font-medium">${index + 1}</td>
                <td class="px-4 py-3.5 text-slate-900 font-semibold">${item.customerName}</td>
                <td class="px-4 py-3.5 text-slate-500 font-mono text-[11px]">${item.customerIdpl}</td>
                <td class="px-4 py-3.5 text-slate-700">${item.description}</td>
                <td class="px-4 py-3.5 whitespace-nowrap">${amountText}</td>
                <td class="px-4 py-3.5 whitespace-nowrap">${statusBadge}</td>
                <td class="px-4 py-3.5 text-slate-500 whitespace-nowrap text-xs">${displayDate}</td>
                <td class="px-4 py-3.5 text-slate-600 uppercase text-[11px] font-bold">${item.paymentMethod}</td>
            `;

            tableBody.appendChild(row);
        });
    }

    function getStatusBadge(status) {
        const badges = {
            'paid': '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">Lunas</span>',
            'unpaid': '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-rose-50 text-rose-700 border border-rose-200">Belum Bayar</span>',
            'partially_paid': '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">Cicilan</span>',
            'installment': '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-amber-50 text-amber-700 border border-amber-200">Cicilan</span>'
        };
        return badges[status] || '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-slate-100 text-slate-700 border border-slate-200">Unknown</span>';
    }

    function showLoading() {
        loadingState.classList.remove('hidden');
        tableContainer.classList.add('hidden');
        emptyState.classList.add('hidden');
    }

    function hideLoading() {
        loadingState.classList.add('hidden');
    }

    function showEmptyState() {
        emptyState.classList.remove('hidden');
        tableContainer.classList.add('hidden');
        dataCount.textContent = 'Menampilkan 0 data';
    }

    function showError(message) {
        alert(message);
    }

    // ============================================
    // Export Functions
    // ============================================

    async function exportToPDF() {
        try {
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF();
            const tenantName = await fetchTenantName();
            const safeTenant = tenantName.replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '_');
            const dateStr = new Date().toISOString().split('T')[0];
            const filename = `Laporan_Keuangan_${safeTenant}_${dateStr}.pdf`;

            // Kop Header Dokumen dengan Identitas Tenant
            doc.setFontSize(16);
            doc.setFont(undefined, 'bold');
            doc.setTextColor(30, 41, 59);
            doc.text(tenantName.toUpperCase(), 14, 15);

            doc.setFontSize(11);
            doc.setFont(undefined, 'bold');
            doc.setTextColor(104, 63, 228);
            doc.text('LAPORAN KEUANGAN & ARUS KAS', 14, 22);

            // Waktu Cetak
            doc.setFontSize(8);
            doc.setFont(undefined, 'normal');
            doc.setTextColor(100, 116, 139);
            doc.text(`Waktu Cetak: ${new Date().toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}`, 14, 28);

            // Ringkasan Keuangan
            doc.setFontSize(10);
            doc.setFont(undefined, 'bold');
            doc.setTextColor(30, 41, 59);
            doc.text('RINGKASAN KEUANGAN:', 14, 38);
            
            doc.setFont(undefined, 'normal');
            doc.setFontSize(9);
            doc.setTextColor(51, 65, 85);

            const paidTotal = filteredInvoices.filter(inv => inv.status === 'paid').reduce((sum, inv) => sum + (inv.total_due || 0), 0);
            const unpaidTotal = filteredInvoices.filter(inv => inv.status === 'unpaid').reduce((sum, inv) => sum + (inv.amount || 0), 0);
            const installmentTotal = filteredInvoices.filter(inv => inv.status === 'partially_paid' || inv.status === 'installment').reduce((sum, inv) => sum + (inv.amount_paid || 0), 0);
            const expenseTotal = filteredExpenses.reduce((sum, exp) => sum + (parseFloat(exp.amount) || 0), 0);
            const netIncome = (paidTotal + installmentTotal) - expenseTotal;
            
            doc.text(`• Total Pendapatan Lunas : ${formatter.format(paidTotal)}`, 14, 45);
            doc.text(`• Total Pengeluaran       : ${formatter.format(expenseTotal)}`, 14, 51);
            doc.text(`• Pendapatan Bersih        : ${formatter.format(netIncome)}`, 14, 57);
            doc.text(`• Total Belum Bayar       : ${formatter.format(unpaidTotal)}`, 110, 45);
            doc.text(`• Total Cicilan           : ${formatter.format(installmentTotal)}`, 110, 51);
            doc.text(`• Jumlah Data             : ${filteredInvoices.length} tagihan, ${filteredExpenses.length} pengeluaran`, 110, 57);

            // Prepare table data from combinedData
            const tableData = combinedData.map((item, index) => {
                const displayDate = new Date(item.date).toLocaleDateString('id-ID');
                const amountStr = formatter.format(item.amount);
                const statusStr = item.type === 'expense' ? 'Pengeluaran' : getStatusText(item.status);
                
                return [
                    index + 1,
                    item.customerName,
                    item.customerIdpl,
                    item.description,
                    item.type === 'expense' ? `-${amountStr}` : `+${amountStr}`,
                    statusStr,
                    displayDate,
                    item.paymentMethod
                ];
            });

            // Add table
            doc.autoTable({
                startY: 64,
                head: [['No', 'Nama', 'ID', 'Keterangan', 'Jumlah', 'Status', 'Tanggal', 'Metode']],
                body: tableData,
                theme: 'striped',
                headStyles: {
                    fillColor: [104, 63, 228],
                    textColor: 255,
                    fontStyle: 'bold'
                },
                styles: {
                    fontSize: 8,
                    cellPadding: 2.5
                },
                columnStyles: {
                    0: { cellWidth: 10 },
                    4: { halign: 'right' }
                }
            });

            // Save PDF
            doc.save(filename);

            showSuccessNotification(`✅ PDF berhasil diexport: ${filename}`);
        } catch (error) {
            console.error('Error exporting PDF:', error);
            showError('Gagal export PDF: ' + error.message);
        }
    }

    async function exportToExcel() {
        try {
            const tenantName = await fetchTenantName();
            const safeTenant = tenantName.replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '_');
            const dateStr = new Date().toISOString().split('T')[0];
            const filename = `Laporan_Keuangan_${safeTenant}_${dateStr}.xlsx`;

            // Prepare data from combinedData
            const excelData = combinedData.map((item, index) => {
                const displayDate = new Date(item.date).toLocaleDateString('id-ID');
                const amount = item.amount || 0;
                const statusStr = item.type === 'expense' ? 'Pengeluaran' : getStatusText(item.status);
                
                return {
                    'No': index + 1,
                    'Tipe': item.type === 'expense' ? 'Pengeluaran' : 'Pendapatan',
                    'Nama Pelanggan': item.customerName,
                    'ID Pelanggan': item.customerIdpl,
                    'Keterangan': item.description,
                    'Jumlah': item.type === 'expense' ? -amount : amount,
                    'Status': statusStr,
                    'Tanggal': displayDate,
                    'Metode Pembayaran': item.paymentMethod
                };
            });

            // Create worksheet
            const ws = XLSX.utils.json_to_sheet(excelData);

            // Set column widths
            const colWidths = [
                { wch: 5 },  // No
                { wch: 12 }, // Tipe
                { wch: 25 }, // Nama
                { wch: 15 }, // ID
                { wch: 30 }, // Keterangan
                { wch: 15 }, // Jumlah
                { wch: 12 }, // Status
                { wch: 15 }, // Tanggal
                { wch: 15 }  // Metode
            ];
            ws['!cols'] = colWidths;

            // Create workbook
            const wb = XLSX.utils.book_new();
            XLSX.utils.book_append_sheet(wb, ws, 'Data Transaksi');

            // Add summary sheet
            const paidTotal = filteredInvoices.filter(inv => inv.status === 'paid').reduce((sum, inv) => sum + (inv.total_due || 0), 0);
            const unpaidTotal = filteredInvoices.filter(inv => inv.status === 'unpaid').reduce((sum, inv) => sum + (inv.amount || 0), 0);
            const installmentTotal = filteredInvoices.filter(inv => inv.status === 'partially_paid' || inv.status === 'installment').reduce((sum, inv) => sum + (inv.amount_paid || 0), 0);
            const expenseTotal = filteredExpenses.reduce((sum, exp) => sum + (parseFloat(exp.amount) || 0), 0);
            const netIncome = (paidTotal + installmentTotal) - expenseTotal;

            const summaryData = [
                { 'Keterangan': 'Nama ISP / Tenant', 'Jumlah': tenantName },
                { 'Keterangan': 'Waktu Cetak', 'Jumlah': new Date().toLocaleString('id-ID') },
                { 'Keterangan': 'Total Pendapatan (Lunas)', 'Jumlah': paidTotal },
                { 'Keterangan': 'Total Pengeluaran', 'Jumlah': expenseTotal },
                { 'Keterangan': 'Pendapatan Bersih', 'Jumlah': netIncome },
                { 'Keterangan': 'Total Belum Bayar', 'Jumlah': unpaidTotal },
                { 'Keterangan': 'Total Cicilan', 'Jumlah': installmentTotal },
                { 'Keterangan': 'Jumlah Tagihan', 'Jumlah': `${filteredInvoices.length} tagihan` },
                { 'Keterangan': 'Jumlah Pengeluaran', 'Jumlah': `${filteredExpenses.length} pengeluaran` }
            ];
            const wsSummary = XLSX.utils.json_to_sheet(summaryData);
            wsSummary['!cols'] = [{ wch: 30 }, { wch: 25 }];
            XLSX.utils.book_append_sheet(wb, wsSummary, 'Ringkasan');

            // Save file
            XLSX.writeFile(wb, filename);

            showSuccessNotification(`✅ Excel berhasil diexport: ${filename}`);
        } catch (error) {
            console.error('Error exporting Excel:', error);
            showError('Gagal export Excel: ' + error.message);
        }
    }

    function getStatusText(status) {
        const statusMap = {
            'paid': 'Lunas',
            'unpaid': 'Belum Bayar',
            'partially_paid': 'Cicilan',
            'installment': 'Cicilan'
        };
        return statusMap[status] || 'Unknown';
    }

    function showSuccessNotification(message) {
        // Simple notification (you can enhance this)
        const notification = document.createElement('div');
        notification.className = 'fixed top-4 right-4 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fade-in';
        notification.textContent = message;
        document.body.appendChild(notification);

        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    // ============================================
    // Initialize
    // ============================================

    await fetchData();
});
