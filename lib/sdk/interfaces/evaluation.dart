import '../models/evaluation_answer_input.dart';
import '../models/evaluation_item_type.dart';
import '../models/evaluation_layout_entry.dart';
import '../models/evaluation_staff_view.dart';
import '../models/evaluation_status.dart';
import '../models/evaluation_template.dart';
import '../models/evaluation_template_item.dart';
import '../models/evaluation_template_item_hit.dart';
import '../models/pagination.dart';

/// Staff-side evaluation operations (`/evaluations`, club_server#302,
/// #535).
///
/// Evaluations are an optional module: where `EVALUATIONS_ENABLED` is off
/// every method throws `ModuleDisabledException` (503
/// `EVALUATIONS_DISABLED`). Read `CapabilitiesSource.getCapabilities()`
/// to decide whether to show the feature rather than probing.
///
/// Only a coach creates an evaluation (an admin gets 403), and until it is
/// published it exists only for its effective owner — the coach it was
/// transferred to, else its creator. Anyone else, an admin included, gets
/// 404 `EVALUATION_NOT_FOUND` from every evaluation method here except
/// [transferEvaluation] and [hardDeleteEvaluation]. Lists return the
/// caller's own evaluations only; an admin owns none.
///
/// Lifecycle is draft → saved → published, and a draft cannot be published
/// directly (422 `INVALID_TRANSITION`). Only a draft is edited — its
/// answers, one at a time, its event and its period; anything else is 422
/// `INVALID_STATE`. Saving refuses an incomplete draft with 422
/// `INCOMPLETE`, whose `ServerException.details['details']['itemIds']`
/// names the items. Event-scoped evaluations require the owner on the
/// event's coach list and an attendance record for the member (422
/// `NOT_ELIGIBLE`).
///
/// Templates are read and written by any staff member — an admin or a
/// coach; a member gets 403. Hard-deleting a template stays super-admin
/// only. A live template's name is unique, compared without regard to
/// case or surrounding spaces (422 `TEMPLATE_NAME_TAKEN`).
abstract interface class EvaluationSource {
  // ══════════════════════════════════════════════════════════════════════════
  // EVALUATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a draft with no answers, created by and owned by the calling
  /// coach. No [eventId] makes a general evaluation. A period gives both
  /// bounds or neither, the end not before the start (422
  /// `VALIDATION_ERROR` otherwise); a one-day period ends where it starts.
  /// A period ending after the server's clock is 422 `PERIOD_IN_FUTURE`:
  /// a review looks back.
  ///
  /// A coach holds one live review per member, template and period — the
  /// exact bounds, or none, which counts as a value; the event is not part
  /// of the key. A second one is 422 `DUPLICATE_EVALUATION`.
  Future<EvaluationStaffView> createEvaluation({
    required int templateId,
    required String createdFor,
    int? eventId,
    DateTime? periodStartUtc,
    DateTime? periodEndUtc,
  });

  /// Fetch one of the caller's evaluations (404 `EVALUATION_NOT_FOUND`).
  Future<EvaluationStaffView> getEvaluation(int id);

  /// List the caller's own evaluations, most recently created first.
  /// [general] true keeps general evaluations only, false event ones only.
  Future<PaginatedList<EvaluationStaffView>> listEvaluations({
    EvaluationStatus? status,
    String? createdFor,
    int? eventId,
    bool? general,
    int offset = 0,
    int limit = 20,
  });

  /// List the caller's own soft-deleted evaluations.
  Future<PaginatedList<EvaluationStaffView>> listDeletedEvaluations({
    int offset = 0,
    int limit = 20,
  });

