<p align="center">
  <a href="https://pub.dev/packages/tarsier_websocket_client">
    <img height="260" src="https://raw.githubusercontent.com/marianz-bonfire/tarsier_websocket_client/master/assets/logo.png">
  </a>
  <h1 align="center">Tarsier WebSocket Client</h1>
</p>

<p align="center">
  <a href="https://pub.dev/packages/tarsier_websocket_client">
    <img src="https://img.shields.io/pub/v/tarsier_websocket_client?label=pub.dev&labelColor=333940&logo=dart">
  </a>
  <a href="https://pub.dev/packages/tarsier_websocket_client/score">
    <img src="https://img.shields.io/pub/points/tarsier_websocket_client?color=2E8B57&label=pub%20points">
  </a>
  <a href="https://github.com/marianz-bonfire/tarsier_websocket_client/actions/workflows/dart.yml">
    <img src="https://github.com/marianz-bonfire/tarsier_websocket_client/actions/workflows/dart.yml/badge.svg">
  </a>
  <a href="https://tarsier-marianz.blogspot.com">
    <img src="https://img.shields.io/static/v1?label=website&message=tarsier-marianz&labelColor=135d34&logo=blogger&logoColor=white&color=fd3a13">
  </a>
</p>

<p align="center">
  <a href="https://pub.dev/documentation/tarsier_websocket_client/latest/">Documentation</a> •
  <a href="https://github.com/marianz-bonfire/tarsier_websocket_client/issues">Issues</a> •
  <a href="https://github.com/marianz-bonfire/tarsier_websocket_client/tree/master/example">Example</a> •
  <a href="https://github.com/marianz-bonfire/tarsier_websocket_client/blob/master/LICENSE">License</a> •
  <a href="https://pub.dev/packages/tarsier_websocket_client">Pub.dev</a>
</p>



