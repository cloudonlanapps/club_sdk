import 'package:meta/meta.dart';

@immutable
class BroadcastEndpoints {
  const BroadcastEndpoints();

  String get list => '/broadcasts';
  String byId(int id) => '/broadcasts/by_id/$id';
  String recipients(int id) => '/broadcasts/by_id/$id/recipients';
}
