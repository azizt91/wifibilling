/**
 * Receipt Printer Module (Struk Pembayaran Internet)
 * Mendukung:
 * 1. Cetak Biasa / PC / USB / Driver Printer (Menggunakan window.print dengan template struk thermal)
 * 2. Cetak Langsung via Bluetooth Thermal Printer (ESC/POS via Web Bluetooth API)
 * 3. Dua Pilihan Ukuran Kertas: 58mm (Printer Mini / Mobile) & 80mm (Printer Kasir Lebar)
 * 4. Salin Teks Format WhatsApp / Berbagi
 */

import { supabase } from './supabase-client.js';

class ReceiptPrinter {
    constructor() {
        this.paperWidth = localStorage.getItem('receipt_paper_width') || '58mm'; // '58mm' | '80mm'
        this.currentInvoice = null;
        this.bluetoothDevice = null;
        this.bluetoothCharacteristic = null;
        this.appSettings = null;
        this.init();
    }

    async init() {
        // Ambil settings dari window atau Supabase
        if (window.APP_SETTINGS) {
            this.appSettings = window.APP_SETTINGS;
        } else {
            try {
                const { data } = await supabase.from('app_settings').select('*').limit(1).maybeSingle();
                this.appSettings = data || {};
            } catch (err) {
                console.warn('Gagal memuat app_settings untuk struk:', err);
                this.appSettings = {};
            }
        }

        // Ambil nama tenant dari tabel tenants jika app_name belum ada atau default
        if (!this.appSettings?.app_name || this.appSettings.app_name === 'WiFi Billing System') {
            try {
                const { data: tenant } = await supabase.from('tenants').select('name').limit(1).maybeSingle();
                if (tenant?.name && tenant.name.trim()) {
                    if (!this.appSettings) this.appSettings = {};
                    this.appSettings.app_name = tenant.name.trim();
                }
            } catch (tErr) {
                console.warn('Gagal memuat nama tenant:', tErr);
            }
        }

        // Ambil custom footer dari whatsapp_settings jika ada
        try {
            const { data: footerRow } = await supabase
                .from('whatsapp_settings')
                .select('setting_value')
                .eq('setting_key', 'receipt_footer')
                .maybeSingle();
            if (footerRow?.setting_value && footerRow.setting_value.trim()) {
                this.receiptFooter = footerRow.setting_value.trim();
                localStorage.setItem('receipt_footer', this.receiptFooter);
            }
        } catch (fErr) {
            console.warn('Gagal memuat receipt_footer:', fErr);
        }
    }

    /**
     * Membuka Modal Preview Struk
     * @param {Object} invoiceData - Data tagihan dari Supabase
     */
    async openReceipt(invoiceData) {
        if (!invoiceData) {
            alert('Data tagihan tidak valid');
            return;
        }

        this.currentInvoice = invoiceData;
        if (!this.appSettings) {
            await this.init();
        }

        this.renderModal();
    }

