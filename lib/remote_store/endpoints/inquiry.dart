import 'package:meta/meta.dart';

/// The inquiry routes (club_server#407, #35): the public form and its
/// token, and the admin inbox.
@immutable
class InquiryEndpoints {
  const InquiryEndpoints();

  String get inbox => '/admin/inquiries';
  String inquiry(int id) => '/admin/inquiries/$id';

  String get submit => '/public/inquiries';
  String get formToken => '/public/inquiries/token';
}
