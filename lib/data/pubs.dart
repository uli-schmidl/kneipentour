import '../models/pub.dart';

final List<Pub> pubs = [
  Pub(
    id: 'pub1',
    name: 'Freedom Riders',
    latitude: 49.3328011848767,
    longitude: 10.849172860642645,
    description: 'Harte Jungs und heiße Bräute',
    iconPath: 'assets/icons/rider.png',
      isMobileUnit: false,
      capacity: 50
  ),
  Pub(
    id: 'pub2',
    name: 'Puzzles',
    latitude: 49.32852650595932,
    longitude: 10.848875312205493,
    description: 'Warme Stube, warme Brüder',
      iconPath: 'assets/icons/puz.png',
      isMobileUnit: false,
      capacity: 15

  ),
  Pub(
    id: 'pub3',
    name: 'Holzkiste',
    latitude: 49.32771451123621,
    longitude: 10.850607275770564,
    description: 'Wo gesoffen wird, fallen Späne',
      iconPath: 'assets/icons/kist.png',
      isMobileUnit: false,
      capacity: 15

  ),
  Pub(
    id: 'pub4',
    name: 'Ominöse Hütte',
    latitude: 49.32762674951475,
    longitude: 10.852052491116698,
    description: 'Wo gehts na do nei?',
      iconPath: 'assets/icons/omin.png',
      isMobileUnit: false,
      capacity: 20

  ),
  Pub(
    id: 'pub5',
    name: 'Forelle',
    latitude: 49.32726637463203,
    longitude: 10.852365865038283,
    description: 'Recht fischig hier...',
      iconPath: 'assets/icons/fore.png',
      isMobileUnit: false,
      capacity: 10

  ),
  Pub(
    id: 'pub6',
    name: 'Johnnys',
    latitude: 49.32656949944516,
    longitude: 10.851283956369251,
    description: 'Die Deckn kennerd ma scho amol verkleiden...',
      iconPath: 'assets/icons/john.png',
    isMobileUnit: false,
      capacity: 10
  ),
  Pub(
      id: 'pub7',
      name: 'Mobile Einheit',
      latitude: 49.32806282231425,
      longitude: 10.85224871540075,
      description: 'Call me maybe!',
      iconPath: 'assets/icons/mobile.png',
      isMobileUnit: true,
      capacity: 0
  ),
];
