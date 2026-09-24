import 'package:meta/meta.dart';

/// Labels for the event detail gallery section.
///
/// Consumed by `cl_club_events` event preview widgets to title the gallery.
@immutable
class EventDetailGalleryLabels {
  const EventDetailGalleryLabels({required this.title, required this.subtitle});

  factory EventDetailGalleryLabels.fromMap(Map<String, dynamic> map) {
    return EventDetailGalleryLabels(
      title: map['title'] as String? ?? 'Gallery',
      subtitle: map['subtitle'] as String? ?? 'Photos and moments',
    );
  }

  final String title;
  final String subtitle;

  Map<String, dynamic> toMap() {
    return {'title': title, 'subtitle': subtitle};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventDetailGalleryLabels &&
        other.title == title &&
        other.subtitle == subtitle;
  }

  @override
  int get hashCode => Object.hash(title, subtitle);
}
