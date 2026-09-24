/// Remote Store - HTTP-based implementation of the Club SDK interfaces.
///
/// This library provides remote implementations that communicate with
/// a backend API server over HTTP.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:club_sdk_2/remote_store.dart';
///
/// // Create a secure client for authenticated operations
/// final client = await createRemoteSecureClient(
///   baseUrl: 'https://api.myexampleclub.com/v1',
/// );
///
/// // Login
/// final token = await client.auth.login('username', 'password');
///
/// // Use authenticated operations
/// final events = await client.events.listEvents(
///   filter: EventFilter.myEvents,
/// );
/// ```
///
/// For the token-free `/public` routes alone, with no login:
///
/// ```dart
/// final public = createRemotePublicSource(
///   baseUrl: 'https://api.myexampleclub.com/v1',
/// );
/// ```
library;

export 'remote_store/http/api_exception.dart' show mapHttpError;
export 'remote_store/remote_client.dart'
    show createRemotePublicSource, createRemoteSecureClient;
export 'remote_store/remote_store.dart' show RemoteStore, UrlTransformer;
