import '../../sdk/interfaces/inquiry.dart';
import '../../sdk/models/inquiry.dart';
import '../../sdk/models/inquiry_kind.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [InquirySource] over `/admin/inquiries`.
class RemoteInquirySource implements InquirySource {
  RemoteInquirySource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<Inquiry>> listInquiries({
    InquiryKind? kind,
    bool? handled,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.inquiries.inbox,
      queryParams: {
        if (kind != null) 'kind': kind.wireName,
        if (handled != null) 'handled': handled.toString(),
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, Inquiry.fromMap);
  }

  @override
  Future<Inquiry> setInquiryHandled(int id, {required bool handled}) async {
    final response = await _store.patch(
      endpoints.inquiries.inquiry(id),
      body: {'handled': handled},
    );
    return Inquiry.fromMap(response);
  }

  @override
  Future<void> deleteInquiry(int id) => _store.delete(
    endpoints.inquiries.inquiry(id),
  );
}
