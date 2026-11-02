// csv-import.js - CSV Import Module for Pelanggan
import { supabase } from './supabase-client.js';

export function initializeCSVImport(fetchDataCallback) {
    // DOM Elements
    const importBtn = document.getElementById('import-csv-btn');
    const modal = document.getElementById('csv-import-modal');
    const closeBtn = document.getElementById('close-csv-modal');
    const cancelBtn = document.getElementById('cancel-import-btn');
    const downloadTemplateBtn = document.getElementById('download-template-btn');
    const uploadArea = document.getElementById('upload-area');
    const fileInput = document.getElementById('csv-file-input');
    const previewSection = document.getElementById('csv-preview-section');
    const previewTable = document.getElementById('csv-preview-table');
    const rowCountSpan = document.getElementById('csv-row-count');
    const startImportBtn = document.getElementById('start-import-btn');
    const progressSection = document.getElementById('import-progress-section');
    const progressBar = document.getElementById('progress-bar');
    const progressText = document.getElementById('progress-text');
    const summarySection = document.getElementById('import-summary-section');
    const successCount = document.getElementById('success-count');
    const failedCount = document.getElementById('failed-count');
    const errorDetails = document.getElementById('error-details');

    let parsedData = [];

    // Event Listeners
    importBtn?.addEventListener('click', openModal);
    closeBtn?.addEventListener('click', closeModal);
    cancelBtn?.addEventListener('click', closeModal);
    downloadTemplateBtn?.addEventListener('click', downloadTemplate);
    // File input change listener - label handles the click (mobile-friendly)
    fileInput?.addEventListener('change', handleFileSelect);
    startImportBtn?.addEventListener('click', startImport);

    // Drag & Drop (Desktop only)
    uploadArea?.addEventListener('dragover', (e) => {
        e.preventDefault();
        uploadArea.classList.add('border-[#FF6B2B]', 'bg-orange-50');
    });

    uploadArea?.addEventListener('dragleave', () => {
        uploadArea.classList.remove('border-[#FF6B2B]', 'bg-orange-50');
    });

    uploadArea?.addEventListener('drop', (e) => {
        e.preventDefault();
        uploadArea.classList.remove('border-[#FF6B2B]', 'bg-orange-50');
        const files = e.dataTransfer.files;

        if (files.length > 0) {
            const file = files[0];
            // Check both filename extension and MIME type
            const isCSV = file.name.toLowerCase().endsWith('.csv') ||
                file.type === 'text/csv' ||
                file.type === 'application/csv' ||
                file.type === 'text/comma-separated-values' ||
                file.type === 'text/plain';

            if (isCSV) {
                handleFile(file);
            } else {
                alert('Hanya file CSV yang diizinkan');
            }
        }
    });

    function openModal() {
        modal.classList.remove('hidden');
        resetModal();
    }

    function closeModal() {
        modal.classList.add('hidden');
        resetModal();
    }

    function resetModal() {
        fileInput.value = '';
        parsedData = [];
        previewSection.classList.add('hidden');
        progressSection.classList.add('hidden');
        summarySection.classList.add('hidden');
        startImportBtn.disabled = true;
        uploadArea.classList.remove('hidden');
    }

    async function downloadTemplate() {
        try {
            const res = await fetch('template_import_pelanggan.csv?t=' + Date.now());
            if (res.ok) {
                const text = await res.text();
                const blob = new Blob(['\uFEFF' + text], { type: 'text/csv;charset=utf-8;' });
                const link = document.createElement('a');
                link.href = URL.createObjectURL(blob);
                link.download = 'template_import_pelanggan.csv';
                link.click();
                return;
            }
        } catch (e) {
            console.warn('Direct fetch template failed, falling back to local generator', e);
        }

        const headers = [
            'full_name', 'whatsapp_number', 'address', 'amount',
            'installation_date', 'device_type', 'ip_static_pppoe',
            'email', 'password'
        ];

        const sampleData = [
            [
                'Budi Santoso', '08123456789', 'Jl. Merdeka No 1 RT 02 RW 03 Bandung', '150000',
                '2024-01-15', 'ONT ZTE F609', '192.168.1.100', '', ''
            ],
            [
                'Siti Aminah', '08198765432', 'Jl. Sudirman No 25 RT 01 RW 02 Jakarta', '150000',
                '2024-03-20', 'ONT Huawei HG8245H', '192.168.1.101', '', ''
            ],
            [
                'Ahmad Wijaya', '08111222333', 'Jl. Asia Afrika No 3 RT 05 RW 01 Surabaya', '150000',
                '2023-12-01', 'Router Mikrotik RB750', '', '', ''
            ],
            [
                'Rina Suryani', '08567891234', 'Jl. Gatot Subroto No 12 RT 03 RW 04 Semarang', '200000',
                '2024-02-10', 'ONT ZTE F660', '192.168.1.102', '', ''
            ],
            [
                'Dedi Kurniawan', '08234567890', 'Jl. Diponegoro No 88 RT 02 RW 01 Yogyakarta', '150000',
                '2023-11-05', 'ONT Fiberhome AN5506', '192.168.1.103', '', ''
            ]
        ];

        const csvContent = [
            headers.join(','),
            ...sampleData.map(row => row.map(v => v.includes(',') ? `"${v}"` : v).join(','))
        ].join('\n');

        const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = 'template_import_pelanggan.csv';
        link.click();
    }

    function handleFileSelect(event) {
        const file = event.target.files[0];
        if (!file) return;

        // Check both filename extension and MIME type for mobile compatibility
        const isCSV = file.name.toLowerCase().endsWith('.csv') ||
            file.type === 'text/csv' ||
            file.type === 'application/csv' ||
            file.type === 'text/comma-separated-values' ||
            file.type === 'text/plain';

        if (isCSV) {
            handleFile(file);
        } else {
            alert('Hanya file CSV yang diizinkan');
        }
    }

    function handleFile(file) {
        Papa.parse(file, {
            header: true,
            skipEmptyLines: true,
            complete: (results) => {
                if (results.data.length === 0) {
                    alert('File CSV kosong');
                    return;
                }

                if (results.data.length > 500) {
                    alert('Maksimal 500 baris per upload');
                    return;
                }

                parsedData = results.data;
                displayPreview(results.data);
                uploadArea.classList.add('hidden');
                startImportBtn.disabled = false;
            },
            error: (error) => {
                alert('Error parsing CSV: ' + error.message);
            }
        });
    }

    function displayPreview(data) {
        const headers = Object.keys(data[0]);
        const previewData = data.slice(0, 5); // Show first 5 rows

        let tableHTML = '<thead class="bg-gray-50"><tr>';
        headers.forEach(header => {
            tableHTML += `<th class="px-4 py-2 text-left text-xs font-semibold text-gray-700 border-b">${header}</th>`;
        });
        tableHTML += '</tr></thead><tbody>';

        previewData.forEach((row, index) => {
            tableHTML += `<tr class="${index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}">`;
            headers.forEach(header => {
                const value = row[header] || '-';
                tableHTML += `<td class="px-4 py-2 text-xs text-gray-600 border-b">${value}</td>`;
            });
            tableHTML += '</tr>';
        });

        tableHTML += '</tbody>';
        previewTable.innerHTML = tableHTML;
        rowCountSpan.textContent = `${data.length} baris data`;
        previewSection.classList.remove('hidden');
    }

    async function startImport() {
        if (!parsedData || parsedData.length === 0) {
            alert('Tidak ada data untuk diimport');
            return;
        }

        // Validate data
        const { valid, errors } = validateCSVData(parsedData);
        if (!valid) {
            alert('Data tidak valid:\n' + errors.join('\n'));
            return;
        }

        // Fetch available packages for automatic package detection
        let dbPackages = [];
        try {
            const { data: pkgData, error: pkgError } = await supabase
                .from('packages')
                .select('id, package_name, price');
            if (pkgError) throw pkgError;
            dbPackages = pkgData || [];
        } catch (err) {
            console.error('Error fetching packages for import:', err);
        }

        if (dbPackages.length === 0) {
            alert('Peringatan: Belum ada paket internet yang dibuat di menu Paket. Silakan tambahkan minimal satu paket terlebih dahulu agar pelanggan dapat dikaitkan.');
            return;
        }

        // Hide preview, show progress
        previewSection.classList.add('hidden');
        progressSection.classList.remove('hidden');
        startImportBtn.disabled = true;
        cancelBtn.disabled = true;

        // Pre-generate all IDPLs (Format 5 karakter: 2 Huruf + 3 Angka, contoh: UD417)
        const idpls = [];
        const existingSet = new Set();
        try {
            const { data: profiles, error: fetchError } = await supabase
                .from('profiles')
                .select('idpl');

            if (!fetchError && profiles) {
                profiles.forEach(p => { if (p.idpl) existingSet.add(p.idpl); });
            }
        } catch (error) {
            console.warn('Error fetching existing IDPLs for CSV import:', error);
        }

        const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        const getRandomCode = () => {
            const l1 = letters.charAt(Math.floor(Math.random() * letters.length));
            const l2 = letters.charAt(Math.floor(Math.random() * letters.length));
            const num = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
            return `${l1}${l2}${num}`;
        };

        for (let i = 0; i < parsedData.length; i++) {
            let candidate = getRandomCode();
            let attempts = 0;
            while (existingSet.has(candidate) && attempts < 100) {
                candidate = getRandomCode();
                attempts++;
            }
            existingSet.add(candidate);
            idpls.push(candidate);
        }

        let successfulImports = 0;
        let failedImports = 0;
        const errorMessages = [];

        for (let i = 0; i < parsedData.length; i++) {
            const row = parsedData[i];
            const rowNumber = i + 2; // +2 because row 1 is header, and we're 0-indexed
            const idpl = idpls[i];

            try {
                const packageId = resolvePackageId(row, dbPackages);
                if (!packageId) {
                    throw new Error('Tidak dapat menemukan paket yang sesuai dengan harga ' + row.amount);
                }
                await importSingleCustomer(row, rowNumber, idpl, packageId);
                successfulImports++;
            } catch (error) {
                failedImports++;
                errorMessages.push(`Baris ${rowNumber}: ${error.message}`);
            }

            // Update progress
            const progress = ((i + 1) / parsedData.length) * 100;
            progressBar.style.width = `${progress}%`;
            progressText.textContent = `${i + 1}/${parsedData.length}`;

            // Small delay to prevent rate limiting
            await new Promise(resolve => setTimeout(resolve, 100));
        }

        // Show summary
        progressSection.classList.add('hidden');
        summarySection.classList.remove('hidden');
        successCount.textContent = successfulImports;
        failedCount.textContent = failedImports;

        if (failedImports > 0) {
            errorDetails.innerHTML = errorMessages.join('<br>');
            errorDetails.classList.remove('hidden');
        }

        cancelBtn.disabled = false;
        cancelBtn.textContent = 'Tutup';

        // Refresh customer list
        if (successfulImports > 0 && fetchDataCallback) {
            await fetchDataCallback();
        }
    }


    function resolvePackageId(row, dbPackages) {
        if (row.package_id && !isNaN(parseInt(row.package_id))) {
            const found = dbPackages.find(p => p.id === parseInt(row.package_id));
            if (found) return found.id;
        }
        const rowAmount = parseFloat(row.amount);
        if (!isNaN(rowAmount)) {
            const foundByPrice = dbPackages.find(p => Math.abs(parseFloat(p.price) - rowAmount) < 0.01);
            if (foundByPrice) return foundByPrice.id;
        }
        if (row.package_name) {
            const cleanName = String(row.package_name).trim().toLowerCase();
            const foundByName = dbPackages.find(p => p.package_name && p.package_name.trim().toLowerCase() === cleanName);
            if (foundByName) return foundByName.id;
        }
        return dbPackages.length > 0 ? dbPackages[0].id : null;
    }

    function validateCSVData(data) {
        const errors = [];
        const requiredFields = ['full_name', 'address', 'whatsapp_number', 'amount'];

        data.forEach((row, index) => {
            const rowNumber = index + 2;

            // Check required fields
            requiredFields.forEach(field => {
                if (!row[field] || String(row[field]).trim() === '') {
                    errors.push(`Baris ${rowNumber}: Field ${field} wajib diisi`);
                }
            });

            // Validate amount (harga tagihan)
            if (row.amount && (isNaN(parseFloat(row.amount)) || parseFloat(row.amount) <= 0)) {
                errors.push(`Baris ${rowNumber}: amount (tagihan) harus berupa angka positif`);
            }

            // Validate optional email if provided
            if (row.email && row.email.trim() !== '' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(row.email.trim())) {
                errors.push(`Baris ${rowNumber}: Format email tidak valid`);
            }

            // Validate optional password if provided
            if (row.password && row.password.trim() !== '' && row.password.trim().length < 6) {
                errors.push(`Baris ${rowNumber}: Password minimal 6 karakter`);
            }

            // Validate optional installation_date format
            if (row.installation_date && row.installation_date.trim() !== '') {
                const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
                if (!dateRegex.test(row.installation_date.trim())) {
                    errors.push(`Baris ${rowNumber}: Format tanggal instalasi salah (gunakan YYYY-MM-DD)`);
                }
            }

            // Validate latitude/longitude if provided
            if (row.latitude && row.latitude.trim() !== '' && isNaN(parseFloat(row.latitude))) {
                errors.push(`Baris ${rowNumber}: Latitude harus berupa angka`);
            }

            if (row.longitude && row.longitude.trim() !== '' && isNaN(parseFloat(row.longitude))) {
                errors.push(`Baris ${rowNumber}: Longitude harus berupa angka`);
            }
        });

        return {
            valid: errors.length === 0,
            errors: errors.slice(0, 10)
        };
    }

    async function importSingleCustomer(row, rowNumber, idpl, packageId) {
        // Auto-generate email if blank: idpl@wifi.id
        const finalEmail = (row.email && row.email.trim())
            ? row.email.trim().toLowerCase()
            : `${idpl.toLowerCase()}@wifi.id`;

        // Auto-generate password if blank: 123456
        const finalPassword = (row.password && row.password.trim().length >= 6)
            ? row.password.trim()
            : '123456';

        // Auto status: AKTIF (default) or NONAKTIF
        const finalStatus = (row.status && row.status.trim().toUpperCase() === 'NONAKTIF')
            ? 'NONAKTIF'
            : 'AKTIF';

        // Prepare installation_date
        let installationDate = row.installation_date?.trim();
        if (installationDate) {
            const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
            if (!dateRegex.test(installationDate)) {
                installationDate = new Date().toISOString();
            } else {
                installationDate = new Date(installationDate).toISOString();
            }
        } else {
            installationDate = new Date().toISOString();
        }

        // Prepare location data
        const latitude = row.latitude?.trim() ? parseFloat(row.latitude) : null;
        const longitude = row.longitude?.trim() ? parseFloat(row.longitude) : null;

        const customerData = {
            email: finalEmail,
            password: finalPassword,
            full_name: row.full_name.trim(),
            address: row.address.trim(),
            whatsapp_number: row.whatsapp_number.trim(),
            gender: 'LAKI-LAKI',
            status: finalStatus,
            device_type: row.device_type?.trim() || null,
            ip_static_pppoe: row.ip_static_pppoe?.trim() || null,
            photo_url: 'assets/avatar_male.svg',
            installation_date: installationDate,
            package_id: packageId,
            amount: parseFloat(row.amount),
            latitude: latitude,
            longitude: longitude,
            idpl: idpl
        };

        console.log(`[CSV Import] Row ${rowNumber} data (IDPL: ${idpl}):`, customerData);

        const { data, error } = await supabase.functions.invoke('create-customer', {
            body: customerData
        });

        console.log(`[CSV Import] Row ${rowNumber} response:`, { data, error });

        if (error) {
            // Extract more detailed error message
            console.error(`[CSV Import] Row ${rowNumber} error details:`, error);
            console.error(`[CSV Import] Full error object:`, JSON.stringify(error, null, 2));

            let errorMsg = 'Gagal menambahkan pelanggan';
            if (error.message) {
                errorMsg = error.message;
            }
            if (error.context) {
                try {
                    let errorBody;
                    if (typeof error.context.json === 'function') {
                        errorBody = await error.context.json();
                    } else if (error.context.body) {
                        errorBody = typeof error.context.body === 'string'
                            ? JSON.parse(error.context.body)
                            : JSON.parse(await new Response(error.context.body).text());
                    }

                    if (errorBody && errorBody.error) {
                        errorMsg = errorBody.error;
                    }
                } catch (e) {
                    console.error('Failed to parse error body:', e);
                }
            }

            // The caller handles error message logging

            throw new Error(errorMsg);
        }

        if (data && data.error) {
            console.error(`[CSV Import] Row ${rowNumber} data error:`, data.error);
            throw new Error(data.error);
        }

        return data;
    }
}