  /// Change a draft's event, its period, or both (club_server#535, R23).
  ///
  /// Each argument follows the ValueGetter pattern: an omitted (null)
  /// getter leaves that field as it is, and a getter returning null clears
  /// it. `eventId: () => null` makes the draft general; `eventId: () => 9`
  /// moves it to event 9. A period gives both bounds or neither, so pass
  /// [periodStartUtc] and [periodEndUtc] together — both returning null
  /// clear it; one alone, or an end before the start, is 422
  /// `VALIDATION_ERROR`. The end may equal the start (a one-day period) but
  /// not lie after the server's clock (422 `PERIOD_IN_FUTURE`).
  ///
  /// Eligibility is checked again for the effective owner against the
  /// resulting event and period: 422 `NOT_ELIGIBLE` when the owner does not
  /// coach that event or the member has no attendance record in it (within
  /// the period, if any); 404 `EVENT_NOT_FOUND` for an unknown event. A
  /// period that makes this a second live review of the same member and
  /// template over the same period for the owner is 422
  /// `DUPLICATE_EVALUATION`. Only a draft is edited (422 `INVALID_STATE`);
  /// the member is fixed at creation.
  Future<EvaluationStaffView> updateEvaluation(
    int id, {
    int? Function()? eventId,
    DateTime? Function()? periodStartUtc,
    DateTime? Function()? periodEndUtc,
  });

  /// Write the answer to item [itemId] of a draft, replacing any earlier
  /// one. An answer that does not fit the item, or an item that is not a
  /// question of the template, is 422 `INVALID_ANSWER`.
  Future<EvaluationStaffView> putAnswer(
    int id,
    int itemId,
    EvaluationAnswerInput answer,
  );

  /// Clear the answer to item [itemId] of a draft, detaching its evidence.
  Future<EvaluationStaffView> clearAnswer(int id, int itemId);

  /// Upload [bytes] as evidence for item [itemId] of a draft, in one step,
  /// and return the evaluation with it attached (club_server#535, R56d).
  ///
  /// The file is stored as a media item uploaded on behalf of the member
  /// the evaluation is about, with access roles `self`, `coach` and
  /// `admin`: the member and staff can download it, nobody else can, and it
  /// is never public. It is linked under the item's id with [filename] as
  /// its metadata. Only the effective owner may upload (404
  /// `EVALUATION_NOT_FOUND` otherwise). An item that is not a question
  /// taking evidence, or a file that is not an image, a video or a PDF, is
  /// 422 `INVALID_EVIDENCE`; an evaluation that is not a draft is 422
  /// `INVALID_STATE`; a file over the server's limit is 413
  /// `FILE_TOO_LARGE`.
  Future<EvaluationStaffView> uploadEvidence(
    int id,
    int itemId, {
    required List<int> bytes,
    required String filename,
    String? contentType,
  });

  /// Soft-delete a draft; returns the deleted row. Saved or published
  /// evaluations must be reverted to draft first (422 `INVALID_STATE`).
  Future<EvaluationStaffView> deleteEvaluation(int id);

  /// Permanently delete a soft-deleted evaluation (super-admin only, named
  /// by id whoever owns it). 422 `HARD_DELETE_NEEDS_SOFT_DELETE` if it has
  /// not been soft-deleted first.
  Future<void> hardDeleteEvaluation(int id);

  /// Restore a soft-deleted evaluation.
  /// 422 `NOTHING_TO_RESTORE` if it is not deleted; 422
  /// `DUPLICATE_EVALUATION` while the owner holds a live review of the same
  /// member, template and period.
  Future<EvaluationStaffView> restoreEvaluation(int id);

  /// draft → saved, once every required question is answered and every
  /// answer that needs a coach note has one (422 `INCOMPLETE`).
  Future<EvaluationStaffView> saveEvaluation(int id);

  /// saved → published. Stamps `publishedAtUtc`, stores the member copy
  /// PDF and notifies the member.
  Future<EvaluationStaffView> publishEvaluation(int id);

  /// published → saved. Clears `publishedAtUtc` and notifies the member.
  Future<EvaluationStaffView> unpublishEvaluation(int id);

  /// saved → draft.
  Future<EvaluationStaffView> revertEvaluation(int id);

