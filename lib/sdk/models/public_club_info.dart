import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'media_ref.dart';

const _mapEquality = DeepCollectionEquality();

/// The club's public identity document (club_server#296, #35).
///
/// [clubInfo] is the free-form preference the admin edits — name, contact
/// block, socials — and [siteMedia] maps a website slot (`hero`, `about`,
/// …) to the media filling it. Both are `{}` where nothing is set, never
/// null, so a website can render an unconfigured deployment.
///
/// A slot carries a [MediaRef], not a uuid (club_server#424): the landing
/// hero is a video on one deployment and a still on the next, and a uuid does
/// not say which. A slot whose media has since been deleted or hidden is
/// absent rather than broken.
@immutable
class PublicClubInfo {
  const PublicClubInfo({this.clubInfo = const {}, this.siteMedia = const {}});

  factory PublicClubInfo.fromMap(Map<String, dynamic> map) {
    return PublicClubInfo(
      clubInfo: Map<String, dynamic>.from(
        (map['clubInfo'] as Map?) ?? const <String, dynamic>{},
      ),
      siteMedia: ((map['siteMedia'] as Map?) ?? const {}).map(
        (key, value) => MapEntry(
          key as String,
          MediaRef.fromMap(Map<String, dynamic>.from(value as Map)),
        ),
      ),
    );
  }

  factory PublicClubInfo.fromJson(String source) =>
      PublicClubInfo.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The club's public identity, as the admin stored it.
  final Map<String, dynamic> clubInfo;

  /// Website media slot to the media filling it.
  final Map<String, MediaRef> siteMedia;

  PublicClubInfo copyWith({
    Map<String, dynamic>? clubInfo,
    Map<String, MediaRef>? siteMedia,
  }) {
    return PublicClubInfo(
      clubInfo: clubInfo ?? this.clubInfo,
      siteMedia: siteMedia ?? this.siteMedia,
    );
  }

  Map<String, dynamic> toMap() => {
    'clubInfo': clubInfo,
    'siteMedia': siteMedia.map((key, value) => MapEntry(key, value.toMap())),
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PublicClubInfo(clubInfo: $clubInfo, siteMedia: $siteMedia)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicClubInfo &&
        _mapEquality.equals(other.clubInfo, clubInfo) &&
        _mapEquality.equals(other.siteMedia, siteMedia);
  }

  @override
  int get hashCode =>
      _mapEquality.hash(clubInfo) ^ _mapEquality.hash(siteMedia);
}
