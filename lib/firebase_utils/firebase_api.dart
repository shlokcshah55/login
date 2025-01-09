import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

void getUser(String userId) async {
  FirebaseFirestore db = FirebaseFirestore.instance;

  await db.collection("users").doc(userId).get().then(
    (DocumentSnapshot doc) {
      var data = doc.data() as Map<String, dynamic>;
    },
    onError: (e) => print("Error getting document: $e"),
  );
}


Future<void> signUpUser(String email, String password, String name) async {
  try {
    // Sign up with Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    User? user = userCredential.user;

    if (user != null) {
      // Add user to Firestore
      FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
        'name': name,
        'email': email,
        'uid': user.uid, // Use uid as the unique identifier
        'followers': [],
        'following': [],
        'saved_locations': [],
      });
    }
  } catch (e) {
    print('Error signing up user: $e');
  }
}

Future<bool> attemptSignIn(String email, String password) async {
  try {
    // Sign in with Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);

    User? user = userCredential.user;

    if (user != null) {
      print('User signed in: ${user.email}');
      // You can fetch additional data from Firestore using the uid
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        print('User data: ${userDoc.data()}');
      }
      return true;
    }
  } catch (e) {
    print('Error signing in user: $e');
  } 
  return false;
}

Future<DocumentSnapshot> getCurrentUserData(User user) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('Users')
      .doc(user.uid)
      .get();
    return userDoc;
  } catch (e) {
    print('Error getting user data: $e');
    return Future.error(e);
  }
}


