import 'package:club_sdk_2/remote_store/endpoints/my_groups.dart';
import 'package:test/test.dart';

void main() {
  const ep = MyGroupsEndpoints();

  group('MyGroupsEndpoints', () {
    test('list', () => expect(ep.list('alice'), '/mygroups/by_id/alice'));
    test(
      'Issue 356: group',
      () => expect(
        ep.group('alice', 7),
        '/mygroups/by_id/alice/group/7',
      ),
    );
    test(
      'eligible',
      () => expect(ep.eligible('alice'), '/mygroups/by_id/alice/eligible'),
    );
    test(
      'join',
      () => expect(ep.join('alice', 7), '/mygroups/by_id/alice/join/7'),
    );
    test(
      'requests',
      () => expect(ep.requests('alice'), '/mygroups/by_id/alice/requests'),
    );
    test(
      'request',
      () => expect(
        ep.request('alice', 42),
        '/mygroups/by_id/alice/requests/42',
      ),
    );
  });
}
