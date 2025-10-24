import 'package:location/location.dart';

void testLocation() async {
  final location = Location();
  final loc = await location.getLocation();
  print("📍 Test: ${loc.latitude}, ${loc.longitude}");
}