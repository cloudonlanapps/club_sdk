import 'package:http/http.dart' as http;

/// The default client on platforms without `dart:io` (the browser, whose
/// connection reuse the browser manages).
http.Client createPlatformHttpClient(Duration idleTimeout) => http.Client();
