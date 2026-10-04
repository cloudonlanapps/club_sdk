import 'package:meta/meta.dart';

/// URL builder for the member-facing `/myevaluations` routes.
@immutable
class MyEvaluationsEndpoints {
  const MyEvaluationsEndpoints();

  String list(String username) => '/myevaluations/by_id/$username';
  String one(String username, int id) => '/myevaluations/by_id/$username/$id';
  String media(String username, int id) =>
      '/myevaluations/by_id/$username/$id/media';
}
