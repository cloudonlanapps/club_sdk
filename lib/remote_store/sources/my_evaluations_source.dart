import '../../sdk/interfaces/my_evaluations.dart';
import '../../sdk/models/evaluation_member_view.dart';
import '../../sdk/models/media_link.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [MyEvaluationsSource] using HTTP API.
class RemoteMyEvaluationsSource implements MyEvaluationsSource {
  RemoteMyEvaluationsSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<EvaluationMemberView>> listMyEvaluations(
    String username, {
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.myEvaluations.list(username),
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, EvaluationMemberView.fromMap);
  }

  @override
  Future<EvaluationMemberView> getMyEvaluation(String username, int id) async =>
      EvaluationMemberView.fromMap(
        await _store.get(endpoints.myEvaluations.one(username, id)),
      );

  @override
  Future<Map<String, List<MediaLink>>> listMyEvaluationMedia(
    String username,
    int id,
  ) async {
    final response = await _store.get(
      endpoints.myEvaluations.media(username, id),
    );
    return response.map((tag, value) {
      final items = (value as List)
          .whereType<Map<String, dynamic>>()
          .map(MediaLink.fromMap)
          .toList(growable: false);
      return MapEntry(tag, items);
    });
  }
}
