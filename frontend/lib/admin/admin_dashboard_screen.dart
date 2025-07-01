import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'report_model.dart';

/// Admin dashboard screen displaying reports from Firestore.
/// Allows approving or deleting reports, including image management in Firebase Storage.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Shows a confirmation dialog and approves the report with the given [reportId].
  /// Updates Firestore fields 'isApproved' and 'approvedTimestamp'.
  Future<void> _approveReport(String reportId) async {
    if (!mounted) return; // Safety check if widget is disposed
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Επιβεβαίωση Έγκρισης'),
        content: const Text('Είστε σίγουροι ότι θέλετε να εγκρίνετε αυτή την αναφορά;'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ακύρωση')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Έγκριση')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reportRef = _firestore.collection('reports').doc(reportId);
        await reportRef.update({
          'isApproved': true,
          'approvedTimestamp': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Η αναφορά εγκρίθηκε.'), backgroundColor: Colors.green));
        }
      } catch (e) {
        print("Error approving report $reportId: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Σφάλμα έγκρισης: ${e.toString()}'), backgroundColor: Colors.red));
        }
      }
    }
  }

  /// Shows a confirmation dialog and deletes the report and its image (if any).
  /// First deletes the image from Firebase Storage, then deletes the Firestore document.
  Future<void> _deleteReport(Report report) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Επιβεβαίωση Διαγραφής'),
        content: const Text('Είστε σίγουροι ότι θέλετε να διαγράψετε οριστικά αυτή την αναφορά (και την εικόνα της αν υπάρχει); Η ενέργεια δεν αναιρείται.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ακύρωση')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Διαγραφή', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Delete image from Firebase Storage (if exists)
        if (report.imageUrl != null && report.imageUrl!.isNotEmpty) {
          try {
            final imageRef = _storage.refFromURL(report.imageUrl!);
            await imageRef.delete();
            print('Image deleted from Storage: ${report.imageUrl}');
          } catch (storageError) {
            print('Could not delete image ${report.imageUrl} from Storage: $storageError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Προειδοποίηση: Αδυναμία διαγραφής εικόνας από Storage. ${storageError.toString()}'), backgroundColor: Colors.orange));
            }
          }
        }

        // 2. Delete Firestore document
        final reportRef = _firestore.collection('reports').doc(report.id);
        await reportRef.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Η αναφορά διαγράφηκε.'), backgroundColor: Colors.green));
        }

      } catch (e) {
        print("Error deleting report ${report.id}: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Σφάλμα διαγραφής: ${e.toString()}'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard - Αναφορές'),
        actions: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(child: Text(user.email ?? 'Admin')),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Αποσύνδεση',
              onPressed: () async {
                await _auth.signOut();
                // Navigation handled automatically by AuthGate/StreamBuilder
              },
            )
          ]
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // You can filter reports here (e.g. only unapproved reports)
        stream: _firestore.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Σφάλμα φόρτωσης δεδομένων: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Δεν υπάρχουν αναφορές.'));
          }

          // Convert Firestore docs to Report models, ignoring errors
          final reports = snapshot.data!.docs.map((doc) {
            try {
              return Report.fromFirestore(doc);
            } catch (e) {
              print("Error parsing report ${doc.id}: $e");
              return null;
            }
          }).whereType<Report>().toList();

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final isApproved = report.isApproved;
              final cardColor = isApproved ? Colors.green.shade50 : Colors.orange.shade50;

              return Card(
                color: cardColor,
                margin: const EdgeInsets.symmetric(vertical: 5.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ημ/νία: ${report.formattedTimestamp}', style: Theme.of(context).textTheme.bodySmall),
                      Text('Τύπος: ${report.obstacleType} (${report.accessibility})'),
                      Text('Τοποθεσία: ${report.locationDescription}'),
                      Text('Συν/νες: ${report.coordinates.latitude.toStringAsFixed(5)}, ${report.coordinates.longitude.toStringAsFixed(5)}'),
                      if (report.description != null && report.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Περιγραφή: ${report.description}'),
                        ),
                      if (report.imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Image.network(
                            report.imageUrl!,
                            height: 100,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) => const Text('Σφάλμα φόρτ. εικόνας', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text('Κατάσταση: ${isApproved ? 'Εγκεκριμένη (${report.formattedApprovalTimestamp})' : 'Εκκρεμεί'}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isApproved ? Colors.green.shade800 : Colors.orange.shade900)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isApproved)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Έγκριση'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _approveReport(report.id),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('Διαγραφή'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _deleteReport(report),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
