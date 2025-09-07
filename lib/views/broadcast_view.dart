import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BroadcastView extends StatefulWidget {
  const BroadcastView({super.key});

  @override
  State<BroadcastView> createState() => _BroadcastViewState();
}

class _BroadcastViewState extends State<BroadcastView> {
  // Controllers
  final _messageController = TextEditingController(text: "Hello World");
  final _channelController = TextEditingController(text: "eg-cart");
  final _eventController = TextEditingController(text: "Test message");

  // State variables
  late SupabaseClient _supabase;
  RealtimeChannel? _channel;
  final List<String> _logs = [];
  bool _isConnected = false;

  // Constants for consistent naming
  static const String _defaultChannelName = "eg-cart";
  static const String _defaultEventName = "Test message";

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _channelController.dispose();
    _eventController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // Initialize Supabase connection
  Future<void> _initializeSupabase() async {
    try {
      if (!Supabase.instance.isInitialized) {
        await Supabase.initialize(
          url: dotenv.env['SUPABASE_PROJECT_KEY']!,
          anonKey: dotenv.env['SUPABASE_PROJECT_KEY']!,
        );
      }

      _supabase = Supabase.instance.client;
      await _setupChannel();
      _addLog('✅ Connected and listening...');

      setState(() => _isConnected = true);
    } catch (e) {
      _addLog('❌ Connection Error: $e');
      setState(() => _isConnected = false);
    }
  }

  // Setup or reconnect channel
  Future<void> _setupChannel() async {
    await _channel?.unsubscribe();

    final channelName = _getChannelName();
    final eventName = _getEventName();

    _channel = _supabase.channel(
      channelName,
      opts: RealtimeChannelConfig(private: false, self: true),
    );

    _channel!
        .onBroadcast(event: eventName, callback: _onMessageReceived)
        .subscribe();

    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Send message
  Future<void> _sendMessage() async {
    if (!_isConnected || _channel == null) {
      _addLog('❌ Not connected');
      return;
    }

    try {
      final message = _messageController.text.trim().isNotEmpty
          ? _messageController.text.trim()
          : "Empty message";

      final eventName = _getEventName();

      await _channel!.sendBroadcastMessage(
        event: eventName,
        payload: {'message': message},
      );

      _addLog('📤 Sent: $message');
    } catch (e) {
      _addLog('❌ Send Error: $e');
    }
  }

  // Handle received messages
  void _onMessageReceived(Map<String, dynamic> payload) {
    try {
      // Handle the payload structure: { "event": "Test message", "payload": { "message": "Hello World" }, "type": "broadcast" }
      final message =
          payload['payload']?['message']?.toString() ??
          payload['message']?.toString() ??
          'Unknown message';

      _addLog('📥 Received: $message');
    } catch (e) {
      _addLog('❌ Parse Error: $e');
    }
  }

  // Reconnect
  Future<void> _reconnect() async {
    _addLog('🔄 Reconnecting...');
    setState(() => _isConnected = false);

    await _setupChannel();

    setState(() => _isConnected = true);
    _addLog('✅ Reconnected successfully');
  }

  // Helper methods
  String _getChannelName() {
    final name = _channelController.text.trim();
    return name.isEmpty ? _defaultChannelName : name;
  }

  String _getEventName() {
    final name = _eventController.text.trim();
    return name.isEmpty ? _defaultEventName : name;
  }

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Broadcast"),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reconnect,
              tooltip: 'Reconnect',
            ),
          ],
        ),
        body: _isConnected
            ? _buildConnectedView(context)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildConnectedView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputSection(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 30),
          _buildLogSection(context),
          const SizedBox(height: 10),
          _buildStatusSection(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField("Channel", _channelController, "Enter channel name"),
        const SizedBox(height: 16),
        _buildTextField("Event", _eventController, "Enter event name"),
        const SizedBox(height: 16),
        _buildTextField(
          "Message",
          _messageController,
          "Enter your message",
          onSubmitted: _sendMessage,
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            hintText: hint,
          ),
          onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isConnected ? _sendMessage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text("SEND MESSAGE"),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _reconnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          child: const Text("RECONNECT"),
        ),
      ],
    );
  }

  Widget _buildLogSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Log", style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton(onPressed: _clearLogs, child: const Text("Clear Log")),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 0.5),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey[50],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            reverse: true,
            child: Text(
              _logs.isEmpty ? 'No messages yet...' : _logs.join("\n"),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Text(
      'Status: ${_isConnected ? "Connected" : "Connecting..."}\n'
      'Channel: ${_getChannelName()}\n'
      'Event: ${_getEventName()}',
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey[600],
        fontFamily: 'monospace',
      ),
    );
  }
}
