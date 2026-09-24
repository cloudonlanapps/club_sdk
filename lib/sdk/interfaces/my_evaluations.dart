import '../models/evaluation_member_view.dart';
import '../models/media_link.dart';
import '../models/pagination.dart';

/// Member-facing evaluation reads (`/myevaluations`, club_server#302).
///
/// A member reads only their own evaluations (403 otherwise) and only the
/// published ones: an unpublished evaluation answers 404, not 403, so a
/// member cannot detect that a coach is drafting something about them
/// (R38). The projection returned has no coach note (R39). Where the
/// module is off every method throws `ModuleDisabledException`.
abstract interface class MyEvaluationsSource {
  /// The member's published evaluations, most recently published first.
  Future<PaginatedList<EvaluationMemberView>> listMyEvaluations(
    String username, {
    int offset = 0,
    int limit = 20,
  });

  /// One published evaluation (404 `EVALUATION_NOT_FOUND` otherwise).
  Future<EvaluationMemberView> getMyEvaluation(String username, int id);

  /// Media the coach shared on a published evaluation, grouped by tag:
  /// only links under a tag beginning `shared_` are returned (R56a), and
  /// only once the evaluation is published (R56b, 404 before).
  Future<Map<String, List<MediaLink>>> listMyEvaluationMedia(
    String username,
    int id,
  );
}
