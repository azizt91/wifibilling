class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://oawsmjpibfwpiaebvhot.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hd3NtanBpYmZ3cGlhZWJ2aG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwODcyNTMsImV4cCI6MjEwODY2MzI1M30.7XUiwHh0UO4v9e8ZNPr_DbR9TgDAE0NZCbD62aMukYk';

  // App Information
  static const String appName = 'WiFi Billing System';
  static const String appVersion = '2.0.0';

  // API Endpoints
  static const String genieacsProxyFunction = 'genieacs-proxy';
  static const String whatsappNotificationFunction = 'send-whatsapp-notification';
  static const String createCustomerFunction = 'create-customer';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Duration
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration mediumCacheDuration = Duration(minutes: 30);
  static const Duration longCacheDuration = Duration(hours: 24);

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String monthYearFormat = 'MMMM yyyy';

  // Regex Patterns
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp phoneRegex = RegExp(r'^(\+62|62|0)[0-9]{9,12}$');
  static final RegExp ipAddressRegex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
  );

  // Hive Box Names
  static const String profileBoxName = 'profiles';
  static const String invoiceBoxName = 'invoices';
  static const String packageBoxName = 'packages';
  static const String settingsBoxName = 'settings';

  // Shared Preferences Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyLastSync = 'last_sync';
  static const String keyShowNominal = 'show_nominal';

  // Error Messages
  static const String errorNoInternet = 'Tidak ada koneksi internet';
  static const String errorServerError = 'Terjadi kesalahan pada server';
  static const String errorUnauthorized = 'Sesi Anda telah berakhir. Silakan login kembali';
  static const String errorNotFound = 'Data tidak ditemukan';
  static const String errorTimeout = 'Koneksi timeout. Silakan coba lagi';

  // SaaS Subscription & Owner Payment Details
  static const String ownerDanaNumber = '089609497390';
  static const String ownerDanaName = 'Taufiq Aziz';
  static const String ownerWhatsApp = '6281914170701';
}
