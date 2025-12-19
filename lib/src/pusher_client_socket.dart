import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:tarsier_websocket_client/src/channels/channel.dart';
import 'package:tarsier_websocket_client/src/collections/channels.collection.dart';
import 'package:tarsier_websocket_client/src/collections/events_listeners.collection.dart';
import 'package:tarsier_websocket_client/src/misc/options.dart';
import 'package:tarsier_websocket_client/src/models/connection_state_change.dart';
import 'package:tarsier_websocket_client/src/utils/print_debug.dart';
import 'package:tarsier_websocket_client/src/websockets/websocket_client/web_socket_client.dart';
import 'package:uuid/uuid.dart';

/// A client for connecting to a Pusher server.
///
/// The [PusherClient] handles establishing and maintaining a WebSocket
/// connection, managing channels, and handling events from the Pusher server.
class PusherClient {
  /// Configuration options for the client.
  ///
  /// These options include connection settings, authentication details,
  /// and event handling configurations.
  final PusherOptions options;

  /// Creates an instance of [PusherClient].
  ///
  /// The [options] parameter is required and provides configuration details
  /// for the client. If `options.autoConnect` is set to `true`, the client
  /// will attempt to connect automatically upon creation.
  PusherClient({required this.options}) {
    onConnectionError(_onConnectionError);
    onConnectionEstablished(_onConnectionEstablished);
    bind("pusher:ping", _onPing);
    bind("pusher:pong", (data) {
      _stopActivityTimer();
      _resetActivityCheck();
    });

    if (options.autoConnect) connect();
  }

  WebSocket? __socket;

  String? _socketId;

  /// The unique socket ID assigned by the Pusher server upon connection.
  String? get socketId => _socketId;

  bool _connected = false;

  /// Whether the client is currently connected to the Pusher server.
  bool get connected => _connected;

  SocketConnectionState _connectionState = const Disconnected();

  /// The current connection state of the client.
  SocketConnectionState get connectionState => _connectionState;

  WebSocket get _socket {
    if (__socket != null) return __socket!;
    throw Exception("The WebSocket is not initialized.");
  }

  /// Establishes a connection to the Pusher server.
  ///
  /// Creates a WebSocket connection using the provided URI in [options].
  /// Also sets up listeners for connection state and incoming messages.
  void connect() {
    __socket = WebSocket(options.uri);

    _socket.connection.listen(_onConnectionStateChange);

    _socket.messages.listen(
      _onMessageReceived,
      onError: (err) => _onEvent('error', err),
    );
  }

  /// Disconnects from the Pusher server.
  ///
  /// Optionally, a [code] and [reason] can be provided to describe the
  /// reason for disconnection.
  void disconnect([int? code, String? reason]) {
    options.log("DISCONNECT", data: {"code": code, "reason": reason}, type: DebugType.warning);

    _socket.close(code, reason);
    __socket = null;
  }

  /// Handles changes in the WebSocket connection state.
  void _onConnectionStateChange(SocketConnectionState state) {
    final states = {
      const Connecting(): 'CONNECTING',
      const Connected(): 'CONNECTED',
      const Reconnecting(): 'RECONNECTING',
      const Reconnected(): 'RECONNECTED',
      const Disconnecting(): 'DISCONNECTING',
      const Disconnected(): 'DISCONNECTED',
    };

    options.log(
      "CONNECTION_STATE_CHANGED",
      message: "The connection state changed from ${states[_connectionState]} to ${states[state]}",
      type: state is Disconnecting ? DebugType.warning : (state is Disconnected ? DebugType.error : DebugType.info),
    );
    _connectionState = state;
    _connected = state is Connected;

    // _onEvent("connection_state_changed", state);
    _onEvent(
        "connection_state_changed",
        ConnectionStateChange(
            previousState: states[_connectionState],
            currentState: states[state]));

    if (state is Connecting) {
      _onEvent('connecting', null);
    } else if (state is Connected) {
      _onEvent('connected', null);
      _resetActivityCheck();
      _reconnectionAttempts = 0;
    } else if (state is Reconnecting) {
      _onEvent('reconnecting', null);
    } else if (state is Reconnected) {
      _onEvent('reconnected', null);
      _resetActivityCheck();
      _reconnectionAttempts = 0;
    } else if (state is Disconnecting) {
      _onEvent('disconnecting', null);
    } else {
      _onEvent('disconnected', state);
      _stopActivityTimer();
      _connected = false;
      _socketId = null;
    }
  }

