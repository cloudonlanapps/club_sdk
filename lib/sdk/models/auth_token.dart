import 'dart:convert';

import 'package:meta/meta.dart';

@immutable
class AuthToken {
  const AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAtUtc,
    this.refreshToken,
  });

  factory AuthToken.fromMap(Map<String, dynamic> map) {
    return AuthToken(
      accessToken: map['accessToken'] as String,
      tokenType: map['tokenType'] as String,
      expiresAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['expiresAtUtc'] as int,
        isUtc: true,
      ),
      refreshToken: map['refreshToken'] as String?,
    );
  }

  factory AuthToken.fromJson(String source) =>
      AuthToken.fromMap(json.decode(source) as Map<String, dynamic>);

  final String accessToken;
  final String tokenType;
  final DateTime expiresAtUtc;

  /// Optional refresh token for obtaining new access tokens.
  /// Present in remote store responses, null for local store.
  final String? refreshToken;

  AuthToken copyWith({
    String? accessToken,
    String? tokenType,
    DateTime? expiresAtUtc,
    String? Function()? refreshToken,
  }) {
    return AuthToken(
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
      expiresAtUtc: expiresAtUtc ?? this.expiresAtUtc,
      refreshToken: refreshToken != null ? refreshToken() : this.refreshToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'tokenType': tokenType,
      'expiresAtUtc': expiresAtUtc.millisecondsSinceEpoch,
      'refreshToken': refreshToken,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'AuthToken(accessToken: $accessToken, tokenType: $tokenType, '
      'expiresAtUtc: $expiresAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AuthToken &&
        other.accessToken == accessToken &&
        other.tokenType == tokenType &&
        other.expiresAtUtc == expiresAtUtc &&
        other.refreshToken == refreshToken;
  }

  @override
  int get hashCode =>
      accessToken.hashCode ^
      tokenType.hashCode ^
      expiresAtUtc.hashCode ^
      refreshToken.hashCode;
}
