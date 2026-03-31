
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_model.dart';

class ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Item>> getItems() {
    return _firestore.collection('items').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item(
          doc.id,
          doc.data()['name'],
          doc.data()['stock'],
          doc.data()['price'],
        );
      }).toList();
    });
  }
}
