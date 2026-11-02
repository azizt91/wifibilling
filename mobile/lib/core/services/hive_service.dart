import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/invoice_model.dart';

class HiveService {
  static const String dashboardStatsBox = 'dashboard_stats';
  static const String customersBox = 'customers';
  static const String invoicesBox = 'invoices';
  static const String cacheMetaBox = 'cache_meta';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProfileModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(InvoiceModelAdapter());
    }

    // Open boxes
    await Hive.openBox(dashboardStatsBox);
    await Hive.openBox<ProfileModel>(customersBox);
    await Hive.openBox<InvoiceModel>(invoicesBox);
    await Hive.openBox(cacheMetaBox);
  }

  static Future<void> clearAllCache() async {
    await Hive.box(dashboardStatsBox).clear();
    await Hive.box<ProfileModel>(customersBox).clear();
    await Hive.box<InvoiceModel>(invoicesBox).clear();
    await Hive.box(cacheMetaBox).clear();
  }

  static Future<void> close() async {
    await Hive.close();
  }
}
