import '../models/evaluation_category.dart';
import '../models/evaluation_scope.dart';
import '../models/evaluation_scope_type.dart';
import '../models/evaluation_score_input.dart';
import '../models/evaluation_staff_view.dart';
import '../models/evaluation_status.dart';
import '../models/evaluation_template.dart';
import '../models/pagination.dart';

/// Staff-side evaluation operations (`/evaluations`, club_server#302).
///
/// Evaluations are an optional module: where `EVALUATIONS_ENABLED` is off
/// every method throws `ModuleDisabledException` (503
/// `EVALUATIONS_DISABLED`). Read `CapabilitiesSource.getCapabilities()`
/// to decide whether to show the feature rather than probing.
///
/// Lifecycle is draft → saved → published, and a draft cannot be published
/// directly (422 `INVALID_TRANSITION`). There is deliberately no method
/// that saves and publishes in one call: the two-step is the point (R19).
/// Scores are validated server-side against the template's categories
/// (422 `INVALID_SCORE`); event-scoped evaluations additionally require
/// the author on the event's coach list and an attendance record for the
/// subject (422 `NOT_ELIGIBLE`).
abstract interface class EvaluationSource {
  // ══════════════════════════════════════════════════════════════════════════
  // EVALUATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a draft. A coach authors their own; only an admin may pass
  /// [authorUsername] to assign the draft to another coach (403 otherwise).
  Future<EvaluationStaffView> createEvaluation({
    required String subjectUsername,
    required int templateId,
    required EvaluationScope scope,
    String? authorUsername,
    List<EvaluationScoreInput>? scores,
    String? comment,
    String? coachNote,
  });

  /// Fetch one evaluation (404 `EVALUATION_NOT_FOUND`).
  Future<EvaluationStaffView> getEvaluation(int id);

  /// List evaluations. A coach sees those assigned to them, an admin all;
  /// [authorUsername] is an admin-only filter.
  Future<PaginatedList<EvaluationStaffView>> listEvaluations({
    EvaluationStatus? status,
    String? subjectUsername,
    String? authorUsername,
    EvaluationScopeType? scopeType,
    int? eventId,
    int offset = 0,
    int limit = 20,
  });

  /// List soft-deleted evaluations.
  Future<PaginatedList<EvaluationStaffView>> listDeletedEvaluations({
    int offset = 0,
    int limit = 20,
  });

  /// Edit content. A null argument leaves that field unchanged. Published
  /// evaluations are immutable (422 `INVALID_STATE`): unpublish first.
  /// Scope cannot be edited (R23).
  Future<EvaluationStaffView> updateEvaluation(
    int id, {
    List<EvaluationScoreInput>? scores,
    String? comment,
    String? coachNote,
  });

  /// Soft-delete a draft; returns the deleted row. Saved or published
  /// evaluations must be reverted to draft first (422 `INVALID_STATE`).
  Future<EvaluationStaffView> deleteEvaluation(int id);

  /// Permanently delete a soft-deleted evaluation (super-admin only).
  Future<void> hardDeleteEvaluation(int id);

  /// Restore a soft-deleted evaluation.
  Future<EvaluationStaffView> restoreEvaluation(int id);

  /// draft → saved.
  Future<EvaluationStaffView> saveEvaluation(int id);

  /// saved → published. Stamps `publishedAtUtc` and notifies the subject.
  Future<EvaluationStaffView> publishEvaluation(int id);

  /// published → saved. Clears `publishedAtUtc` and notifies the subject.
  Future<EvaluationStaffView> unpublishEvaluation(int id);

  /// saved → draft.
  Future<EvaluationStaffView> revertEvaluation(int id);

  /// Reassign to another coach (admin only, before publication). The new
  /// author must satisfy the same eligibility the original did (R37).
  Future<EvaluationStaffView> transferEvaluation(
    int id, {
    required String newAuthorUsername,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATES
  // ══════════════════════════════════════════════════════════════════════════

  /// List templates. Readable by any staff member.
  Future<PaginatedList<EvaluationTemplate>> listTemplates({
    int offset = 0,
    int limit = 20,
  });

  /// List soft-deleted templates.
  Future<PaginatedList<EvaluationTemplate>> listDeletedTemplates({
    int offset = 0,
    int limit = 20,
  });

  /// Fetch one template (404 `TEMPLATE_NOT_FOUND`).
  Future<EvaluationTemplate> getTemplate(int id);

  /// Create a template (admin only). [categories] carry no `id`.
  Future<EvaluationTemplate> createTemplate({
    required String name,
    required List<EvaluationScopeType> scopes,
    required List<EvaluationCategory> categories,
    String? description,
  });

  /// Edit a template (admin only). A null argument leaves that field
  /// unchanged. Re-declaring [categories] while evaluations reference the
  /// template is 422 `TEMPLATE_IN_USE`.
  Future<EvaluationTemplate> updateTemplate(
    int id, {
    String? name,
    String? description,
    List<EvaluationScopeType>? scopes,
    List<EvaluationCategory>? categories,
  });

  /// Soft-delete a template; returns the deleted row. Refused while any
  /// evaluation references it (422 `TEMPLATE_IN_USE`).
  Future<EvaluationTemplate> deleteTemplate(int id);

  /// Permanently delete a soft-deleted template (super-admin only).
  Future<void> hardDeleteTemplate(int id);

  /// Restore a soft-deleted template.
  Future<EvaluationTemplate> restoreTemplate(int id);

  /// Create a draft for [subjectUsername] seeded with the template's
  /// default scores, authored by the caller (R50). [scope] must be one the
  /// template declares (422 `TEMPLATE_SCOPE_MISMATCH`).
  Future<EvaluationStaffView> applyTemplate(
    int templateId, {
    required String subjectUsername,
    required EvaluationScope scope,
    String? comment,
    String? coachNote,
  });
}
