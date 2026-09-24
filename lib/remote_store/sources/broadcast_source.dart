import '../../sdk/interfaces/broadcast.dart';
import '../../sdk/models/broadcast.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [BroadcastSource] using HTTP API.
class RemoteBroadcastSource implements BroadcastSource {
  RemoteBroadcastSource(this._store);

  final RemoteStore _store;

  @override
  Future<Broadcast> createBroadcast({
    required AudienceSelector audienceSelector,
    required Map<String, dynamic> payload,
    DateTime? expiresAtUtc,
    bool email = false,
    String? emailSubject,
    String? emailBody,
  }) async {
    assert(
      !email ||
          (emailSubject != null &&
              emailSubject.isNotEmpty &&
              emailBody != null &&
              emailBody.isNotEmpty),
      'emailSubject and emailBody are required when email is true',
    );
    final body = <String, dynamic>{
      'audienceSelector': audienceSelector.toMap(),
      'payload': payload,
      if (expiresAtUtc != null)
        'expiresAtUtc': expiresAtUtc.toUtc().millisecondsSinceEpoch,
      if (email) ...<String, dynamic>{
        'email': true,
        'emailSubject': emailSubject,
        'emailBody': emailBody,
      },
    };
    final response = await _store.post(endpoints.broadcasts.list, body: body);
    return Broadcast.fromMap(response);
  }

  @override
  Future<PaginatedList<Broadcast>> listBroadcasts({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.broadcasts.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Broadcast.fromMap);
  }

  @override
  Future<Broadcast> getBroadcast(int id) async {
    final response = await _store.get(endpoints.broadcasts.byId(id));
    return Broadcast.fromMap(response);
  }

  @override
  Future<PaginatedList<BroadcastRecipient>> listRecipients(
    int id, {
    String? statusFilter,
    int offset = 0,
    int limit = 50,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
      'status': ?statusFilter,
    };
    final response = await _store.get(
      endpoints.broadcasts.recipients(id),
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, BroadcastRecipient.fromMap);
  }

  @override
  Future<Broadcast> revokeBroadcast(int id) async {
    final response = await _store.delete(endpoints.broadcasts.byId(id));
    if (response == null) {
      throw StateError(
        'DELETE /broadcasts/by_id/$id returned no body; '
        'expected the revoked broadcast row',
      );
    }
    return Broadcast.fromMap(response);
  }
}
