import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/admin/reports/presentation/pages/admin_reports_page.dart';

class ReportPdfService {
  static Future<Uint8List> generatePdf({
    required ReportData data,
    String storeName = 'WiFi Billing System',
    required NumberFormat currencyFormat,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
    final dateOnlyFormat = DateFormat('dd/MM/yyyy', 'id_ID');
    final netIncome = data.totalPendapatan - data.totalPengeluaran;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      storeName.isNotEmpty ? storeName : 'WiFi Billing System',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepPurple700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'LAPORAN KEUANGAN & TRANSAKSI',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dicetak pada:',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.deepPurple300),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          // Ringkasan Keuangan Card
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RINGKASAN LAPORAN',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepPurple900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Pendapatan (Lunas):', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            currencyFormat.format(data.totalPendapatan),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Pengeluaran:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            currencyFormat.format(data.totalPengeluaran),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Pendapatan Bersih:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            currencyFormat.format(netIncome),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: netIncome >= 0 ? PdfColors.blue700 : PdfColors.red700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Belum Bayar:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            currencyFormat.format(data.totalUnpaid),
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Cicilan:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            currencyFormat.format(data.totalInstallment),
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Jumlah Transaksi:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text(
                            '${data.items.length} Data (${data.countLunas} Lunas, ${data.countPengeluaran} Pengeluaran)',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Tabel Transaksi
          pw.Text(
            'RINCIAN TRANSAKSI (${data.items.length})',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['No', 'Tanggal', 'Nama / Keterangan', 'Tipe', 'Metode', 'Status', 'Nominal'],
            data: List<List<dynamic>>.generate(data.items.length, (index) {
              final item = data.items[index];
              final isExpense = item.type == 'expense';
              final statusText = item.status == 'paid'
                  ? 'Lunas'
                  : item.status == 'unpaid'
                      ? 'Belum Bayar'
                      : item.status == 'partially_paid' || item.status == 'installment'
                          ? 'Cicilan'
                          : isExpense
                              ? 'Pengeluaran'
                              : item.status;

              final nameDesc = item.description.isNotEmpty && item.description != item.customerName
                  ? '${item.customerName}\n(${item.description})'
                  : item.customerName;

              return [
                '${index + 1}',
                dateOnlyFormat.format(item.date),
                nameDesc,
                isExpense ? 'Pengeluaran' : 'Pendapatan',
                item.paymentMethod.isNotEmpty ? item.paymentMethod : '-',
                statusText,
                '${isExpense ? '-' : '+'}${currencyFormat.format(item.amount)}',
              ];
            }),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple700),
            headerAlignment: pw.Alignment.center,
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FixedColumnWidth(48),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(55),
              4: const pw.FixedColumnWidth(45),
              5: const pw.FixedColumnWidth(50),
              6: const pw.FixedColumnWidth(75),
            },
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

