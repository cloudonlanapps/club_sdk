import 'dart:convert';

import 'package:meta/meta.dart';

/// One member a bulk attendance mark declined to record, and why (#14).
///
/// [code] is an `SdkErrorCode`, `INSUFFICIENT_CREDIT` where the member
/// holds no usable credit for the programme. The member stays enrolled;
/// no attendance record was written for them.
@immutable
class RefusedAttendance {
  const RefusedAttendance({
    required this.membername,
    required this.code,
    required this.message,
  });

  factory RefusedAttendance.fromMap(Map<String, dynamic> map) {
    return RefusedAttendance(
      membername: map['membername'] as String,
      code: map['code'] as String,
      message: map['message'] as String? ?? '',
    );
  }

  factory RefusedAttendance.fromJson(String source) =>
      RefusedAttendance.fromMap(json.decode(source) as Map<String, dynamic>);

  final String membername;
  final String code;
  final String message;

  RefusedAttendance copyWith({
    String? membername,
    String? code,
    String? message,
  }) {
    return RefusedAttendance(
      membername: membername ?? this.membername,
      code: code ?? this.code,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toMap() {
    return {'membername': membername, 'code': code, 'message': message};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'RefusedAttendance(membername: $membername, code: $code, '
      'message: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RefusedAttendance &&
        other.membername == membername &&
        other.code == code &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(membername, code, message);
}
