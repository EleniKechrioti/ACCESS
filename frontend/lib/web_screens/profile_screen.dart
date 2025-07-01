import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Displays the user profile screen including:
/// - An embedded Power BI dashboard (web only)
/// - A list of reports fetched by postal code (TK)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Power BI embed URL (iframe for web)
  final String powerBiUrl =
      'https://app.powerbi.com/reportEmbed?reportId=dc6a2823-3800-44e2-acc3-e8e9c99582ac&autoAuth=true&ctid=ad5ba4a2-7857-4ea1-895e-b3d5207a174f';

  /// Gateway base URL (update to production URL when needed)
  final String gatewayBaseUrl = 'http://localhost:9090';

  /// Test postal code used to fetch reports
  final String testTk = '11523';

  @override
  void initState() {
    super.initState();

    /// Register iframe view for Power BI — works only on web
    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'power-bi-view',
            (int viewId) {
          final iFrameElement = html.IFrameElement()
            ..src = powerBiUrl
            ..style.border = 'none'
            ..width = '100%'
            ..height = '500';
          return iFrameElement;
        },
      );
    }
  }

  /// Fetches reports from the gateway by postal code
  Future<List<Map<String, dynamic>>> fetchReportsByTk(String tk) async {
    final url = Uri.parse('$gatewayBaseUrl/reports-by-tk?tk=$tk');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List reports = decoded['reports'] ?? [];
      return List<Map<String, dynamic>>.from(reports);
    } else {
      throw Exception('Αποτυχία φόρτωσης αναφορών');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Το Προφίλ μου'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Power BI Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (kIsWeb)
              SizedBox(
                height: 400,
                child: HtmlElementView(viewType: 'power-bi-view'),
              )
            else
              Container(
                height: 100,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Text('Power BI dashboard διατίθεται μόνο σε web'),
              ),
            const SizedBox(height: 30),
            const Text(
              'Οι Αναφορές μου',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _ReportsList(
              fetchReports: () => fetchReportsByTk(testTk),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateless widget that displays a list of reports using a Future
class _ReportsList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() fetchReports;
  const _ReportsList({required this.fetchReports});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Σφάλμα: ${snapshot.error}');
        }

        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const Text('Δεν υπάρχουν διαθέσιμες αναφορές.');
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];

            /// Extract values safely from Firestore-style nested objects
            final title = report["locationDescription"]["stringValue"] ?? 'Χωρίς τίτλο';
            final dateRaw = report["timestamp"]["timestampValue"];

            String dateStr;
            if (dateRaw is String) {
              dateStr = dateRaw;
            } else if (dateRaw != null && dateRaw is Map && dateRaw['seconds'] != null) {
              final seconds = dateRaw['seconds'] as int;
              final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
              dateStr = date.toLocal().toString();
            } else {
              dateStr = '';
            }

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text('Ημερομηνία: $dateStr'),
              ),
            );
          },
        );
      },
    );
  }
}