  /// Handles WebSocket connection errors.
  void _onConnectionError(dynamic error) {
    options.log("CONNECTION_ERROR", message: "Error: $error", type: DebugType.error);

    disconnect(1006, error.message);

    if (error is SocketException) {
      _reconnect();
    }
  }

  int _reconnectionAttempts = 0;

  /// Attempts to reconnect to the server if the connection is lost.
  void _reconnect() async {
    if (_reconnectionAttempts < options.maxReconnectionAttempts) {
      _reconnectionAttempts++;
      await Future.delayed(options.reconnectGap);
      connect();
    } else {
      disconnect(null, "Max reconnection attempts reached");
    }
  }

  /// Handles successful WebSocket connection establishment.
  void _onConnectionEstablished(Map data) {
    options.log("CONNECTION_ESTABLISHED", data: data, type: DebugType.success);
    _socketId = data['socket_id'];
    _connected = true;
    _reSubscribe();
  }

  /// Handles the ping event from the Pusher server.
  void _onPing(data) {
    options.log("PINGING", data: "$data");
    sendEvent("pusher:pong", data);
  }

  Timer? _activityTimer;

  /// Sends an activity check (ping) to the server.
  void _sendActivityCheck() {
    _stopActivityTimer();

    var dataValue = {"device_id": Uuid().v4()};
    sendEvent("pusher:ping", dataValue);

    _activityTimer = Timer.periodic(
      Duration(milliseconds: options.pongTimeout),
      (timer) {
        _onEvent("pusher:error", "Activity timeout");
        disconnect(null, "Activity timeout");
      },
    );
  }

  /// Resets the activity check timer.
  void _resetActivityCheck() {
    _stopActivityTimer();
    _activityTimer = Timer.periodic(
      Duration(milliseconds: options.activityTimeout),
      (timer) => _sendActivityCheck(),
    );
  }

  /// Stops the activity timer.
  void _stopActivityTimer() {
    _activityTimer?.cancel();
  }

  final _eventsListeners = EventsListenersCollection();

