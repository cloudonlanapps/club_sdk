import 'package:http/http.dart' as http;

import 'default_http_client_stub.dart'
    if (dart.library.io) 'default_http_client_io.dart';

/// How long the default client keeps an idle connection for reuse (#92).
///
/// It sits below common server keep-alive timeouts (uvicorn closes an idle
/// connection after 5 s), so the client does not write a request onto a
/// connection the server has already closed.
const Duration defaultHttpIdleTimeout = Duration(seconds: 3);

/// The client `RemoteStore` uses when the caller passes none.
///
/// On the VM it keeps idle connections for [defaultHttpIdleTimeout]; in the
/// browser it is the platform client, whose connection reuse the browser
/// manages.
http.Client createDefaultHttpClient() =>
    createPlatformHttpClient(defaultHttpIdleTimeout);
