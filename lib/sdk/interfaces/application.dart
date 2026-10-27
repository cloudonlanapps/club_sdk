import '../models/application_clause_library.dart';
import '../models/application_content.dart';
import '../models/application_fact.dart';
import '../models/application_filled_clause.dart';
import '../models/application_labels.dart';
import '../models/application_patch.dart';
import '../models/application_status.dart';
import '../models/application_template.dart';
import '../models/pagination.dart';

/// Printable application forms (`/applications`, club_server#93, #66).
///
/// An admin writes a template — its facts, texts and age categories — and
/// moves it draft → saved → published. A member downloads their own form
/// of a published template as a PDF, filled from their profile, prints
/// it, signs it and hands it in. Nothing records the download.
///
/// An optional module: available only where the deployment turns
/// applications on **and** requires identity verification
/// (`Capabilities.applications`). Otherwise every method throws
/// `ModuleDisabledException` (503 `APPLICATIONS_DISABLED`).
///
/// Who may call what: writing, the moves, [duplicateApplication],
/// [downloadPreview], [downloadMemberForm], [getLabels], [getClauses] and
/// [fillClause] are an admin's (403 otherwise). [listApplications],
/// [getApplication] and [downloadOwnForm] are any signed-in user's —
/// `registered`, `pending` or approved. A member sees the published
/// templates only, and only once they have uploaded an identity document:
/// before that the list is empty, and a read or a form is 422
/// `IDENTITY_DOCUMENT_REQUIRED`.
/// A template a member may not see is 404 `APPLICATION_NOT_FOUND`.
///
/// A PDF is the form's bytes (`application/pdf`); the server names it
/// `application-<id>-<username>.pdf`.
abstract interface class ApplicationSource {
  /// Create a draft from [content] (201). Every field may be left for
  /// later; nothing is checked for completeness until [saveApplication].
  /// A shape the server cannot store — among them a text that is not
  /// `{language: text}`, such as a `{"clause": …}` or `{"fact": …}`
  /// reference — is 422 `VALIDATION_ERROR`.
  Future<ApplicationTemplate> createApplication(ApplicationContent content);

  /// List the templates the caller may see, newest first: an admin every
  /// state, narrowed by [status]; a member the published ones. [limit] is
  /// at most 100.
  Future<PaginatedList<ApplicationTemplate>> listApplications({
    ApplicationStatus? status,
    int offset = 0,
    int limit = 20,
  });

  /// One template the caller may see (404 `APPLICATION_NOT_FOUND`).
  Future<ApplicationTemplate> getApplication(int id);

  /// Change a draft: each field [patch] gives replaces the stored one,
  /// null clears it, a field left out keeps its value. A saved or
  /// published template is 422 `INVALID_STATE`.
  Future<ApplicationTemplate> updateApplication(
    int id,
    ApplicationPatch patch,
  );

  /// Soft-delete a draft or saved template and return it; it is no longer
  /// listed or read. A published one is 422 `INVALID_STATE`.
  Future<ApplicationTemplate> deleteApplication(int id);

  /// Draft → saved. Refused, staying a draft, when a text the form needs
  /// is missing or lacks a print language (`ApplicationIncompleteException`),
  /// or the details alone overflow page 1
  /// (`ApplicationDoesNotFitException`). Otherwise the layout is decided and
  /// stored on the template.
  Future<ApplicationTemplate> saveApplication(int id);

  /// Saved → published: members see it.
  Future<ApplicationTemplate> publishApplication(int id);

  /// Published → saved: members no longer see it.
  Future<ApplicationTemplate> unpublishApplication(int id);

  /// Saved → draft: editable again; the stored layout is dropped.
  ///
  /// Every move from another state is 422 `INVALID_TRANSITION`.
  Future<ApplicationTemplate> revertApplication(int id);

  /// A new draft (201) copied from template [id], in any state: the same
  /// content, no layout. The source is unchanged.
  Future<ApplicationTemplate> duplicateApplication(int id);

  /// Template [id], in any state, drawn for the server's fictional demo
  /// member and watermarked "PREVIEW".
  Future<List<int>> downloadPreview(int id);

  /// The caller's own form of published template [id]. A member no age
  /// category matches, or with no date of birth, is 422
  /// `APPLICATION_NOT_ELIGIBLE`.
  Future<List<int>> downloadOwnForm(int id);

  /// [username]'s form of published template [id], for an admin. A
  /// template not published is 422 `APPLICATION_NOT_PUBLISHED`; an unknown
  /// user 404 `USER_NOT_FOUND`.
  Future<List<int>> downloadMemberForm(int id, String username);

  /// The label catalogue, to pre-fill the editor.
  Future<ApplicationLabels> getLabels();

  /// The clause library, for the editor's pickers.
  Future<ApplicationClauseLibrary> getClauses();

  /// Library clause [clause] with each gap filled from [facts] (gap →
  /// fact), in every library language, for the editor to insert as custom
  /// text (club_server#107). No template is read or changed. An unknown
  /// clause, a gap without a fact, a fact for no gap, a fact of the wrong
  /// type or an unknown choice is 422 `APPLICATION_INVALID_REFERENCE`.
  Future<ApplicationFilledClause> fillClause(
    String clause, {
    Map<String, ApplicationFact> facts = const {},
  });
}
