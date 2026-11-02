// ganti-wifi.js - WiFi SSID & Password Change via GenieACS
import { supabase } from './supabase-client.js';
import { checkAuth, requireRole } from './auth.js';

let currentUser = null;
let currentProfile = null;
let genieacsSettings = {};

document.addEventListener('DOMContentLoaded', async function() {
    // Check authentication and require USER role
    currentUser = await requireRole('USER');
    if (!currentUser) return;

    // Load GenieACS settings
    await loadGenieACSSettings();

    // Check if GenieACS is enabled
    if (genieacsSettings.genieacs_enabled !== 'true') {
        alert('Fitur ganti WiFi tidak tersedia saat ini.');
        window.location.href = 'pelanggan_profile.html';
        return;
    }

    // Load user profile and IP mapping
    await loadUserData();

    // Initialize event listeners
    initializeEventListeners();

    // Load change history
    await loadChangeHistory();
});

async function loadGenieACSSettings() {
    try {
        const { data, error } = await supabase
            .from('genieacs_settings')
            .select('*');

        if (error) throw error;

        data?.forEach(setting => {
            genieacsSettings[setting.setting_key] = setting.setting_value;
        });

        console.log('GenieACS settings loaded:', genieacsSettings);
    } catch (error) {
        console.error('Error loading GenieACS settings:', error);
        showNotification('Gagal memuat pengaturan GenieACS', 'error');
    }
}

async function loadUserData() {
    try {
        // Get user profile with IP address
        const { data: profile, error: profileError } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', currentUser.id)
            .single();

        if (profileError) throw profileError;
        currentProfile = profile;

        // Get IP from profile.ip_static_pppoe
        const ipAddress = profile.ip_static_pppoe;

        if (ipAddress && ipAddress.trim() !== '') {
            document.getElementById('current-ip').textContent = ipAddress;
            // Try to get current SSID from GenieACS
            await getCurrentSSID(ipAddress);
        } else {
            document.getElementById('current-ip').textContent = 'Tidak ditemukan';
            document.getElementById('current-ssid').textContent = 'Tidak tersedia';
            showNotification('IP Address tidak ditemukan. Hubungi admin untuk mengatur IP Address Anda.', 'warning');
        }

    } catch (error) {
        console.error('Error loading user data:', error);
        showNotification('Gagal memuat data pengguna', 'error');
    }
}

async function getCurrentSSID(ipAddress) {
    try {
        // Call GenieACS API to get current SSID
        const genieacsUrl = genieacsSettings.genieacs_url;
        if (!genieacsUrl) {
            document.getElementById('current-ssid').textContent = 'URL GenieACS tidak dikonfigurasi';
            return;
        }

        // Build auth header if username/password provided
        const headers = {
            'Content-Type': 'application/json'
        };

        if (genieacsSettings.genieacs_username && genieacsSettings.genieacs_password) {
            const auth = btoa(`${genieacsSettings.genieacs_username}:${genieacsSettings.genieacs_password}`);
            headers['Authorization'] = `Basic ${auth}`;
        }

        // Helper to build query (IP vs PPPoE Username)
        const isIpAddress = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(ipAddress);
        let queryStr = isIpAddress 
            ? `{"InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress":"${ipAddress}"}`
            : `{"VirtualParameters.PPPUsername":"${ipAddress}"}`;

        // Query device by IP address or PPPoE Username
        const response = await fetch(`${genieacsUrl}/devices?query=${queryStr}`, {
            method: 'GET',
            headers: headers
        });

        if (!response.ok) {
            throw new Error('Gagal mengambil data dari GenieACS');
        }

        const devices = await response.json();
        
        if (devices && devices.length > 0) {
            const device = devices[0];
            // Try to get SSID from device parameters
            // Path may vary depending on device model
            const ssidPath = 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID';
            const ssid = device[ssidPath]?._value || 'Tidak dapat diambil';
            document.getElementById('current-ssid').textContent = ssid;
        } else {
            document.getElementById('current-ssid').textContent = 'Device tidak ditemukan';
        }

    } catch (error) {
        console.error('Error getting current SSID:', error);
        document.getElementById('current-ssid').textContent = 'Gagal mengambil data';
    }
}

