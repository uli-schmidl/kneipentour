import 'package:cloud_firestore/cloud_firestore.dart';


void main() {
  printPubs();
}

void printPubs() async {
  final snap = await FirebaseFirestore.instance.collection('pubs').get();
  for (var d in snap.docs) {
    print({
      "id": d.id,
      "name": d["name"],
      "capacity": d["capacity"],
      "latitude": d["latitude"],
      "longitude": d["longitude"],
    });
  }
}