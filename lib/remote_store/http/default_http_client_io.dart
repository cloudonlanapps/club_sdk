import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The default client on platforms with `dart:io`: an [IOClient] whose
/// connections are dropped after [idleTimeout] idle.
http.Client createPlatformHttpClient(Duration idleTimeout) =>
    IOClient(configureDefaultHttpClient(HttpClient(), idleTimeout));

/// Applies the default client's settings to [client] and returns it.
HttpClient configureDefaultHttpClient(
  HttpClient client,
  Duration idleTimeout,
) => client..idleTimeout = idleTimeout;
