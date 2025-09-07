import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BroadcastController extends GetxController {
  late SupabaseClient supabase;
  final eventController = TextEditingController();
  final channelController = TextEditingController();
}
