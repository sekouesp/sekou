import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { broadcast, message }

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String text;
  final Timestamp timestamp;
  bool read;
  final String? targetRoute;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.text,
    required this.timestamp,
    this.read = false,
    this.targetRoute,
  });
}
