// Apply App Settings Module - Extended Version
// Auto-apply settings to ALL pages including login, customer pages, PWA

import { supabase } from './supabase-client.js';

class ApplySettings {
    constructor() {
        this.settings = null;
        this.init();
    }

    async init() {
        // 1. Try local settings immediately for zero-flicker loading
        const localSettings = this.getLocalSettings();
        if (localSettings) {
            this.settings = localSettings;
            this.applyAllSettings(localSettings);
        }

        // 2. Fetch fresh data from Supabase
        try {
            const freshSettings = await this.fetchSettingsFromDB();
            if (freshSettings) {
                this.settings = freshSettings;
                this.saveLocalSettings(freshSettings);
                this.applyAllSettings(freshSettings);
            } else if (!localSettings) {
                // Apply defaults if no settings exist in DB or localStorage
                this.applyAllSettings({});
            }
        } catch (error) {
            console.error('Error fetching settings from database:', error);
            if (!localSettings) {
                this.applyAllSettings({});
            }
        }
    }

    getTenantSlugFromUrl() {
        try {
            const params = new URLSearchParams(window.location.search);
            const slug = params.get('t') || params.get('tenant') || params.get('slug');
            if (slug && slug.trim()) {
                const clean = slug.trim().toLowerCase();
                sessionStorage.setItem('current_tenant_slug', clean);
                return clean;
            }
            return sessionStorage.getItem('current_tenant_slug') || null;
        } catch (e) {
            return null;
        }
    }

    async fetchSettingsFromDB() {
        // Cek apakah ada parameter slug tenant di URL (misal: index.html?t=apik atau index.html?t=selinggonet)
        let slug = this.getTenantSlugFromUrl();
        if (slug) {
            try {
                const { data: tenantBranding, error: rpcError } = await supabase
                    .rpc('get_tenant_branding_by_slug', { p_slug: slug });

                if (!rpcError && tenantBranding && tenantBranding.found) {
                    return tenantBranding;
                }
            } catch (rpcErr) {
                console.warn('[ApplySettings] Gagal memanggil get_tenant_branding_by_slug:', rpcErr);
            }
        }

        // Fallback: Jika tidak ada slug di URL, coba deteksi tenant dari sesi user yang sedang login
        try {
            const { data: { session } } = await supabase.auth.getSession();
            if (session?.user?.id) {
                const { data: profile } = await supabase
                    .from('profiles')
                    .select('tenant_id')
                    .eq('id', session.user.id)
                    .maybeSingle();

                if (profile?.tenant_id) {
                    const { data: tenant } = await supabase
                        .from('tenants')
                        .select('slug, name, branding')
                        .eq('id', profile.tenant_id)
                        .maybeSingle();

                    if (tenant) {
                        if (tenant.slug) {
                            sessionStorage.setItem('current_tenant_slug', tenant.slug);
                        }
                        const branding = tenant.branding || {};
                        return {
                            found: true,
                            app_name: branding.app_name || tenant.name,
                            app_short_name: branding.app_short_name || tenant.name,
                            logo_url: branding.logo_url || null,
                            theme_color: branding.theme_color || '#5324e0',
                            ...branding
                        };
                    }
                }
            }
        } catch (authErr) {
            // Abaikan jika belum login atau session gagal
        }

        try {
            const { data, error } = await supabase
                .from('app_settings')
                .select('*')
                .limit(1)
                .maybeSingle();

            if (error) {
                console.warn('Supabase app_settings fetch warning:', error.message);
                return null;
            }

            return data || null;
        } catch (error) {
            console.error('Error querying app_settings table:', error);
            return null;
        }
    }

    applyAllSettings(settings) {
        const safeSettings = settings || {};
        const appName = safeSettings.app_name || 'WiFi Billing System';

        // Apply to document head & meta tags
        this.applyTitle(appName);
        this.applyAppleMobileTitle(appName);
        this.applyPWAIcons(safeSettings);
        this.applyFavicon(safeSettings.favicon_url || safeSettings.icon_512_url);
        this.applyThemeColor(safeSettings.theme_color);
        this.applyManifest(safeSettings);

        // Apply to specific page elements (admin, login, register, customer pages)
        this.applyToAdminPages(safeSettings);
        this.applyToLoginPage(safeSettings);
        this.applyToCustomerPages(safeSettings);

        // Export globally for other JS scripts
        window.APP_SETTINGS = safeSettings;
    }

