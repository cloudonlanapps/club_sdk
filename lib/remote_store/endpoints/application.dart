import 'package:meta/meta.dart';

/// URL builder for `/applications`: printable application templates and
/// their forms (club_server#93, #66).
@immutable
class ApplicationEndpoints {
  const ApplicationEndpoints();

  String get list => '/applications';
  String get labels => '/applications/labels';
  String get clauses => '/applications/clauses';
  String get library => '/applications/library';
  String libraryText(int id) => '/applications/library/$id';
  String byId(int id) => '/applications/$id';
  String save(int id) => '/applications/$id/save';
  String publish(int id) => '/applications/$id/publish';
  String unpublish(int id) => '/applications/$id/unpublish';
  String revert(int id) => '/applications/$id/revert';
  String duplicate(int id) => '/applications/$id/duplicate';
  String preview(int id) => '/applications/$id/preview';
  String ownForm(int id) => '/applications/$id/form';
  String memberForm(int id, String username) =>
      '/applications/$id/form/$username';
}