  /// Hand an unpublished evaluation to the coach [owner]: by its effective
  /// owner, or by an admin naming it by id. Returns nothing — afterwards
  /// only the new owner sees it. The new owner must be eligible as the
  /// creator was (422 `NOT_ELIGIBLE`); a published one is 422
  /// `INVALID_STATE`. A new owner who already holds a live review of the
  /// same member, template and period is 422 `DUPLICATE_EVALUATION`.
  Future<void> transferEvaluation(int id, {required String owner});

  /// The member copy as it would be published, as PDF bytes: the owner's
  /// preview, at any status, generated and never stored.
  Future<List<int>> previewMemberCopy(int id);

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATES
  // ══════════════════════════════════════════════════════════════════════════

  /// List templates. Readable by any staff member.
  Future<PaginatedList<EvaluationTemplate>> listTemplates({
    int offset = 0,
    int limit = 20,
  });

  /// List soft-deleted templates. Any staff member.
  Future<PaginatedList<EvaluationTemplate>> listDeletedTemplates({
    int offset = 0,
    int limit = 20,
  });

  /// Fetch one template (404 `TEMPLATE_NOT_FOUND`).
  Future<EvaluationTemplate> getTemplate(int id);

  /// Create a template whole, its items inline in [layout]. Any staff
  /// member. A template with no question is 422; a name a live template
  /// already holds (ignoring case and surrounding spaces) is 422
  /// `TEMPLATE_NAME_TAKEN`. An item with `originItemId` is a
  /// copy, which must keep its origin's answer domain (422
  /// `ORIGIN_MISMATCH`; an unknown origin is 404 `ITEM_NOT_FOUND`).
  Future<EvaluationTemplate> createTemplate({
    required String name,
    required List<EvaluationLayoutEntry<EvaluationTemplateItem>> layout,
  });

  /// Rename (allowed while in use) or re-lay out a template. Any staff
  /// member. The layout must name every item exactly once (422
  /// `INVALID_LAYOUT`); a name another live template holds is 422
  /// `TEMPLATE_NAME_TAKEN`. A null argument leaves that field unchanged.
  Future<EvaluationTemplate> updateTemplate(
    int id, {
    String? name,
    List<EvaluationLayoutEntry<int>>? layout,
  });

  /// Add [item] at the end of the layout, or of the [section] (created if
  /// absent). Any staff member.
  Future<EvaluationTemplate> addItem(
    int templateId,
    EvaluationTemplateItem item, {
    String? section,
  });

  /// Replace item [itemId] whole with [item]; it keeps its id and origin.
  /// Changing its type is 422 `ITEM_TYPE_FIXED`; an item of another
  /// template is 404 `ITEM_NOT_FOUND`. Any staff member.
  Future<EvaluationTemplate> replaceItem(
    int templateId,
    int itemId,
    EvaluationTemplateItem item,
  );

  /// Remove item [itemId] and its place in the layout. Any staff member.
  Future<EvaluationTemplate> removeItem(int templateId, int itemId);

  /// Items of every live template, matching [search] in their text and of
  /// [type], to copy into another template. Any staff member.
  Future<PaginatedList<EvaluationTemplateItemHit>> searchItems({
    String? search,
    EvaluationItemType? type,
    int offset = 0,
    int limit = 20,
  });

  /// Soft-delete a template; returns the deleted row. Any staff member.
  /// Refused while a live evaluation uses it (422 `TEMPLATE_IN_USE`). A
  /// soft-deleted template holds no name.
  Future<EvaluationTemplate> deleteTemplate(int id);

  /// Permanently delete a soft-deleted template (super-admin only).
  /// 422 `HARD_DELETE_NEEDS_SOFT_DELETE` if it has not been soft-deleted
  /// first; 422 `TEMPLATE_IN_USE` while any evaluation uses it.
  Future<void> hardDeleteTemplate(int id);

  /// Restore a soft-deleted template. Any staff member.
  /// 422 `NOTHING_TO_RESTORE` if it is not deleted; 422
  /// `TEMPLATE_NAME_TAKEN` if a live template now holds its name.
  Future<EvaluationTemplate> restoreTemplate(int id);
}
