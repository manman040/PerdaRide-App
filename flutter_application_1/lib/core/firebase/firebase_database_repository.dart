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

  /// Runs an atomic read-modify-write against [path]. [transactionHandler]
  /// receives the current value and must return `Transaction.success(...)`
  /// with the new value, or `Transaction.abort()` to leave it untouched --
  /// the SDK retries the handler itself if another client's write races
  /// this one, so it may run more than once per call.
  Future<TransactionResult> runTransaction(
    String path,
    TransactionHandler transactionHandler, {
    bool applyLocally = true,
  }) {
    return _firebase
        .refFromUrl(path)
        .runTransaction(transactionHandler, applyLocally: applyLocally);
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

  /// One-shot read of the children of [path] whose [child] key equals
  /// [value]. Only the matching records leave the server, so a rider's
  /// history does not download every booking. Needs a matching `.indexOn`
  /// entry in the database rules for [child].
  Future<DataSnapshot> queryEqualTo(String path, String child, Object value) {
    return _firebase.refFromUrl(path).orderByChild(child).equalTo(value).get();
  }
}