    /**
     * Helper formatting mata uang Rupiah
     */
    formatRupiah(amount) {
        return new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        }).format(amount || 0);
    }

    /**
     * Helper formatting tanggal & waktu
     */
    formatDateTime(dateStr) {
        const d = dateStr ? new Date(dateStr) : new Date();
        return d.toLocaleDateString('id-ID', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    /**
     * Data olahan untuk dicetak
     */
    getReceiptData() {
        const inv = this.currentInvoice;
        const app = this.appSettings || {};

        let appName = app.app_name;
        if (!appName || appName === 'WiFi Billing System') {
            const cachedSettings = localStorage.getItem('app_settings');
            if (cachedSettings) {
                try {
                    const parsed = JSON.parse(cachedSettings);
                    if (parsed.app_name && parsed.app_name !== 'WiFi Billing System') {
                        appName = parsed.app_name;
                    }
                } catch (e) {}
            }
        }
        appName = appName || 'WiFi Billing System';

        const appAddress = app.office_address || app.offline_payment_address || 'Layanan Internet Cepat & Stabil';
        const appPhone = app.whatsapp_number || '-';

        const customerName = inv.profiles?.full_name || 'Pelanggan';
        const customerId = inv.profiles?.idpl || inv.customer_id || '-';
        const customerPhone = inv.profiles?.whatsapp_number || '-';
        const period = inv.invoice_period || '-';

        const totalDue = Number(inv.total_due || inv.amount || 0);
        const amountPaid = Number(inv.amount_paid || (inv.status === 'paid' ? totalDue : 0));
        const remaining = Math.max(0, totalDue - amountPaid);

        // Status penentuan matematis yang akurat
        const statusLower = (inv.status || '').toLowerCase().trim();
        let statusText = 'BELUM BAYAR';
        if (statusLower === 'paid' || statusLower === 'lunas' || (amountPaid >= totalDue && totalDue > 0)) {
            statusText = 'LUNAS';
        } else if (statusLower === 'partially_paid' || statusLower === 'installment' || statusLower === 'cicilan' || (amountPaid > 0 && amountPaid < totalDue)) {
            statusText = 'CICILAN';
        }

        const footerText = this.receiptFooter || 
            localStorage.getItem('receipt_footer') || 
            'Terima kasih atas pembayaran Anda.\nSimpan struk ini sebagai bukti pembayaran sah.';

        const paymentMethod = inv.payment_method ? inv.payment_method.toUpperCase() : 'TUNAI';
        const paidAt = this.formatDateTime(inv.paid_at || inv.last_payment_date || new Date());
        const noInvoice = (inv.id || '').substring(0, 8).toUpperCase();

        return {
            appName,
            appAddress,
            appPhone,
            noInvoice,
            paidAt,
            customerName,
            customerId,
            customerPhone,
            period,
            totalDue,
            amountPaid,
            remaining,
            statusText,
            paymentMethod,
            footerText,
            rawInvoice: inv
        };
    }

    /**
     * Render Modal Preview Struk di Layar
     */
    renderModal() {
        const existing = document.getElementById('receipt-printer-modal');
        if (existing) existing.remove();

        const data = this.getReceiptData();
        const is58 = this.paperWidth === '58mm';

        const modal = document.createElement('div');
        modal.id = 'receipt-printer-modal';
        modal.className = 'receipt-modal-overlay';
        modal.innerHTML = `
            <style>
                .receipt-modal-overlay {
                    position: fixed;
                    inset: 0;
                    background: rgba(15, 23, 42, 0.75);
                    backdrop-filter: blur(4px);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 9999;
                    padding: 16px;
                    overflow-y: auto;
                    font-family: 'Manrope', -apple-system, BlinkMacSystemFont, sans-serif;
                }
                .receipt-modal-card {
                    background: #ffffff;
                    border-radius: 20px;
                    width: 100%;
                    max-width: 440px;
                    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                    display: flex;
                    flex-direction: column;
                    overflow: hidden;
                    max-height: 94vh;
                    animation: popIn 0.2s cubic-bezier(0.16, 1, 0.3, 1);
                }
                @keyframes popIn {
                    from { transform: scale(0.95); opacity: 0; }
                    to { transform: scale(1); opacity: 1; }
                }
                .receipt-paper-container {
                    background: #e2e8f0;
                    padding: 20px 16px 24px 16px;
                    overflow-y: auto;
                    display: flex;
                    justify-content: center;
                    align-items: flex-start;
                    max-height: 62vh;
                }
                /* Tampilan Realistis Kertas Struk Thermal */
                .thermal-paper {
                    background: #ffffff;
                    color: #111827;
                    font-family: 'Courier New', Courier, monospace;
                    padding: 16px 14px 20px 14px;
                    box-shadow: 0 6px 24px rgba(0, 0, 0, 0.15);
                    position: relative;
                    border-radius: 2px;
                    height: auto;
                    min-height: fit-content;
                    align-self: flex-start;
                    margin: 8px auto;
                    transition: width 0.25s ease;
                }
                .thermal-paper.width-58 {
                    width: 270px;
                    font-size: 11.5px;
                    line-height: 1.35;
                }
                .thermal-paper.width-80 {
                    width: 350px;
                    font-size: 12.5px;
                    line-height: 1.4;
                }
                .thermal-paper::before, .thermal-paper::after {
                    content: "";
                    position: absolute;
                    left: 0;
                    right: 0;
                    height: 6px;
                    background-size: 10px 10px;
                }
                .thermal-paper::before {
                    top: -6px;
                    background-image: radial-gradient(circle at 5px 6px, transparent 4px, #ffffff 5px);
                }
                .thermal-paper::after {
                    bottom: -6px;
                    background-image: radial-gradient(circle at 5px 0px, transparent 4px, #ffffff 5px);
                }
                .thermal-divider {
                    border-top: 1px dashed #6b7280;
                    margin: 8px 0;
                }
                .thermal-double-divider {
                    border-top: 1px double #111827;
                    border-bottom: 1px double #111827;
                    height: 3px;
                    margin: 8px 0;
                }
                .thermal-row {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 2px;
                }
                .thermal-row .lbl {
                    color: #374151;
                }
                .thermal-row .val {
                    text-align: right;
                    font-weight: 600;
                    color: #000;
                    word-break: break-word;
                }
            </style>

            <div class="receipt-modal-card">
                <!-- Header Modal -->
                <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between bg-white">
                    <div>
                        <h3 class="font-bold text-gray-800 text-lg flex items-center gap-2">
                            <span>🧾 Cetak Struk Pembayaran</span>
                        </h3>
                        <p class="text-xs text-gray-500 mt-0.5">Pilih ukuran & cara mencetak struk</p>
                    </div>
                    <button id="btn-close-receipt-modal" class="text-gray-400 hover:text-gray-700 w-8 h-8 rounded-full hover:bg-gray-100 flex items-center justify-center text-xl transition-colors">
                        &times;
                    </button>
                </div>

                <!-- Toggle Ukuran Kertas 58mm / 80mm -->
                <div class="px-5 py-3 bg-gray-50 border-b border-gray-200/70">
                    <div class="flex items-center justify-between">
                        <span class="text-xs font-semibold text-gray-600">Ukuran Kertas Printer:</span>
                        <div class="inline-flex bg-gray-200/80 p-0.5 rounded-lg text-xs font-medium">
                            <button id="btn-opt-58mm" class="px-3 py-1.5 rounded-md transition-all ${is58 ? 'bg-white text-indigo-700 shadow-sm font-bold' : 'text-gray-600 hover:text-gray-900'}">
                                58 mm (Mini/Portable)
                            </button>
                            <button id="btn-opt-80mm" class="px-3 py-1.5 rounded-md transition-all ${!is58 ? 'bg-white text-indigo-700 shadow-sm font-bold' : 'text-gray-600 hover:text-gray-900'}">
                                80 mm (Standar POS)
                            </button>
                        </div>
                    </div>
                    <p class="text-[11px] text-gray-500 mt-1.5">
                        💡 <em>58mm pas untuk printer thermal Bluetooth / saku. 80mm untuk printer kasir meja.</em>
                    </p>
                </div>

                <!-- Preview Area Kertas Struk -->
                <div class="receipt-paper-container">
                    <div id="thermal-receipt-preview" class="thermal-paper ${is58 ? 'width-58' : 'width-80'}">
                        <!-- Header Usaha -->
                        <div style="text-align: center;">
                            <div style="font-size: 15px; font-weight: bold; letter-spacing: 0.5px;">${data.appName}</div>
                            <div style="font-size: 10px; color: #4b5563; margin-top: 2px;">${data.appAddress}</div>
                            <div style="font-size: 10px; color: #4b5563;">WA/CS: ${data.appPhone}</div>
                        </div>

                        <div class="thermal-divider"></div>

                        <!-- Judul & No Nota -->
                        <div style="text-align: center; font-weight: bold; font-size: 11px; margin-bottom: 2px;">
                            BUKTI PEMBAYARAN INTERNET
                        </div>
                        <div style="text-align: center; font-size: 10px; color: #4b5563; margin-bottom: 4px;">
                            No: #${data.noInvoice}
                        </div>

                        <div style="text-align: center; margin: 6px 0;">
                            <span style="border: 1px solid #111827; padding: 2px 10px; font-weight: bold; font-size: 12px; letter-spacing: 1px;">
                                *** ${data.statusText} ***
                            </span>
                        </div>

                        <div class="thermal-divider"></div>

                        <!-- Data Transaksi -->
                        <div class="thermal-row">
                            <span class="lbl">Waktu:</span>
                            <span class="val">${data.paidAt}</span>
                        </div>
                        <div class="thermal-row">
                            <span class="lbl">ID Pelanggan:</span>
                            <span class="val">${data.customerId}</span>
                        </div>
                        <div class="thermal-row">
                            <span class="lbl">Nama:</span>
                            <span class="val">${data.customerName}</span>
                        </div>
                        <div class="thermal-row">
                            <span class="lbl">Periode:</span>
                            <span class="val">${data.period}</span>
                        </div>
                        <div class="thermal-row">
                            <span class="lbl">Metode:</span>
                            <span class="val">${data.paymentMethod}</span>
                        </div>

                        <div class="thermal-divider"></div>

                        <!-- Rincian Biaya -->
                        <div class="thermal-row">
                            <span class="lbl">Total Tagihan:</span>
                            <span class="val">${this.formatRupiah(data.totalDue)}</span>
                        </div>
                        <div class="thermal-row" style="font-weight: bold;">
                            <span class="lbl" style="font-weight: bold; color: #000;">Jumlah Dibayar:</span>
                            <span class="val" style="font-size: 13px;">${this.formatRupiah(data.amountPaid)}</span>
                        </div>
                        ${data.remaining > 0 ? `
                        <div class="thermal-row" style="color: #b91c1c;">
                            <span class="lbl" style="color: #b91c1c;">Sisa Tagihan:</span>
                            <span class="val" style="color: #b91c1c;">${this.formatRupiah(data.remaining)}</span>
                        </div>
                        ` : ''}

                        <div class="thermal-double-divider"></div>

                        <!-- Footer -->
                        <div style="text-align: center; font-size: 10px; color: #4b5563; margin-top: 6px;">
                            ${data.footerText.split('\n').filter(l => l.trim()).map(l => `<div style="margin-top: 1px;">${l.trim()}</div>`).join('')}
                            <div style="margin-top: 4px; font-weight: bold; color: #111;">${data.appName}</div>
                        </div>
                    </div>
                </div>

                <!-- Tombol Aksi Cetak -->
                <div class="p-4 bg-white border-t border-gray-100 flex flex-col gap-2.5">
                    <div class="grid grid-cols-2 gap-2.5">
                        <!-- Tombol Cetak PC / Standar -->
                        <button id="btn-print-standard" class="flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 active:scale-[0.98] text-white py-2.5 px-3 rounded-xl font-semibold text-xs shadow-md shadow-indigo-200 transition-all">
                            <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                            </svg>
                            <span>Cetak PC / Driver</span>
                        </button>

                        <!-- Tombol Cetak Bluetooth -->
                        <button id="btn-print-bluetooth" class="flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 active:scale-[0.98] text-white py-2.5 px-3 rounded-xl font-semibold text-xs shadow-md shadow-blue-200 transition-all">
                            <svg class="w-4 h-4 shrink-0" fill="currentColor" viewBox="0 0 24 24">
                                <path d="M14.88 16.29L13 18.17V14.41L14.88 16.29M13 5.83L14.88 7.71L13 9.59V5.83M17.71 7.71L12 2H11V9.58L6.41 5L5 6.41L10.59 12L5 17.58L6.41 19L11 14.41V22H12L17.71 16.29L13.41 12L17.71 7.71Z"/>
                            </svg>
                            <span>Cetak Bluetooth</span>
                        </button>
                    </div>

                    <!-- Tombol Salin Teks Format WhatsApp -->
                    <button id="btn-copy-receipt-text" class="w-full flex items-center justify-center gap-2 bg-gray-100 hover:bg-gray-200 text-gray-700 py-2 px-3 rounded-xl font-medium text-xs transition-colors">
                        <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/>
                        </svg>
                        <span>Salin Teks Nota (Untuk WA)</span>
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Event listener ukuran kertas
        const btn58 = document.getElementById('btn-opt-58mm');
        const btn80 = document.getElementById('btn-opt-80mm');
        const preview = document.getElementById('thermal-receipt-preview');

        btn58.addEventListener('click', () => {
            this.paperWidth = '58mm';
            localStorage.setItem('receipt_paper_width', '58mm');
            preview.className = 'thermal-paper width-58';
            btn58.className = 'px-3 py-1.5 rounded-md transition-all bg-white text-indigo-700 shadow-sm font-bold';
            btn80.className = 'px-3 py-1.5 rounded-md transition-all text-gray-600 hover:text-gray-900';
        });

        btn80.addEventListener('click', () => {
            this.paperWidth = '80mm';
            localStorage.setItem('receipt_paper_width', '80mm');
            preview.className = 'thermal-paper width-80';
            btn80.className = 'px-3 py-1.5 rounded-md transition-all bg-white text-indigo-700 shadow-sm font-bold';
            btn58.className = 'px-3 py-1.5 rounded-md transition-all text-gray-600 hover:text-gray-900';
        });

        // Close handlers
        document.getElementById('btn-close-receipt-modal').addEventListener('click', () => modal.remove());
        modal.addEventListener('click', (e) => {
            if (e.target === modal) modal.remove();
        });

        // Print handlers
        document.getElementById('btn-print-standard').addEventListener('click', () => this.printStandard());
        document.getElementById('btn-print-bluetooth').addEventListener('click', () => this.printBluetooth());
        document.getElementById('btn-copy-receipt-text').addEventListener('click', () => this.copyReceiptText());
    }

    /**
     * Metode 1: Cetak Standar PC / Driver / Browser window.print()
     * Menggunakan iframe terisolasi agar tampilan website tidak terganggu
     */
    printStandard() {
        const data = this.getReceiptData();
        const is58 = this.paperWidth === '58mm';
        const printWidth = is58 ? '48mm' : '72mm';
        const bodyWidth = is58 ? '58mm' : '80mm';

        // Buat iframe tersembunyi
        let iframe = document.getElementById('receipt-print-frame');
        if (iframe) iframe.remove();

        iframe = document.createElement('iframe');
        iframe.id = 'receipt-print-frame';
        iframe.style.position = 'fixed';
        iframe.style.right = '0';
        iframe.style.bottom = '0';
        iframe.style.width = '0';
        iframe.style.height = '0';
        iframe.style.border = 'none';
        document.body.appendChild(iframe);

        const htmlContent = `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Struk_${data.customerId}_${data.period}</title>
                <style>
                    @page {
                        margin: 0;
                        size: ${bodyWidth} auto;
                    }
                    * {
                        box-sizing: border-box;
                    }
                    body {
                        margin: 0 auto;
                        padding: ${is58 ? '2mm 3mm' : '4mm 5mm'};
                        width: ${bodyWidth};
                        font-family: 'Courier New', Courier, monospace;
                        font-size: ${is58 ? '11px' : '12px'};
                        color: #000;
                        background: #fff;
                        line-height: 1.3;
                    }
                    .text-center { text-align: center; }
                    .text-right { text-align: right; }
                    .bold { font-weight: bold; }
                    .title { font-size: ${is58 ? '13px' : '15px'}; font-weight: bold; }
                    .divider {
                        border-top: 1px dashed #000;
                        margin: 6px 0;
                    }
                    .double-divider {
                        border-top: 1px double #000;
                        border-bottom: 1px double #000;
                        height: 3px;
                        margin: 6px 0;
                    }
                    .row {
                        display: flex;
                        justify-content: space-between;
                        margin-bottom: 2px;
                    }
                    .row .lbl {
                        width: 45%;
                    }
                    .row .val {
                        width: 55%;
                        text-align: right;
                        word-break: break-word;
                    }
                    .badge {
                        display: inline-block;
                        border: 1px solid #000;
                        padding: 2px 6px;
                        margin: 4px 0;
                        font-weight: bold;
                    }
                </style>
            </head>
            <body>
                <div class="text-center">
                    <div class="title">${data.appName}</div>
                    <div style="font-size: 9.5px;">${data.appAddress}</div>
                    <div style="font-size: 9.5px;">WA/CS: ${data.appPhone}</div>
                </div>

                <div class="divider"></div>

                <div class="text-center bold" style="font-size: 10.5px;">BUKTI PEMBAYARAN INTERNET</div>
                <div class="text-center" style="font-size: 9.5px;">No: #${data.noInvoice}</div>

                <div class="text-center">
                    <span class="badge">*** ${data.statusText} ***</span>
                </div>

                <div class="divider"></div>

                <div class="row">
                    <span class="lbl">Waktu:</span>
                    <span class="val">${data.paidAt}</span>
                </div>
                <div class="row">
                    <span class="lbl">ID Pelanggan:</span>
                    <span class="val">${data.customerId}</span>
                </div>
                <div class="row">
                    <span class="lbl">Nama:</span>
                    <span class="val">${data.customerName}</span>
                </div>
                <div class="row">
                    <span class="lbl">Periode:</span>
                    <span class="val">${data.period}</span>
                </div>
                <div class="row">
                    <span class="lbl">Metode:</span>
                    <span class="val">${data.paymentMethod}</span>
                </div>

                <div class="divider"></div>

                <div class="row">
                    <span class="lbl">Total Tagihan:</span>
                    <span class="val">${this.formatRupiah(data.totalDue)}</span>
                </div>
                <div class="row bold">
                    <span class="lbl">Jumlah Dibayar:</span>
                    <span class="val" style="font-size: ${is58 ? '12px' : '13px'};">${this.formatRupiah(data.amountPaid)}</span>
                </div>
                ${data.remaining > 0 ? `
                <div class="row">
                    <span class="lbl">Sisa Tagihan:</span>
                    <span class="val">${this.formatRupiah(data.remaining)}</span>
                </div>
                ` : ''}

                <div class="double-divider"></div>

                <div class="text-center" style="font-size: 9.5px; margin-top: 6px;">
                    ${data.footerText.split('\n').filter(l => l.trim()).map(l => `<div style="margin-top: 1px;">${l.trim()}</div>`).join('')}
                    <div class="bold" style="margin-top: 3px;">${data.appName}</div>
                </div>
                <div style="height: 12mm;"></div>
            </body>
            </html>
        `;

        const doc = iframe.contentWindow.document;
        doc.open();
        doc.write(htmlContent);
        doc.close();

        setTimeout(() => {
            iframe.contentWindow.focus();
            iframe.contentWindow.print();
        }, 300);
    }

    /**
     * Metode 2: Cetak Langsung Thermal via Web Bluetooth API (ESC/POS)
     */
    async printBluetooth() {
        if (!navigator.bluetooth) {
            alert('Browser ini belum mendukung Web Bluetooth API.\n\nGunakan Google Chrome atau Microsoft Edge (di Android atau Windows/PC/Laptop), atau klik tombol "Cetak PC / Driver" sebagai gantinya.');
            return;
        }

        const btn = document.getElementById('btn-print-bluetooth');
        const origText = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = `
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>Menghubungkan...</span>
        `;

        try {
            // Minta user memilih printer bluetooth
            // Banyak printer thermal bluetooth menggunakan service generic/serial
            const device = await navigator.bluetooth.requestDevice({
                filters: [
                    { services: ['000018f0-0000-1000-8000-00805f9b34fb'] },
                    { services: ['e7810a71-73ae-499d-8c15-faa9aef0c3f2'] },
                    { services: ['49535343-fe7d-4ae5-8fa9-9fafd205e455'] },
                    { services: ['0000ffe0-0000-1000-8000-00805f9b34fb'] }
                ],
                optionalServices: [
                    '000018f0-0000-1000-8000-00805f9b34fb',
                    'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
                    '49535343-fe7d-4ae5-8fa9-9fafd205e455',
                    '0000ffe0-0000-1000-8000-00805f9b34fb'
                ]
            }).catch(async (err) => {
                // Fallback: tampilkan semua device jika filter spesifik tidak menemukan printer
                return await navigator.bluetooth.requestDevice({
                    acceptAllDevices: true,
                    optionalServices: [
                        '000018f0-0000-1000-8000-00805f9b34fb',
                        'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
                        '49535343-fe7d-4ae5-8fa9-9fafd205e455',
                        '0000ffe0-0000-1000-8000-00805f9b34fb'
                    ]
                });
            });

            if (!device) throw new Error('Perangkat Bluetooth dibatalkan');

            btn.innerHTML = `<span>Menyambungkan ke ${device.name || 'Printer'}...</span>`;
            const server = await device.gatt.connect();

            // Cari primary service yang aktif
            const services = await server.getPrimaryServices();
            let characteristic = null;

            for (const service of services) {
                const characteristics = await service.getCharacteristics();
                for (const c of characteristics) {
                    if (c.properties.write || c.properties.writeWithoutResponse) {
                        characteristic = c;
                        break;
                    }
                }
                if (characteristic) break;
            }

            if (!characteristic) {
                throw new Error('Tidak ditemukan saluran tulis (write characteristic) pada printer ini.');
            }

            btn.innerHTML = `<span>Mencetak Struk...</span>`;

            // Buat buffer ESC/POS
            const buffer = this.generateEscPosBuffer();

            // Kirim per chunk (512 bytes limit BLE MTU)
            const chunkSize = 100;
            for (let i = 0; i < buffer.length; i += chunkSize) {
                const chunk = buffer.slice(i, i + chunkSize);
                if (characteristic.properties.writeWithoutResponse) {
                    await characteristic.writeValueWithoutResponse(chunk);
                } else {
                    await characteristic.writeValue(chunk);
                }
                await new Promise(r => setTimeout(r, 20));
            }

            btn.className = 'flex items-center justify-center gap-2 bg-green-600 text-white py-2.5 px-3 rounded-xl font-semibold text-xs shadow-md';
            btn.innerHTML = `<span>✓ Berhasil Dicetak!</span>`;

            setTimeout(() => {
                btn.className = 'flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 active:scale-[0.98] text-white py-2.5 px-3 rounded-xl font-semibold text-xs shadow-md shadow-blue-200 transition-all';
                btn.innerHTML = origText;
                btn.disabled = false;
            }, 2500);

        } catch (error) {
            console.error('Bluetooth print error:', error);
            if (error.name !== 'NotFoundError') {
                alert(`Gagal mencetak via Bluetooth: ${error.message}\n\nTips: Anda juga bisa menggunakan tombol "Cetak PC / Driver" untuk mencetak ke printer bluetooth yang sudah dipasangkan (paired) di Windows / Android.`);
            }
            btn.innerHTML = origText;
            btn.disabled = false;
        }
    }

    /**
     * Generator Perintah ESC/POS Binary untuk Printer Thermal
     */
    generateEscPosBuffer() {
        const data = this.getReceiptData();
        const is58 = this.paperWidth === '58mm';
        const maxCols = is58 ? 32 : 48;

        const ESC = 0x1B;
        const GS = 0x1D;

        const bytes = [];
        const pushBytes = (...arr) => bytes.push(...arr);
        const pushText = (text) => {
            const encoder = new TextEncoder();
            const encoded = encoder.encode(text);
            for (let i = 0; i < encoded.length; i++) {
                bytes.push(encoded[i]);
            }
        };

        const pushLine = (text) => {
            pushText(text + '\n');
        };

        const pushRow = (left, right) => {
            const leftStr = String(left || '');
            const rightStr = String(right || '');
            const spaces = maxCols - leftStr.length - rightStr.length;
            if (spaces > 0) {
                pushLine(leftStr + ' '.repeat(spaces) + rightStr);
            } else {
                pushLine(leftStr);
                pushLine(' '.repeat(Math.max(0, maxCols - rightStr.length)) + rightStr);
            }
        };

        // 1. Inisialisasi Printer
        pushBytes(ESC, 0x40); // Reset

        // 2. Header (Tengah, Bold, Normal Size agar muat di kertas 58mm tanpa kata terpotong)
        pushBytes(ESC, 0x61, 0x01); // Center
        pushBytes(ESC, 0x45, 0x01); // Bold ON
        pushBytes(GS, 0x21, 0x00);  // Normal size (jangan double width pada 58mm agar teks tidak meluber)
        pushLine(data.appName.toUpperCase());
        pushBytes(ESC, 0x45, 0x00); // Bold OFF
        pushLine(data.appAddress);
        pushLine('WA/CS: ' + data.appPhone);

        // Divider
        pushLine('-'.repeat(maxCols));

        // Judul Struk
        pushBytes(ESC, 0x45, 0x01); // Bold
        pushLine('STRUK PEMBAYARAN TAGIHAN');
        pushBytes(ESC, 0x45, 0x00);
        pushLine('No: #' + data.noInvoice);
        pushLine('');
        pushBytes(ESC, 0x45, 0x01);
        pushLine(`*** ${data.statusText} ***`);
        pushBytes(ESC, 0x45, 0x00);

        pushLine('-'.repeat(maxCols));

        // Data Transaksi (Rata Kiri)
        pushBytes(ESC, 0x61, 0x00); // Left align
        pushRow('Waktu:', data.paidAt);
        pushRow('ID Pelanggan:', data.customerId);
        pushRow('Nama:', data.customerName);
        pushRow('Periode:', data.period);
        pushRow('Metode:', data.paymentMethod);

        pushLine('-'.repeat(maxCols));

        // Rincian Pembayaran
        pushRow('Total Tagihan:', this.formatRupiah(data.totalDue));
        pushBytes(ESC, 0x45, 0x01); // Bold
        pushRow('Jumlah Dibayar:', this.formatRupiah(data.amountPaid));
        pushBytes(ESC, 0x45, 0x00); // Bold OFF

        if (data.remaining > 0) {
            pushRow('Sisa Tagihan:', this.formatRupiah(data.remaining));
        }

        pushLine('='.repeat(maxCols));

        // Footer Dinamis
        pushBytes(ESC, 0x61, 0x01); // Center
        for (const line of data.footerText.split('\n')) {
            const clean = line.trim();
            if (clean) pushLine(clean);
        }
        pushBytes(ESC, 0x45, 0x01);
        pushLine(data.appName);
        pushBytes(ESC, 0x45, 0x00);

        // Feed paper
        pushBytes(0x0A, 0x0A, 0x0A, 0x0A);
        // Cut command (GS V 0)
        pushBytes(GS, 0x56, 0x00);

        return new Uint8Array(bytes);
    }

    /**
     * Salin Teks Format WhatsApp ke Clipboard
     */
    async copyReceiptText() {
        const data = this.getReceiptData();
        const text = 
`*🧾 ${data.appName}*
_${data.appAddress}_
_WA: ${data.appPhone}_
=============================
*STRUK PEMBAYARAN TAGIHAN*
No: #${data.noInvoice}
Status: *[ ${data.statusText} ]*
=============================
• Waktu: ${data.paidAt}
• ID Pelanggan: ${data.customerId}
• Nama: ${data.customerName}
• Periode: ${data.period}
• Metode: ${data.paymentMethod}
-----------------------------
• Total Tagihan : ${this.formatRupiah(data.totalDue)}
• Jumlah Dibayar: *${this.formatRupiah(data.amountPaid)}*
${data.remaining > 0 ? `• Sisa Tagihan  : ${this.formatRupiah(data.remaining)}\n` : ''}=============================
${data.footerText}`;

        try {
            await navigator.clipboard.writeText(text);
            const btn = document.getElementById('btn-copy-receipt-text');
            const orig = btn.innerHTML;
            btn.innerHTML = `<span class="text-green-600 font-bold">✓ Teks Struk Berhasil Disalin!</span>`;
            setTimeout(() => {
                btn.innerHTML = orig;
            }, 2000);
        } catch (e) {
            alert('Gagal menyalin teks otomatis. Silakan salin secara manual.');
        }
    }
}

// Singleton Instance
export const receiptPrinter = new ReceiptPrinter();
window.receiptPrinter = receiptPrinter;
