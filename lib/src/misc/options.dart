import 'dart:convert';
import 'dart:developer' as dev;

import 'package:pinenacl/api.dart';
import 'package:pinenacl/x25519.dart' show SecretBox;
import 'package:tarsier_websocket_client/src/utils/print_debug.dart';

import 'auth_options.dart';

export 'auth_options.dart';

/// Configuration options for the Pusher client.
///
/// [PusherOptions] provides customizable settings for connecting to the Pusher server,
/// including connection parameters, authentication, logging, and reconnection behavior.
class PusherOptions {
  /// The application's unique key used for authentication.
  final String key;

  /// The WebSocket host URI.
  ///
  /// If not provided, a default host will be generated based on the cluster or standard Pusher endpoints.
  final String? host;

  /// The port used for non-encrypted WebSocket connections (default: 80).
  final int wsPort;

  /// The port used for encrypted WebSocket connections (default: 443).
  final int wssPort;

  /// Whether to use encrypted WebSocket connections.
  ///
  /// Defaults to `true`, which uses `wss`. Set to `false` to use `ws`.
  final bool encrypted;

  /// The cluster used to connect to Pusher.
  ///
  /// Example: `eu`, `us2`. If specified, the host will be generated using this value.
  final String? cluster;

  /// Timeout for detecting client activity (in milliseconds).
  ///
  /// Defaults to `120000` (2 minutes).
  final int activityTimeout;

  /// Timeout for waiting for a pong response (in milliseconds).
  ///
  /// Defaults to `30000` (30 seconds).
  final int pongTimeout;

  /// Custom parameters appended to the connection URI.
  final Map<String, String> parameters;

  /// Additional identifier of the client.
  final Map<String, dynamic>? identifier;

  /// Authentication options for secure connections.
  final PusherAuthOptions auth;

  /// Whether to enable logging for client actions.
  ///
  /// Defaults to `false`. If enabled, logs are output using the Dart `log` utility.
  final bool enableLogging;

  /// Whether to automatically connect the client upon initialization.
  ///
  /// Defaults to `true`.
  final bool autoConnect;

  /// Maximum number of reconnection attempts.
  ///
  /// Defaults to `6`. After this limit, the client stops attempting to reconnect.
  final int maxReconnectionAttempts;

  /// Duration between reconnection attempts.
  ///
  /// Defaults to 2 seconds.
  final Duration reconnectGap;

  /// Optional handler for decrypting encrypted channel data.
  ///
  /// If not provided, a default decryption handler is used.
  final Map<String, dynamic> Function(
    Uint8List sharedSecret,
    Map<String, dynamic> data,
  )? channelDecryption;

  /// Creates an instance of [PusherOptions].
  ///
  /// The [key] and [authOptions] are required.
  /// Optional parameters like [host], [cluster], [enableLogging], and others
  /// allow for further customization.
  const PusherOptions({
    required this.key,
    this.cluster,
    this.host,
    this.wsPort = 80,
    this.wssPort = 443,
    this.encrypted = true,
    this.activityTimeout = 120000,
    this.pongTimeout = 30000,
    this.parameters = const {
      'client': 'pusher-client-socket-dart',
      'protocol': '7',
      'version': '0.0.2',
      "flash": "false",
    },
    this.identifier,
    required this.auth,
    this.enableLogging = false,
    this.autoConnect = true,
    this.maxReconnectionAttempts = 6,
    this.reconnectGap = const Duration(seconds: 2),
    this.channelDecryption,
  });

  /// Constructs the WebSocket URI based on the provided options.
  ///
  /// This generates the URI dynamically, considering encryption, host, cluster,
  /// and additional query parameters.
  Uri get uri {
    Uri? hostUri;
    try {
      hostUri = Uri.parse(host!);
      if (hostUri.scheme.isEmpty) {
        hostUri = Uri.parse('${encrypted ? 'wss' : 'ws'}://$host');
      }
    } catch (e) {
      dev.log("Invalid host: $host", error: e);
    }

    return Uri(
      scheme: hostUri?.scheme.isNotEmpty == true
          ? hostUri!.scheme
          : (encrypted ? 'wss' : 'ws'),
      host: hostUri?.host.isNotEmpty == true
          ? hostUri!.host
          : (cluster != null ? 'ws-$cluster.pusher.com' : 'ws.pusher.com'),
      port: hostUri?.port == 0 ? (encrypted ? wssPort : wsPort) : uri.port,
      queryParameters: {
        ...parameters,
        if (hostUri?.query.isNotEmpty == true) ...hostUri!.queryParameters,
      },
      path: '/app/$key',
    );
  }

  /// Logs a message with an optional level and channel.
  ///
  /// The [level] parameter indicates the severity or category of the log.
  /// The optional [channel] and [message] provide additional context.
  log(String level,
      {String? channel, String? event, dynamic data, dynamic message, DebugType type = DebugType.info}) {
    if (enableLogging) {
      String tag = [
        "PUSHER_",
        if (channel != null) "CHANNEL_",
        level,
      ].join("");

      // Create a Map and filter out null values
      Map<String, dynamic> logData = {
        if (channel != null) "channel": channel,
        if (event != null) "event": event,
        if (data != null) "data": data,
        if (message != null) "message": message,
      };

      // Convert the Map to a JSON string
      String value = jsonEncode(logData);

      printLog(tag: tag, message: value, type: type);
    }
  }

  /// Decodes a Base64-encoded ciphertext into a [ByteList].
  ByteList _decodeCipherText(String cipherText) {
    Uint8List uint8list = base64Decode(cipherText);
    ByteData byteData = ByteData.sublistView(uint8list);
    List<int> data = List<int>.generate(
        byteData.lengthInBytes, (index) => byteData.getUint8(index));
    return ByteList(data);
  }

  /// Decrypts channel data using the provided shared secret and data.
  ///
  /// Uses the [channelDecryption] handler if provided, otherwise defaults
  /// to [defaultChannelDecryptionHandler].
  Map<String, dynamic> decryptChannelData(
    Uint8List sharedSecret,
    Map<String, dynamic> data,
  ) =>
      (channelDecryption ?? defaultChannelDecryptionHandler)(
        sharedSecret,
        data,
      );

  /// Default handler for decrypting encrypted channel data.
  ///
  /// Expects `data` to contain `ciphertext` and `nonce` fields. If these fields
  /// are not present, an exception is thrown. Decrypts the ciphertext using the
  /// provided shared secret and nonce.
  Map<String, dynamic> defaultChannelDecryptionHandler(
    Uint8List sharedSecret,
    Map<String, dynamic> data,
  ) {
    if (!data.containsKey("ciphertext") || !data.containsKey("nonce")) {
      throw Exception(
        "Unexpected format for encrypted event, expected object with `ciphertext` and `nonce` fields, got: $data",
      );
    }

    final ByteList cipherText = _decodeCipherText(data["ciphertext"]);

    final Uint8List nonce = base64Decode(data["nonce"]);

    final SecretBox secretBox = SecretBox(sharedSecret);
    final Uint8List decryptedData = secretBox.decrypt(cipherText, nonce: nonce);

    return jsonDecode(utf8.decode(decryptedData)) as Map<String, dynamic>;
  }
}
