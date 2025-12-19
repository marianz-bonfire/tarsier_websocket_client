import 'dart:convert';
import 'dart:typed_data';

import '../utils/print_debug.dart';
import 'channel.dart';


/// Represents a private encrypted channel that inherits from [PrivateChannel].
///
/// The [PrivateEncryptedChannel] class provides functionality for
/// handling encrypted messages exchanged over a private channel.
/// It employs a shared secret to decrypt incoming event data.
class PrivateEncryptedChannel extends PrivateChannel {
  /// Creates an instance of [PrivateEncryptedChannel] with the specified [client] and [name].
  ///
  /// The [client] parameter is the instance of the Pusher client,
  /// and the [name] parameter is the name of the encrypted channel to connect to.
  PrivateEncryptedChannel({
    required super.client,
    required super.name,
  });

  /// Decrypts the provided data map using the shared secret.
  ///
  /// Throws an [Exception] if the shared secret is missing
  /// in the authentication data. The decryption process is handled
  /// by the [decryptChannelData] method of the Pusher client options.
  Map<String, dynamic> _decrypt(Map<String, dynamic> data) {
    if (sharedSecret == null) {
      throw Exception("SharedSecret is missing in the auth data");
    }

    return client.options.decryptChannelData(sharedSecret!, data);
  }

  /// The shared secret for the encrypted channel.
  ///
  /// Returns the shared secret as a [Uint8List] if it exists
  /// in the authentication data; otherwise, returns null.
  Uint8List? get sharedSecret => authData?.sharedSecret != null
      ? base64Decode(authData!.sharedSecret!)
      : null;

  /// Handles the incoming event by decrypting the data, if it is not a Pusher internal event.
  ///
  /// This overrides the base [handleEvent] method from [PrivateChannel].
  /// If the event data is a map and does not start with "pusher:", it will
  /// attempt to decrypt the data before passing it to the superclass method.
  /// Logs an error if decryption fails.
  @override
  void handleEvent(String event, [data]) {
    if (data is Map && !event.startsWith("pusher:")) {
      try {
        data = _decrypt(data as Map<String, dynamic>);
      } catch (e) {
        options.log("ERROR", channel: name, message: "Failed to decrypt event data: $e", type: DebugType.error);
        return;
      }
    }

    super.handleEvent(event, data);
  }

  /// Triggers an event on the channel (Disabled for encrypted channels).
  ///
  /// This method is overridden from the [PrivateChannel] class to prevent
  /// triggering events on encrypted channels. An exception is thrown
  /// if an attempt is made to invoke this method.
  @override
  void trigger(String event, [data]) {
    throw Exception("Cannot trigger events on an encrypted channel");
  }
}
