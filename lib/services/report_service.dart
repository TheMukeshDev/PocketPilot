import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/expense.dart';

class ReportService {
  ReportService._();

  static final ReportService instance = ReportService._();

  String _currency(int value) =>
      'INR ${NumberFormat.decimalPattern('en_IN').format(value)}';

  Future<void> exportSpendingReportPdf({
    required List<Expense> expenses,
    required int monthlyBudget,
    required int rent,
  }) async {
    final fileName =
        'budget_report_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.pdf';

    final doc = pw.Document();
    final spent = expenses.fold<int>(0, (sum, item) => sum + item.amount);
    final available = monthlyBudget - rent;
    final remaining = available - spent;
    final dateFormat = DateFormat('dd MMM yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'PocketPilot - Spending Report',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${dateFormat.format(DateTime.now())}'),
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metricCard('Monthly Budget', _currency(monthlyBudget)),
              _metricCard('Rent', _currency(rent)),
              _metricCard('Spent', _currency(spent)),
              _metricCard('Remaining', _currency(remaining)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Expense Entries',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          if (expenses.isEmpty)
            pw.Text('No expenses found for this period.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: const ['Date', 'Title', 'Category', 'Amount'],
              data: expenses
                  .map(
                    (expense) => [
                      dateFormat.format(expense.date),
                      expense.title,
                      expense.category,
                      _currency(expense.amount),
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );

    final bytes = await doc.save();

    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  pw.Container _metricCard(String title, String value) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
