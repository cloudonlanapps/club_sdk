import '../../sdk/interfaces/capabilities.dart';
import '../../sdk/models/capabilities.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [CapabilitiesSource].
class RemoteCapabilitiesSource implements CapabilitiesSource {
  RemoteCapabilitiesSource(this._store);

  final RemoteStore _store;

  @override
  Future<Capabilities> getCapabilities() async {
    final response = await _store.get(endpoints.capabilities.capabilities);
    return Capabilities.fromMap(response);
  }
}
