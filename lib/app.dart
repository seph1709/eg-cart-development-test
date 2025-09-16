import 'package:devmode/controller/broadcast_controller.dart';
import 'package:devmode/views/broadcast_view.dart';
import 'package:devmode/views/mapdisplay_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(BroadcastController());
    return GetMaterialApp(
      title: "EG-Cart dev test",
      home: Scaffold(
        appBar: AppBar(title: Text("EG-Cart Dev Test")),
        body: SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Get.to(BroadcastView());
                  },
                  child: Text("BroadCast"),
                ),
                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Get.to(MapView());
                  },
                  child: Text("View Map"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
