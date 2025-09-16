import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const String _defaultChannelName = "egcart";
  static const String _defaultEventName = "cart001";
  final sample = {
    "event": "cart001",
    "payload": {
      "position":
          "{\"links\":[{\"A\":\"1783\",\"R\":\"10.6\"},{\"A\":\"1782\",\"R\":\"31.3\"},{\"A\":\"1781\",\"R\":\"41.3\"}]}",
    },
    "type": "broadcast",
  };

  final gridGap = 50;
  final deviceColors = [Colors.red, Colors.blue, Colors.orange, Colors.purple];

  var links =
      "{\"links\":[{\"A\":\"1783\",\"R\":\"10.6\"},{\"A\":\"1782\",\"R\":\"13.3\"},{\"A\":\"1781\",\"R\":\"41.3\"}]}";

  // State variables
  late SupabaseClient _supabase;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  @override
  void dispose() {
    super.dispose();
    _channel?.unsubscribe();
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
      print('✅ Connected and listening...');
    } catch (e) {
      print('❌ Connection Error: $e');
    }
  }

  // Setup or reconnect channel
  Future<void> _setupChannel() async {
    await _channel?.unsubscribe();

    final channelName = _defaultChannelName;
    final eventName = _defaultEventName;

    _channel = _supabase.channel(
      channelName,
      opts: RealtimeChannelConfig(private: false, self: true),
    );

    _channel!
        .onBroadcast(event: eventName, callback: _onMessageReceived)
        .subscribe();

    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _onMessageReceived(Map<String, dynamic> payload) {
    try {
      print('message received');

      final message = payload['payload']["position"];

      setState(() {
        links = message.toString();
      });
    } catch (e) {
      print('❌ Parse Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Developer Tool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Map Developer Tool')),
        body: InteractiveViewer(
          child: CustomPaint(
            painter: MapCanvas(
              gridGap: gridGap,
              deviceColors: deviceColors,
              links: links,
            ),
            size: Size(
              MediaQuery.sizeOf(context).width,
              MediaQuery.sizeOf(context).height,
            ),
          ),
        ),
      ),
    );
  }
}

class MapCanvas extends CustomPainter {
  MapCanvas({
    required this.gridGap,
    required this.deviceColors,
    required this.links,
  });

  final int gridGap;
  final List<Color> deviceColors;
  final String links;

  int metersToPixels(double meters) {
    //0.5 m = 50 pixels
    return (meters * 100).toInt();
  }

  void drawGrid(Canvas canvas, Size size) {
    //inialize paint
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    //draw vertical lines
    for (double i = 0; i < size.width; i += gridGap) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    //draw horizontal lines
    for (double i = 0; i < size.height; i += gridGap) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  void drawTag(
    Canvas canvas,
    Size size, {
    required Offset position,
    required Color color,
  }) {
    final tagPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw diamond shape for tag
    final path = Path();
    final center = position;
    path.moveTo(center.dx, center.dy - 5);
    path.lineTo(center.dx + 5, center.dy);
    path.lineTo(center.dx, center.dy + 5);
    path.lineTo(center.dx - 5, center.dy);
    path.close();
    canvas.drawPath(path, tagPaint);
  }

  void drawAnchor(Canvas canvas, Size size, {required int index}) {
    final position = [
      Offset(0, size.height / 2), //left center anchor
      Offset(size.width, size.height / 2), //right center anchor
      Offset(size.width / 2, size.height), //bottom center anchor
      Offset(size.width / 2, 0), //top center anchor
    ];
    final anchorPaint = Paint()
      ..color = deviceColors[index]
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    canvas.drawCircle(position[index], 4, anchorPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawGrid(canvas, size);

    // for (var i = 0; i < links.length; i++) {
    //   drawAnchor(canvas, size, index: i);
    // }

    // Offset? tagPosition = trilateration(
    //   anchorsJson: links,
    //   size: size,
    //   canvas: canvas,
    // );

    // if (tagPosition != null) {
    //   drawTag(canvas, size, position: tagPosition, color: Colors.green);
    //   if (kDebugMode) {
    //     print(
    //       'Calculated tag position: (${tagPosition.dx.toStringAsFixed(2)}, ${tagPosition.dy.toStringAsFixed(2)})',
    //     );
    //   }
    // } else {
    //   if (kDebugMode) {
    //     print('Failed to calculate tag position');
    //   }
    // }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Anchor {
  double x;
  double y;
  double distance;

  Anchor(this.x, this.y) : distance = 0.0;

  void updateDistance(double distance) {
    this.distance = distance;
  }
}

class Trilateration {
  Anchor anchor0;
  Anchor anchor1;
  Anchor anchor2;

  Trilateration(this.anchor0, this.anchor1, this.anchor2);

  Offset calcUserLocation() {
    double A = 2 * (anchor1.x - anchor0.x);
    double B = 2 * (anchor1.y - anchor0.y);
    num C =
        math.pow(anchor0.distance, 2) -
        math.pow(anchor1.distance, 2) -
        math.pow(anchor0.x, 2) +
        math.pow(anchor1.x, 2) -
        math.pow(anchor0.y, 2) +
        math.pow(anchor1.y, 2);
    double D = 2 * (anchor2.x - anchor1.x);
    double E = 2 * (anchor2.y - anchor1.y);
    num F =
        math.pow(anchor1.distance, 2) -
        math.pow(anchor2.distance, 2) -
        math.pow(anchor1.x, 2) +
        math.pow(anchor2.x, 2) -
        math.pow(anchor1.y, 2) +
        math.pow(anchor2.y, 2);

    double userX = ((F * B) - (E * C)) / ((B * D) - (E * A));
    double userY = ((F * A) - (D * C)) / ((A * E) - (D * B));

    return Offset(userX, userY);
  }
}