**Tarsier WebSocket Client** is a Dart package for managing WebSocket connections and real-time event handling. It is designed to be compatible with the Pusher WebSocket protocol used by [pusher.com](https://pusher.com/docs/channels/). This package extends the functionality of the `pusher_client` package to support the *Windows platform*, while maintaining compatibility with other platforms.

~~This package has been tested with [Laravel WebSockets](https://beyondco.de/docs/laravel-websockets/getting-started/introduction) from [BeyondCode](https://beyondco.de/). Although not explicitly tested with Pusher.com, it is expected to work with Pusher due to protocol compatibility.~~

This package has been tested and verified to work with [Laravel WebSockets](https://beyondco.de/docs/laravel-websockets/getting-started/introduction) by [BeyondCode](https://beyondco.de/) as well as [pusher.com](https://pusher.com/docs/channels/).
Since both services follow the same protocol, they are fully supported.


## ✨ Features
- **WebSocket Connection Management**: Connect, disconnect, and manage state seamlessly.
- **Channel Types**:
    - `Public Channels`: Basic channels without authentication.
    - `Private Channels`: Secure channels requiring authentication.
    - `Presence Channels`: Channels for tracking online users and presence data.
    - `Private Encrypted Channels`: Secure and encrypted channels for sensitive data.
- **Event Handling**: Bind, unbind, and handle custom events.
- **Authentication**: Secure private and presence channels with authentication options.
- **Encryption**: Support for encrypted channels using SecretBox for secure communication.
- **Windows Platform Support**: Extends the pusher_client package to work on Windows
- **Reconnection Logic**: Automatic reconnection with configurable retry attempts and intervals.
- **Logging**: Configurable logging for debugging and monitoring.

<p align="center">
  <a href="https://pub.dev/packages/tarsier_websocket_client">
    <img src="https://raw.githubusercontent.com/marianz-bonfire/tarsier_websocket_client/master/example/flutter_example/assets/NvdCYXm98i.png">
  </a>
</p>

## 👋 Disclaimer
~~This package is designed to work with the Pusher WebSocket protocol. It has been thoroughly tested with [Laravel WebSockets](https://beyondco.de/docs/laravel-websockets/getting-started/introduction) but not explicitly with the official [pusher.com](https://pusher.com/docs/channels/) service. If it works with [Laravel WebSockets](https://beyondco.de/docs/laravel-websockets/getting-started/introduction), it is likely to work with [pusher.com](https://pusher.com/docs/channels/) due to protocol compatibility. Feedback from developers testing it with Pusher.com is highly appreciated.~~

This package is designed for the **Pusher WebSocket protocol**.  It has been tested with **Laravel WebSockets (BeyondCode)** and **Pusher (pusher.com)**.

> **Note / TODO:**  
> Compatibility with **Laravel Reverb** has not yet been fully tested and is planned for a future update.


### Compatibility Roadmap
- ✅ Laravel WebSockets (BeyondCode)
- ✅ Pusher (pusher.com)
- ⏳ Laravel Reverb (planned)


## 🚀 Installation
Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  tarsier_websocket_client: ^1.1.1
```
Install it by running:
```sh
flutter pub get
```
Import it in your Dart code:
```dart
import 'package:tarsier_websocket_client/tarsier_websocket_client.dart';
```

## 📒 Usage
- **Basic Setup**
    
    Here's an example of setting up and using the Tarsier WebSocket Client:

```dart
import 'package:tarsier_websocket_client/tarsier_websocket_client.dart';

void main() {
  final client = TarsierWebsocketClient(
    options: PusherOptions(
      key: 'your-app-key',
      authOptions: PusherAuthOptions(
        endpoint: 'https://example.com/auth',
        headers: {
          'Authorization': 'Bearer your-token',
        },
      ),
    ),
  );

  // Log event when there's an error on connection
  client.onConnectionError((error) {
    print("Connection error: $error");
  });
  client.onError((error) {
    print("Error: $error");
  });
  client.onDisconnected((data) {
    print("Disconnected: $data");
  });

  // Connect to the WebSocket server
  client.connect();

  // Subscribe to a public channel
  final channel = client.subscribe<Channel>('my-channel');
  channel.bind('my-event', (data) {
    print('Event received: $data');
  });

  // Subscribe to a private channel
  final privateChannel = client.private('private-my-channel');
  privateChannel.bind('my-private-event', (data) {
    print('Private event received: $data');
  });

  // Disconnect when done
  client.disconnect();
}
```
- **Presence Channel Example**
```dart
final presenceChannel = client.presence('presence-my-channel');
presenceChannel.bind('user-joined', (data) {
  print('A new user joined: $data');
});
```
- **Logging**

Enable logging for debugging:
```dart
final client = TarsierWebsocketClient(
  options: PusherOptions(
    key: 'your-app-key',
    enableLogging: true, //Set to true if you want to enable logging
    authOptions: PusherAuthOptions(endpoint: 'https://example.com/auth'),
  ),
);
```
## ⚒️ API Reference

### Classes
- `TarsierWebsocketClient`: Main entry point for managing WebSocket connections.
- `PusherOptions`: Configures connection options such as authentication, encryption, and timeouts.
- `PusherAuthOptions`: Authentication options for private and presence channels.
- `Channel`: Base class for public channels.
- `PrivateChannel`: Secure channels requiring authentication.
- `PresenceChannel`: Channels with presence tracking.
- `PrivateEncryptedChannel`: Secure and encrypted channels.
### Methods
- `connect()`: Establishes a connection to the WebSocket server.
- `disconnect()`: Closes the connection.
- `subscribe(channelName)`: Subscribes to a channel by name.
- `unsubscribe(channelName)`: Unsubscribes from a channel.
- `unsubscribeAll()`: Unsubscribes from all channels.
- `bind(event, listener)`: Binds a listener to an event.
- `unbind(event, listener)`: Unbinds a listener from an event.
## 🎖️ License
This project is licensed under the [MIT License](https://mit-license.org/). See the LICENSE file for details.
## 🐞 Contributing
Contributions are welcome! Please submit a pull request or file an issue for any bugs or feature requests
on [GitHub](https://github.com/marianz-bonfire/tarsier_websocket_client).