    applyTitle(appName) {
        const name = appName || 'WiFi Billing System';
        const currentPage = this.getCurrentPageName();
        document.title = currentPage ? `${currentPage} - ${name}` : name;
    }

    applyAppleMobileTitle(appName) {
        const name = appName || 'WiFi Billing System';
        let appleMeta = document.querySelector('meta[name="apple-mobile-web-app-title"]');
        if (appleMeta) {
            appleMeta.setAttribute('content', name);
        } else {
            appleMeta = document.createElement('meta');
            appleMeta.setAttribute('name', 'apple-mobile-web-app-title');
            appleMeta.setAttribute('content', name);
            document.head.appendChild(appleMeta);
        }
    }

    applyPWAIcons(settings) {
        const cb = '?v=3';
        const fallbackIcon = settings?.logo_url || 'assets/logo_wifi.png';
        const icon512 = (settings?.icon_512_url || fallbackIcon) + (settings?.icon_512_url ? '' : cb);
        const icon192 = (settings?.icon_192_url || fallbackIcon) + (settings?.icon_192_url ? '' : cb);

        // 512x512 PWA Icon
        let link512 = document.querySelector('link[sizes="512x512"]');
        if (link512) {
            link512.href = icon512;
        } else {
            link512 = document.createElement('link');
            link512.rel = 'icon';
            link512.type = 'image/png';
            link512.sizes = '512x512';
            link512.href = icon512;
            document.head.appendChild(link512);
        }

        // 192x192 PWA Icon / Apple touch icon
        let link192 = document.querySelector('link[sizes="192x192"]') || document.querySelector('link[rel="apple-touch-icon"]');
        if (link192) {
            link192.href = icon192;
        } else {
            link192 = document.createElement('link');
            link192.rel = 'apple-touch-icon';
            link192.sizes = '192x192';
            link192.href = icon192;
            document.head.appendChild(link192);
        }
    }

    applyFavicon(faviconUrl) {
        const url = faviconUrl || 'assets/logo_512x512.png';

        // Update all standard favicon links
        const faviconLinks = document.querySelectorAll('link[rel="shortcut icon"], link[rel="icon"]:not([sizes])');
        if (faviconLinks.length > 0) {
            faviconLinks.forEach(link => {
                link.href = url;
            });
        } else {
            const link = document.createElement('link');
            link.rel = 'shortcut icon';
            link.href = url;
            document.head.appendChild(link);
        }
    }

    applyThemeColor(themeColor) {
        if (!themeColor) return;

        let themeColorMeta = document.querySelector('meta[name="theme-color"]');
        if (themeColorMeta) {
            themeColorMeta.setAttribute('content', themeColor);
        } else {
            themeColorMeta = document.createElement('meta');
            themeColorMeta.setAttribute('name', 'theme-color');
            themeColorMeta.setAttribute('content', themeColor);
            document.head.appendChild(themeColorMeta);
        }
    }

    applyManifest(settings) {
        const appName = settings?.app_name || 'WiFi Billing System';
        const appShortName = settings?.app_short_name || appName;
        const appDesc = settings?.app_description || 'Sistem Manajemen Billing & Pelanggan';
        const slug = this.getTenantSlugFromUrl();
        const startUrl = slug ? `/?t=${encodeURIComponent(slug)}` : "/";
        const fallbackIcon = settings?.logo_url || "assets/logo_wifi.png";
        const icon192 = settings?.icon_192_url || fallbackIcon;
        const icon512 = settings?.icon_512_url || fallbackIcon;

        const manifestData = {
            name: appName,
            short_name: appShortName,
            description: appDesc,
            start_url: startUrl,
            display: "standalone",
            background_color: settings?.background_color || "#667eea",
            theme_color: settings?.theme_color || "#667eea",
            orientation: "portrait-primary",
            categories: ["business", "productivity"],
            lang: "id",
            dir: "ltr",
            scope: "/",
            icons: [
                {
                    src: icon192,
                    sizes: "192x192",
                    type: "image/png",
                    purpose: "any"
                },
                {
                    src: icon512,
                    sizes: "512x512",
                    type: "image/png",
                    purpose: "maskable"
                }
            ]
        };

        const manifestBlob = new Blob([JSON.stringify(manifestData)], {
            type: 'application/json'
        });
        const manifestURL = URL.createObjectURL(manifestBlob);

        let manifestLink = document.querySelector('link[rel="manifest"]');
        if (manifestLink) {
            manifestLink.href = manifestURL;
        }

        localStorage.setItem('pwa_manifest', JSON.stringify(manifestData));
    }

