import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarsier_websocket_client/tarsier_websocket_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pusher Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PusherClientScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PusherClientScreen extends StatefulWidget {
  const PusherClientScreen({super.key});

  @override
  State<PusherClientScreen> createState() => _PusherClientScreenState();
}

enum ConnectionStatus { disconnected, connecting, connected, error }

class _PusherClientScreenState extends State<PusherClientScreen> {
  final _scrollController = ScrollController();
  final List<LogEntry> _logs = [];

  // Form controllers
  final _hostController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _clusterController = TextEditingController();
  final _channelController = TextEditingController();
  final _eventController = TextEditingController();
  final _dataController = TextEditingController();

  // Form keys
  final _connectionFormKey = GlobalKey<FormState>();
  final _subscriptionFormKey = GlobalKey<FormState>();

  // Pusher
  PusherClient? _pusher;
  Channel? _channel;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  @override
  void dispose() {
    _disconnectPusher();
    _hostController.dispose();
    _apiKeyController.dispose();
    _clusterController.dispose();
    _channelController.dispose();
    _eventController.dispose();
    _dataController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _hostController.text = prefs.getString('pusher_host') ?? '192.168.10.121';
      _apiKeyController.text = prefs.getString('pusher_api_key') ?? '182c58278217ab48deab';
      _clusterController.text = prefs.getString('pusher_cluster') ?? 'mt1';
      _channelController.text = prefs.getString('pusher_channel') ?? 'message-channel';
      _eventController.text = prefs.getString('pusher_event') ?? 'message-event';
      _dataController.text = prefs.getString('pusher_data') ?? 'test';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('pusher_host', _hostController.text);
    await prefs.setString('pusher_api_key', _apiKeyController.text);
    await prefs.setString('pusher_cluster', _clusterController.text);
    await prefs.setString('pusher_channel', _channelController.text);
    await prefs.setString('pusher_event', _eventController.text);
    await prefs.setString('pusher_data', _dataController.text);
  }

  Future<void> _connectToPusher() async {
    if (!_connectionFormKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    await _savePreferences();

    setState(() {
      _connectionStatus = ConnectionStatus.connecting;
    });

    _addLog('🔗 Connecting to Pusher...', LogType.info);

    // Disconnect existing connection if any
    await _disconnectPusher();

    final options = PusherOptions(
      key: _apiKeyController.text,
      host: _hostController.text,
      wsPort: 6001,
      encrypted: false,
      cluster: _clusterController.text,
      auth: PusherAuthOptions(
        '${_hostController.text}/broadcasting/auth',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer',
        },
      ),
      enableLogging: true,
    );

    _pusher = PusherClient(options: options);

    // Setup event listeners
    _setupPusherListeners();

    // Connect
    _pusher!.connect();
  }

  void _setupPusherListeners() {
    _pusher?.onConnectionStateChange((state) {

      LogType type = LogType.info;

      if (state.currentState == 'CONNECTED') {
        setState(() {
          _connectionStatus = ConnectionStatus.connected;
        });
        type = LogType.success;
        _subscribeToChannel();
      } else if (state.currentState == 'DISCONNECTED') {
        setState(() {
          _connectionStatus = ConnectionStatus.disconnected;
        });
        type = LogType.error;
      }
      _addLog(
        '🔄 Connection state: ${state.previousState} → ${state.currentState}',
        type,
      );
    });

    _pusher?.onConnectionError((error) {
      _addLog('❌ Connection error: ${error?.message}', LogType.error);
      setState(() {
        _connectionStatus = ConnectionStatus.error;
      });
    });

    _pusher?.onError((error) {
      _addLog('⚠️ Pusher error: $error', LogType.error);
    });
  }

  Future<void> _subscribeToChannel() async {
    if (!_subscriptionFormKey.currentState!.validate()) {
      return;
    }

    final channelName = _channelController.text;
    final eventName = _eventController.text;

    _addLog('📡 Subscribing to channel: $channelName', LogType.info);

    _channel = _pusher?.subscribe(channelName);

    _channel?.onSubscriptionSuccess((event) {
      _addLog('✅ Subscribed to channel: $channelName', LogType.success);
    });

    _channel?.bind(eventName, (event) {
      _addLog('📩 Event received: ${event?.data}', LogType.event);
    });
  }

