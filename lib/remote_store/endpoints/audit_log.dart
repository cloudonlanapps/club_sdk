import 'package:meta/meta.dart';

@immutable
class AuditLogEndpoints {
  const AuditLogEndpoints();

  String get list => '/audit_log';
}