    applyToAdminPages(settings) {
        const appName = settings?.app_name || settings?.app_short_name || 'WiFi Billing';

        // 1. Update teks judul brand di desktop navbar ("WiFi Billing" -> Nama Tenant)
        const brandTitleElements = document.querySelectorAll('.desktop-brand-title, #desktop-brand-title, header.hidden.md\\:block h1');
        brandTitleElements.forEach(el => {
            el.textContent = appName;
            el.title = appName;
        });

        // 2. Update logo brand di navbar desktop jika tenant memiliki logo_url kustom
        const defaultLogo = "assets/logo_wifi.png";
        const hasCustomLogo = settings?.logo_url &&
            settings.logo_url !== defaultLogo &&
            settings.logo_url !== 'assets/sn-blue.png' &&
            !settings.logo_url.startsWith('data:image/svg+xml');

        if (hasCustomLogo) {
            const logoContainers = document.querySelectorAll('.desktop-brand-logo, #desktop-brand-logo, header.hidden.md\\:block .w-10.h-10');
            logoContainers.forEach(container => {
                container.classList.remove('bg-gradient-to-tr', 'from-brand-600', 'to-indigo-600', 'text-white');
                container.classList.add('bg-white', 'border', 'border-slate-200/80', 'p-1', 'overflow-hidden');
                container.innerHTML = `<img src="${settings.logo_url}" alt="${appName}" class="w-full h-full object-contain rounded-lg">`;
            });
        }
    }

    applyToLoginPage(settings) {
        const appName = settings?.app_name || 'WiFi Billing System';
        const defaultLogo = "assets/logo_wifi.png";
        const isOldDefaultLogo = !settings?.logo_url || settings.logo_url === 'assets/sn-blue.png' || settings.logo_url.startsWith('data:image/svg+xml');
        const logoUrl = isOldDefaultLogo ? defaultLogo : settings.logo_url;

        // Login page (index.html / login.html)
        document.querySelectorAll('#login-logo, .login-logo').forEach(el => {
            el.src = logoUrl;
            el.alt = appName;
        });
        document.querySelectorAll('#login-app-name, .login-app-name').forEach(el => {
            el.textContent = appName;
        });
        document.querySelectorAll('#login-app-tagline, .login-app-tagline').forEach(el => {
            if (settings?.app_tagline && settings.app_tagline.trim()) {
                el.textContent = settings.app_tagline.trim();
                el.classList.remove('hidden');
            } else {
                el.classList.add('hidden');
            }
        });

        // Register page (register.html)
        const registerLogo = document.getElementById('register-logo');
        const registerAppName = document.getElementById('register-app-name');

        if (registerLogo) {
            registerLogo.src = logoUrl;
            registerLogo.alt = 'Your Logo';
        }
        if (registerAppName) {
            registerAppName.textContent = appName;
        }

        // Fallback for general logo & app-name class selectors
        const logoImgs = document.querySelectorAll('.app-logo-img, .brand-logo');
        logoImgs.forEach(img => {
            img.src = logoUrl;
            img.alt = 'Your Logo';
        });

        const appNameEls = document.querySelectorAll('.app-brand-name');
        appNameEls.forEach(el => {
            el.textContent = appName;
        });
    }

