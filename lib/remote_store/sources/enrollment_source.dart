import '../../sdk/interfaces/enrollment.dart';
import '../../sdk/models/credit_disposition.dart';
import '../../sdk/models/enrollment.dart';
import '../../sdk/models/enums.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [EnrollmentSource] using HTTP API.
class RemoteEnrollmentSource implements EnrollmentSource {
  RemoteEnrollmentSource(this._store);

  final RemoteStore _store;

  // ═══════════════════════════════════════════════════════════════════════════
  // ORGANIZER ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> invite(int eventId, String username) async {
    await _store.postVoid(
      endpoints.enrollments.invite(eventId),
      body: {
        'membernames': [username],
      },
    );
  }

  @override
  Future<void> inviteBulk(int eventId, List<String> usernames) async {
    await _store.postVoid(
      endpoints.enrollments.invite(eventId),
      body: {
        'membernames': usernames,
      },
    );
  }

  @override
  Future<void> assign(int eventId, String username) async {
    await _store.postVoid(
      endpoints.enrollments.assign(eventId),
      body: {
        'membernames': [username],
      },
    );
  }

  @override
  Future<void> assignBulk(int eventId, List<String> usernames) async {
    await _store.postVoid(
      endpoints.enrollments.assign(eventId),
      body: {
        'membernames': usernames,
      },
    );
  }

  @override
  Future<void> assignTrial(int eventId, String username) async {
    await _store.postVoid(
      endpoints.enrollments.assignTrial(eventId),
      body: {
        'membername': username,
      },
    );
  }

  @override
  Future<void> approveRequest(int eventId, String username) async {
    await _store.postVoid(
      endpoints.enrollments.approve(eventId),
      body: {
        'membernames': [username],
      },
    );
  }

  @override
  Future<void> approveRequestsBulk(int eventId, List<String> usernames) async {
    await _store.postVoid(
      endpoints.enrollments.approve(eventId),
      body: {
        'membernames': usernames,
      },
    );
  }

  @override
  Future<void> rejectRequest(
    int eventId,
    String username, {
    String? reason,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.reject(eventId),
      body: {
        'membernames': [username],
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> rejectRequestsBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.reject(eventId),
      body: {
        'membernames': usernames,
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> removeEnrollment(
    int eventId,
    String username, {
    String? reason,
    CreditDisposition? creditDisposition,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.remove(eventId),
      body: {
        'membernames': [username],
        'reason': ?reason,
        'creditDisposition': ?creditDisposition?.toMap(),
      },
    );
  }

  @override
  Future<void> removeEnrollmentsBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
    CreditDisposition? creditDisposition,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.remove(eventId),
      body: {
        'membernames': usernames,
        'reason': ?reason,
        'creditDisposition': ?creditDisposition?.toMap(),
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WITHDRAWAL APPROVAL
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> approveWithdraw(
    int eventId,
    String username, {
    CreditDisposition? creditDisposition,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.approveWithdraw(eventId),
      body: {
        'membernames': [username],
        'creditDisposition': ?creditDisposition?.toMap(),
      },
    );
  }

  @override
  Future<void> approveWithdrawBulk(
    int eventId,
    List<String> usernames, {
    CreditDisposition? creditDisposition,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.approveWithdraw(eventId),
      body: {
        'membernames': usernames,
        'creditDisposition': ?creditDisposition?.toMap(),
      },
    );
  }

  @override
  Future<void> rejectWithdraw(
    int eventId,
    String username, {
    String? reason,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.rejectWithdraw(eventId),
      body: {
        'membernames': [username],
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> rejectWithdrawBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
  }) async {
    await _store.postVoid(
      endpoints.enrollments.rejectWithdraw(eventId),
      body: {
        'membernames': usernames,
        'reason': ?reason,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<EnrollmentStatus?> getEnrollmentStatus(
    int eventId,
    String username,
  ) async {
    final enrollments = await listEnrollments(eventId);
    return enrollments[username];
  }

  @override
  Future<Enrollment> getEnrollment(int eventId, String username) async {
    // Per-member enrollment endpoint removed in Phase 3.
    // Use myEvents.getMyEnrollment() for full enrollment details.
    throw UnsupportedError(
      'getEnrollment is no longer available on the admin API. '
      'Use myEvents.getMyEnrollment(username, eventId) instead.',
    );
  }

  @override
  Future<Map<String, EnrollmentStatus>> listEnrollments(
    int eventId, {
    EnrollmentStatus? status,
  }) async {
    final queryParams = <String, String>{
      if (status != null) 'status': status.name,
    };
    final response = await _store.get(
      endpoints.enrollments.list(eventId),
      queryParams: queryParams,
    );
    final enrollments = response['enrollments'] as Map<String, dynamic>? ?? {};
    return enrollments.map(
      (key, value) => MapEntry(
        key,
        EnrollmentStatus.values.firstWhere(
          (e) => e.name == (value as String),
          orElse: () => EnrollmentStatus.rejected,
        ),
      ),
    );
  }

  @override
  Future<Map<String, Enrollment>> listEnrollmentsDetailed(
    int eventId, {
    EnrollmentStatus? status,
  }) async {
    final queryParams = <String, String>{
      if (status != null) 'status': status.name,
    };
    final response = await _store.get(
      endpoints.enrollments.list(eventId),
      queryParams: queryParams,
    );
    final records = response['records'] as List<dynamic>? ?? [];
    final result = <String, Enrollment>{};
    for (final item in records) {
      final enrollment = Enrollment.fromMap(item as Map<String, dynamic>);
      result[enrollment.membername] = enrollment;
    }
    return result;
  }
}
