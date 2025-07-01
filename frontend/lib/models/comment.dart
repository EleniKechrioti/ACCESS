import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;          // Firestore doc ID
  final String userId;      // ID of user who posted comment
  final String? photoUrl;   // Optional photo URL attached to comment
  final String? text;       // Optional comment text
  final DateTime timestamp; // When comment was created

  Comment({
    required this.id,
    required this.userId,
    this.photoUrl,
    this.text,
    required this.timestamp,
  });

  /// Creates Comment instance from Firestore data and document ID
  factory Comment.fromMap(Map<String, dynamic> map, String id) {
    return Comment(
      id: id,
      userId: map['userId'] ?? '',
      photoUrl: map['photoUrl'],
      text: map['text'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  /// Converts Comment instance into a Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'photoUrl': photoUrl,
      'text': text,
      'timestamp': DateTime.now(),  // Use current time when saving
    };
  }
}
