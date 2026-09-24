import 'package:meta/meta.dart';

/// URL builder for `/evaluations` and its templates (club_server#302).
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

  String get templates => '/evaluations/templates';
  String get templatesDeleted => '/evaluations/templates/deleted';
  String template(int id) => '/evaluations/templates/by_id/$id';
  String templateHardDelete(int id) => '/evaluations/templates/by_id/$id/hard';
  String templateRestore(int id) => '/evaluations/templates/by_id/$id/restore';
  String templateApply(int id) => '/evaluations/templates/by_id/$id/apply';
}
