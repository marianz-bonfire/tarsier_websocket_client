## 1.1.0
- Updated dependency versions to latest stable releases
- Improved Dart 3 analysis and linting configuration
- Bumped compatibility with all Dart 3.x SDKs
- Enhanced logging
- Updated and enhanced the main example

## 1.0.1
- Upgraded environment SDK constraint
- Upgraded some dependencies
- Added colorized log printing
- Added some necessary classes for enhancement
* Fixed issue of flutter pinning 
+ Added new flutter example project
+ Added initial github workflow


## 1.0.0-dev

- ### Added
    - Initial release of the `Tarsier WebSocket Client` package.
    - Implemented the `TarsierWebsocketClient` class for managing WebSocket connections and interacting with real-time events.
    - Added the following core components:
        - `PusherClient`: The primary client for managing WebSocket connections and handling events.
        - `PusherOptions`: Configuration options for customizing the WebSocket connection, authentication, and reconnection behavior.
        - `PusherAuthOptions`: Authentication settings for private and presence channels.
    - Introduced channel management with the following channel types:
        - `Public Channels`: Basic channels without authentication.
        - `Private Channels`: Secure channels requiring authentication.
        - `Presence Channels`: Channels for tracking online users and presence data.
        - `Private Encrypted Channels`: Secure and encrypted channels for sensitive data.
    - Added utilities for managing events:
        - `EventsListenersCollection`: Handles event listeners for individual channels and global events.
        - `ChannelsCollection`: Manages the lifecycle of channels (creation, subscription, unsubscription, and cleanup).
    - Implemented event decryption for encrypted channels using `SecretBox` from `pinenacl`.
    - Provided extensible support for event logging with customizable verbosity.
    - Included default and customizable handlers for activity and pong timeouts.
