// paket.js - Package Management with CRUD
import { supabase } from './supabase-client.js';
import { requireRole, initLogout } from './auth.js';

document.addEventListener('DOMContentLoaded', async () => {
    await requireRole('ADMIN');
    initLogout('desktop-logout-btn');

    // State Management
    let allPackages = [];
    let filteredPackages = [];
    let currentEditingPackageId = null;

    // DOM Selectors
    const views = { list: document.getElementById('list-view'), form: document.getElementById('form-view') };
    const packageList = document.getElementById('package-list');
    const searchInput = document.getElementById('search-input');
    const clearSearchBtn = document.getElementById('clear-search-btn');
    const packageForm = document.getElementById('package-form');
    const formTitle = document.getElementById('form-title');
    const saveBtnText = document.getElementById('save-btn-text');
    const backToPelangganBtn = document.getElementById('back-to-pelanggan');
    const desktopBadge = document.getElementById('desktop-package-badge');

    // Initial Setup
    initializeEventListeners();
    fetchPackages();

    // Event Listeners
    function initializeEventListeners() {
        // Back buttons
        backToPelangganBtn?.addEventListener('click', () => window.location.href = 'pelanggan.html');
        document.getElementById('back-from-form')?.addEventListener('click', () => {
            if (confirm('Yakin ingin kembali? Perubahan yang belum disimpan akan hilang.')) {
                switchView('list');
            }
        });
        document.getElementById('cancel-btn')?.addEventListener('click', () => {
            if (confirm('Yakin ingin membatalkan? Perubahan yang belum disimpan akan hilang.')) {
                switchView('list');
            }
        });

        // Add package button (Mobile & Desktop)
        const openAddModal = () => {
            currentEditingPackageId = null;
            formTitle.textContent = 'Tambah Paket';
            saveBtnText.textContent = 'Simpan';
            packageForm.reset();
            switchView('form');
        };

        document.getElementById('add-package-btn')?.addEventListener('click', openAddModal);
        document.getElementById('desktop-add-package-btn')?.addEventListener('click', openAddModal);

        // Form submit
        packageForm.addEventListener('submit', handleSubmit);

        // Search functionality
        searchInput.addEventListener('input', handleSearch);
        clearSearchBtn.addEventListener('click', () => {
            searchInput.value = '';
            clearSearchBtn.classList.add('hidden');
            filteredPackages = [...allPackages];
            renderPackages();
        });

        // Event delegation for edit/delete buttons
        packageList.addEventListener('click', (e) => {
            const editBtn = e.target.closest('.edit-package-btn');
            const deleteBtn = e.target.closest('.delete-package-btn');

            if (editBtn) {
                const packageId = parseInt(editBtn.dataset.packageId);
                handleEdit(packageId);
            } else if (deleteBtn) {
                const packageId = parseInt(deleteBtn.dataset.packageId);
                handleDelete(packageId);
            }
        });
    }

    // View Management
    function switchView(viewName) {
        Object.values(views).forEach(view => view.classList.add('hidden'));
        if (views[viewName]) views[viewName].classList.remove('hidden');
        window.scrollTo(0, 0);
    }

    // Fetch Packages
    async function fetchPackages() {
        showSkeletonLoading();
        
        try {
            const { data, error } = await supabase
                .from('packages')
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;

            allPackages = data || [];
            filteredPackages = [...allPackages];
            renderPackages();
        } catch (error) {
            console.error('Error fetching packages:', error);
            showError('Gagal memuat data paket');
        }
    }

    // Render Packages
    function renderPackages() {
        if (desktopBadge) {
            desktopBadge.textContent = `${filteredPackages.length} Paket`;
        }

        if (filteredPackages.length === 0) {
            packageList.innerHTML = `
                <div class="col-span-full flex flex-col items-center justify-center py-16 px-4 bg-white rounded-2xl border border-slate-200/80 text-center">
                    <div class="w-14 h-14 rounded-full bg-slate-100 flex items-center justify-center text-slate-400 mb-3">
                        <svg xmlns="http://www.w3.org/2000/svg" width="28px" height="28px" fill="currentColor" viewBox="0 0 256 256">
                            <path d="M224,48H32A16,16,0,0,0,16,64V192a16,16,0,0,0,16,16H224a16,16,0,0,0,16-16V64A16,16,0,0,0,224,48Zm0,144H32V64H224V192ZM176,88a8,8,0,0,1-8,8H88a8,8,0,0,1,0-16h80A8,8,0,0,1,176,88Zm0,40a8,8,0,0,1-8,8H88a8,8,0,0,1,0-16h80A8,8,0,0,1,176,128Z"></path>
                        </svg>
                    </div>
                    <h4 class="font-bold text-slate-800 text-sm mb-1">${searchInput.value ? 'Paket Tidak Ditemukan' : 'Belum Ada Paket Internet'}</h4>
                    <p class="text-xs text-slate-500 max-w-sm mb-4">
                        ${searchInput.value ? 'Coba ubah kata kunci pencarian Anda.' : 'Tambahkan paket baru untuk mulai mendaftarkan paket internet bagi pelanggan.'}
                    </p>
                </div>
            `;
            return;
        }

        packageList.innerHTML = filteredPackages.map(pkg => createPackageCard(pkg)).join('');
    }

    // Create Package Card
    function createPackageCard(pkg) {
        const formatter = new Intl.NumberFormat('id-ID', {
            style: 'currency',
            currency: 'IDR',
            minimumFractionDigits: 0
        });

        return `
            <div class="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-xs hover:shadow-md hover:border-brand-200 transition-all flex flex-col justify-between group">
                <div>
                    <div class="flex items-start justify-between gap-2 mb-2">
                        <div>
                            <span class="inline-flex items-center text-[10px] font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded mb-1">ID: ${pkg.id}</span>
                            <h3 class="text-slate-900 text-base sm:text-lg font-bold leading-snug group-hover:text-brand-700 transition-colors">${pkg.package_name}</h3>
                        </div>
                        <div class="flex items-center gap-1.5 flex-shrink-0">
                            <button class="edit-package-btn flex items-center justify-center w-8 h-8 rounded-lg bg-slate-100 text-slate-600 hover:bg-brand-50 hover:text-brand-600 transition-colors" data-package-id="${pkg.id}" title="Edit Paket">
                                <svg xmlns="http://www.w3.org/2000/svg" width="16px" height="16px" fill="currentColor" viewBox="0 0 256 256">
                                    <path d="M227.31,73.37,182.63,28.69a16,16,0,0,0-22.63,0L36.69,152A15.86,15.86,0,0,0,32,163.31V208a16,16,0,0,0,16,16H92.69A15.86,15.86,0,0,0,104,219.31L227.31,96A16,16,0,0,0,227.31,73.37ZM92.69,208H48V163.31l88-88L180.69,120ZM192,108.69,147.31,64l24-24L216,84.69Z"></path>
                                </svg>
                            </button>
                            <button class="delete-package-btn flex items-center justify-center w-8 h-8 rounded-lg bg-slate-100 text-slate-600 hover:bg-rose-50 hover:text-rose-600 transition-colors" data-package-id="${pkg.id}" title="Hapus Paket">
                                <svg xmlns="http://www.w3.org/2000/svg" width="16px" height="16px" fill="currentColor" viewBox="0 0 256 256">
                                    <path d="M216,48H176V40a24,24,0,0,0-24-24H104A24,24,0,0,0,80,40v8H40a8,8,0,0,0,0,16h8V208a16,16,0,0,0,16,16H192a16,16,0,0,0,16-16V64h8a8,8,0,0,0,0-16ZM96,40a8,8,0,0,1,8-8h48a8,8,0,0,1,8,8v8H96Zm96,168H64V64H192ZM112,104v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Zm48,0v64a8,8,0,0,1-16,0V104a8,8,0,0,1,16,0Z"></path>
                                </svg>
                            </button>
                        </div>
                    </div>

                    <div class="flex items-center gap-2 mb-3">
                        <span class="inline-flex items-center gap-1.5 bg-brand-50 text-brand-700 px-2.5 py-1 rounded-full text-xs font-bold border border-brand-200">
                            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="currentColor" viewBox="0 0 256 256">
                                <path d="M247.31,124.76c-.35-.79-8.82-19.58-27.65-38.41C194.57,61.26,162.88,48,128,48S61.43,61.26,36.34,86.35C17.51,105.18,9,124,8.69,124.76a8,8,0,0,0,0,6.5c.35.79,8.82,19.57,27.65,38.4C61.43,194.74,93.12,208,128,208s66.57-13.26,91.66-38.34c18.83-18.83,27.3-37.61,27.65-38.4A8,8,0,0,0,247.31,124.76ZM128,192c-30.78,0-57.67-11.19-79.93-33.25A133.47,133.47,0,0,1,25,128,133.33,133.33,0,0,1,48.07,97.25C70.33,75.19,97.22,64,128,64s57.67,11.19,79.93,33.25A133.46,133.46,0,0,1,231.05,128C223.84,141.46,192.43,192,128,192Zm0-112a48,48,0,1,0,48,48A48.05,48.05,0,0,0,128,80Zm0,80a32,32,0,1,1,32-32A32,32,0,0,1,128,160Z"></path>
                            </svg>
                            ${pkg.speed_mbps} Mbps
                        </span>
                    </div>

                    ${pkg.description ? `<p class="text-xs text-slate-500 line-clamp-2 mb-4 leading-relaxed">${pkg.description}</p>` : '<div class="mb-4"></div>'}
                </div>

                <div class="pt-3 border-t border-slate-100 flex items-baseline justify-between">
                    <span class="text-xs text-slate-400 font-medium">Tarif Bulanan</span>
                    <p class="text-xl font-extrabold text-emerald-600">${formatter.format(pkg.price)}<span class="text-xs text-slate-400 font-normal">/bln</span></p>
                </div>
            </div>
        `;
    }

    // Handle Search
    function handleSearch() {
        const query = searchInput.value.toLowerCase().trim();
        
        if (query) {
            clearSearchBtn.classList.remove('hidden');
            filteredPackages = allPackages.filter(pkg => 
                pkg.package_name.toLowerCase().includes(query) ||
                (pkg.description && pkg.description.toLowerCase().includes(query))
            );
        } else {
            clearSearchBtn.classList.add('hidden');
            filteredPackages = [...allPackages];
        }
        
        renderPackages();
    }

    // Handle Submit
    async function handleSubmit(e) {
        e.preventDefault();
        
        const packageData = {
            package_name: document.getElementById('package-name').value.trim(),
            price: parseFloat(document.getElementById('package-price').value),
            speed_mbps: parseInt(document.getElementById('package-speed').value),
            description: document.getElementById('package-description').value.trim() || null
        };

        const submitBtn = e.target.querySelector('button[type="submit"]');
        submitBtn.disabled = true;
        saveBtnText.textContent = 'Menyimpan...';

        try {
            if (currentEditingPackageId) {
                // Update existing package
                const { error } = await supabase
                    .from('packages')
                    .update(packageData)
                    .eq('id', currentEditingPackageId);

                if (error) throw error;
                showSuccess('Paket berhasil diperbarui');
            } else {
                // Create new package
                const { error } = await supabase
                    .from('packages')
                    .insert([packageData]);

                if (error) throw error;
                showSuccess('Paket berhasil ditambahkan');
            }

            await fetchPackages();
            switchView('list');
        } catch (error) {
            console.error('Error saving package:', error);
            showError('Gagal menyimpan paket: ' + error.message);
        } finally {
            submitBtn.disabled = false;
            saveBtnText.textContent = 'Simpan';
        }
    }

    // Handle Edit
    function handleEdit(packageId) {
        const pkg = allPackages.find(p => p.id === packageId);
        if (!pkg) return;

        currentEditingPackageId = packageId;
        formTitle.textContent = 'Edit Paket';
        saveBtnText.textContent = 'Perbarui';

        document.getElementById('package-name').value = pkg.package_name;
        document.getElementById('package-price').value = pkg.price;
        document.getElementById('package-speed').value = pkg.speed_mbps;
        document.getElementById('package-description').value = pkg.description || '';

        switchView('form');
    }

    // Handle Delete
    async function handleDelete(packageId) {
        const pkg = allPackages.find(p => p.id === packageId);
        if (!pkg) return;

        if (!confirm(`Yakin ingin menghapus paket "${pkg.package_name}"?\n\nPeringatan: Pelanggan yang menggunakan paket ini akan terpengaruh.`)) {
            return;
        }

        try {
            const { error } = await supabase
                .from('packages')
                .delete()
                .eq('id', packageId);

            if (error) throw error;

            showSuccess('Paket berhasil dihapus');
            await fetchPackages();
        } catch (error) {
            console.error('Error deleting package:', error);
            showError('Gagal menghapus paket: ' + error.message);
        }
    }

    // Skeleton Loading
    function showSkeletonLoading() {
        packageList.innerHTML = Array(6).fill(0).map(() => `
            <div class="bg-white rounded-2xl border border-slate-200/80 p-5 shadow-xs animate-pulse">
                <div class="flex items-start justify-between mb-4">
                    <div class="space-y-2 flex-1">
                        <div class="h-3 bg-slate-200 rounded w-16"></div>
                        <div class="h-5 bg-slate-200 rounded w-36"></div>
                        <div class="h-6 bg-slate-200 rounded-full w-24"></div>
                    </div>
                    <div class="flex gap-1.5">
                        <div class="w-8 h-8 bg-slate-200 rounded-lg"></div>
                        <div class="w-8 h-8 bg-slate-200 rounded-lg"></div>
                    </div>
                </div>
                <div class="h-10 bg-slate-100 rounded-xl mb-3"></div>
                <div class="pt-3 border-t border-slate-100 flex justify-between items-center">
                    <div class="h-3 bg-slate-200 rounded w-20"></div>
                    <div class="h-5 bg-slate-200 rounded w-24"></div>
                </div>
            </div>
        `).join('');
    }

    // Notification Functions
    function showSuccess(message) {
        alert('✓ ' + message);
    }

    function showError(message) {
        alert('✗ ' + message);
    }
});
