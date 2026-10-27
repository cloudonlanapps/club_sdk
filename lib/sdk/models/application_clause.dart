import 'application_library_text.dart';

/// One entry of the clauses list (`GET /applications/clauses`,
/// club_server#93, R7; #133): a text of the club's library, which the
/// editor pastes into a template as written, its `{gap}`s included. The
/// PDF fills each gap from the template's fact of that name.
///
/// The server's built-in clauses are seeded into the library on first use
/// (club_server#133, #96), so every entry is a library text: a seeded one
/// keeps its built-in key in [ApplicationLibraryText.key], one the club
/// wrote has none. Each is edited and deleted through
/// `ApplicationSource.updateLibraryText` / `deleteLibraryText`.
typedef ApplicationClause = ApplicationLibraryText;
