import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_avatar.dart';
import '../../../../../data/providers/dashboard_provider.dart';
import '../../../../../data/providers/auth_provider.dart';
import '../../../../../data/providers/notification_provider.dart';
import '../../../notifications/presentation/pages/admin_notifications_page.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _showProfit = true, _showPendapatan = true, _showPengeluaran = true;
  final _months = ['Semua Bulan','Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final charts = ref.watch(dashboardChartsProvider);
    final user = ref.watch(currentUserProvider);
    final month = ref.watch(selectedMonthProvider);
    final year = ref.watch(selectedYearProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: Column(children: [
          _header(user, month, year),
          Expanded(child: RefreshIndicator(
            onRefresh: () async { ref.invalidate(dashboardStatsProvider); ref.invalidate(dashboardChartsProvider); },
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(padding: const EdgeInsets.all(16), child: stats.when(
                data: (s) => _statsCards(context, s),
                loading: () => _loading(),
                error: (e, _) => _error(e.toString()))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: charts.when(
                data: (d) => _chartsSection(d),
                loading: () => _chartsLoading(),
                error: (_, __) => const SizedBox.shrink())),
              const SizedBox(height: 100),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _header(AsyncValue<dynamic> user, int month, int year) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF667EEA), Color(0xFF5324E0)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 18), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [_avatar(user), const SizedBox(width: 10), Expanded(child: _userInfo(user)),
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminNotificationsPage())),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            unreadCount.when(
              data: (count) => count > 0 ? Positioned(right: 0, top: 0, child: Container(
                padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(count > 99 ? '99+' : count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(), error: (_, __) => const SizedBox.shrink())]),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white, size: 22), onPressed: _logout, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36))]),
        const SizedBox(height: 6),
        Text(DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now()) + ' pukul ' + DateFormat('HH.mm', 'id_ID').format(DateTime.now()) + ' WIB', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _monthFilter(month)), const SizedBox(width: 10), Expanded(child: _yearFilter(year))]),
      ]))));
  }

  Widget _avatar(AsyncValue<dynamic> u) => u.when(
    data: (user) => AppAvatar(photoUrl: user?.photoUrl, name: user?.fullName, size: 42),


    loading: () => Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3))),
    error: (_, __) => Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.3)), child: const Icon(Icons.person, color: Colors.white)));

  Widget _userInfo(AsyncValue<dynamic> u) => u.when(
    data: (user) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Hallo, ${user?.fullName ?? "Admin"}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
      Text(user?.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10), overflow: TextOverflow.ellipsis)]),
    loading: () => const Text('Memuat...', style: TextStyle(color: Colors.white, fontSize: 14)),
    error: (_, __) => const Text('Error', style: TextStyle(color: Colors.white)));

  Widget _monthFilter(int v) => Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
    child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: v, isExpanded: true, dropdownColor: const Color(0xFF667EEA), isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      items: List.generate(_months.length, (i) => DropdownMenuItem(value: i, child: Text(_months[i]))),
      onChanged: (x) => x != null ? ref.read(selectedMonthProvider.notifier).state = x : null)));

  Widget _yearFilter(int v) => Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
    child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: v, isExpanded: true, dropdownColor: const Color(0xFF667EEA), isDense: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
      items: List.generate(4, (i) => DropdownMenuItem(value: DateTime.now().year - i, child: Text((DateTime.now().year - i).toString()))),
      onChanged: (x) => x != null ? ref.read(selectedYearProvider.notifier).state = x : null)));

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Konfirmasi'), content: const Text('Yakin ingin keluar?'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Keluar'))]));
    if (ok == true && mounted) { await ref.read(authControllerProvider).logout(); if (mounted) context.go('/login'); }
  }

  Widget _statsCards(BuildContext ctx, dynamic s) {
    final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final month = ref.read(selectedMonthProvider);
    final year = ref.read(selectedYearProvider);
    
    return Column(children: [
      _largeCard('Profit', f.format(s.profit), Icons.account_balance_wallet, [const Color(0xFF9969C7), const Color(0xFF6A359C)], _showProfit, () => setState(() => _showProfit = !_showProfit)),
      const SizedBox(height: 8),
      // Row 1: Pendapatan & Pengeluaran
      IntrinsicHeight(child: Row(children: [
        Expanded(child: _smallToggle('Pendapatan', f.format(s.totalRevenue), Icons.trending_up, [const Color(0xFF004e92), const Color(0xFF000428)], _showPendapatan, () => setState(() => _showPendapatan = !_showPendapatan))),
        const SizedBox(width: 8),
        Expanded(child: _smallToggle('Pengeluaran', f.format(s.totalExpenses), Icons.trending_down, [const Color(0xFF485563), const Color(0xFF29323c)], _showPengeluaran, () => setState(() => _showPengeluaran = !_showPengeluaran))),
      ])),
      const SizedBox(height: 8),
      // Row 2: Pelanggan Aktif & Tidak Aktif
      IntrinsicHeight(child: Row(children: [
        Expanded(child: _smallCard('Pelanggan Aktif', s.activeCustomers.toString(), Icons.people, [const Color(0xFF1e3c72), const Color(0xFF2a5298)], () => ctx.push('/admin/customers?status=AKTIF'))),
        const SizedBox(width: 8),
        Expanded(child: _smallCard('Pelanggan Tdk Aktif', s.inactiveCustomers.toString(), Icons.person_off, [const Color(0xFF614385), const Color(0xFF516395)], () => ctx.push('/admin/customers?status=NONAKTIF'))),
      ])),
      const SizedBox(height: 8),
      // Row 3: Belum Bayar & Lunas
      IntrinsicHeight(child: Row(children: [
        Expanded(child: _smallCard('Belum Bayar', s.unpaidInvoicesCount.toString(), Icons.schedule, [const Color(0xFF4e4376), const Color(0xFF2b5876)], () => ctx.push('/admin/invoices?status=unpaid&bulan=$month&tahun=$year'))),
        const SizedBox(width: 8),
        Expanded(child: _smallCard('Lunas', s.paidInvoicesCount.toString(), Icons.check_circle, [const Color(0xFF141e30), const Color(0xFF243b55)], () => ctx.push('/admin/invoices?status=paid&bulan=$month&tahun=$year'))),
      ])),
    ]);
  }

  Widget _largeCard(String l, String v, IconData icon, List<Color> g, bool vis, VoidCallback t) => Container(
    width: double.infinity, clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: g[0].withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, size: 32, color: Colors.white.withOpacity(0.9)), _eye(vis, t)]),
      const SizedBox(height: 8),
      Text(l, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Text(vis ? v : 'Rp •••••••', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]));

  Widget _smallToggle(String l, String v, IconData icon, List<Color> g, bool vis, VoidCallback t) => Container(
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: g[0].withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]),
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)), _eye(vis, t, s: true)]),
      const SizedBox(height: 8),
      Text(l, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(vis ? v : 'Rp •••••••', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)]));

  Widget _smallCard(String l, String v, IconData icon, List<Color> g, VoidCallback? tap) => GestureDetector(onTap: tap, child: Container(
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g), borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: g[0].withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]),
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)), if (tap != null) Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white.withOpacity(0.7))]),
      const SizedBox(height: 8),
      Text(l, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      if (tap != null) ...[const SizedBox(height: 4), Text('👆 Ketuk untuk detail', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10))]])));

  Widget _eye(bool vis, VoidCallback t, {bool s = false}) => GestureDetector(onTap: t, child: Container(padding: EdgeInsets.all(s ? 6 : 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
    child: Icon(vis ? Icons.visibility : Icons.visibility_off, color: Colors.white.withOpacity(0.9), size: s ? 16 : 20)));

  Widget _chartsSection(dynamic d) => d == null ? const SizedBox.shrink() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _revenueChartCard(d),
    const SizedBox(height: 12),
    _chartCard('Status Pembayaran', 'Bulan ini', SizedBox(height: 200, child: _paymentChart(d))),
    const SizedBox(height: 12),
    _chartCard('Pertumbuhan Pelanggan', 'Baru vs Cabut', SizedBox(height: 200, child: _growthChart(d))),
    const SizedBox(height: 12),
    _chartCard('Total Pelanggan Aktif', 'Kumulatif 6 bulan', SizedBox(height: 200, child: _totalChart(d)))]);

  // Chart card container - sama seperti web (bg-white rounded-2xl shadow-lg p-6)
  Widget _chartCard(String t, String s, Widget c) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
        Row(children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]),
      ]),
      const SizedBox(height: 20),
      c,
    ]),
  );

  // Revenue chart card - sama seperti web (Pendapatan & Profit)
  Widget _revenueChartCard(dynamic d) {
    final lb = d.labels as List<String>? ?? [];
    final rv = d.revenueData as List<double>? ?? [];
    final ex = d.expensesData as List<double>? ?? [];
    final pf = d.profitData as List<double>? ?? [];
    if (lb.isEmpty || rv.isEmpty) return _chartCard('Pendapatan & Profit', '6 bulan terakhir', _noData());
    
    final allData = [...rv, ...ex, ...pf];
    final f = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    
    // Warna sama seperti web Chart.js
    const colorPendapatan = Color(0xFF22C55E); // green-500
    const colorPengeluaran = Color(0xFFEF4444); // red-500
    const colorProfit = Color(0xFF8B5CF6); // violet-500
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Flexible(child: Text('Pendapatan & Profit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)))),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: colorPendapatan, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('6 bulan terakhir', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          ]),
        ]),
        const SizedBox(height: 12),
        // Legend seperti web - dengan usePointStyle
        Wrap(spacing: 16, runSpacing: 8, children: [
          _legendItem('Pendapatan', colorPendapatan),
          _legendItem('Pengeluaran', colorPengeluaran),
          _legendItem('Profit', colorProfit),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: LineChart(LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1F2937),
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(10),
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                final idx = touchedSpots.first.x.toInt();
                final month = idx >= 0 && idx < lb.length ? lb[idx] : '';
                return touchedSpots.asMap().entries.map((e) {
                  final spot = e.value;
                  String label = '';
                  Color color = Colors.white;
                  if (spot.barIndex == 0) { label = 'Pendapatan'; color = colorPendapatan; }
                  else if (spot.barIndex == 1) { label = 'Pengeluaran'; color = colorPengeluaran; }
                  else if (spot.barIndex == 2) { label = 'Profit'; color = colorProfit; }
                  return LineTooltipItem(
                    e.key == 0 ? '$month\n$label: ${f.format(spot.y)}' : '$label: ${f.format(spot.y)}',
                    TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: _int(allData.map((e) => e as num).toList())),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(_cmp(v), style: const TextStyle(fontSize: 8, color: Colors.grey)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, _) { final i = v.toInt(); return i >= 0 && i < lb.length && v == i.toDouble() ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(lb[i], style: const TextStyle(fontSize: 7, color: Colors.grey))) : const SizedBox.shrink(); })),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), 
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
          borderData: FlBorderData(show: false), 
          lineBarsData: [
            // Pendapatan - hijau seperti web
            LineChartBarData(
              spots: rv.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true, curveSmoothness: 0.3,
              color: colorPendapatan, barWidth: 3,
              dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: colorPendapatan, strokeWidth: 2, strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: colorPendapatan.withOpacity(0.15)),
            ),
            // Pengeluaran - merah seperti web
            if (ex.isNotEmpty) LineChartBarData(
              spots: ex.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true, curveSmoothness: 0.3,
              color: colorPengeluaran, barWidth: 3,
              dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: colorPengeluaran, strokeWidth: 2, strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: colorPengeluaran.withOpacity(0.15)),
            ),
            // Profit - ungu seperti web
            if (pf.isNotEmpty) LineChartBarData(
              spots: pf.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true, curveSmoothness: 0.3,
              color: colorProfit, barWidth: 3,
              dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: colorProfit, strokeWidth: 2, strokeColor: Colors.white)),
              belowBarData: BarAreaData(show: true, color: colorProfit.withOpacity(0.15)),
            ),
          ],
        ))),
      ]));
  }

  // Legend item dengan point style seperti web Chart.js
  Widget _legendItem(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)))]);

  // Payment Status Doughnut Chart - sama seperti web
  Widget _paymentChart(dynamic d) {
    final counts = d.invoiceStatusCounts as Map<String, int>? ?? {};
    if (counts.isEmpty) return _noData();
    final lb = ['Lunas', 'Cicilan', 'Belum Bayar'];
    final vl = [counts['paid'] ?? 0, counts['partially_paid'] ?? 0, counts['unpaid'] ?? 0];
    // Warna sama seperti web
    final cl = [const Color(0xFF22C55E), const Color(0xFFF59E0B), const Color(0xFFEF4444)];
    final total = vl.fold<int>(0, (a, b) => a + b);
    
    return Row(children: [
      // Doughnut chart dengan cutout 60% seperti web
      Expanded(flex: 3, child: PieChart(PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 50, // cutout 60%
        sections: vl.asMap().entries.map((e) {
          final p = total > 0 ? (e.value / total * 100) : 0;
          return PieChartSectionData(
            value: e.value.toDouble(),
            color: cl[e.key % cl.length],
            radius: 35,
            title: p > 5 ? '${p.toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            titlePositionPercentageOffset: 0.55,
          );
        }).toList(),
      ))),
      const SizedBox(width: 16),
      // Legend di bawah seperti web
      Expanded(flex: 2, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lb.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: cl[e.key % cl.length], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                Text('${vl[e.key]} tagihan', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
              ],
            )),
          ]),
        )).toList(),
      )),
    ]);
  }

  // Customer Growth Bar Chart - sama seperti web (Baru vs Cabut)
  Widget _growthChart(dynamic d) {
    final lb = d.labels as List<String>? ?? [];
    final nw = d.customerGrowthData as List<int>? ?? [];
    final ch = d.customerNetData as List<int>? ?? [];
    if (lb.isEmpty || nw.isEmpty) return _noData();
    
    // Warna sama seperti web
    const colorBaru = Color(0xFF22C55E);
    const colorCabut = Color(0xFFEF4444);
    
    return Column(children: [
      // Legend di atas seperti web
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendItem('Pelanggan Baru', colorBaru),
          const SizedBox(width: 20),
          _legendItem('Pelanggan Cabut', colorCabut),
        ]),
      ),
      Expanded(child: BarChart(BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 32, getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= lb.length || v != i.toDouble()) return const SizedBox.shrink();
            // Singkat nama bulan agar tidak rapat
            final shortMonth = lb[i].length > 3 ? lb[i].substring(0, 3) : lb[i];
            return Padding(padding: const EdgeInsets.only(top: 8), child: Text(shortMonth, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))));
          })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(lb.length, (i) => BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: [
            BarChartRodData(toY: nw[i].toDouble(), color: colorBaru, width: 10, borderRadius: BorderRadius.circular(3)),
            if (ch.isNotEmpty && i < ch.length) BarChartRodData(toY: ch[i].abs().toDouble(), color: colorCabut, width: 10, borderRadius: BorderRadius.circular(3)),
          ],
        )),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F2937),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Baru' : 'Cabut';
              return BarTooltipItem('$label: ${rod.toY.toInt()} pelanggan', const TextStyle(color: Colors.white, fontSize: 12));
            },
          ),
        ),
      ))),
    ]);
  }

  // Total Active Customers Line Chart - sama seperti web
  Widget _totalChart(dynamic d) {
    final lb = d.labels as List<String>? ?? [];
    final vl = d.customerTotalData as List<int>? ?? [];
    if (lb.isEmpty || vl.isEmpty) return _noData();
    
    const colorTotal = Color(0xFF8B5CF6); // violet-500 seperti web
    
    return LineChart(LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, _) {
          final i = v.toInt();
          return i >= 0 && i < lb.length && v == i.toDouble()
            ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(lb[i], style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))))
            : const SizedBox.shrink();
        })),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1F2937),
          tooltipRoundedRadius: 8,
          getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(
            'Total Aktif: ${spot.y.toInt()} pelanggan',
            const TextStyle(color: Colors.white, fontSize: 12),
          )).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: vl.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
          isCurved: true, curveSmoothness: 0.3,
          color: colorTotal, barWidth: 3,
          dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: colorTotal, strokeWidth: 2, strokeColor: Colors.white)),
          belowBarData: BarAreaData(show: true, color: colorTotal.withOpacity(0.15)),
        ),
      ],
    ));
  }

  double _int(List<num> v) => v.isEmpty ? 1 : (v.reduce((a, b) => a > b ? a : b) / 4).ceilToDouble().clamp(1, double.infinity);
  String _cmp(double v) => v >= 1000000 ? '${(v / 1000000).toStringAsFixed(1)}jt' : v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}rb' : v.toInt().toString();
  Widget _noData() => const Center(child: Text('No data', style: TextStyle(color: Colors.grey, fontSize: 11)));

  // Loading skeleton untuk stats cards
  Widget _loading() => Column(children: [
    // Large card skeleton (Profit)
    Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
      child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
    const SizedBox(height: 8),
    // Row 1: Pendapatan & Pengeluaran
    _skeletonRow(),
    const SizedBox(height: 8),
    // Row 2: Pelanggan Aktif & Tidak Aktif
    _skeletonRow(),
    const SizedBox(height: 8),
    // Row 3: Belum Bayar & Lunas
    _skeletonRow(),
  ]);

  Widget _skeletonRow() => Shimmer.fromColors(
    baseColor: Colors.grey[300]!, 
    highlightColor: Colors.grey[100]!,
    child: Row(children: [
      Expanded(child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
    ]),
  );

  // Error widget
  Widget _error(String msg) => Center(child: Padding(padding: const EdgeInsets.all(20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 48),
      const SizedBox(height: 12),
      const Text('Gagal memuat data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(msg, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)])));

  // Loading skeleton untuk charts
  Widget _chartsLoading() => Column(children: List.generate(4, (_) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
      child: Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))))));
}
