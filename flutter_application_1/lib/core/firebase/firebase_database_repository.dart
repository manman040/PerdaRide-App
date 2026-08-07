import 'package:firebase_database/firebase_database.dart';

import 'perdaride_firebase.dart';

class FirebaseDatabaseRepository {
  FirebaseDatabaseRepository(this._firebase);

  final PerdaRideFirebase _firebase;

  Future<void> setData(String path, Map<String, dynamic> data) {
    return _firebase.refFromUrl(path).set(data);
  }

  Future<void> updateData(String path, Map<String, dynamic> data) {
    return _firebase.refFromUrl(path).update(data);
  }

  Future<void> removePath(String path) {
    return _firebase.refFromUrl(path).remove();
  }

  Future<DataSnapshot> getData(String path) {
    return _firebase.refFromUrl(path).get();
  }

  Future<String> pushData(String path, Map<String, dynamic> data) async {
    final ref = _firebase.refFromUrl(path).push();
    await ref.set(data);
    return ref.key ?? '';
  }

  Stream<DatabaseEvent> watchPath(String path) {
    return _firebase.refFromUrl(path).onValue;
  }

  Stream<DatabaseEvent> watchChildAdded(String path) {
    return _firebase.refFromUrl(path).onChildAdded;
  }
}
