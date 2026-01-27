import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/constants.dart';

class PushNotificationService {
  final String? apiSecretKey = dotenv.env["API_SECRET_KEY"];
  final String apiEndpoint = 'https://europe-west1-pinit-a97eb.cloudfunctions.net/send_push_notification';

  /// Send notification when someone requests to follow a user
  Future<bool> sendFollowRequestNotification({
    required String recipientUserId,
    required String requesterUserId,
  }) async {
    try {
      // Fetch recipient's FCM token
      final fcmToken = await _getFCMToken(recipientUserId);
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('PushNotificationService: Recipient has no FCM token, skipping notification');
        }
        return false;
      }

      // Fetch requester's profile data
      final requesterProfile = await _getUserProfile(requesterUserId);
      if (requesterProfile == null) {
        if (kDebugMode) {
          print('PushNotificationService: Could not fetch requester profile');
        }
        return false;
      }

      final String requesterName = requesterProfile['name'] ?? requesterProfile['username'] ?? 'Someone';

      if (kDebugMode) {
        print('PushNotificationService: Sending follow request notification');
        print('  Recipient FCM token length: ${fcmToken.length}');
        print('  Requester name: $requesterName');
        print('  Requester ID: $requesterUserId');
      }

      // Send notification (all data values must be strings)
      return await _sendNotification(
        fcmToken: fcmToken,
        title: 'New Follow Request',
        body: '$requesterName requested to follow you',
        userId: requesterUserId,
        type: 'follow_request',
      );
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error sending follow request notification: $e');
      }
      return false;
    }
  }

  /// Send notification when a follow request is accepted
  Future<bool> sendFollowAcceptedNotification({
    required String recipientUserId,
    required String accepterUserId,
  }) async {
    try {
      // Fetch recipient's FCM token
      final fcmToken = await _getFCMToken(recipientUserId);
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('PushNotificationService: Recipient has no FCM token, skipping notification');
        }
        return false;
      }

      // Fetch accepter's profile data
      final accepterProfile = await _getUserProfile(accepterUserId);
      if (accepterProfile == null) {
        if (kDebugMode) {
          print('PushNotificationService: Could not fetch accepter profile');
        }
        return false;
      }

      final String accepterName = accepterProfile['name'] ?? accepterProfile['username'] ?? 'Someone';


      // Send notification (all data values must be strings)
      return await _sendNotification(
        fcmToken: fcmToken,
        title: 'Follow Request Accepted',
        body: '$accepterName accepted your follow request',
        userId: accepterUserId,
        type: 'follow_accepted',
      );
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error sending follow accepted notification: $e');
      }
      return false;
    }
  }

  /// Send notification when a user is added to a bubble
  Future<bool> sendUserAddedToBubbleNotification({
    required String recipientUserId,
    required String inviterUserId,
    required String bubbleId,
    required String bubbleName,
  }) async {
    try {
      // Fetch recipient's FCM token
      final fcmToken = await _getFCMToken(recipientUserId);
      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) {
          print('PushNotificationService: Recipient has no FCM token, skipping notification');
        }
        return false;
      }

      // Fetch inviter's profile data
      final inviterProfile = await _getUserProfile(inviterUserId);
      if (inviterProfile == null) {
        if (kDebugMode) {
          print('PushNotificationService: Could not fetch inviter profile');
        }
        return false;
      }

      final String inviterName = inviterProfile['name'] ?? inviterProfile['username'] ?? 'Someone';
      final String inviterAvatar = inviterProfile['profile_image_url'] ?? '';

      if (kDebugMode) {
        print('PushNotificationService: Sending user added to bubble notification');
        print('  Recipient FCM token length: ${fcmToken.length}');
        print('  Inviter name: $inviterName');
        print('  Bubble name: $bubbleName');
      }

      // Send notification (all data values must be strings)
      return await _sendNotification(
        fcmToken: fcmToken,
        title: 'New Bubble Invitation',
        body: '$inviterName added you to $bubbleName',
        userId: inviterUserId,
        type: 'user_added_to_bubble',
        additionalData: {
          'inviterUsername': inviterName,
          'inviterAvatar': inviterAvatar,
          'inviterId': inviterUserId,
          'bubbleName': bubbleName,
          'bubbleId': bubbleId,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error sending user added to bubble notification: $e');
      }
      return false;
    }
  }

  /// Send notification to all bubble members when a new message is sent
  Future<void> sendBubbleMessageNotification({
    required String bubbleId,
    required String senderId,
    required String messageContent,
  }) async {
    try {
      if (kDebugMode) {
        print('PushNotificationService: Sending bubble message notifications for bubble: $bubbleId');
      }

      // Fetch sender's profile data
      final senderProfile = await _getUserProfile(senderId);
      if (senderProfile == null) {
        if (kDebugMode) {
          print('PushNotificationService: Could not fetch sender profile');
        }
        return;
      }

      final String senderName = senderProfile['name'] ?? senderProfile['username'] ?? 'Someone';
      final String senderAvatar = senderProfile['profile_image_url'] ?? '';

      // Fetch bubble info to get bubble name
      final bubbleResponse = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableBubbles)
          .select('${SupabaseConstants.columnName}')
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .single();

      final String bubbleName = bubbleResponse[SupabaseConstants.columnName] ?? 'Group Chat';

      // Fetch all bubble members except the sender
      final membersResponse = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableBubbleMembers)
          .select(SupabaseConstants.columnUserId)
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .neq(SupabaseConstants.columnUserId, senderId);

      final members = membersResponse as List<dynamic>;

      if (kDebugMode) {
        print('PushNotificationService: Found ${members.length} members to notify');
      }

      // Create a preview of the message (truncate if too long)
      final messagePreview = messageContent.length > 50
          ? '${messageContent.substring(0, 50)}...'
          : messageContent;

      // Send notification to each member
      for (final member in members) {
        final memberId = member[SupabaseConstants.columnUserId] as String;

        // Fetch member's FCM token
        final fcmToken = await _getFCMToken(memberId);
        if (fcmToken == null || fcmToken.isEmpty) {
          if (kDebugMode) {
            print('PushNotificationService: Member $memberId has no FCM token, skipping');
          }
          continue;
        }

        // Send notification
        await _sendNotification(
          fcmToken: fcmToken,
          title: 'New message in $bubbleName',
          body: '$senderName: $messagePreview',
          userId: senderId,
          type: 'new_message',
          additionalData: {
            'senderUsername': senderName,
            'senderAvatar': senderAvatar,
            'bubbleName': bubbleName,
            'bubbleId': bubbleId,
            'messagePreview': messagePreview,
          },
        );
      }

      if (kDebugMode) {
        print('PushNotificationService: ✅ Sent notifications to ${members.length} members');
      }
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error sending bubble message notifications: $e');
      }
    }
  }

  /// Fetch FCM token from Supabase for a given user ID
  Future<String?> _getFCMToken(String userId) async {
    try {
      final response = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUsers)
          .select(SupabaseConstants.columnFcmToken)
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      return response[SupabaseConstants.columnFcmToken] as String?;
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error fetching FCM token: $e');
      }
      return null;
    }
  }

  /// Fetch user profile data from Supabase
  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final response = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUsers)
          .select('${SupabaseConstants.name}, ${SupabaseConstants.columnUsername}, ${SupabaseConstants.columnProfileImageUrl}')
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      if (kDebugMode) {
        print('PushNotificationService: Fetched user profile: $response');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error fetching user profile: $e');
      }
      return null;
    }
  }

  /// Send notification via Cloud Function API
  Future<bool> _sendNotification({
    required String fcmToken,
    required String title,
    required String body,
    required String userId,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {

      final dataPayload = {
        'type': type,
        'id': 'notif_${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'userId': userId,
        ...(additionalData ?? {}),
      };

      final payload = {
        'fcm_token': fcmToken,
        'title': title,
        'body': body,
        'data': dataPayload,
      };


      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiSecretKey',
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (kDebugMode) {
        print('PushNotificationService: Response status code: ${response.statusCode}');
        print('PushNotificationService: Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('PushNotificationService: ✅ Notification sent successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('PushNotificationService: ❌ Failed to send notification');
          print('PushNotificationService: Status code: ${response.statusCode}');
          print('PushNotificationService: Error response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('PushNotificationService: Error sending notification: $e');
      }
      return false;
    }
  }
}
