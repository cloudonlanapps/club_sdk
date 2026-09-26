import '../../sdk/interfaces/evaluation.dart';
import '../../sdk/models/evaluation_category.dart';
import '../../sdk/models/evaluation_scope.dart';
import '../../sdk/models/evaluation_scope_type.dart';
import '../../sdk/models/evaluation_score_input.dart';
import '../../sdk/models/evaluation_staff_view.dart';
import '../../sdk/models/evaluation_status.dart';
import '../../sdk/models/evaluation_template.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [EvaluationSource] using HTTP API.
class RemoteEvaluationSource implements EvaluationSource {
  RemoteEvaluationSource(this._store);

  final RemoteStore _store;

  Future<EvaluationStaffView> _postView(String path) async =>
      EvaluationStaffView.fromMap(await _store.post(path));

  @override
  Future<EvaluationStaffView> createEvaluation({
    required String subjectUsername,
    required int templateId,
    required EvaluationScope scope,
    String? authorUsername,
    List<EvaluationScoreInput>? scores,
    String? comment,
    String? coachNote,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.list,
      body: <String, dynamic>{
        'subjectUsername': subjectUsername,
        'templateId': templateId,
        'scope': scope.toMap(),
        'authorUsername': ?authorUsername,
        if (scores != null) 'scores': scores.map((s) => s.toMap()).toList(),
        'comment': ?comment,
        'coachNote': ?coachNote,
      },
    );
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<EvaluationStaffView> getEvaluation(int id) async =>
      EvaluationStaffView.fromMap(
        await _store.get(endpoints.evaluations.byId(id)),
      );

  @override
  Future<PaginatedList<EvaluationStaffView>> listEvaluations({
    EvaluationStatus? status,
    String? subjectUsername,
    String? authorUsername,
    EvaluationScopeType? scopeType,
    int? eventId,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.list,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
        'status': ?status?.wireName,
        'subjectUsername': ?subjectUsername,
        'authorUsername': ?authorUsername,
        'scopeType': ?scopeType?.wireName,
        'eventId': ?eventId?.toString(),
      },
    );
    return PaginatedList.fromMap(response, EvaluationStaffView.fromMap);
  }

  @override
  Future<PaginatedList<EvaluationStaffView>> listDeletedEvaluations({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.deleted,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, EvaluationStaffView.fromMap);
  }

  @override
  Future<EvaluationStaffView> updateEvaluation(
    int id, {
    List<EvaluationScoreInput>? scores,
    String? comment,
    String? coachNote,
  }) async {
    final response = await _store.patch(
      endpoints.evaluations.byId(id),
      body: <String, dynamic>{
        if (scores != null) 'scores': scores.map((s) => s.toMap()).toList(),
        'comment': ?comment,
        'coachNote': ?coachNote,
      },
    );
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<EvaluationStaffView> deleteEvaluation(int id) async {
    final response = await _store.delete(endpoints.evaluations.byId(id));
    if (response == null) {
      throw StateError(
        'DELETE /evaluations/by_id/$id returned no body; '
        'expected the deleted evaluation',
      );
    }
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<void> hardDeleteEvaluation(int id) async {
    await _store.delete(endpoints.evaluations.hardDelete(id));
  }

  @override
  Future<EvaluationStaffView> restoreEvaluation(int id) =>
      _postView(endpoints.evaluations.restore(id));

  @override
  Future<EvaluationStaffView> saveEvaluation(int id) =>
      _postView(endpoints.evaluations.save(id));

  @override
  Future<EvaluationStaffView> publishEvaluation(int id) =>
      _postView(endpoints.evaluations.publish(id));

  @override
  Future<EvaluationStaffView> unpublishEvaluation(int id) =>
      _postView(endpoints.evaluations.unpublish(id));

  @override
  Future<EvaluationStaffView> revertEvaluation(int id) =>
      _postView(endpoints.evaluations.revert(id));

  @override
  Future<EvaluationStaffView> transferEvaluation(
    int id, {
    required String newAuthorUsername,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.transfer(id),
      body: <String, dynamic>{'newAuthorUsername': newAuthorUsername},
    );
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<PaginatedList<EvaluationTemplate>> listTemplates({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.templates,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, EvaluationTemplate.fromMap);
  }

  @override
  Future<PaginatedList<EvaluationTemplate>> listDeletedTemplates({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.templatesDeleted,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, EvaluationTemplate.fromMap);
  }

  @override
  Future<EvaluationTemplate> getTemplate(int id) async =>
      EvaluationTemplate.fromMap(
        await _store.get(endpoints.evaluations.template(id)),
      );

  @override
  Future<EvaluationTemplate> createTemplate({
    required String name,
    required List<EvaluationScopeType> scopes,
    required List<EvaluationCategory> categories,
    String? description,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.templates,
      body: <String, dynamic>{
        'name': name,
        'description': ?description,
        'scopes': scopes.map((s) => s.wireName).toList(),
        'categories': categories.map((c) => c.toInputMap()).toList(),
      },
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> updateTemplate(
    int id, {
    String? name,
    String? description,
    List<EvaluationScopeType>? scopes,
    List<EvaluationCategory>? categories,
  }) async {
    final response = await _store.patch(
      endpoints.evaluations.template(id),
      body: <String, dynamic>{
        'name': ?name,
        'description': ?description,
        if (scopes != null) 'scopes': scopes.map((s) => s.wireName).toList(),
        if (categories != null)
          'categories': categories.map((c) => c.toInputMap()).toList(),
      },
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> deleteTemplate(int id) async {
    final response = await _store.delete(endpoints.evaluations.template(id));
    if (response == null) {
      throw StateError(
        'DELETE /evaluations/templates/by_id/$id returned no body; '
        'expected the deleted template',
      );
    }
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<void> hardDeleteTemplate(int id) async {
    await _store.delete(endpoints.evaluations.templateHardDelete(id));
  }

  @override
  Future<EvaluationTemplate> restoreTemplate(int id) async =>
      EvaluationTemplate.fromMap(
        await _store.post(endpoints.evaluations.templateRestore(id)),
      );

  @override
  Future<EvaluationStaffView> applyTemplate(
    int templateId, {
    required String subjectUsername,
    required EvaluationScope scope,
    String? comment,
    String? coachNote,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.templateApply(templateId),
      body: <String, dynamic>{
        'subjectUsername': subjectUsername,
        'scope': scope.toMap(),
        'comment': ?comment,
        'coachNote': ?coachNote,
      },
    );
    return EvaluationStaffView.fromMap(response);
  }
}
