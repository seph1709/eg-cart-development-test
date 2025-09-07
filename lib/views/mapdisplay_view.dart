import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

class UWBPositionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UWB Position Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
      ),
      home: UWBPositionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class UWBPositionScreen extends StatefulWidget {
  @override
  _UWBPositionScreenState createState() => _UWBPositionScreenState();
}

class _UWBPositionScreenState extends State<UWBPositionScreen>
    with TickerProviderStateMixin {
  // Core configuration variables - EXACTLY same as Python code
  double distance_a1_a2 = 3.0;
  double meter2pixel = 100.0;
  double range_offset = 0.9;
  int UDP_PORT = 8080; // Changed from 80 to avoid permission issues

  // Developer settings
  String anchor1_id = "1782";
  String anchor2_id = "1783";
  bool showDeveloperPanel = false;
  bool showLogConsole = false;

  // Core state variables - same naming as Python
  double a1_range = 0.0;
  double a2_range = 0.0;
  double tagX = 0.0;
  double tagY = 0.0;
  int node_count = 0;
  bool tagVisible = false;

  // Graph transformation state
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  // Connection state
  bool _isConnected = false;
  String _serverStatus = "Starting...";
  String UDP_IP = "";

  // Log console
  List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  ServerSocket? server;
  Socket? clientSocket;
  Timer? dataTimer;
  List<Offset> _positionHistory = [];

  // Tab controller for settings/logs
  late TabController _tabController;

  // Controllers for developer settings
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _meterPixelController = TextEditingController();
  final TextEditingController _rangeOffsetController = TextEditingController();
  final TextEditingController _anchor1Controller = TextEditingController();
  final TextEditingController _anchor2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _addLog("Application started");
    _startServer();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    setState(() {
      _logs.add("[$timestamp] $message");
      if (_logs.length > 1000) {
        _logs.removeAt(0); // Keep only last 1000 logs
      }
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });

    // Also print to console
    print("[$timestamp] $message");
  }

  void _initializeControllers() {
    _portController.text = UDP_PORT.toString();
    _distanceController.text = distance_a1_a2.toString();
    _meterPixelController.text = meter2pixel.toString();
    _rangeOffsetController.text = range_offset.toString();
    _anchor1Controller.text = anchor1_id;
    _anchor2Controller.text = anchor2_id;
  }

  @override
  void dispose() {
    dataTimer?.cancel();
    clientSocket?.close();
    server?.close();
    _tabController.dispose();
    _logScrollController.dispose();
    _portController.dispose();
    _distanceController.dispose();
    _meterPixelController.dispose();
    _rangeOffsetController.dispose();
    _anchor1Controller.dispose();
    _anchor2Controller.dispose();
    super.dispose();
  }

  // EXACT replica of Python's server setup
  Future<void> _startServer() async {
    try {
      // Get hostname and IP - exact same logic as Python
      final interfaces = await NetworkInterface.list();
      UDP_IP = '127.0.0.1'; // Default

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            UDP_IP = addr.address;
            break;
          }
        }
      }

      _addLog("***Local ip: $UDP_IP***"); // Exact same print format

      // Create TCP server - same as Python's socket setup
      server = await ServerSocket.bind(UDP_IP, UDP_PORT);
      _addLog("Server listening on $UDP_IP:$UDP_PORT");

      setState(() {
        _serverStatus = "Listening on $UDP_IP:$UDP_PORT";
      });

      // Listen for connections - same as Python's sock.accept()
      server!.listen((Socket socket) {
        _addLog(
          "Client connected from ${socket.remoteAddress}:${socket.remotePort}",
        );
        setState(() {
          _isConnected = true;
          _serverStatus =
              "Connected: ${socket.remoteAddress}:${socket.remotePort}";
        });
        clientSocket = socket;
        _startDataReading();
      });
    } catch (e) {
      _addLog("Error starting server: $e");
      setState(() {
        _serverStatus = "Error: ${e.toString()}";
      });
    }
  }

  void _restartServer() async {
    _addLog("Restarting server...");
    // Stop current server
    dataTimer?.cancel();
    clientSocket?.close();
    server?.close();

    setState(() {
      _isConnected = false;
      _serverStatus = "Restarting...";
    });

    await Future.delayed(Duration(milliseconds: 500));
    await _startServer();
  }

  void _startDataReading() {
    // Same timing as Python (0.1 seconds)
    dataTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      // Python calls read_data() in loop
      _readData();
    });
  }

  // EXACT replica of Python's read_data() function
  void _readData() {
    if (clientSocket == null) return;

    try {
      clientSocket!.listen(
        (data) {
          // Same as Python: data.recv(1024).decode('UTF-8')
          String line = String.fromCharCodes(data);
          List<dynamic> uwb_list = _processReceivedData(line);
          _processUWBList(uwb_list);
        },
        onError: (error) {
          _addLog("Socket error: $error");
          setState(() {
            _isConnected = false;
            _serverStatus = "Connection error";
          });
        },
        onDone: () {
          _addLog("Client disconnected");
          setState(() {
            _isConnected = false;
            _serverStatus = "Client disconnected";
          });
          clientSocket = null;
        },
      );
    } catch (e) {
      _addLog("Error reading data: $e");
    }
  }

  // EXACT replica of Python's JSON processing in read_data()
  List<dynamic> _processReceivedData(String line) {
    List<dynamic> uwb_list = [];

    try {
      var uwb_data = jsonDecode(line);
      _addLog("Received: ${jsonEncode(uwb_data)}"); // Same print as Python

      uwb_list = uwb_data["links"];
      for (var uwb_anchor in uwb_list) {
        _addLog(
          "Anchor data: ${jsonEncode(uwb_anchor)}",
        ); // Same print as Python
      }
    } catch (e) {
      _addLog(
        "JSON parse error: $e, Raw data: $line",
      ); // Same error handling as Python
    }

    return uwb_list;
  }

  // EXACT replica of Python's main loop processing
  void _processUWBList(List<dynamic> uwb_list) {
    node_count = 0; // Reset counter like Python

    for (var one in uwb_list) {
      // EXACT same logic as Python's main loop
      if (one["A"] == anchor1_id) {
        // Same as Python: if one["A"] == "1782"
        a1_range = uwb_range_offset(double.parse(one["R"].toString()));
        node_count += 1;
        _addLog("A1 ($anchor1_id) range: ${a1_range.toStringAsFixed(2)}m");
      }

      if (one["A"] == anchor2_id) {
        // Same as Python: if one["A"] == "1783"
        a2_range = uwb_range_offset(double.parse(one["R"].toString()));
        node_count += 1;
        _addLog("A2 ($anchor2_id) range: ${a2_range.toStringAsFixed(2)}m");
      }
    }

    // EXACT same condition as Python
    if (node_count == 2) {
      var position = tag_pos(a2_range, a1_range, distance_a1_a2);
      setState(() {
        tagX = position[0];
        tagY = position[1];
        tagVisible = true;
        _positionHistory.add(Offset(tagX, tagY));
        if (_positionHistory.length > 50) {
          _positionHistory.removeAt(0);
        }
      });
      _addLog(
        "Tag position: (${tagX.toStringAsFixed(1)}, ${tagY.toStringAsFixed(1)})",
      ); // Same print format as Python
    } else {
      _addLog("Incomplete data: $node_count/2 nodes");
    }
  }

  // EXACT replica of Python's uwb_range_offset function
  double uwb_range_offset(double uwb_range) {
    double temp = uwb_range;
    return temp; // Can be modified to apply range_offset if needed
  }

  // EXACT replica of Python's tag_pos function
  List<double> tag_pos(double a, double b, double c) {
    // Same algorithm as Python - using cosine rule
    var cos_a = (b * b + c * c - a * a) / (2 * b * c);
    var x = b * cos_a;
    var y = b * math.sqrt(1 - cos_a * cos_a);

    // Same rounding as Python: round(x.real, 1), round(y.real, 1)
    return [_roundTo1Decimal(x), _roundTo1Decimal(y)];
  }

  double _roundTo1Decimal(double value) {
    return (value * 10).round() / 10; // Same as Python's round(x, 1)
  }

  void _applyDeveloperSettings() {
    setState(() {
      UDP_PORT = int.tryParse(_portController.text) ?? 8080;
      distance_a1_a2 = double.tryParse(_distanceController.text) ?? 3.0;
      meter2pixel = double.tryParse(_meterPixelController.text) ?? 100.0;
      range_offset = double.tryParse(_rangeOffsetController.text) ?? 0.9;
      anchor1_id = _anchor1Controller.text.isNotEmpty
          ? _anchor1Controller.text
          : "1782";
      anchor2_id = _anchor2Controller.text.isNotEmpty
          ? _anchor2Controller.text
          : "1783";
    });

    _addLog(
      "Settings applied: Port=$UDP_PORT, Distance=${distance_a1_a2}m, A1=$anchor1_id, A2=$anchor2_id",
    );

    // Restart server with new settings
    _restartServer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Settings applied, server restarted")),
    );
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
    _addLog("View reset to center");
  }

  void _clearTrail() {
    setState(() {
      _positionHistory.clear();
    });
    _addLog("Position trail cleared");
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    _addLog("Log console cleared");
  }

  bool _mockDataEnabled = false;

  void _toggleMockData() {
    setState(() {
      _mockDataEnabled = !_mockDataEnabled;
    });

    if (_mockDataEnabled) {
      _addLog("Mock data generator started");
      MockUWBDataGenerator.start(
        (data) {
          _addLog("Mock data generated");
          List<dynamic> uwb_list = _processReceivedData(data);
          _processUWBList(uwb_list);
        },
        anchor1_id,
        anchor2_id,
      );
    } else {
      _addLog("Mock data generator stopped");
      MockUWBDataGenerator.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('UWB Position Tracker'),
        backgroundColor: Colors.blue[600],
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.terminal),
            onPressed: () {
              setState(() {
                showLogConsole = !showLogConsole;
              });
            },
            tooltip: 'Toggle Log Console',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              setState(() {
                showDeveloperPanel = !showDeveloperPanel;
              });
            },
            tooltip: 'Developer Settings',
          ),
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearTrail,
            tooltip: 'Clear Trail',
          ),
          IconButton(
            icon: Icon(Icons.center_focus_strong),
            onPressed: _resetView,
            tooltip: 'Reset View',
          ),
          IconButton(
            icon: Icon(_mockDataEnabled ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleMockData,
            tooltip: 'Toggle Mock Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Developer Settings Panel
            if (showDeveloperPanel) _buildDeveloperPanel(),

            // Log Console Panel
            if (showLogConsole) _buildLogConsole(),

            // Status Panel
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _serverStatus,
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatusCard(
                        "${anchor1_id} Range",
                        "${a1_range.toStringAsFixed(2)}m",
                        Colors.cyan[700]!,
                      ),
                      _buildStatusCard(
                        "${anchor2_id} Range",
                        "${a2_range.toStringAsFixed(2)}m",
                        Colors.orange[700]!,
                      ),
                      _buildStatusCard(
                        "Nodes",
                        "$node_count/2",
                        Colors.purple[700]!,
                      ),
                      _buildStatusCard(
                        "Tag Pos",
                        tagVisible
                            ? "(${tagX.toStringAsFixed(1)}, ${tagY.toStringAsFixed(1)})"
                            : "---",
                        Colors.green[700]!,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Graph Area
            Container(
              height: MediaQuery.of(context).size.height - 300,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[400]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRect(
                child: GestureDetector(
                  onScaleStart: (details) {},
                  onScaleUpdate: (details) {
                    setState(() {
                      double newScale = _scale * details.scale;
                      newScale = newScale.clamp(0.1, 5.0);
                      _offset += details.focalPointDelta;
                      _scale = newScale;
                    });
                  },
                  child: CustomPaint(
                    painter: GraphPainter(
                      a1Range: a1_range,
                      a2Range: a2_range,
                      tagX: tagX,
                      tagY: tagY,
                      tagVisible: tagVisible,
                      scale: _scale,
                      offset: _offset,
                      positionHistory: _positionHistory,
                      distance_a1_a2: distance_a1_a2,
                      meter2pixel: meter2pixel,
                      anchor1_id: anchor1_id,
                      anchor2_id: anchor2_id,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),

            // Control Panel
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(Icons.zoom_in, "Zoom In", () {
                    setState(() {
                      _scale = (_scale * 1.2).clamp(0.1, 5.0);
                    });
                  }),
                  _buildControlButton(Icons.zoom_out, "Zoom Out", () {
                    setState(() {
                      _scale = (_scale / 1.2).clamp(0.1, 5.0);
                    });
                  }),
                  _buildControlButton(Icons.my_location, "Center", _resetView),
                  _buildControlButton(
                    Icons.timeline,
                    "${_positionHistory.length} pts",
                    _clearTrail,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogConsole() {
    return Container(
      height: 200,
      color: Colors.black87,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[800],
            child: Row(
              children: [
                Icon(Icons.terminal, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  "Log Console",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                TextButton(
                  onPressed: _clearLogs,
                  child: Text("Clear", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(8),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      _logs[index],
                      style: TextStyle(
                        color: Colors.green[300],
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperPanel() {
    // Initialize TabController here to avoid late initialization error
    _tabController ??= TabController(length: 2, vsync: this);

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue[800],
            indicatorColor: Colors.blue[600],
            tabs: [
              Tab(text: "Network Settings"),
              Tab(text: "Positioning Settings"),
            ],
          ),
          Container(
            height: 220,
            child: TabBarView(
              controller: _tabController,
              children: [_buildNetworkSettings(), _buildPositioningSettings()],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: _applyDeveloperSettings,
                child: Text("Apply Settings"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  _initializeControllers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Settings reset to default")),
                  );
                },
                child: Text("Reset to Default"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSettings() {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField("Port", _portController, "8080")),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  "Local IP",
                  TextEditingController(text: UDP_IP),
                  "Auto-detected",
                  enabled: false,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "Anchor 1 ID",
                  _anchor1Controller,
                  "1782",
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  "Anchor 2 ID",
                  _anchor2Controller,
                  "1783",
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Note: Changing port or IDs requires server restart",
            style: TextStyle(color: Colors.orange[800], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPositioningSettings() {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "Distance A1-A2 (m)",
                  _distanceController,
                  "3.0",
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  "Meter to Pixel",
                  _meterPixelController,
                  "100",
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  "Range Offset",
                  _rangeOffsetController,
                  "0.9",
                ),
              ),
              SizedBox(width: 16),
              Expanded(child: Container()), // Empty space
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Distance A1-A2: Physical separation between anchors\nMeter to Pixel: Visualization scale factor",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? Colors.black : Colors.grey,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey[100],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[100],
            foregroundColor: Colors.blue[800],
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final double a1Range;
  final double a2Range;
  final double tagX;
  final double tagY;
  final bool tagVisible;
  final double scale;
  final Offset offset;
  final List<Offset> positionHistory;
  final double distance_a1_a2;
  final double meter2pixel;
  final String anchor1_id;
  final String anchor2_id;

  GraphPainter({
    required this.a1Range,
    required this.a2Range,
    required this.tagX,
    required this.tagY,
    required this.tagVisible,
    required this.scale,
    required this.offset,
    required this.positionHistory,
    required this.distance_a1_a2,
    required this.meter2pixel,
    required this.anchor1_id,
    required this.anchor2_id,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Apply transformations
    canvas.save();
    canvas.translate(centerX + offset.dx, centerY + offset.dy);
    canvas.scale(scale);

    // Draw grid
    _drawGrid(canvas, size);

    // Draw coordinate axes
    _drawAxes(canvas, size);

    // Calculate anchor positions - SAME as Python positioning
    final a1Pos = Offset(-distance_a1_a2 * meter2pixel / 2, 0);
    final a2Pos = Offset(distance_a1_a2 * meter2pixel / 2, 0);

    // Draw range circles
    _drawRangeCircle(canvas, a1Pos, a1Range, Colors.cyan.withOpacity(0.3));
    _drawRangeCircle(canvas, a2Pos, a2Range, Colors.orange.withOpacity(0.3));

    // Draw anchors
    _drawAnchor(canvas, a1Pos, "${anchor1_id}(0,0)", Colors.cyan[700]!);
    _drawAnchor(
      canvas,
      a2Pos,
      "${anchor2_id}(${distance_a1_a2})",
      Colors.orange[700]!,
    );

    // Draw position history trail
    _drawTrail(canvas);

    // Draw current tag position - SAME positioning as Python
    if (tagVisible) {
      final tagPos = Offset(
        (tagX - distance_a1_a2 / 2) * meter2pixel,
        -tagY * meter2pixel, // Negative Y for screen coordinates
      );
      _drawTag(canvas, tagPos, Colors.green[700]!);
    }

    canvas.restore();

    // Draw scale and info
    _drawInfo(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    final majorGridPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.0;

    final gridSpacing = meter2pixel / 4; // Grid every 0.25 meters
    final majorSpacing = meter2pixel; // Major grid every meter

    final bounds = size.width > size.height ? size.width : size.height;
    final gridRange = (bounds / scale).toInt();

    for (int i = -gridRange; i <= gridRange; i++) {
      final pos = i * gridSpacing;
      final paint = i % 4 == 0 ? majorGridPaint : gridPaint;

      canvas.drawLine(
        Offset(pos, -gridRange * gridSpacing),
        Offset(pos, gridRange * gridSpacing),
        paint,
      );

      canvas.drawLine(
        Offset(-gridRange * gridSpacing, pos),
        Offset(gridRange * gridSpacing, pos),
        paint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.0;

    final arrowPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // X-axis
    canvas.drawLine(Offset(-200, 0), Offset(200, 0), axisPaint);
    final xArrow = Path()
      ..moveTo(190, -5)
      ..lineTo(200, 0)
      ..lineTo(190, 5)
      ..close();
    canvas.drawPath(xArrow, arrowPaint);

    // Y-axis
    canvas.drawLine(Offset(0, -200), Offset(0, 200), axisPaint);
    final yArrow = Path()
      ..moveTo(-5, -190)
      ..lineTo(0, -200)
      ..lineTo(5, -190)
      ..close();
    canvas.drawPath(yArrow, arrowPaint);

    _drawAxisLabel(canvas, Offset(205, -5), "X (m)", Colors.black87);
    _drawAxisLabel(canvas, Offset(5, -205), "Y (m)", Colors.black87);
  }

  void _drawRangeCircle(
    Canvas canvas,
    Offset center,
    double range,
    Color color,
  ) {
    if (range <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, range * meter2pixel, paint);
  }

  void _drawAnchor(Canvas canvas, Offset pos, String label, Color color) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(pos, 15, paint);
    canvas.drawCircle(pos, 15, borderPaint);

    _drawLabel(canvas, pos + Offset(20, -10), label, color);
  }

  void _drawTag(Canvas canvas, Offset pos, Color color) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()
      ..moveTo(pos.dx, pos.dy - 12)
      ..lineTo(pos.dx + 12, pos.dy)
      ..lineTo(pos.dx, pos.dy + 12)
      ..lineTo(pos.dx - 12, pos.dy)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    _drawLabel(canvas, pos + Offset(15, -15), "TAG", color);
  }

  void _drawTrail(Canvas canvas) {
    if (positionHistory.length < 2) return;

    final trailPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    bool first = true;

    for (var pos in positionHistory) {
      final screenPos = Offset(
        (pos.dx - distance_a1_a2 / 2) * meter2pixel,
        -pos.dy * meter2pixel,
      );

      if (first) {
        path.moveTo(screenPos.dx, screenPos.dy);
        first = false;
      } else {
        path.lineTo(screenPos.dx, screenPos.dy);
      }
    }

    canvas.drawPath(path, trailPaint);

    final pointPaint = Paint()..color = Colors.green.withOpacity(0.8);

    for (int i = 0; i < positionHistory.length; i++) {
      final pos = positionHistory[i];
      final screenPos = Offset(
        (pos.dx - distance_a1_a2 / 2) * meter2pixel,
        -pos.dy * meter2pixel,
      );
      final alpha = (i / positionHistory.length * 255).round();
      pointPaint.color = Colors.green.withAlpha(alpha);
      canvas.drawCircle(screenPos, 3, pointPaint);
    }
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, pos);
  }

  void _drawAxisLabel(Canvas canvas, Offset pos, String text, Color color) {
    final textStyle = TextStyle(
      color: color,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, pos);
  }

  void _drawInfo(Canvas canvas, Size size) {
    final infoPaint = Paint()..color = Colors.white.withOpacity(0.9);
    final borderPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final infoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 150, 10, 140, 90),
      Radius.circular(8),
    );

    canvas.drawRRect(infoRect, infoPaint);
    canvas.drawRRect(infoRect, borderPaint);

    final infoText = [
      "Scale: ${(scale * 100).toInt()}%",
      "Trail: ${positionHistory.length} points",
      "Range A1: ${a1Range.toStringAsFixed(2)}m",
      "Range A2: ${a2Range.toStringAsFixed(2)}m",
      "Tag: ${tagVisible ? 'Visible' : 'Hidden'}",
    ];

    for (int i = 0; i < infoText.length; i++) {
      _drawLabel(
        canvas,
        Offset(size.width - 145, 20 + i * 15),
        infoText[i],
        Colors.black87,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// Mock data generator for testing - maintains same data format as Python
class MockUWBDataGenerator {
  static Timer? _timer;
  static Function(String)? _onDataReceived;
  static double _angle = 0;
  static String _anchor1Id = "1782";
  static String _anchor2Id = "1783";

  static void start(
    Function(String) onDataReceived,
    String anchor1Id,
    String anchor2Id,
  ) {
    _onDataReceived = onDataReceived;
    _anchor1Id = anchor1Id;
    _anchor2Id = anchor2Id;

    // Generate data more frequently for smooth movement
    _timer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      _generateMockData();
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _onDataReceived = null;
    _angle = 0; // Reset angle
  }

  static void _generateMockData() {
    _angle += 0.1; // Increase step for faster movement

    // Simulate figure-8 movement pattern for more interesting visualization
    final centerX = 1.5;
    final centerY = 1.0;
    final radiusX = 1.0;
    final radiusY = 0.8;

    // Figure-8 pattern using parametric equations
    final tagX = centerX + radiusX * math.sin(_angle);
    final tagY = centerY + radiusY * math.sin(_angle * 2) / 2;

    // Calculate distances from anchors at (0,0) and (3,0)
    final d1 = math.sqrt(tagX * tagX + tagY * tagY);
    final d2 = math.sqrt((tagX - 3.0) * (tagX - 3.0) + tagY * tagY);

    // Add small random noise to simulate real-world conditions
    final random = math.Random();
    final noise1 = (random.nextDouble() - 0.5) * 0.1; // ±5cm noise
    final noise2 = (random.nextDouble() - 0.5) * 0.1;

    // EXACT same JSON format as Python expects
    final mockData = {
      "links": [
        {"A": _anchor1Id, "R": (d1 + noise1).toStringAsFixed(3)},
        {"A": _anchor2Id, "R": (d2 + noise2).toStringAsFixed(3)},
      ],
    };

    _onDataReceived?.call(jsonEncode(mockData));
  }
}
