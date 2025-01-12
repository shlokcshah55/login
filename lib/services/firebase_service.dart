import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/models/location_model.dart';

class FirebaseService {
  final FirebaseAuth auth_ = FirebaseAuth.instance;
  final FirebaseFirestore db_ = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // Get a user's data by userId
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      DocumentSnapshot doc = await db_.collection("users").doc(userId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        print('No such user found');
        return null;
      }
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Sign up a new user and save their data to Firestore
  Future<void> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Sign up with Firebase Authentication
      UserCredential userCredential = await auth_.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Add user to Firestore
        await db_.collection('Users').doc(user.uid).set({
          'name': name,
          'email': email,
          'uid': user.uid, // Use uid as the unique identifier
          'followers': [],
          'following': [],
          'saved_locations': [],
        });
        print('User signed up successfully');
      }
    } catch (e) {
      print('Error signing up user: $e');
    }
  }

  // Attempt to sign in a user
  Future<bool> attemptSignIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await auth_.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        print('User signed in: ${user.email}');

        // Fetch additional user data from Firestore
        DocumentSnapshot userDoc = await db_.collection('Users').doc(user.uid).get();

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

  // Get the current user's Firestore data
  Future<DocumentSnapshot?> getCurrentUserData(User user) async {
    try {
      DocumentSnapshot userDoc = await db_.collection('Users').doc(user.uid).get();
      return userDoc;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  Future<List<LocationModel>> getSavedLocations(User user) async {
    try {
      DocumentSnapshot userDoc = await db_.collection('Users').doc(user.uid).get();
      List<dynamic> savedLocations = userDoc.get('saved_locations');
      List<LocationModel> locations = [];

      for (var location in savedLocations) {
        locations.add(LocationModel.fromMap(location));
      }

      return locations;
    } catch (e) {
      print('Error getting saved locations: $e');
      return [];
    }
  }

  Future<void> storeLocation(LocationModel location) async {}

}
