import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class representing a user-submitted report of an obstacle or accessibility issue.
/// Contains metadata like user info, location, timestamps, approval status, and optional description/image.
class Report {
  final String id;
  final String userId;
  final String? userEmail;
  final String locationDescription;
  final GeoPoint coordinates;
  final String obstacleType;
  final String accessibility;
  final String? description;
  final String? imageUrl;
  final Timestamp timestamp;
  final bool isApproved;
  final Timestamp? approvedTimestamp;

  Report({
    required this.id,
    required this.userId,
    this.userEmail,
    required this.locationDescription,
    required this.coordinates,
    required this.obstacleType,
    required this.accessibility,
    this.description,
    this.imageUrl,
    required this.timestamp,
    required this.isApproved,
    this.approvedTimestamp,
  });

  /// Factory constructor to create a Report instance from Firestore document snapshot data.
  factory Report.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for Report ${doc.id}');
    }

    return Report(
      id: doc.id,
      userId: data['userId'] ?? 'unknown_user',
      userEmail: data['userEmail'] as String?,
      locationDescription: data['locationDescription'] ?? 'Άγνωστη τοποθεσία',
      // Safe handling of GeoPoint field
      coordinates: data['coordinates'] is GeoPoint
          ? data['coordinates'] as GeoPoint
          : const GeoPoint(0, 0), // Default fallback if missing or invalid type
      obstacleType: data['obstacleType'] ?? 'Άγνωστος τύπος',
      accessibility: data['accessibility'] ?? 'Άγνωστη προσβασιμότητα',
      description: data['description'] as String?,
      imageUrl: data['imageUrl'] as String?,
      // Safe handling of Timestamp field
      timestamp: data['timestamp'] is Timestamp
          ? data['timestamp'] as Timestamp
          : Timestamp.now(), // Default fallback if missing or invalid type
      isApproved: data['isApproved'] ?? false, // Default false
      approvedTimestamp: data['approvedTimestamp'] as Timestamp?,
    );
  }

  /// Helper getter to format the main timestamp for display (e.g. '2025-04-29 12:30').
  String get formattedTimestamp {
    return timestamp.toDate().toLocal().toString().substring(0, 16);
  }

  /// Helper getter to format the approval timestamp or return '-' if not approved yet.
  String get formattedApprovalTimestamp {
    if (approvedTimestamp == null) return '-';
    return approvedTimestamp!.toDate().toLocal().toString().substring(0, 16);
  }
}
