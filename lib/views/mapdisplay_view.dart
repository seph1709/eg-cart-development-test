import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double metersToPixels(double meters, {int baseConvertion = 100}) {
  //0.5 m = 50 pixels
  return (meters * baseConvertion).toDouble();
}

double pixelsToMeters(double pixels, {double baseConvertion = 100.0}) {
  // 50 pixels = 0.5 m
  return pixels / baseConvertion;
}

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

  var links =
      "{\"links\":[{\"A\":\"1783\",\"R\":\"0.6\"},{\"A\":\"1782\",\"R\":\"1.3\"},{\"A\":\"1786\",\"R\":\"1.3\"}]}";

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
      if (kDebugMode) {
        print('✅ Connected and listening...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Connection Error: $e');
      }
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
      if (kDebugMode) {
        print('message received');
      }

      final message = payload['payload']["position"];

      setState(() {
        links = message.toString();
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Parse Error: $e');
      }
    }
  }

  num baseConvertion =
      100; // 1 meter = 100 pixels ginagamit para maatansya ang pixel na irerender katumbas ng real distance ng mga anchor
  double anchorXDistance =
      2.7; //horizontal distance between ng two anchor (anchor 0 and anchor 1)
  double anchorYDistance =
      3.5; //vertical distance between two ng anchor (anchor 0 and anchor 3 or anchor 1 and anchor 3)
  bool showSettings = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Developer Tool',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Map Developer Tool'),
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  showSettings = !showSettings;
                });
              },
              label: Icon(Icons.settings, size: 25),
            ),
          ],
        ),
        body: Stack(
          children: [
            InteractiveViewer(
              child: CustomPaint(
                painter: MapCanvas(
                  gridGap: gridGap,
                  links: links,
                  baseConvertion: baseConvertion,
                  anchorXDistance: anchorXDistance,
                  anchorYDistance: anchorYDistance,
                ),
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
              ),
            ),
            if (showSettings)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.white70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Base Conversion: 1 meter = $baseConvertion pixels',
                        ),
                        Slider(
                          value: baseConvertion.toDouble(),
                          min: 5,
                          max: 200,
                          divisions: 195,
                          label: baseConvertion.toString(),
                          onChanged: (value) {
                            setState(() {
                              baseConvertion = value.toInt();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.white70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Anchor X Distance: $anchorXDistance meters'),
                        Slider(
                          value: anchorXDistance,
                          min: 1.0,
                          max: 200.0,
                          divisions: 199,
                          label: anchorXDistance.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              anchorXDistance = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.white70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Anchor Y Distance: $anchorYDistance meters'),
                        Slider(
                          value: anchorYDistance,
                          min: 1.0,
                          max: 200.0,
                          divisions: 199,
                          label: anchorYDistance.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              anchorYDistance = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class MapCanvas extends CustomPainter {
  MapCanvas({
    required this.gridGap,
    required this.links,
    required this.baseConvertion,
    required this.anchorXDistance,
    required this.anchorYDistance,
  });

  final int gridGap;
  final String links;
  final num baseConvertion;
  final double anchorXDistance;
  final double anchorYDistance;

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
    required num baseConvertion,
  }) {
    final tagPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (kDebugMode) {
      print(
        Offset(
          metersToPixels(position.dx, baseConvertion: baseConvertion.toInt()),
          metersToPixels(position.dy, baseConvertion: baseConvertion.toInt()),
        ),
      );
    }

    canvas.drawCircle(
      Offset(
        metersToPixels(position.dx, baseConvertion: baseConvertion.toInt()),
        metersToPixels(position.dy, baseConvertion: baseConvertion.toInt()),
      ),
      4,
      tagPaint,
    );
  }

  void drawAnchor(Anchor anchor, Canvas canvas) {
    final anchorColors = {
      "1783": Colors.red,
      "1782": Colors.blue,
      "1786": Colors.green,
      "1784": Colors.orange,
    };

    // para sa text ng anchor
    final textSpan = TextSpan(
      text: 'A${anchor.id}\n${anchor.distance.toStringAsFixed(2)}m',
      style: TextStyle(
        color: anchorColors[anchor.id]!,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: anchor.size.width);

    textPainter.paint(
      canvas,
      Offset(
        metersToPixels(anchor.x, baseConvertion: baseConvertion.toInt()) - 20,
        metersToPixels(anchor.y, baseConvertion: baseConvertion.toInt()) + 10,
      ),
    );

    final anchorPaint = Paint()
      ..color = anchorColors[anchor.id]!
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // end ng pagdraw ng text

    canvas.drawCircle(
      Offset(
        metersToPixels(anchor.x, baseConvertion: baseConvertion.toInt()),
        metersToPixels(anchor.y, baseConvertion: baseConvertion.toInt()),
      ),
      4,
      anchorPaint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    late List<Anchor> listOfAnchors;

    //grid sa mapa
    drawGrid(canvas, size);

    jsonDecode(links);

    var lin = jsonDecode(links)["links"].length;

    listOfAnchors = List.generate(
      lin,
      (index) => Anchor(
        jsonDecode(links)["links"][index]["R"],
        id: jsonDecode(links)["links"][index]["A"],
        size: size,
        baseConvertion: baseConvertion,
        anchorXDistance: anchorXDistance,
        anchorYDistance: anchorYDistance,
      ),
    );

    //kada isang element sa list of anchors, i-draw sa canvas
    for (var i = 0; i < listOfAnchors.length; i++) {
      var currentAnchor = listOfAnchors[i];
      drawAnchor(currentAnchor, canvas);
    }

    //siguraduhin na ang tatlong anchor ay nasa tamang order para sa trilateration
    final leftAnchor = listOfAnchors.firstWhere((id) => id.id == "1783");
    final rightAnchor = listOfAnchors.firstWhere((id) => id.id == "1782");
    final bottomAnchor = listOfAnchors.firstWhere((id) => id.id == "1786");

    // kunin ang position ng tag gamit ang trilateration
    Trilateration trilateration = Trilateration(
      leftAnchor,
      rightAnchor,
      bottomAnchor,
    );

    // resulta ng trilateration
    Offset userOffset = trilateration.calcUserLocation();

    // draw user tag
    drawTag(
      canvas,
      size,
      position: userOffset,
      color: Colors.black,
      baseConvertion: baseConvertion,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class Anchor {
  String id;
  Size size;
  num baseConvertion;
  double anchorXDistance;
  double anchorYDistance;
  late double x;
  late double y;
  late double distance;

  Anchor(
    String range, {
    required this.id,
    required this.size,
    required this.baseConvertion,
    required this.anchorXDistance,
    required this.anchorYDistance,
  }) {
    // final mapWidthinPixel = size.width;
    // final mapHeightinPixel = size.height;

    // final mapWidthinMeters = pixelsToMeters(
    //   mapWidthinPixel,
    //   baseConvertion: baseConvertion.toDouble(),
    // );
    // final mapHeightinMeters = pixelsToMeters(
    //   mapHeightinPixel,
    //   baseConvertion: baseConvertion.toDouble(),
    // );

    final defaultPositions = {
      "1783": Offset(0, 0), //left center unang anchor
      "1782": Offset(anchorXDistance, 0), //right center ikalawang anchor
      "1786": Offset(
        anchorXDistance / 2,
        anchorYDistance,
      ), //bottom center ikatlong anchor
      "1784": Offset(anchorXDistance / 2, 0), //top center    ikaapat na anchor
    };

    // print(range);

    x = defaultPositions[id]!.dx;
    y = defaultPositions[id]!.dy;
    distance = double.parse(range);

    if (kDebugMode) {
      print('Anchor $id at ($x, $y) with distance $distance');
    }
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