function initializeEventListeners() {
    // Back button
    document.getElementById('back-btn')?.addEventListener('click', () => {
        window.location.href = 'pelanggan_profile.html';
    });

    // Toggle password visibility
    document.getElementById('toggle-password')?.addEventListener('click', () => {
        const passwordInput = document.getElementById('new-password');
        passwordInput.type = passwordInput.type === 'password' ? 'text' : 'password';
    });

    // Form submit
    document.getElementById('wifi-form')?.addEventListener('submit', handleFormSubmit);
}

async function handleFormSubmit(e) {
    e.preventDefault();

    const newSSID = document.getElementById('new-ssid').value.trim();
    const newPassword = document.getElementById('new-password').value;

    // Validation: minimal salah satu diisi
    if (!newSSID && !newPassword) {
        showNotification('Harap isi Nama WiFi Baru atau Password WiFi Baru', 'error');
        return;
    }

    if (newPassword && newPassword.length < 8) {
        showNotification('Password minimal 8 karakter', 'error');
        return;
    }

    // Get IP from current profile
    if (!currentProfile || !currentProfile.ip_static_pppoe || currentProfile.ip_static_pppoe.trim() === '') {
        showNotification('IP Address tidak ditemukan. Hubungi admin untuk mengatur IP Address Anda.', 'error');
        return;
    }

    const ipAddress = currentProfile.ip_static_pppoe;

    // Confirm action
    const changeList = [];
    if (newSSID) changeList.push(`• Nama WiFi Baru: ${newSSID}`);
    if (newPassword) changeList.push(`• Password WiFi Baru: (Diperbarui)`);

    if (!confirm(`Yakin ingin menyimpan perubahan WiFi?\n\n${changeList.join('\n')}\n\nProses membutuhkan waktu 1-2 menit.`)) {
        return;
    }

    // Show loading
    setLoading(true);

    try {
        const currentSSIDText = document.getElementById('current-ssid').textContent;

        // Save to log first
        const { data: logData, error: logError } = await supabase
            .from('wifi_change_logs')
            .insert({
                customer_id: currentUser.id,
                ip_address: ipAddress,
                old_ssid: currentSSIDText,
                new_ssid: newSSID || currentSSIDText,
                status: 'processing'
            })
            .select()
            .single();

        if (logError) throw logError;

        // Call GenieACS API to change WiFi
        const result = await changeWiFiViaGenieACS(ipAddress, newSSID, newPassword);

        if (result.success) {
            // Update log status
            await supabase
                .from('wifi_change_logs')
                .update({ status: 'success' })
                .eq('id', logData.id);

            showNotification('✅ Perubahan WiFi berhasil disimpan! Silakan hubungkan ulang perangkat Anda.', 'success');
            
            // Clear inputs
            document.getElementById('new-password').value = '';
            document.getElementById('new-ssid').value = '';

            // Reload data
            setTimeout(() => {
                loadUserData();
                loadChangeHistory();
            }, 2000);
        } else {
            // Update log status with error
            await supabase
                .from('wifi_change_logs')
                .update({ 
                    status: 'failed',
                    error_message: result.message 
                })
                .eq('id', logData.id);

            showNotification(`❌ Gagal menyimpan perubahan: ${result.message}`, 'error');
        }

    } catch (error) {
        console.error('Error changing WiFi:', error);
        showNotification(`❌ Error: ${error.message}`, 'error');
    } finally {
        setLoading(false);
    }
}

