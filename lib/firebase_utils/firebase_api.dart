import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void playBase() async {
  FirebaseFirestore db = FirebaseFirestore.instance;

}

void getUsers() async {
  FirebaseFirestore db = FirebaseFirestore.instance;

  await db.collection("users").get().then(
    (event) {
      for (DocumentSnapshot doc in event.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print(data['username']);
      }
    }, 
    onError: (e) => print("Error getting document: $e"),
  );
}


void addUser() async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  await firestore.collection('Users').doc('user_id_1').set({
    'name': 'Waste Man',
    'followers': [],
    'following': [],
    'saved_locations': [],
    'posts': []
  });
}





