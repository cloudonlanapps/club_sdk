import 'package:club_sdk_2/remote_store/endpoints/venue.dart';
import 'package:test/test.dart';

void main() {
  const ep = VenueEndpoints();

  group('VenueEndpoints', () {
    test('list', () => expect(ep.list, '/venues'));
    test('deleted', () => expect(ep.deleted, '/venues/deleted'));
    test('venue', () => expect(ep.venue(1), '/venues/by_id/1'));
    test('restore', () => expect(ep.restore(1), '/venues/by_id/1/restore'));
    test('hardDelete', () => expect(ep.hardDelete(1), '/venues/by_id/1/hard'));
  });
}
