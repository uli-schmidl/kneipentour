import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/pending_action_manager.dart';

class SyncManager {
  static Future<void> processPendingActions() async {
    final pending = await PendingActionManager.load();
    if (pending.isEmpty) return;

    print("🔄 Synchronisiere ${pending.length} Aktionen...");

    for (final action in pending) {
      try {
        if (action.type == "check-in") {
          print("➡️ Sync Check-in: ${action.guestId} → ${action.pubId}");
          await ActivityManager().checkInGuest(
            guestId: action.guestId,
            pubId: action.pubId,
            latitude: action.latitude,
            longitude: action.longitude,
          );
        } else if (action.type == "drink") {
          print("➡️ Sync Drink: ${action.guestId} @ ${action.pubId}");
          await ActivityManager().logDrink(
            guestId: action.guestId,
            pubId: action.pubId,
            pubName: action.pubName ?? "Unbekannt",
            latitude: action.latitude,
            longitude: action.longitude,
            payment: action.payment,
          );
        }
      } catch (e) {
        print("❌ Fehler beim Sync: $e");
        // nicht löschen → sync später nochmal probieren
        return;
      }
    }

    await PendingActionManager.clear();
    print("✅ Synchronisierung abgeschlossen!");
  }
}
