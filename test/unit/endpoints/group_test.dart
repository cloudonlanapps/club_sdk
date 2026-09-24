import 'package:club_sdk_2/remote_store/endpoints/group.dart';
import 'package:test/test.dart';

void main() {
  const ep = GroupEndpoints();

  group('GroupEndpoints', () {
    test('list', () => expect(ep.list, '/groups'));
    test('deleted', () => expect(ep.deleted, '/groups/deleted'));
    test('group', () => expect(ep.group(1), '/groups/by_id/1'));
    test('restore', () => expect(ep.restore(1), '/groups/by_id/1/restore'));
    test('hardDelete', () => expect(ep.hardDelete(1), '/groups/by_id/1/hard'));
    test(
      'addMember',
      () => expect(
        ep.addMember(1, 'alice'),
        '/groups/by_id/1/members/byname/alice',
      ),
    );
    test(
      'removeMember',
      () =>
          expect(ep.removeMember(1, 'alice'), '/groups/by_id/1/members/alice'),
    );
    test('members', () => expect(ep.members(1), '/groups/by_id/1/members'));
    test(
      'myGroups',
      () => expect(ep.myGroups('alice'), '/users/by_id/alice/groups'),
    );
    test(
      'bulkMembers',
      () => expect(ep.bulkMembers(1), '/groups/by_id/1/members/bulk'),
    );
    test('eligible', () => expect(ep.eligible(1), '/groups/by_id/1/eligible'));
    test('requests', () => expect(ep.requests(1), '/groups/by_id/1/requests'));
    test(
      'approveRequest',
      () => expect(
        ep.approveRequest(1, 42),
        '/groups/by_id/1/requests/42/approve',
      ),
    );
    test(
      'rejectRequest',
      () => expect(
        ep.rejectRequest(1, 42),
        '/groups/by_id/1/requests/42/reject',
      ),
    );
  });
}
