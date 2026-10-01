import '../../sdk/interfaces/evaluation.dart';
import '../../sdk/models/evaluation_answer_input.dart';
import '../../sdk/models/evaluation_item_type.dart';
import '../../sdk/models/evaluation_layout_entry.dart';
import '../../sdk/models/evaluation_staff_view.dart';
import '../../sdk/models/evaluation_status.dart';
import '../../sdk/models/evaluation_template.dart';
import '../../sdk/models/evaluation_template_item.dart';
import '../../sdk/models/evaluation_template_item_hit.dart';
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
    required int templateId,
    required String createdFor,
    int? eventId,
    DateTime? periodStartUtc,
    DateTime? periodEndUtc,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.list,
      body: <String, dynamic>{
        'templateId': templateId,
        'createdFor': createdFor,
        'eventId': ?eventId,
        'periodStartUtc': ?periodStartUtc?.millisecondsSinceEpoch,
        'periodEndUtc': ?periodEndUtc?.millisecondsSinceEpoch,
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
    String? createdFor,
    int? eventId,
    bool? general,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.list,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
        'status': ?status?.wireName,
        'createdFor': ?createdFor,
        'eventId': ?eventId?.toString(),
        'general': ?general?.toString(),
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
  Future<EvaluationStaffView> updateEvaluationPeriod(
    int id, {
    required DateTime? periodStartUtc,
    required DateTime? periodEndUtc,
  }) async {
    final response = await _store.patch(
      endpoints.evaluations.byId(id),
      body: <String, dynamic>{
        'periodStartUtc': periodStartUtc?.millisecondsSinceEpoch,
        'periodEndUtc': periodEndUtc?.millisecondsSinceEpoch,
      },
    );
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<EvaluationStaffView> putAnswer(
    int id,
    int itemId,
    EvaluationAnswerInput answer,
  ) async {
    final response = await _store.put(
      endpoints.evaluations.answer(id, itemId),
      body: answer.toMap(),
    );
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<EvaluationStaffView> clearAnswer(int id, int itemId) async {
    final path = endpoints.evaluations.answer(id, itemId);
    final response = await _store.delete(path);
    if (response == null) {
      throw StateError(
        'DELETE $path returned no body; expected the evaluation',
      );
    }
    return EvaluationStaffView.fromMap(response);
  }

  @override
  Future<EvaluationStaffView> uploadEvidence(
    int id,
    int itemId, {
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final response = await _store.uploadMultipart(
      endpoints.evaluations.evidence(id, itemId),
      fileBytes: bytes,
      filename: filename,
      contentType: contentType,
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
  Future<void> transferEvaluation(int id, {required String owner}) async {
    await _store.post(
      endpoints.evaluations.transfer(id),
      body: <String, dynamic>{'owner': owner},
    );
  }

  @override
  Future<List<int>> previewMemberCopy(int id) =>
      _store.downloadBytes(endpoints.evaluations.pdf(id));

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
    required List<EvaluationLayoutEntry<EvaluationTemplateItem>> layout,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.templates,
      body: <String, dynamic>{
        'name': name,
        'layout': layout.map((e) => e.toWire((i) => i.toMap())).toList(),
      },
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> updateTemplate(
    int id, {
    String? name,
    List<EvaluationLayoutEntry<int>>? layout,
  }) async {
    final response = await _store.patch(
      endpoints.evaluations.template(id),
      body: <String, dynamic>{
        'name': ?name,
        if (layout != null)
          'layout': layout.map((e) => e.toWire((itemId) => itemId)).toList(),
      },
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> addItem(
    int templateId,
    EvaluationTemplateItem item, {
    String? section,
  }) async {
    final response = await _store.post(
      endpoints.evaluations.templateItems(templateId),
      body: <String, dynamic>{'item': item.toMap(), 'section': ?section},
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> replaceItem(
    int templateId,
    int itemId,
    EvaluationTemplateItem item,
  ) async {
    final response = await _store.put(
      endpoints.evaluations.templateItem(templateId, itemId),
      body: item.toMap(),
    );
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<EvaluationTemplate> removeItem(int templateId, int itemId) async {
    final path = endpoints.evaluations.templateItem(templateId, itemId);
    final response = await _store.delete(path);
    if (response == null) {
      throw StateError('DELETE $path returned no body; expected the template');
    }
    return EvaluationTemplate.fromMap(response);
  }

  @override
  Future<PaginatedList<EvaluationTemplateItemHit>> searchItems({
    String? search,
    EvaluationItemType? type,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.evaluations.itemSearch,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
        'search': ?search,
        'type': ?type?.wireName,
      },
    );
    return PaginatedList.fromMap(response, EvaluationTemplateItemHit.fromMap);
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
}
