class VideoItem {
  final String id;
  final String title;
  final String thumbnailUrl;
  final Duration? duration;

  const VideoItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    this.duration,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$id';
}