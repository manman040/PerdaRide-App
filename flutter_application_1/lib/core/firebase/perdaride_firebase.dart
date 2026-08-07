import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PerdaRideFirebase {
  PerdaRideFirebase._();

  static final PerdaRideFirebase instance = PerdaRideFirebase._();

  static const databaseUrl =
      'https://drive-ab344-default-rtdb.asia-southeast1.firebasedatabase.app';

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseDatabase database = FirebaseDatabase.instance;

  DatabaseReference ref(String path) => database.ref(path);
  DatabaseReference refFromUrl(String path) =>
      database.refFromURL('$databaseUrl/$path');

  User? get currentUser => auth.currentUser;
}