  Future<void> _triggerEvent() async {
    if (_dataController.text.isEmpty) {
      _addLog('Please enter data to send', LogType.warning);
      return;
    }
    final channelName = _channelController.text;
    final eventName = _eventController.text;
    final data = _dataController.text;

    _addLog('🚀 Triggering event with data: $data', LogType.info);

    _pusher?.sendEvent(eventName, data, channelName);
  }

  Future<void> _disconnectPusher() async {
    if (_channel != null) {
      _pusher?.unsubscribe(_channelController.text);
    }

    _pusher?.disconnect();

    setState(() {
      _connectionStatus = ConnectionStatus.disconnected;
      _channel = null;
      _pusher = null;
    });

    _addLog('🔌 Disconnected from Pusher', LogType.info);
  }

  void _addLog(String message, LogType type) {
    setState(() {
      _logs.add(LogEntry(
        message: message,
        type: type,
        timestamp: DateTime.now(),
      ));

      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.disconnected:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (_connectionStatus) {
      case ConnectionStatus.connected:
        return 'CONNECTED';
      case ConnectionStatus.connecting:
        return 'CONNECTING';
      case ConnectionStatus.error:
        return 'ERROR';
      case ConnectionStatus.disconnected:
        return 'DISCONNECTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusher Client'),
        actions: [
          _buildStatusIndicator(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _connectionFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connection Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _hostController,
                        label: 'Host',
                        validator: (value) => value?.isEmpty == true ? 'Host is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _apiKeyController,
                        label: 'API Key',
                        validator: (value) => value?.isEmpty == true ? 'API Key is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _clusterController,
                        label: 'Cluster',
                        validator: (value) => value?.isEmpty == true ? 'Cluster is required' : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _connectionStatus == ConnectionStatus.connected ? _disconnectPusher : _connectToPusher,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _connectionStatus == ConnectionStatus.connected ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: _connectionStatus == ConnectionStatus.connected
                              ? const Icon(Icons.link_off, size: 20)
                              : const Icon(Icons.link, size: 20),
                          label: Text(
                            _connectionStatus == ConnectionStatus.connected ? 'Disconnect' : 'Connect',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Subscription Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _subscriptionFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Subscription Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _channelController,
                        label: 'Channel',
                        validator: (value) => value?.isEmpty == true ? 'Channel is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _eventController,
                        label: 'Event',
                        validator: (value) => value?.isEmpty == true ? 'Event is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _dataController,
                        label: 'Event Data',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _subscribeToChannel,
                              icon: const Icon(Icons.subscriptions, size: 20),
                              label: const Text('Subscribe'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _triggerEvent,
                              icon: const Icon(Icons.send, size: 20),
                              label: const Text('Trigger Event'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs Section
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text(
                            'Event Logs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _clearLogs,
                            icon: const Icon(Icons.clear_all),
                            tooltip: 'Clear logs',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12),
                          ),
                        ),
                        child: _logs.isEmpty
                            ? const Center(
                                child: Text(
                                  'No logs yet. Connect to start receiving events.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  final log = _logs[index];
                                  return LogItem(log: log);
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor().withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

enum LogType { info, success, error, warning, event }

class LogEntry {
  final String message;
  final LogType type;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.type,
    required this.timestamp,
  });
}

class LogItem extends StatelessWidget {
  final LogEntry log;

  const LogItem({super.key, required this.log});

  Color _getLogColor() {
    switch (log.type) {
      case LogType.success:
        return Colors.green;
      case LogType.error:
        return Colors.red;
      case LogType.warning:
        return Colors.orange;
      case LogType.event:
        return Colors.blue;
      case LogType.info:
        return Colors.grey[700]!;
    }
  }

  IconData _getLogIcon() {
    switch (log.type) {
      case LogType.success:
        return Icons.check_circle;
      case LogType.error:
        return Icons.error;
      case LogType.warning:
        return Icons.warning;
      case LogType.event:
        return Icons.message;
      case LogType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _getLogIcon(),
            color: _getLogColor(),
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(
                    color: _getLogColor(),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${log.timestamp.minute.toString().padLeft(2, '0')}:'
                  '${log.timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
