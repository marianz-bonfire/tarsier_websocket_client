import 'package:meta/meta.dart';
import 'package:tarsier_websocket_client/src/collections/events_listeners.collection.dart';
import 'package:tarsier_websocket_client/src/misc/options.dart';
import 'package:tarsier_websocket_client/src/pusher_client_socket.dart';

export 'private_channel.dart';
export 'private_encrypted_channel.dart';
export 'presence_channel.dart';

/// A representation of a Pusher channel.
///
/// A channel is a fundamental concept in Pusher, allowing clients to subscribe
/// to events and interact with them through events like subscription success,
/// binding to custom events, and handling received events.
class Channel {
  /// The Pusher client instance associated with this channel.
  final PusherClient client;

  /// The name of the channel.
  ///
  /// Channel names can determine the type of channel:
  /// - Public: no prefix
  /// - Private: starts with `private-`
  /// - Presence: starts with `presence-`
  /// - Encrypted: starts with `private-encrypted-`
  final String name;

  /// Creates an instance of [Channel].
  ///
  /// The [client] parameter specifies the Pusher client, and [name] specifies
  /// the name of the channel.
  Channel({required this.client, required this.name});

  /// Retrieves the Pusher client options.
  ///
  /// These options define the configuration and behavior of the Pusher client.
  PusherOptions get options => client.options;

  /// Retrieves the authentication options for the Pusher client.
  PusherAuthOptions get authOptions => options.auth;

  bool _subscribed = false;

  /// Whether the channel is currently subscribed.
  ///
  /// Returns `true` if the client is subscribed to this channel; otherwise,
  /// returns `false`.
  bool get subscribed => _subscribed;

  /// Checks if the channel is a private channel.
  ///
  /// Returns `true` if the channel name starts with `private-`.
  bool get isPrivate => name.startsWith("private-");

  /// Checks if the channel is a presence channel.
  ///
  /// Returns `true` if the channel name starts with `presence-`.
  bool get isPresence => name.startsWith("presence-");

  /// Checks if the channel is an encrypted channel.
  ///
  /// Returns `true` if the channel name starts with `private-encrypted-`.
  bool get isEncrypted => name.startsWith("private-encrypted-");

  /// Checks if the channel is a public channel.
  ///
  /// Returns `true` if the channel is neither private, presence, nor encrypted.
  bool get isPublic => !isPrivate && !isPresence && !isEncrypted;

  /// Sets the value of the subscribed property.
  ///
  /// This is a protected setter intended for internal use.
  @protected
  set subscribed(bool value) {
    _subscribed = value;
  }

  /// Subscribes to the channel.
  ///
  /// If the channel is already subscribed and [force] is `false`, this method
  /// does nothing. If [force] is `true`, it re-subscribes to the channel even
  /// if it is already subscribed.
  void subscribe([bool force = false]) async {
    if (!client.connected ||
        (subscribed && !force) ||
        client.socketId == null) {
      return;
    }

    _subscribed = false;

    options.log("SUBSCRIBE", channel: name);

    client.sendEvent("pusher:subscribe", {"channel": name});

    if (isPublic) _subscribed = true;
  }

  final _eventsListenersCollection = EventsListenersCollection();

  /// Binds a listener to a specified event.
  ///
  /// The [event] parameter specifies the event name, and [listener] is the
  /// callback function to execute when the event is triggered.
  void bind(String event, Function listener) {
    options.log("EVENT_BINDING", event: event, channel: name);

    _eventsListenersCollection.bind(event, listener);
  }

  /// Unbinds all listeners associated with a specific event.
  ///
  /// The [event] parameter specifies the event name whose listeners should
  /// be removed.
  void unbind(String event) => _eventsListenersCollection.unbindAll(event);

  /// Handles an incoming event from the Pusher server.
  ///
  /// The [event] parameter specifies the name of the event, and [data]
  /// contains the event payload.
  void handleEvent(String event, dynamic data) {
    options.log('EVENT', channel: name, event: event, data: data);

    _eventsListenersCollection.handleEvent(event, data);
  }

  /// Unsubscribes from the channel.
  ///
  /// This removes the channel from the client's channels collection and stops
  /// receiving events for this channel.
  void unsubscribe() {
    client.sendEvent("pusher:unsubscribe", {"channel": name});

    _subscribed = false;

    client.channelsCollection.remove(name);
  }

  /// Binds a listener to the subscription success event.
  ///
  /// This event is triggered when the client successfully subscribes to
  /// the channel. The [listener] parameter is the callback function to
  /// execute when the event is triggered.
  void onSubscriptionSuccess(Function listener) {
    bind("pusher:subscription_succeeded", listener);
  }

  /// Binds a listener to the internal subscription success event.
  ///
  /// This is used internally by the Pusher client. The [listener] parameter
  /// is the callback function to execute when the event is triggered.
  void onInternalSubscriptionSuccess(Function listener) {
    bind("pusher_internal:subscription_succeeded", listener);
  }
}
