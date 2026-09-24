import 'dart:convert';

import 'package:meta/meta.dart';

/// Represents a v2 media record (image, video, or pdf).
///
/// Maps to the server's `/v1/media` response schema.
@immutable
class Media {
  const Media({
    required this.id,
    required this.uuid,
    required this.originalFilename,
    required this.mediaType,
    required this.mimeType,
    required this.originalMimeType,
    required this.filename,
    required this.fileSize,
    required this.preserveOriginal,
    required this.conversionStatus,
    required this.accessRoles,
    required this.isEncrypted,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.conversionError,
    this.uploadedBy,
    this.deletedAtUtc,
  });

  factory Media.fromMap(Map<String, dynamic> map) {
    final roles = map['accessRoles'];
    final accessRoles = roles is List
        ? roles.map((e) => e.toString()).toList()
        : <String>['public'];
    return Media(
      id: map['id'] as int,
      uuid: map['uuid'] as String,
      originalFilename: map['originalFilename'] as String,
      mediaType: map['mediaType'] as String,
      mimeType: map['mimeType'] as String,
      originalMimeType: map['originalMimeType'] as String,
      filename: map['filename'] as String,
      fileSize: map['fileSize'] as int,
      preserveOriginal: map['preserveOriginal'] as bool? ?? false,
      conversionStatus: map['conversionStatus'] as String,
      conversionError: map['conversionError'] as String?,
      uploadedBy: map['uploadedBy'] as String?,
      accessRoles: accessRoles,
      isEncrypted: map['isEncrypted'] as bool? ?? false,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      deletedAtUtc: map['deletedAtUtc'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            ),
    );
  }

  factory Media.fromJson(String source) =>
      Media.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String uuid;
  /// The name the file was uploaded under. See [originalMimeType].
  final String originalFilename;
  final String mediaType;

  /// The type of the **stored** file — what a download's `Content-Type` says.
  ///
  /// Not the uploaded type: an image uploaded as PNG without
  /// `preserveOriginal` is stored and served as WebP, and this says
  /// `image/webp` (club_server#426).
  final String mimeType;

  /// The type the file was uploaded as, kept beside [originalFilename].
  final String originalMimeType;

  /// The name to put in the download URL and to save the file under.
  final String filename;

  final int fileSize;
  final bool preserveOriginal;
  final String conversionStatus;
  final String? conversionError;
  final String? uploadedBy;
  final List<String> accessRoles;
  final bool isEncrypted;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? deletedAtUtc;

  bool get isDeleted => deletedAtUtc != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'originalFilename': originalFilename,
      'mediaType': mediaType,
      'mimeType': mimeType,
      'originalMimeType': originalMimeType,
      'filename': filename,
      'fileSize': fileSize,
      'preserveOriginal': preserveOriginal,
      'conversionStatus': conversionStatus,
      'conversionError': conversionError,
      'uploadedBy': uploadedBy,
      'accessRoles': accessRoles,
      'isEncrypted': isEncrypted,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  Media copyWith({
    int? id,
    String? uuid,
    String? originalFilename,
    String? mediaType,
    String? mimeType,
    String? originalMimeType,
    String? filename,
    int? fileSize,
    bool? preserveOriginal,
    String? conversionStatus,
    String? Function()? conversionError,
    String? Function()? uploadedBy,
    List<String>? accessRoles,
    bool? isEncrypted,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? deletedAtUtc,
  }) {
    return Media(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      originalFilename: originalFilename ?? this.originalFilename,
      mediaType: mediaType ?? this.mediaType,
      mimeType: mimeType ?? this.mimeType,
      originalMimeType: originalMimeType ?? this.originalMimeType,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      preserveOriginal: preserveOriginal ?? this.preserveOriginal,
      conversionStatus: conversionStatus ?? this.conversionStatus,
      conversionError: conversionError != null
          ? conversionError()
          : this.conversionError,
      uploadedBy: uploadedBy != null ? uploadedBy() : this.uploadedBy,
      accessRoles: accessRoles ?? this.accessRoles,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return 'Media(id: $id, uuid: $uuid, '
        'originalFilename: $originalFilename, '
        'mediaType: $mediaType, mimeType: $mimeType, fileSize: $fileSize, '
        'preserveOriginal: $preserveOriginal, '
        'conversionStatus: $conversionStatus, '
        'conversionError: $conversionError, uploadedBy: $uploadedBy, '
        'accessRoles: $accessRoles, isEncrypted: $isEncrypted, '
        'createdAtUtc: $createdAtUtc, updatedAtUtc: $updatedAtUtc, '
        'deletedAtUtc: $deletedAtUtc)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Media &&
        other.id == id &&
        other.uuid == uuid &&
        other.originalFilename == originalFilename &&
        other.mediaType == mediaType &&
        other.mimeType == mimeType &&
        other.originalMimeType == originalMimeType &&
        other.filename == filename &&
        other.fileSize == fileSize &&
        other.preserveOriginal == preserveOriginal &&
        other.conversionStatus == conversionStatus &&
        other.conversionError == conversionError &&
        other.uploadedBy == uploadedBy &&
        listEquals(other.accessRoles, accessRoles) &&
        other.isEncrypted == isEncrypted &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      uuid,
      originalFilename,
      mediaType,
      mimeType,
      originalMimeType,
      filename,
      fileSize,
      preserveOriginal,
      conversionStatus,
      conversionError,
      uploadedBy,
      Object.hashAll(accessRoles),
      isEncrypted,
      createdAtUtc,
      updatedAtUtc,
      deletedAtUtc,
    );
  }
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