  /// Handles incoming WebSocket messages.
  void _onMessageReceived(message) {
    options.log("MESSAGE_RECEIVED", message: message, type: DebugType.success);

    dynamic event;

    try {
      event = jsonDecode(message);
    } catch (e) {
      throw Exception('Invalid message "$message", cannot decode message JSON');
    }

    if (event is Map) {
      if (event.containsKey('event')) {
        String eventName = event['event'].replaceAll(
          'pusher_internal:',
          'pusher:',
        );
        dynamic data = event['data'];

        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            printError('_onMessageReceived', e.toString());
          }
        }

        _onEvent(eventName, data, event["channel"]);
      } else {
        throw Exception('Invalid event "$event", missing event name');
      }
    } else {
      throw Exception(
        'Invalid event "$event", the event must be a map but ${event.runtimeType} given',
      );
    }
  }

  /// Handles custom events and routes them to the appropriate channel.
  void _onEvent(String event, data, [String? channel]) {
    _eventsListeners.handleEvent(event, data, channel);

    if (channel != null) {
      channelsCollection.get(channel)?.handleEvent(event, data);
    }
  }

  /// Binds a listener to an event.
  ///
  /// The [event] parameter specifies the event name, and [listener] is the
  /// callback function to execute when the event is triggered.
  void bind(String event, Function listener) {
    options.log("EVENT_BINDING", event: event, type: DebugType.verbose);

    _eventsListeners.bind(event, listener);
  }

  /// Sends an event to the server.
  ///
  /// The [event] parameter specifies the event name. The optional [data]
  /// parameter is the event payload, and [channel] specifies the target channel.
  void sendEvent(String event, [dynamic data, String? channel]) {
    options.log("SEND_EVENT", event: event, data: data);
    _socket.send(jsonEncode({
      "event": event,
      "data": data,
      if (channel != null) "channel": channel,
    }));
  }

  /// Binds a listener to the connection state change event.
  ///
  /// The [listener] is a callback that is invoked whenever the client's
  /// connection state changes. The new state is passed as a parameter.
  void onConnectionStateChange(Function(ConnectionStateChange) listener) =>
      bind("connection_state_changed", listener);

  /// Binds a listener to the connecting event.
  ///
  /// The [listener] callback is invoked when the client begins the process
  /// of establishing a connection to the Pusher server.
  void onConnecting(Function listener) => bind('connecting', listener);

  /// Binds a listener to the connected event.
  ///
  /// The [listener] callback is invoked when the client successfully connects
  /// to the Pusher server.
  void onConnected(Function listener) => bind('connected', listener);

  /// Binds a listener to the connection established event.
  ///
  /// This event is specific to the "pusher:connection_established" message
  /// from the server. The [listener] callback is invoked when the event occurs.
  void onConnectionEstablished(Function listener) =>
      bind("pusher:connection_established", listener);

  /// Binds a listener to the reconnecting event.
  ///
  /// The [listener] callback is invoked when the client attempts to reconnect
  /// to the server after a disconnection.
  void onReconnecting(Function listener) => bind('reconnecting', listener);

  /// Binds a listener to the reconnected event.
  ///
  /// The [listener] callback is invoked when the client successfully
  /// reconnects to the server after a disconnection.
  void onReconnected(Function listener) => bind('reconnected', listener);

  /// Binds a listener to the disconnecting event.
  ///
  /// The [listener] callback is invoked when the client begins disconnecting
  /// from the server.
  void onDisconnecting(Function listener) => bind('disconnecting', listener);

  /// Binds a listener to the disconnected event.
  ///
  /// The [listener] callback is invoked when the client successfully
  /// disconnects from the server.
  void onDisconnected(Function listener) => bind('disconnected', listener);

  /// Binds a listener to the connection error event.
  ///
  /// The [listener] callback is invoked when the client encounters
  /// a connection error.
  void onConnectionError(Function(dynamic error) listener) =>
      bind('connection_error', listener);

  /// Binds a listener to the error event.
  ///
  /// This event is triggered for general errors encountered by the client.
  /// The [listener] callback is invoked with the error details.
  void onError(Function(dynamic error) listener) =>
      bind('pusher:error', listener);

  /// Internal collection of active channels.
  ///
  /// This is used to manage the lifecycle and subscriptions of channels.
  @internal
  late final channelsCollection = ChannelsCollection(this);

  /// Returns a channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. The optional
  /// [subscribe] parameter, if set to `true`, subscribes to the channel before
  /// returning it.
  T channel<T extends Channel>(String channelName, {bool subscribe = false}) =>
      channelsCollection.channel<T>(channelName, subscribe: subscribe);

  /// Returns a private channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. If the name
  /// does not start with "private-", it is automatically prefixed. The optional
  /// [subscribe] parameter, if set to `true`, subscribes to the channel before
  /// returning it.
  PrivateChannel private(String channelName, {bool subscribe = false}) =>
      channel(
        channelName.startsWith("private-")
            ? channelName
            : "private-$channelName",
        subscribe: subscribe,
      );

  /// Returns a private encrypted channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. If the name
  /// does not start with "private-encrypted-", it is automatically prefixed.
  /// The optional [subscribe] parameter, if set to `true`, subscribes to the
  /// channel before returning it.
  PrivateChannel privateEncrypted(String channelName,
          {bool subscribe = false}) =>
      channel(
        channelName.startsWith("private-encrypted-")
            ? channelName
            : "private-encrypted-$channelName",
        subscribe: subscribe,
      );

  /// Returns a presence channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. If the name
  /// does not start with "presence-", it is automatically prefixed. The optional
  /// [subscribe] parameter, if set to `true`, subscribes to the channel before
  /// returning it.
  PresenceChannel presence(String channelName, {bool subscribe = false}) =>
      channel(
        channelName.startsWith("presence-")
            ? channelName
            : "presence-$channelName",
        subscribe: subscribe,
      );

  /// Subscribes to a channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. Returns the
  /// subscribed channel.
  T subscribe<T extends Channel>(String channelName) =>
      channel<T>(channelName, subscribe: true);

  /// Unsubscribes from a channel by its name.
  ///
  /// The [channelName] parameter specifies the channel's name. This removes
  /// the channel from the client's active channels collection.
  void unsubscribe(String channelName) => channel(channelName).unsubscribe();

  /// Unsubscribes from all channels.
  ///
  /// This iterates through all active channels and unsubscribes from each.
  void unsubscribeAll() => channelsCollection.forEach(
        (channel) => channel.unsubscribe(),
      );

  /// Re-subscribes to all previously subscribed channels.
  ///
  /// This is typically called after a reconnection to ensure that the client
  /// regains access to its channels.
  void _reSubscribe() => channelsCollection.forEach(
        (channel) => channel.subscribe(true),
      );
}
