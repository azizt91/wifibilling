// PWA Installer - Handle installation and updates
class PWAInstaller {
    constructor() {
        this.deferredPrompt = null;
        this.isInstalled = false;
        this.init();
    }

    init() {
        // Register Service Worker
        this.registerServiceWorker();
        
        // Handle beforeinstallprompt event
        this.handleInstallPrompt();
        
        // Check if app is already installed
        this.checkInstallStatus();
        
        // Handle app state changes
        this.handleAppStateChanges();
        
        // Add install button if not installed
        this.addInstallButton();

        // Bind custom in-page install buttons (e.g. on login.html)
        this.bindCustomInstallButtons();
    }

    async registerServiceWorker() {
        if ('serviceWorker' in navigator) {
            try {
                const registration = await navigator.serviceWorker.register('./sw.js');
                console.log('PWA: Service Worker registered successfully', registration);
                
                // Handle service worker updates
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    newWorker.addEventListener('statechange', () => {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            // New content available, show update notification
                            this.showUpdateNotification();
                        }
                    });
                });
            } catch (error) {
                console.warn('PWA: Service Worker registration failed', error);
            }
        }
    }

    handleInstallPrompt() {
        window.addEventListener('beforeinstallprompt', (event) => {
            console.log('PWA: Install prompt available');
            event.preventDefault();
            this.deferredPrompt = event;
            this.showInstallButton();
        });

        window.addEventListener('appinstalled', () => {
            console.log('PWA: App installed successfully');
            this.isInstalled = true;
            this.hideInstallButton();
            this.showSuccessMessage('Aplikasi berhasil dipasang di HP!');
        });
    }

    checkInstallStatus() {
        // Check if running in standalone mode (installed)
        if (window.matchMedia('(display-mode: standalone)').matches || 
            window.navigator.standalone === true) {
            this.isInstalled = true;
        }
    }

    handleAppStateChanges() {
        // Handle online/offline status
        window.addEventListener('online', () => {
            this.showOnlineStatus();
        });

        window.addEventListener('offline', () => {
            this.showOfflineStatus();
        });
    }

    addInstallButton() {
        // Create install button container
        const installContainer = document.createElement('div');
        installContainer.id = 'pwa-install-container';
        installContainer.style.cssText = `
            position: fixed;
            bottom: 90px;
            right: 20px;
            z-index: 1000;
            display: none;
        `;

        // Create install button
        const installButton = document.createElement('button');
        installButton.id = 'pwa-install-btn';
        installButton.innerHTML = '📲 Pasang Aplikasi';
        installButton.style.cssText = `
            background-color: #6a5acd;
            color: white;
            border: none;
            padding: 12px 20px;
            border-radius: 25px;
            font-weight: 700;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(106, 90, 205, 0.35);
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 13px;
        `;

        installButton.addEventListener('mouseover', () => {
            installButton.style.transform = 'translateY(-2px)';
            installButton.style.boxShadow = '0 6px 20px rgba(106, 90, 205, 0.45)';
        });

        installButton.addEventListener('mouseout', () => {
            installButton.style.transform = 'translateY(0)';
            installButton.style.boxShadow = '0 4px 15px rgba(106, 90, 205, 0.35)';
        });

        installButton.addEventListener('click', () => {
            this.installApp();
        });

        installContainer.appendChild(installButton);
        document.body.appendChild(installContainer);
    }

    bindCustomInstallButtons() {
        const handleCustomClick = (e) => {
            e.preventDefault();
            if (this.deferredPrompt) {
                this.installApp();
            } else if (this.isInstalled) {
                this.showSuccessMessage('Aplikasi sudah terpasang di perangkat Anda!');
            } else {
                this.showInstallGuideModal();
            }
        };

        const buttons = document.querySelectorAll('#btn-install-pwa-login, .btn-pwa-install, #btn-install-superadmin-header, #btn-install-superadmin-login');
        buttons.forEach(btn => {
            btn.addEventListener('click', handleCustomClick);
        });
    }

    showInstallButton() {
        const container = document.getElementById('pwa-install-container');
        if (container && !this.isInstalled) {
            container.style.display = 'block';
        }
    }

    hideInstallButton() {
        const container = document.getElementById('pwa-install-container');
        if (container) {
            container.style.display = 'none';
        }
    }

    async installApp() {
        if (this.deferredPrompt) {
            this.deferredPrompt.prompt();
            const { outcome } = await this.deferredPrompt.userChoice;
            
            if (outcome === 'accepted') {
                console.log('PWA: User accepted install prompt');
            } else {
                console.log('PWA: User dismissed install prompt');
            }
            
            this.deferredPrompt = null;
            this.hideInstallButton();
        } else {
            this.showInstallGuideModal();
        }
    }

    showInstallGuideModal() {
        if (document.getElementById('pwa-guide-modal')) return;

        const modal = document.createElement('div');
        modal.id = 'pwa-guide-modal';
        modal.style.cssText = `
            position: fixed;
            inset: 0;
            background: rgba(15, 23, 42, 0.7);
            backdrop-filter: blur(4px);
            z-index: 99999;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 16px;
        `;

        modal.innerHTML = `
            <div style="background: white; border-radius: 20px; max-width: 420px; width: 100%; padding: 24px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.2); font-family: sans-serif; color: #1e293b;">
                <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px;">
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <span style="font-size: 24px;">📲</span>
                        <h3 style="margin: 0; font-size: 17px; font-weight: 800; color: #0f172a;">Install Aplikasi ke HP</h3>
                    </div>
                    <button id="btn-close-pwa-guide" style="background: none; border: none; font-size: 22px; cursor: pointer; color: #94a3b8; line-height: 1;">&times;</button>
                </div>
                <p style="font-size: 13px; color: #475569; line-height: 1.5; margin-bottom: 16px;">
                    Anda dapat memasang aplikasi WiFi Billing langsung ke layar utama HP / Laptop tanpa melalui Play Store:
                </p>
                <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 14px; font-size: 12.5px; color: #334155; line-height: 1.5; margin-bottom: 20px;">
                    <p style="margin: 0 0 8px 0;"><strong>📱 Google Chrome (Android/PC):</strong><br>Klik menu titik 3 di pojok kanan atas browser, lalu pilih <strong>"Pasang / Install Aplikasi"</strong> atau <strong>"Tambahkan ke Layar Utama"</strong>.</p>
                    <p style="margin: 0;"><strong>🍎 Safari (iPhone / iOS):</strong><br>Tekan tombol <strong>Bagikan (Share)</strong> di bagian bawah, lalu pilih <strong>"Add to Home Screen (Tambahkan ke Layar Utama)"</strong>.</p>
                </div>
                <button id="btn-ok-pwa-guide" style="width: 100%; padding: 12px; background: #6366f1; color: white; border: none; border-radius: 12px; font-size: 13px; font-weight: 700; cursor: pointer;">
                    Mengerti
                </button>
            </div>
        `;

        document.body.appendChild(modal);

        const closeModal = () => modal.remove();
        document.getElementById('btn-close-pwa-guide')?.addEventListener('click', closeModal);
        document.getElementById('btn-ok-pwa-guide')?.addEventListener('click', closeModal);
        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeModal();
        });
    }

    showUpdateNotification() {
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background-color: #28a745;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            z-index: 1001;
            box-shadow: 0 4px 15px rgba(40, 167, 69, 0.3);
        `;
        notification.innerHTML = `
            <div style="display: flex; align-items: center; gap: 10px;">
                <span>🔄</span>
                <span>Update tersedia! Refresh untuk versi terbaru.</span>
                <button onclick="window.location.reload()" style="
                    background: white;
                    color: #28a745;
                    border: none;
                    padding: 5px 10px;
                    border-radius: 4px;
                    cursor: pointer;
                    font-weight: 500;
                ">Refresh</button>
            </div>
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 10000);
    }

    showSuccessMessage(message) {
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background-color: #10b981;
            color: white;
            padding: 12px 18px;
            border-radius: 10px;
            z-index: 100001;
            box-shadow: 0 4px 15px rgba(16, 185, 129, 0.3);
            font-size: 13px;
            font-weight: 600;
        `;
        notification.innerHTML = `<span>✓ ${message}</span>`;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 4000);
    }

    showOnlineStatus() {
        this.showStatusMessage('Koneksi internet tersambung kembali', '#28a745');
    }

    showOfflineStatus() {
        this.showStatusMessage('Mode offline - beberapa data mungkin disimpan lokal', '#eab308');
    }

    showStatusMessage(message, color) {
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            left: 50%;
            transform: translateX(-50%);
            background-color: ${color};
            color: white;
            padding: 10px 18px;
            border-radius: 20px;
            z-index: 100001;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            font-size: 12.5px;
            font-weight: 600;
        `;
        notification.innerHTML = `<span>${message}</span>`;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 3000);
    }
}

// Initialize PWA when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.pwaInstaller = new PWAInstaller();
});