async function changeWiFiViaGenieACS(ipAddress, newSSID, newPassword) {
    try {
        const genieacsUrl = genieacsSettings.genieacs_url;
        if (!genieacsUrl) {
            return { success: false, message: 'URL GenieACS tidak dikonfigurasi' };
        }

        // Build auth header
        const headers = {
            'Content-Type': 'application/json'
        };

        if (genieacsSettings.genieacs_username && genieacsSettings.genieacs_password) {
            const auth = btoa(`${genieacsSettings.genieacs_username}:${genieacsSettings.genieacs_password}`);
            headers['Authorization'] = `Basic ${auth}`;
        }

        // Helper to build query (IP vs PPPoE Username)
        const isIpAddress = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(ipAddress);
        let queryStr = isIpAddress 
            ? `{"InternetGatewayDevice.WANDevice.1.WANConnectionDevice.1.WANIPConnection.1.ExternalIPAddress":"${ipAddress}"}`
            : `{"VirtualParameters.PPPUsername":"${ipAddress}"}`;

        // Step 1: Find device by IP or PPPoE Username
        const devicesResponse = await fetch(`${genieacsUrl}/devices?query=${queryStr}`, {
            method: 'GET',
            headers: headers
        });

        if (!devicesResponse.ok) {
            return { success: false, message: 'Gagal menemukan device di GenieACS' };
        }

        const devices = await devicesResponse.json();
        
        if (!devices || devices.length === 0) {
            return { success: false, message: 'Device tidak ditemukan di GenieACS' };
        }

        const deviceId = devices[0]._id;

        // Step 2: Siapkan parameter yang ingin diubah (SSID, Password, atau keduanya)
        const parameterValues = [];

        if (newSSID) {
            const ssidPath = 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.SSID';
            parameterValues.push([ssidPath, newSSID, 'xsd:string']);
        }

        if (newPassword) {
            const passwordPath = 'InternetGatewayDevice.LANDevice.1.WLANConfiguration.1.PreSharedKey.1.KeyPassphrase';
            parameterValues.push([passwordPath, newPassword, 'xsd:string']);
        }

        if (parameterValues.length === 0) {
            return { success: false, message: 'Tidak ada parameter yang diubah' };
        }

        // Step 3: Kirim task setParameterValues ke GenieACS
        const taskResponse = await fetch(`${genieacsUrl}/devices/${deviceId}/tasks?timeout=3000&connection_request`, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify({
                name: 'setParameterValues',
                parameterValues: parameterValues
            })
        });

        if (!taskResponse.ok) {
            return { success: false, message: 'Gagal mengatur parameter WiFi' };
        }

        return { success: true, message: 'WiFi berhasil disimpan' };

    } catch (error) {
        console.error('Error in changeWiFiViaGenieACS:', error);
        return { success: false, message: error.message };
    }
}

async function loadChangeHistory() {
    try {
        const { data, error } = await supabase
            .from('wifi_change_logs')
            .select('*')
            .eq('customer_id', currentUser.id)
            .order('changed_at', { ascending: false })
            .limit(5);

        if (error) throw error;

        const historyList = document.getElementById('history-list');
        
        if (!data || data.length === 0) {
            historyList.innerHTML = '<p class="text-xs text-gray-500 text-center py-4">Belum ada riwayat perubahan</p>';
            return;
        }

        historyList.innerHTML = data.map(log => {
            const date = new Date(log.changed_at).toLocaleString('id-ID');
            const statusColor = log.status === 'success' ? 'text-green-600' : log.status === 'failed' ? 'text-red-600' : 'text-yellow-600';
            const statusText = log.status === 'success' ? 'Berhasil' : log.status === 'failed' ? 'Gagal' : 'Diproses';
            
            return `
                <div class="flex items-start gap-2 p-2 bg-gray-50 rounded-lg">
                    <div class="flex-1">
                        <p class="text-xs font-medium text-gray-800">${log.new_ssid}</p>
                        <p class="text-xs text-gray-500">${date}</p>
                        ${log.error_message ? `<p class="text-xs text-red-600 mt-1">${log.error_message}</p>` : ''}
                    </div>
                    <span class="text-xs font-semibold ${statusColor}">${statusText}</span>
                </div>
            `;
        }).join('');

    } catch (error) {
        console.error('Error loading history:', error);
        document.getElementById('history-list').innerHTML = '<p class="text-xs text-red-500 text-center py-4">Gagal memuat riwayat</p>';
    }
}

function setLoading(isLoading) {
    const submitBtn = document.getElementById('submit-btn');
    const submitText = document.getElementById('submit-text');
    const submitLoading = document.getElementById('submit-loading');

    submitBtn.disabled = isLoading;
    
    if (isLoading) {
        submitText.classList.add('hidden');
        submitLoading.classList.remove('hidden');
    } else {
        submitText.classList.remove('hidden');
        submitLoading.classList.add('hidden');
    }
}

function showNotification(message, type = 'info') {
    const bgColor = type === 'success' ? '#28a745' : type === 'error' ? '#dc3545' : type === 'warning' ? '#ffc107' : '#17a2b8';
    const icon = type === 'success' ? '✓' : type === 'error' ? '✕' : '⚠';

    const notification = document.createElement('div');
    notification.style.cssText = `position: fixed; top: 20px; right: 20px; background-color: ${bgColor}; color: white; padding: 15px 20px; border-radius: 8px; z-index: 1002; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2); animation: slideInRight 0.3s ease; max-width: 90%;`;
    notification.innerHTML = `<div style="display: flex; align-items: center; gap: 10px;"><span style="font-size: 18px;">${icon}</span><span>${message}</span></div>`;
    
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
    }, 5000);
}
