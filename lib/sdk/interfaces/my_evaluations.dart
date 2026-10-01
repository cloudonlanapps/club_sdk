import '../models/evaluation_member_view.dart';
import '../models/media_link.dart';
import '../models/pagination.dart';

/// Member-facing evaluation reads (`/myevaluations`, club_server#302,
/// #535).
///
/// Open to the member themselves and to any coach; anyone else, an admin
/// included, gets 403. Only published evaluations are served: an
/// unpublished one answers 404, not 403, so a member cannot detect that a
/// coach is drafting something about them (R38). The projection carries
/// no private item (R39). Where the module is off every method throws
/// `ModuleDisabledException`.
abstract interface class MyEvaluationsSource {
  /// The member's published evaluations, most recently published first.
  Future<PaginatedList<EvaluationMemberView>> listMyEvaluations(
    String username, {
    int offset = 0,
    int limit = 20,
  });

  /// One published evaluation (404 `EVALUATION_NOT_FOUND` otherwise).
  Future<EvaluationMemberView> getMyEvaluation(String username, int id);

  /// The published evaluation's media, grouped by tag: evidence on its
  /// public items under each item's id (`EvaluationMediaTags.evidence`),
  /// and the stored member copy PDF under `EvaluationMediaTags.memberCopy`.
  /// 404 before publication.
  Future<Map<String, List<MediaLink>>> listMyEvaluationMedia(
    String username,
    int id,
  );
}
