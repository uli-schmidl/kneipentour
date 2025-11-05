import 'package:kneipentour/config/location_config.dart';
import 'package:kneipentour/data/activity_manager.dart';
import 'package:kneipentour/data/guest_manager.dart';
import 'package:kneipentour/data/pub_manager.dart';

import '../models/achievement.dart';

class AchievementData {
  final List<Achievement> all = [
    Achievement(
      id: 'first_checkin',
      title: 'Erster Check-in 🍻',
      description: 'Zum ersten Mal in einer Kneipe eingecheckt.',
      iconPath: 'assets/icons/achievements/first.png',
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        print('checkin condition for first_checkin');
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        print('result: $acts.isNotEmpty');
        return acts.isNotEmpty;
      },
    ),
    Achievement(
      id: 'five_drinks',
      title: 'Durstlöscher 💧',
      description: 'Fünf Getränke konsumiert.',
      iconPath: 'assets/icons/achievements/drinks.png',
      trigger: AchievementEventType.drink,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'drink');
        return acts.length>=5;
      },
    ),
    Achievement(
      id: 'three_pubs',
      title: 'Tour-Starter 🧭',
      description: 'Drei verschiedene Kneipen besucht.',
      iconPath: 'assets/icons/achievements/pubs.png',
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        final uniquePubs = acts.map((a) => a.pubId).toSet();
        return uniquePubs.length >= 3;
      },

    ),
    Achievement(
      id: 'bonus_master',
      title: 'Nimmersatt 🍺🍺🍺🍺🍺',
      description: 'Mehr als 5 Bonusdrinks gesammelt.',
      iconPath: 'assets/icons/achievements/bonus.png',
      trigger: AchievementEventType.drink,
      condition: (guestId) async {
        // Alle Drink Activities laden
        final drinks = await ActivityManager().getGuestActivities(guestId, action: 'drink');
        if (drinks.isEmpty) return false;

        // Drinks pro Kneipe zählen
        final Map<String, int> counts = {};
        for (final d in drinks) {
          counts[d.pubId] = (counts[d.pubId] ?? 0) + 1;
        }

        // Bonusdrinks berechnen:
        // pro Kneipe: alles > 2 zählen als Bonus
        int bonus = 0;
        for (final count in counts.values) {
          if (count > 2) {
            bonus += (count - 2);
          }
        }

        print("🎁 Bonusdrinks für $guestId: $bonus");
        return bonus >= 5;
      },
    ),
    Achievement(
      id: 'night_owl',
      title: 'Nachtschwärmer 🌙',
      description: 'Nach Mitternacht zum ersten mal eingecheckt.',
      iconPath: 'assets/icons/achievements/night.png',
      hidden: true,
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        if (acts.isEmpty) return false;
        return acts.any((a) => (a.timestampBegin?.hour ?? 10) >= 0 && (a.timestampBegin?.hour ?? 10) < 4);
      },

    ),
    Achievement(
      id: 'notfall',
      title: '112 🚨',
      description: 'Mobile Einheit angefordert.',
      iconPath: 'assets/icons/mobile.png',
      trigger: AchievementEventType.requestMobileUnit,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'request_mobile');
        return acts.isNotEmpty;
      },
    ),
    Achievement(
      id: 'biker',
      title: 'Biker ',
      description: 'Freedom Riders besucht.',
      iconPath: 'assets/icons/achievements/bike.png',
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        return acts.any((a) => a.pubId=='gmjsY6aLm2h7Z9lxeWDO');
      },

    ),
    Achievement(
      id: 'glotzer',
      title: 'Glotzer ',
      description: 'In eine Kneipe eingecheckt und nichts getrunken.',
      iconPath: 'assets/icons/achievements/glotzer.png',
      hidden: true,
      trigger: AchievementEventType.checkOut,
      condition: (guestId) async {
        final checkIns = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        final drinks = await ActivityManager().getGuestActivities(guestId, action: 'drink');
        final drinkPubIds = drinks.map((a) => a.pubId).toSet();
        return checkIns.any((c) => !drinkPubIds.contains(c.pubId));
      },

    ),
    Achievement(
      id: 'murmel',
      title: 'Und täglich grüßt das Murmeltier ',
      description: 'In eine Kneipe 2x eingecheckt.',
      iconPath: 'assets/icons/achievements/murmel.png',
      hidden: true,
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        final counts = <String, int>{};
        for (final a in acts) {
          counts[a.pubId] = (counts[a.pubId] ?? 0) + 1;
        }
        return counts.values.any((count) => count >= 2);
      },

    ),
    Achievement(
      id: 'joy',
      title: 'Genießer',
      description: 'Über eine Stunde zwischen zwei Getränken gebraucht.',
      iconPath: 'assets/icons/achievements/joy.png',
      hidden: true,
      trigger: AchievementEventType.drink,
      condition: (guestId) async {
        final drinks = await ActivityManager().getGuestActivities(guestId, action: 'drink');
        if (drinks.length < 2) return false;

        // Nur Drinks mit gültigem timestampBegin berücksichtigen
        final validDrinks = drinks.where((d) => d.timestampBegin != null).toList();
        if (validDrinks.length < 2) return false;

        // Nach Zeitpunkt sortieren
        validDrinks.sort((a, b) => a.timestampBegin!.compareTo(b.timestampBegin!));

        // Abstände zwischen den Drinks prüfen
        for (int i = 1; i < validDrinks.length; i++) {
          final prev = validDrinks[i - 1].timestampBegin!;
          final curr = validDrinks[i].timestampBegin!;
          final diff = curr.difference(prev);
          if (diff.inMinutes > 60) return true;
        }

        return false;
      },


    ),
    Achievement(
      id: 'early',
      title: 'Early bird',
      description: 'Vor 20 Uhr eingecheckt.',
      iconPath: 'assets/icons/achievements/ebird.png',
      hidden: true,
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        return acts.any((a) => (a.timestampBegin?.hour ?? 22) < 20);
      },

    ),
    Achievement(
      id: 'late',
      title: 'Late bird',
      description: 'Nach 23 Uhr das erste mal eingecheckt.',
      iconPath: 'assets/icons/achievements/lbird.png',
      hidden: true,
      trigger: AchievementEventType.checkIn,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');
        return acts.any((a) => (a.timestampBegin?.hour ?? 0) >= 23);
      },

    ),
    Achievement(
      id: 'hocker',
      title: 'Hocker',
      description: 'Nach 2 Uhr noch eingecheckt.',
      iconPath: 'assets/icons/achievements/hock.png',
      hidden: true,
      trigger: AchievementEventType.locationUpdate,
      condition: (guestId) async {
        final acts = await ActivityManager().getGuestActivities(guestId, action: 'check-in');

        final now = DateTime.now();

        // Nur prüfen, wenn es nach 2 Uhr ist
        if (now.hour < 2 && now.hour>8) return false;

        // Finde offene Check-ins (kein timestampEnd gesetzt)
        final openCheckIns = acts.where((a) => a.timestampEnd == null);

        // Erfolg, wenn mind. ein offener Check-in existiert
        return openCheckIns.isNotEmpty;
      },
    ),
    Achievement(
      id: 'wicken',
      title: 'In die Wicken',
      description: 'Du warst weitab von allen Kneipen.',
      iconPath: 'assets/icons/achievements/hock.png',
      hidden: true,
      trigger: AchievementEventType.locationUpdate,
      condition: (guestId) async {

        // 2. Gastposition holen
        final guest = await GuestManager().getGuest(guestId);
        if (guest == null || guest.latitude == 0 || guest.longitude == 0) return false;

        final guestLat = guest.latitude;
        final guestLng = guest.longitude;

        // 3. Alle Kneipen holen
        final pubs = PubManager().allPubs;
        if (pubs.isEmpty) return false;

        // 4. Distanz zur *nächsten* Kneipe berechnen
        double minDistance = double.infinity;

        for (final pub in pubs) {
          final d = LocationConfig.calculateDistance(
            guestLat, guestLng,
            pub.latitude, pub.longitude,
          );
          if (d < minDistance) minDistance = d;
        }

        print("🌲 Distanz zur nächsten Kneipe (untwegs): ${minDistance.toStringAsFixed(1)}m");

        // 5. Threshold (z. B. > 200m)
        return minDistance > 200;
      },
    ),
  ];
}
