import 'package:cloud_firestore/cloud_firestore.dart';

class VideoItem {
  final String id;
  final String title;
  final String channel;
  final String thumbnailUrl;
  final DateTime publishedAt;

  const VideoItem({
    required this.id,
    required this.title,
    required this.channel,
    required this.thumbnailUrl,
    required this.publishedAt,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$id';

  factory VideoItem.fromMap(Map<String, dynamic> map) {
    return VideoItem(
      id: map['id'] as String,
      title: map['title'] as String,
      channel: map['channel'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String,
      publishedAt: (map['publishedAt'] as Timestamp).toDate(),
    );
  }
}