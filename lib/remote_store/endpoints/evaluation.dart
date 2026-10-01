import 'package:meta/meta.dart';

/// URL builder for `/evaluations` and its templates (club_server#302,
/// #535).
@immutable
class EvaluationEndpoints {
  const EvaluationEndpoints();

  String get list => '/evaluations';
  String get deleted => '/evaluations/deleted';
  String byId(int id) => '/evaluations/by_id/$id';
  String hardDelete(int id) => '/evaluations/by_id/$id/hard';
  String restore(int id) => '/evaluations/by_id/$id/restore';
  String save(int id) => '/evaluations/by_id/$id/save';
  String publish(int id) => '/evaluations/by_id/$id/publish';
  String unpublish(int id) => '/evaluations/by_id/$id/unpublish';
  String revert(int id) => '/evaluations/by_id/$id/revert';
  String transfer(int id) => '/evaluations/by_id/$id/transfer';
  String pdf(int id) => '/evaluations/by_id/$id/pdf';
  String answer(int id, int itemId) => '/evaluations/by_id/$id/answers/$itemId';

  String get templates => '/evaluations/templates';
  String get templatesDeleted => '/evaluations/templates/deleted';
  String get itemSearch => '/evaluations/templates/items';
  String template(int id) => '/evaluations/templates/by_id/$id';
  String templateHardDelete(int id) => '/evaluations/templates/by_id/$id/hard';
  String templateRestore(int id) => '/evaluations/templates/by_id/$id/restore';
  String templateItems(int id) => '/evaluations/templates/by_id/$id/items';
  String templateItem(int id, int itemId) =>
      '/evaluations/templates/by_id/$id/items/$itemId';
}
