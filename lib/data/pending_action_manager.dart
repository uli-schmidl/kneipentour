import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pending_action.dart';

class PendingActionManager {
  static const _key = "pending_actions";

  static Future<void> add(PendingAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.add(jsonEncode(action.toMap()));
    await prefs.setStringList(_key, list);
  }

  static Future<List<PendingAction>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((e) => PendingAction.fromMap(jsonDecode(e))).toList();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
