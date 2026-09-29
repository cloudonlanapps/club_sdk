import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The default client on platforms with `dart:io`: an [IOClient] whose
/// connections are dropped after [idleTimeout] idle (#92).
///
/// A client supplied for the current zone with `http.runWithClient` wins
/// (#94): `http.Client()` returns it, and it is used as is. Without one,
/// `http.Client()` gives a plain [IOClient], which is swapped for the
/// configured one. (A zone that supplies an [IOClient] of its own is
/// indistinguishable from that default and gets the configured client.)
http.Client createPlatformHttpClient(Duration idleTimeout) {
  final fromZone = http.Client();
  if (fromZone is! IOClient) return fromZone;
  fromZone.close();
  return IOClient(configureDefaultHttpClient(HttpClient(), idleTimeout));
}

/// Applies the default client's settings to [client] and returns it.
HttpClient configureDefaultHttpClient(
  HttpClient client,
  Duration idleTimeout,
) => client..idleTimeout = idleTimeout;
