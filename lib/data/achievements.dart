import '../models/achievement.dart';

List<Achievement> allAchievements = [
  Achievement(
    id: 'first_checkin',
    title: 'Erster Check-in 🍻',
    description: 'Zum ersten Mal in einer Kneipe eingecheckt.',
    iconPath: 'assets/icons/ach_first.png',
  ),
  Achievement(
    id: 'five_drinks',
    title: 'Durstlöscher 💧',
    description: 'Fünf Getränke konsumiert.',
    iconPath: 'assets/icons/ach_drinks.png',
  ),
  Achievement(
    id: 'three_pubs',
    title: 'Tour-Starter 🧭',
    description: 'Drei verschiedene Kneipen besucht.',
    iconPath: 'assets/icons/ach_pubs.png',
  ),
  Achievement(
    id: 'bonus_master',
    title: 'Nimmersatt 🍺🍺🍺🍺🍺',
    description: 'Mehr als 5 Bonusdrinks gesammelt.',
    iconPath: 'assets/icons/ach_bonus.png',
  ),
  Achievement(
    id: 'night_owl',
    title: 'Nachtschwärmer 🌙',
    description: 'Nach Mitternacht eingecheckt.',
    iconPath: 'assets/icons/ach_night.png',
  ),
  Achievement(
    id: 'notfall',
    title: '112 🚨',
    description: 'Mobile Einheit angefordert.',
    iconPath: 'assets/icons/ach_night.png',
  ),
  Achievement(
    id: 'biker',
    title: 'Biker ',
    description: 'Freedom Riders besucht.',
    iconPath: 'assets/icons/bike.png',
  ),
  Achievement(
    id: 'glotzer',
    title: 'Glotzer ',
    description: 'In eine Kneipe eingecheckt und nichts getrunken.',
    iconPath: 'assets/icons/glotzer.png',
  ),
  Achievement(
    id: 'murmel',
    title: 'Und täglich grüßt das Murmeltier ',
    description: 'In eine Kneipe 2x eingecheckt.',
    iconPath: 'assets/icons/murmel.png',
  ),
  Achievement(
    id: 'joy',
    title: 'Genießer',
    description: 'Über eine Stunde zwischen zwei Getränken gebraucht.',
    iconPath: 'assets/icons/joy.png',
  ),
  Achievement(
    id: 'early',
    title: 'Early bird',
    description: 'Vor 20 Uhr eingecheckt.',
    iconPath: 'assets/icons/ebird.png',
  ),
  Achievement(
    id: 'late',
    title: 'Late bird',
    description: 'Nach 23 Uhr das erste mal eingecheckt.',
    iconPath: 'assets/icons/lbird.png',
  ),
  Achievement(
    id: 'hocker',
    title: 'Hocker',
    description: 'Nach 2 Uhr noch eingecheckt.',
    iconPath: 'assets/icons/hock.png',
  ),
];
