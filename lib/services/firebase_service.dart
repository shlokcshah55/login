import 'dart:developer';
import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/models/location_model.dart';
import 'package:provider/provider.dart';

class FirebaseService {
  final FirebaseAuth auth_ = FirebaseAuth.instance;
  final FirebaseFirestore db_ = FirebaseFirestore.instance;
  static final Timestamp arbitary_past_point = Timestamp.fromDate(DateTime(2025,1,1,12,00,0));

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // Get a user's data by userId
  Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      DocumentSnapshot userDoc = await db_.collection('Users').doc(userId).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

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
        log('FirebaseService: User signed in: ${user.email}');
        // Fetch additional user data from Firestore
        await getUser(user.uid);
        return true;
      }
    } catch (e) {
      log('FirebaseService: Error signing in user: $e');
    }
    return false;
  }

  Future<void> signOut() async {
    try {
      await auth_.signOut();
    } catch (e) {
      log('Error signing out: $e');
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
          'saved_locations': {},
        });
        print('User signed up successfully');
      }
    } catch (e) {
      print('Error signing up user: $e');
    }
  }

  Future<void> storeLocation(LocationModel location) async {
    try {
      // check if location in database already
      DocumentSnapshot locationDoc = await db_.collection('Locations').doc(location.id).get();
      if (!locationDoc.exists) {
        await db_.collection('Locations').doc(location.id).set({
          'name': location.name,
          'location': GeoPoint(location.position!.latitude, location.position!.longitude),
          'saved_count': 0,
          'location_type': "restaurant", // TODO: Add location type to LocationModel
          'address': location.vicinity,
          'description': location.description,
          'rating': location.rating,
          'photo_reference': location.photoReference ?? '',
        });
      }
      // add reference to location in user's saved locations
      await db_.collection('Users').doc(auth_.currentUser!.uid).update({
        'saved_locations.${location.id}': Timestamp.now(),
      });

      updateLocationInfo(location.id);
    } catch (e) {
      log('Error storing location: $e');
    }
  }

  /// Update the saved_count field in the Locations collection
  /// In future will add more data regarding locations to aid recommendation engine
  Future<void> updateLocationInfo(String id) {
    return db_.collection('Locations').doc(id).update({
      'saved_count': FieldValue.increment(1),
    });
  }

  Future<Map<LocationModel, Timestamp>> getSavedLocationsMap() async {
    Map<LocationModel, Timestamp> savedLocationsWithTimestamps = {};
    try {
      DocumentSnapshot userDoc = await db_.collection('Users').doc(auth_.currentUser!.uid).get();
      Map<String, dynamic> savedLocationsMap = userDoc.get('saved_locations'); ;
      print("getSavedLocationsMap: $savedLocationsMap");
      for (String locationId in savedLocationsMap.keys) {
        DocumentSnapshot locationDoc = await db_.collection('Locations').doc(locationId).get();
        
        LocationModel loc = LocationModel.fromDocument(locationDoc);
        Timestamp timestamp = savedLocationsMap[locationId];
        savedLocationsWithTimestamps[loc] = timestamp;
      }
  } catch (e) {
    log('Error getting saved locations: $e');
  }
  return savedLocationsWithTimestamps;
}

Future<Timestamp?> getLocationTimestamp(String locationId) async {
  try {
    // Get the user's document
    DocumentSnapshot userDoc = await db_.collection('Users').doc(auth_.currentUser!.uid).get();

    // Retrieve the saved_locations map
    Map<String, dynamic> savedLocationsMap = userDoc.get('saved_locations');

    // Check if the locationId exists in the map
    if (savedLocationsMap.containsKey(locationId)) {
      return savedLocationsMap[locationId] as Timestamp;
    } else {
      log('Location ID $locationId not found in saved locations.');
      return null; // Return null if locationId is not in the map
    }
  } catch (e) {
    log('Error getting timestamp for location ID $locationId: $e');
    return null; // Return null in case of an error
  }
}


Future<void> updateUserLocationTimestamp(String locationId) async {
  try {
     await db_.collection('Users').doc(auth_.currentUser!.uid).update({
        'saved_locations.$locationId': Timestamp.now(),
      });
  } catch (e) {
    log('Error getting saved locations');
  }
}

Future<List<LocationModel>> getSavedLocations() async {
    List<LocationModel> locTimestamps = [];
    try {
      Map<LocationModel, Timestamp> locTimestamp = await getSavedLocationsMap();
      locTimestamps = locTimestamp.keys.toList();
      print("getSavedLocations: $locTimestamps");
    } catch (e) {
      log('Error getting saved locations: $e');
    }
    return locTimestamps;

  }

  Future<void> removeSavedLocation(String id) async {
    try {
      await db_.collection('Users').doc(auth_.currentUser!.uid).update({
        'saved_locations.$id': FieldValue.delete(),
      });
    } catch (e) {
      log('Error removing saved location: $e');
    }
  }
}

