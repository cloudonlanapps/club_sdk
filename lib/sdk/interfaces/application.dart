import '../models/application_clause_library.dart';
import '../models/application_content.dart';
import '../models/application_labels.dart';
import '../models/application_library_text.dart';
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
/// [downloadPreview], [downloadBlankForm], [downloadMemberForm],
/// [getLabels], [getClauses] and the club library ([listLibraryTexts] …
/// [deleteLibraryText]) are an admin's (403 otherwise; 401 signed out). [listApplications],
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
  /// A printed text may hold `{name}` gaps (`name` matching
  /// `[a-z][a-z0-9_]*`; other braces are literal), stored as written and
  /// filled from the fact of that name when a PDF is drawn
  /// (club_server#126).
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
  /// null clears it, a field left out keeps its value. Gaps are stored as
  /// written, even one naming no fact. A saved or
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
  /// a gap names no fact of the template
  /// (`ApplicationUnknownFactException`, club_server#126), or the details
  /// alone overflow page 1 (`ApplicationDoesNotFitException`). Otherwise
  /// the layout is decided on the filled texts and stored on the template.
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

  /// Saved or published template [id]'s form with no member in it and no
  /// watermark: every label, box and tick box, for filling in by hand
  /// (club_server#129). A published template's is the drawing stored when
  /// it was published, with its side mark "Form <publishId>"; a saved
  /// one's is drawn on request, with no publish mark. The server names it
  /// `application-<id>-blank.pdf`.
  ///
  /// A draft is 422 `APPLICATION_NOT_SAVED`; an unknown template 404
  /// `APPLICATION_NOT_FOUND`.
  Future<List<int>> downloadBlankForm(int id);

  /// The caller's own form of published template [id]. A member no age
  /// category matches, or with no date of birth, is 422
  /// `APPLICATION_NOT_ELIGIBLE`.
  ///
  /// [category] is the index of the age category to tick
  /// (club_server#108): needed when the member fits several
  /// (`ApplicationCategoryRequiredException` otherwise), and it must be one
  /// they fit (`ApplicationCategoryNotFittingException` otherwise). A
  /// member's [getApplication] lists the ones they fit
  /// (`ApplicationTemplate.fittingCategories`).
  Future<List<int>> downloadOwnForm(int id, {int? category});

  /// [username]'s form of published template [id], for an admin. A
  /// template not published is 422 `APPLICATION_NOT_PUBLISHED`; an unknown
  /// user 404 `USER_NOT_FOUND`. [category] is chosen as for
  /// [downloadOwnForm], for that member.
  Future<List<int>> downloadMemberForm(
    int id,
    String username, {
    int? category,
  });

  /// The label catalogue, to pre-fill the editor.
  Future<ApplicationLabels> getLabels();

  /// The clauses list, for the editor's pickers: the built-in clauses,
  /// then the club's library texts, each marked with its source and given
  /// as written, gaps included (club_server#126).
  Future<ApplicationClauseLibrary> getClauses();

  /// Every club library text, oldest first (club_server#126, R7a).
  Future<List<ApplicationLibraryText>> listLibraryTexts();

  /// One club library text (404 `APPLICATION_LIBRARY_TEXT_NOT_FOUND`).
  Future<ApplicationLibraryText> getLibraryText(int id);

  /// Add a club library text (201). A shape the server refuses — a name
  /// not 1–100 characters, an empty text, a language outside the
  /// catalogue, a heading on a kind that is not a rule — is 422
  /// `VALIDATION_ERROR`.
  Future<ApplicationLibraryText> createLibraryText(
    ApplicationLibraryTextInput input,
  );

  /// Change club library text [id]: the fields [patch] gives replace the
  /// stored ones, and a null heading clears it. A result that would be
  /// refused as a new text is 422 `VALIDATION_ERROR` and changes nothing;
  /// an unknown [id] is 404 `APPLICATION_LIBRARY_TEXT_NOT_FOUND`.
  Future<ApplicationLibraryText> updateLibraryText(
    int id,
    ApplicationLibraryTextPatch patch,
  );

  /// Remove club library text [id] for good (204). No template changes:
  /// a template holds the texts pasted into it. An unknown [id] is 404
  /// `APPLICATION_LIBRARY_TEXT_NOT_FOUND`.
  Future<void> deleteLibraryText(int id);
}
