import '../../sdk/interfaces/application.dart';
import '../../sdk/models/application_clause_library.dart';
import '../../sdk/models/application_content.dart';
import '../../sdk/models/application_labels.dart';
import '../../sdk/models/application_library_text.dart';
import '../../sdk/models/application_patch.dart';
import '../../sdk/models/application_status.dart';
import '../../sdk/models/application_template.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [ApplicationSource] using HTTP API.
class RemoteApplicationSource implements ApplicationSource {
  RemoteApplicationSource(this._store);

  final RemoteStore _store;

  Future<ApplicationTemplate> postTemplate(String path) async =>
      ApplicationTemplate.fromMap(await _store.post(path));

  @override
  Future<ApplicationTemplate> createApplication(
    ApplicationContent content,
  ) async => ApplicationTemplate.fromMap(
    await _store.post(endpoints.applications.list, body: content.toMap()),
  );

  @override
  Future<PaginatedList<ApplicationTemplate>> listApplications({
    ApplicationStatus? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _store.get(
      endpoints.applications.list,
      queryParams: <String, String>{
        'offset': offset.toString(),
        'limit': limit.toString(),
        'status': ?status?.wireName,
      },
    );
    return PaginatedList.fromMap(response, ApplicationTemplate.fromMap);
  }

  @override
  Future<ApplicationTemplate> getApplication(int id) async =>
      ApplicationTemplate.fromMap(
        await _store.get(endpoints.applications.byId(id)),
      );

  @override
  Future<ApplicationTemplate> updateApplication(
    int id,
    ApplicationPatch patch,
  ) async => ApplicationTemplate.fromMap(
    await _store.patch(endpoints.applications.byId(id), body: patch.toMap()),
  );

  @override
  Future<ApplicationTemplate> deleteApplication(int id) async {
    final path = endpoints.applications.byId(id);
    final response = await _store.delete(path);
    if (response == null) {
      throw StateError('DELETE $path returned no body; expected the template');
    }
    return ApplicationTemplate.fromMap(response);
  }

  @override
  Future<ApplicationTemplate> saveApplication(int id) =>
      postTemplate(endpoints.applications.save(id));

  @override
  Future<ApplicationTemplate> publishApplication(int id) =>
      postTemplate(endpoints.applications.publish(id));

  @override
  Future<ApplicationTemplate> unpublishApplication(int id) =>
      postTemplate(endpoints.applications.unpublish(id));

  @override
  Future<ApplicationTemplate> revertApplication(int id) =>
      postTemplate(endpoints.applications.revert(id));

  @override
  Future<ApplicationTemplate> duplicateApplication(int id) =>
      postTemplate(endpoints.applications.duplicate(id));

  @override
  Future<List<int>> downloadPreview(int id) =>
      _store.downloadBytes(endpoints.applications.preview(id));

  @override
  Future<List<int>> downloadBlankForm(int id) =>
      _store.downloadBytes(endpoints.applications.blankForm(id));

  /// The `?category=` of a form download, when one is chosen.
  static Map<String, String> categoryQuery(int? category) => {
    'category': ?category?.toString(),
  };

  @override
  Future<List<int>> downloadOwnForm(int id, {int? category}) =>
      _store.downloadBytes(
        endpoints.applications.ownForm(id),
        queryParams: categoryQuery(category),
      );

  @override
  Future<List<int>> downloadMemberForm(
    int id,
    String username, {
    int? category,
  }) => _store.downloadBytes(
    endpoints.applications.memberForm(id, username),
    queryParams: categoryQuery(category),
  );

  @override
  Future<ApplicationLabels> getLabels() async => ApplicationLabels.fromMap(
    await _store.get(endpoints.applications.labels),
  );

  @override
  Future<ApplicationClauseLibrary> getClauses() async =>
      ApplicationClauseLibrary.fromMap(
        await _store.get(endpoints.applications.clauses),
      );

  @override
  Future<List<ApplicationLibraryText>> listLibraryTexts() async => [
    for (final t in await _store.getList(endpoints.applications.library))
      ApplicationLibraryText.fromMap(t as Map<String, dynamic>),
  ];

  @override
  Future<ApplicationLibraryText> getLibraryText(int id) async =>
      ApplicationLibraryText.fromMap(
        await _store.get(endpoints.applications.libraryText(id)),
      );

  @override
  Future<ApplicationLibraryText> createLibraryText(
    ApplicationLibraryTextInput input,
  ) async => ApplicationLibraryText.fromMap(
    await _store.post(endpoints.applications.library, body: input.toMap()),
  );

  @override
  Future<ApplicationLibraryText> updateLibraryText(
    int id,
    ApplicationLibraryTextPatch patch,
  ) async => ApplicationLibraryText.fromMap(
    await _store.patch(
      endpoints.applications.libraryText(id),
      body: patch.toMap(),
    ),
  );

  @override
  Future<void> deleteLibraryText(int id) async {
    await _store.delete(endpoints.applications.libraryText(id));
  }
}