    applyToCustomerPages(settings) {
        if (settings?.whatsapp_number) {
            window.WHATSAPP_NUMBER = settings.whatsapp_number;
            window.dispatchEvent(new CustomEvent('settings-loaded', {
                detail: { whatsapp: settings.whatsapp_number }
            }));

            const waLinks = document.querySelectorAll('a[href*="wa.me"], a[href*="whatsapp"]');
            waLinks.forEach(link => {
                try {
                    const url = new URL(link.href);
                    url.pathname = `/${settings.whatsapp_number}`;
                    link.href = url.toString();
                } catch (e) {
                    // Ignore malformed URLs
                }
            });
        }
    }

    getCurrentPageName() {
        const path = window.location.pathname;
        const filename = path.split('/').pop().split('.')[0] || 'index';
        
        const pageNames = {
            'index': 'Login',
            'login': 'Login',
            'register': 'Daftar Admin',
            'dashboard': 'Dashboard',
            'pelanggan': 'Pelanggan',
            'tagihan': 'Tagihan',
            'lunas': 'Riwayat Lunas',
            'laporan': 'Laporan',
            'pengeluaran': 'Pengeluaran',
            'profile': 'Profil',
            'paket': 'Paket Internet',
            'ganti-wifi': 'Ganti WiFi',
            'notifikasi': 'Notifikasi',
            'payment-methods': 'Metode Pembayaran',
            'app-settings': 'Pengaturan Aplikasi',
            'pelanggan_dashboard': 'Dashboard Pelanggan',
            'pelanggan_profile': 'Profil Pelanggan',
            'pelanggan_riwayat_lunas': 'Riwayat Pembayaran',
            'pelanggan_info': 'Pusat Bantuan'
        };

        return pageNames[filename] || '';
    }

    getLocalSettings() {
        try {
            const settings = localStorage.getItem('app_settings');
            return settings ? JSON.parse(settings) : null;
        } catch (e) {
            return null;
        }
    }

    saveLocalSettings(settings) {
        try {
            localStorage.setItem('app_settings', JSON.stringify(settings));
        } catch (e) {
            console.error('Error saving local settings:', e);
        }
    }
}

// Auto-initialize on script load
const appSettingsInstance = new ApplySettings();

// Re-apply when DOM is fully loaded if elements were not ready during initial script load
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        const settings = appSettingsInstance.settings || appSettingsInstance.getLocalSettings() || {};
        appSettingsInstance.applyAllSettings(settings);
    });
} else {
    const settings = appSettingsInstance.settings || appSettingsInstance.getLocalSettings() || {};
    appSettingsInstance.applyAllSettings(settings);
}

// Export helper functions for other modules
export function getAppSettings() {
    return window.APP_SETTINGS || JSON.parse(localStorage.getItem('app_settings')) || {};
}

export function getWhatsAppNumber() {
    const settings = getAppSettings();
    return settings?.whatsapp_number || '';
}

export function getOfflinePaymentInfo() {
    const settings = getAppSettings();
    return {
        name: settings?.offline_payment_name || '',
        address: settings?.offline_payment_address || ''
    };
}

export function getQRISInfo() {
    const settings = getAppSettings();
    const defaultQris = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='300' height='300' viewBox='0 0 300 300'><rect width='300' height='300' fill='%23f8f9fa' rx='16'/><rect x='20' y='20' width='260' height='260' fill='none' stroke='%23cbd5e1' stroke-width='4' stroke-dasharray='8 8' rx='12'/><path d='M70 70h50v50H70zm20 20h10v10H90zm90-20h50v50h-50zm20 20h10v10h-10zm-110 90h50v50H70zm20 20h10v10H90zm70-40h20v20h-20zm30 0h20v20h-20zm-30 30h20v20h-20zm30 30h20v20h-20zm-30 0h20v20h-20z' fill='%2364748b'/><text x='50%' y='62%' text-anchor='middle' fill='%23475569' font-size='14' font-weight='bold' font-family='sans-serif'>BELUM ADA QRIS</text><text x='50%' y='70%' text-anchor='middle' fill='%2394a3b8' font-size='11' font-family='sans-serif'>Upload di Pengaturan Aplikasi</text></svg>";
    const isOldQris = !settings?.qris_image_url || settings.qris_image_url === 'assets/qris.jpeg';

    return {
        imageUrl: isOldQris ? defaultQris : settings.qris_image_url,
        showQRIS: settings?.show_qris !== false
    };
}
