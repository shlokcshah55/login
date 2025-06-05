import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_flutter/supabase_client.dart';

class ImageUploadService {
  final SupabaseClient _client = SupabaseClientManager().client;

  /// Upload profile image to Supabase storage
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (kDebugMode) {
        print('Starting image upload for user: ${user.id}');
        print('Image file path: ${imageFile.path}');
        print('Image file size: ${await imageFile.length()} bytes');
      }

      // Generate unique filename
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'profile_images/$fileName';

      if (kDebugMode) {
        print('Upload path: $path');
      }

      // Upload to Supabase storage
      final response = await _client.storage
          .from('avatars')
          .upload(path, imageFile, fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ));

      if (kDebugMode) {
        print('Upload response: $response');
      }

      // Get public URL
      final publicUrl = _client.storage
          .from('avatars')
          .getPublicUrl(path);

      if (kDebugMode) {
        print('Image uploaded successfully: $publicUrl');
      }

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      
      // If upload fails, try with upsert: true (overwrite existing)
      try {
        final user = _client.auth.currentUser;
        if (user == null) return null;

        final fileName = '${user.id}_profile.jpg';
        final path = 'profile_images/$fileName';

        if (kDebugMode) {
          print('Retrying upload with upsert: true');
        }

        final response = await _client.storage
            .from('avatars')
            .upload(path, imageFile, fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ));

        if (kDebugMode) {
          print('Retry upload response: $response');
        }

        final publicUrl = _client.storage
            .from('avatars')
            .getPublicUrl(path);

        return publicUrl;
      } catch (e2) {
        if (kDebugMode) {
          print('Error uploading image with upsert: $e2');
        }
        
        // Try with a different bucket name as final fallback
        return await _uploadToDefaultBucket(imageFile);
      }
    }
  }

  /// Try uploading to a default/public bucket as fallback
  Future<String?> _uploadToDefaultBucket(File imageFile) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Try common bucket names
      const bucketNames = ['images', 'uploads', 'public', 'files'];
      
      for (String bucketName in bucketNames) {
        try {
          if (kDebugMode) {
            print('Trying bucket: $bucketName');
          }
          
          final path = 'profile_images/$fileName';
          await _client.storage
              .from(bucketName)
              .upload(path, imageFile, fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ));

          final publicUrl = _client.storage
              .from(bucketName)
              .getPublicUrl(path);

          if (kDebugMode) {
            print('Successfully uploaded to bucket: $bucketName');
          }

          return publicUrl;
        } catch (e) {
          if (kDebugMode) {
            print('Failed to upload to bucket $bucketName: $e');
          }
          continue;
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error in fallback upload: $e');
      }
      return null;
    }
  }

  /// Delete profile image from Supabase storage
  Future<bool> deleteProfileImage(String imageUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(imageUrl);
      final path = uri.pathSegments.skip(3).join('/'); // Skip /storage/v1/object/public/avatars/

      await _client.storage
          .from('avatars')
          .remove([path]);

      if (kDebugMode) {
        print('Image deleted successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting image: $e');
      }
      return false;
    }
  }
}
