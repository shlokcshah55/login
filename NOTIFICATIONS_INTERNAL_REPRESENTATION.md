# Notifications Internal Representation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Data Models](#data-models)
3. [Notification Types](#notification-types)
4. [Data Flow](#data-flow)
5. [FCM Integration](#fcm-integration)
6. [Backend Services](#backend-services)
7. [UI Representation](#ui-representation)
8. [Code Examples](#code-examples)

---

## Architecture Overview

The notification system uses **two distinct models** that serve different purposes:

### Dual-Model System

#### 1. Legacy Model: `NotificationModel`
- **Location**: `lib/models/notification.dart`
- **Purpose**: Simple mock data generation for UI development
- **Status**: Legacy, primarily for testing
- **Structure**: Flat data class with direct properties

#### 2. Modern Model: `BaseNotification` Hierarchy
- **Location**: `lib/models/notifications/base_notification.dart`
- **Purpose**: Production notification system with FCM integration
- **Status**: Active, currently in use
- **Structure**: Abstract base class with specialized subclasses

### Design Pattern
The modern system uses:
- **Abstract Factory Pattern**: `BaseNotification.fromRemoteMessage()` creates appropriate subclass instances
- **Template Method Pattern**: Base class defines common behavior, subclasses implement specifics
- **Immutable Data**: All notification objects are immutable value objects

---

## Data Models

### Legacy Model: NotificationModel

```dart
class NotificationModel {
  final String id;
  final String userAvatar;
  final String username;
  final String message;
  final String? actionLabel;
  final DateTime timestamp;
  final bool isRead;
}
```

**Fields:**
- `id` - Unique identifier
- `userAvatar` - URL to user's avatar image
- `username` - Display name of user
- `message` - Notification message text
- `actionLabel` - Optional button label (e.g., "Follow", "View")
- `timestamp` - When notification was created
- `isRead` - Read/unread status

**Methods:**
- `getFormattedTimestamp()` - Returns relative time string (e.g., "5m ago")
- `getMockNotifications()` - Static method generating test data

**Limitations:**
- No type safety for different notification types
- No FCM integration
- Cannot be extended for new notification types

---

### Modern Model: BaseNotification Hierarchy

#### Base Class: BaseNotification

```dart
abstract class BaseNotification {
  final String id;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;

  // Abstract methods for subclasses
  String getAvatarUrl();
  String getMessage();
  String? getActionLabel();
  bool hasAction();
  Map<String, dynamic> toFCMData();
  String getNotificationTitle();
  String getNotificationBody();

  // Factory method for FCM parsing
  static BaseNotification? fromRemoteMessage(RemoteMessage message);
}
```

**Core Properties:**
- `id` - Unique notification identifier
- `timestamp` - Creation timestamp
- `isRead` - Read status (always `false` when received from FCM)
- `type` - Enum value from `NotificationType`

**Abstract Methods Contract:**
Every subclass must implement:
- `getAvatarUrl()` - Return avatar/icon URL for display
- `getMessage()` - Return human-readable message text
- `getActionLabel()` - Return button text or null if no action
- `hasAction()` - Return whether notification has an action button
- `toFCMData()` - Serialize to FCM data payload
- `getNotificationTitle()` - Title for push notification

**Factory Pattern:**
```dart
static BaseNotification? fromRemoteMessage(RemoteMessage message) {
  final type = message.data['type'];

  switch (type) {
    case 'video_processed':
      return VideoProcessedNotification.fromFCMData(data);
    case 'follow_request':
      return FollowRequestNotification.fromFCMData(data);
    case 'follow_accepted':
      return FollowAcceptedNotification.fromFCMData(data);
    case 'friend_visited_location':
      return FriendVisitedLocationNotification.fromFCMData(data);
    case 'friend_added_bubble':
      return FriendAddedToBubbleNotification.fromFCMData(data);
    default:
      return null;
  }
}
```

---

## Notification Types

### Enum Definition

```dart
enum NotificationType {
  videoProcessed,
  followRequest,
  followAccepted,
  friendVisitedLocation,
  friendAddedToBubble,
}
```

---

### 1. VideoProcessedNotification

**Purpose**: Notify user when a TikTok video is processed and location is extracted.

**Class Structure:**
```dart
class VideoProcessedNotification extends BaseNotification {
  final String locationName;
  final String locationId;
}
```

**Additional Fields:**
- `locationName` - Name of extracted location (e.g., "Sunset Beach Cafe")
- `locationId` - Database ID of location

**Display:**
- **Avatar**: App logo placeholder
- **Message**: "We have saved {locationName} from the shared TikTok"
- **Action**: "View" button

**FCM Payload:**
```json
{
  "type": "video_processed",
  "id": "notif_123",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "locationName": "Sunset Beach Cafe",
  "locationId": "loc_123"
}
```

**Use Case**: Sent by `ai/tiktok-processor` after successfully processing a shared TikTok video.

---

### 2. FollowRequestNotification

**Purpose**: Notify user when someone requests to follow them.

**Class Structure:**
```dart
class FollowRequestNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
}
```

**Additional Fields:**
- `username` - Requesting user's display name
- `userAvatar` - URL to requesting user's avatar
- `userId` - Database ID of requesting user

**Display:**
- **Avatar**: Requesting user's avatar
- **Message**: "{username} has requested to follow you"
- **Action**: "Accept" button

**FCM Payload:**
```json
{
  "type": "follow_request",
  "id": "notif_456",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "username": "sarah_jones",
  "userAvatar": "https://example.com/avatar.jpg",
  "userId": "user_789"
}
```

---

### 3. FollowAcceptedNotification

**Purpose**: Notify user when their follow request is accepted.

**Class Structure:**
```dart
class FollowAcceptedNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
}
```

**Additional Fields:**
- `username` - User who accepted the request
- `userAvatar` - URL to their avatar
- `userId` - Database ID

**Display:**
- **Avatar**: Accepting user's avatar
- **Message**: "{username} has accepted your follow request"
- **Action**: None (no button)

**FCM Payload:**
```json
{
  "type": "follow_accepted",
  "id": "notif_789",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "username": "mike_wilson",
  "userAvatar": "https://example.com/avatar2.jpg",
  "userId": "user_456"
}
```

---

### 4. FriendVisitedLocationNotification

**Purpose**: Notify user when a friend visits/checks into a location.

**Class Structure:**
```dart
class FriendVisitedLocationNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
  final String locationName;
  final String locationId;
}
```

**Additional Fields:**
- `username` - Friend's display name
- `userAvatar` - Friend's avatar URL
- `userId` - Friend's database ID
- `locationName` - Location they visited
- `locationId` - Location database ID

**Display:**
- **Avatar**: Friend's avatar
- **Message**: "{username} went to {locationName}"
- **Action**: "View" button

**FCM Payload:**
```json
{
  "type": "friend_visited_location",
  "id": "notif_101",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "username": "emma_davis",
  "userAvatar": "https://example.com/avatar3.jpg",
  "userId": "user_101",
  "locationName": "Central Park",
  "locationId": "loc_456"
}
```

---

### 5. FriendAddedToBubbleNotification

**Purpose**: Notify user when a friend adds a location to a shared bubble.

**Class Structure:**
```dart
class FriendAddedToBubbleNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
  final String bubbleName;
  final String bubbleId;
  final String locationName;
}
```

**Additional Fields:**
- `username` - Friend's display name
- `userAvatar` - Friend's avatar URL
- `userId` - Friend's database ID
- `bubbleName` - Name of the bubble
- `bubbleId` - Bubble database ID
- `locationName` - Location added to bubble

**Display:**
- **Avatar**: Friend's avatar
- **Message**: "{username} saved a location to {bubbleName}"
- **Action**: "View" button

**FCM Payload:**
```json
{
  "type": "friend_added_bubble",
  "id": "notif_202",
  "timestamp": "2026-01-10T15:30:00.000Z",
  "username": "alex_chen",
  "userAvatar": "https://example.com/avatar4.jpg",
  "userId": "user_202",
  "bubbleName": "Coffee Spots",
  "bubbleId": "bubble_789",
  "locationName": "Blue Bottle Coffee"
}
```

---

## Data Flow

### Complete Notification Journey

```
┌─────────────────────────────────────────────────────────────────┐
│                        BACKEND (Python)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Event Occurs (e.g., TikTok processed)                       │
│     └─> ai/tiktok-processor/main.py                             │
│                                                                   │
│  2. Fetch User's FCM Token                                       │
│     └─> Query Supabase: users.fcm_token                         │
│                                                                   │
│  3. Build Notification Payload                                   │
│     └─> Create JSON with type + data fields                     │
│                                                                   │
│  4. Send to Cloud Function                                       │
│     └─> POST to send-push-notification function                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   CLOUD FUNCTION (Python)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  5. Receive Request                                              │
│     └─> ai/send-notification/main.py                            │
│                                                                   │
│  6. Validate Authorization                                       │
│     └─> Check Bearer token                                       │
│                                                                   │
│  7. Build FCM Message                                            │
│     └─> Create Firebase message with:                           │
│         - notification (title, body)                             │
│         - data (custom payload)                                  │
│         - platform config (iOS/Android)                          │
│                                                                   │
│  8. Send via Firebase Admin SDK                                  │
│     └─> messaging.send(message)                                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   FIREBASE CLOUD MESSAGING                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  9. Route to Device                                              │
│     └─> APNs (iOS) or FCM (Android)                             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT (Flutter/Dart)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  10. Receive FCM Message                                         │
│      └─> FCMService._handleForegroundMessage()                  │
│      └─> Or background handler                                   │
│                                                                   │
│  11. Parse RemoteMessage                                         │
│      └─> BaseNotification.fromRemoteMessage()                   │
│      └─> Routes to appropriate subclass constructor             │
│                                                                   │
│  12. Store in Memory                                             │
│      └─> FCMService._notifications list                         │
│                                                                   │
│  13. Broadcast to UI                                             │
│      └─> _notificationController.add(notification)              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         UI LAYER (Flutter)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  14. Listen to Stream                                            │
│      └─> NotificationsPopover subscribes to stream              │
│                                                                   │
│  15. Update UI                                                   │
│      └─> SmartNotificationListItem renders notification         │
│      └─> Shows avatar, message, action button                   │
│      └─> Updates badge count                                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### State Transitions

```
[Created on Backend]
    ↓ (FCM)
[Received by Client] → isRead: false
    ↓ (User taps)
[Marked as Read] → isRead: true (local only, not persisted)
    ↓ (Time passes)
[Cleared/Expired] → Removed from memory
```

---

## FCM Integration

### Token Management

**Location**: `lib/services/fcm_service.dart`

#### Save Token (Login)
```dart
Future<void> saveFCMToken(String fcmToken) async {
  await SupabaseClientManager().client.rpc(
    'update_fcm_token',
    params: {
      'p_user_id': userId,
      'p_fcm_token': fcmToken,
    },
  );
}
```

**Database**: Stored in `users.fcm_token` column in Supabase.

#### Clear Token (Logout)
```dart
Future<void> clearFCMToken() async {
  await SupabaseClientManager().client.rpc(
    'update_fcm_token',
    params: {
      'p_user_id': userId,
      'p_fcm_token': '', // Empty string
    },
  );
}
```

#### Token Refresh
Automatically handled via `FirebaseMessaging.instance.onTokenRefresh` listener.

---

### Message Handling

#### Three Scenarios

**1. Foreground (App Active)**
```dart
FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

void _handleForegroundMessage(RemoteMessage message) {
  final notification = BaseNotification.fromRemoteMessage(message);
  _notifications.insert(0, notification);
  _notificationController.add(notification);
  // TODO: Show in-app banner
}
```

**2. Background (App Minimized)**
```dart
FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

void _handleNotificationTap(RemoteMessage message) {
  final notification = BaseNotification.fromRemoteMessage(message);
  // TODO: Navigate to appropriate screen
}
```

**3. Terminated (App Not Running)**
```dart
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  _handleNotificationTap(initialMessage);
}
```

---

### Platform Configuration

#### iOS (APNs)
```python
apns=messaging.APNSConfig(
    payload=messaging.APNSPayload(
        aps=messaging.Aps(
            sound='default',
            badge=1,
            content_available=True,
        )
    )
)
```

#### Android
```python
android=messaging.AndroidConfig(
    priority='high',
    notification=messaging.AndroidNotification(
        sound='default',
        priority='high',
    )
)
```

---

## Backend Services

### 1. Send Push Notification (Cloud Function)

**Location**: `ai/send-notification/main.py`

**URL**: `https://us-central1-pinit-a97eb.cloudfunctions.net/send-push-notification`

**Purpose**: Generic FCM sender accessible via authenticated HTTP POST.

**Request Format:**
```json
POST /send-push-notification
Headers:
  Authorization: Bearer <API_SECRET_KEY>
  Content-Type: application/json

Body:
{
  "fcm_token": "user's FCM device token",
  "title": "Notification Title",
  "body": "Notification message",
  "data": {
    "type": "video_processed",
    "id": "notif_123",
    "locationName": "Beach Cafe",
    "locationId": "loc_456",
    "timestamp": "2026-01-10T15:30:00.000Z"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message_id": "projects/pinit-a97eb/messages/123456"
}
```

**Security**: Requires `API_SECRET_KEY` environment variable for authorization.

---

### 2. TikTok Processor Notification

**Location**: `ai/tiktok-processor/main.py`

**Function**: `send_video_processed_notification()`

**Trigger**: After successfully processing TikTok video and extracting location.

**Flow:**
1. Query Supabase for user's FCM token
2. Build notification payload with location data
3. POST to `send-push-notification` function
4. Handle errors and retry logic

**Error Notifications:**
Also sends error notifications for:
- `already_saved` - Location already in user's collection
- `no_location` - Could not extract location from TikTok
- `generic` - Processing failure

---

### Database Schema

**Table**: `users`

**Relevant Column:**
```sql
fcm_token TEXT -- Firebase Cloud Messaging device token
```

**RPC Function**: `update_fcm_token(p_user_id UUID, p_fcm_token TEXT)`

Updates or clears FCM token for user.

---

## UI Representation

### NotificationsPopover

**Location**: `lib/widgets/profile/notifications_popover.dart`

**Purpose**: Full-screen notification list accessible from profile page.

**Features:**
- Pull-to-refresh
- Unread count badge
- "Mark all as read" button
- Real-time updates via stream subscription
- Empty state for no notifications

**Stream Subscription:**
```dart
_notificationSubscription = FCMService().notificationStream.listen((notification) {
  setState(() {
    _notifications = FCMService().notifications;
  });
});
```

---

### SmartNotificationListItem

**Location**: `lib/widgets/profile/notifications/smart_notification_list_item.dart`

**Purpose**: Individual notification list item with type-specific rendering.

**Rendering Logic:**
```dart
if (notification.type == NotificationType.videoProcessed) {
  // Render with app icon, location name, "View" button
} else if (notification.type == NotificationType.followRequest) {
  // Render with user avatar, username, "Accept" button
}
// ... other types
```

**Features:**
- Type-specific styling
- Avatar/icon display
- Dynamic action buttons
- Read/unread visual states
- Tap handlers

---

### Read State Management

**Current Implementation**:
- Read state is **local only** (in-memory in `FCMService`)
- **Not persisted** to database
- Resets on app restart

**Method:**
```dart
void markAsRead(String notificationId) {
  // TODO: Recreate notification with isRead: true
  // (notifications are immutable)
}
```

**Limitation**: Read state is not synchronized across devices or sessions.

---

## Code Examples

### Example 1: Sending Notification from Backend

```python
import httpx

# In your backend code
def send_notification_to_user(user_id, notification_type, data):
    # 1. Fetch FCM token from database
    response = supabase.table('users') \
        .select('fcm_token') \
        .eq('supabase_id', user_id) \
        .single() \
        .execute()

    fcm_token = response.data['fcm_token']

    # 2. Build payload
    payload = {
        'fcm_token': fcm_token,
        'title': 'New Notification',
        'body': 'You have a new update',
        'data': {
            'type': notification_type,
            'id': generate_id(),
            'timestamp': datetime.utcnow().isoformat(),
            **data  # Additional fields
        }
    }

    # 3. Send to Cloud Function
    headers = {
        'Authorization': f'Bearer {API_SECRET}',
        'Content-Type': 'application/json'
    }

    response = httpx.post(
        'https://us-central1-pinit-a97eb.cloudfunctions.net/send-push-notification',
        headers=headers,
        json=payload
    )

    return response.json()

# Usage for video processed notification
send_notification_to_user(
    user_id='user_123',
    notification_type='video_processed',
    data={
        'locationName': 'Sunset Beach Cafe',
        'locationId': 'loc_456'
    }
)
```

---

### Example 2: Receiving Notification in Flutter

```dart
// In your app initialization
await FCMService().initialize();

// Listen for notifications
FCMService().notificationStream.listen((notification) {
  print('Received: ${notification.getMessage()}');

  // Handle different types
  if (notification.type == NotificationType.followRequest) {
    final followNotif = notification as FollowRequestNotification;
    showFollowRequestDialog(followNotif.username);
  }
});
```

---

### Example 3: Displaying Notifications in UI

```dart
class NotificationsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BaseNotification>(
      stream: FCMService().notificationStream,
      builder: (context, snapshot) {
        final notifications = FCMService().notifications;

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];

            return SmartNotificationListItem(
              notification: notification,
              onTap: () {
                // Navigate based on type
                navigateToNotificationTarget(notification);
              },
              onActionTap: () {
                // Handle action button
                handleNotificationAction(notification);
              },
            );
          },
        );
      },
    );
  }
}
```

---

### Example 4: Creating Custom Notification Type

To add a new notification type:

**1. Add to enum:**
```dart
// lib/models/notification_type.dart
enum NotificationType {
  videoProcessed,
  followRequest,
  followAccepted,
  friendVisitedLocation,
  friendAddedToBubble,
  newCommentOnPost, // NEW
}
```

**2. Create notification class:**
```dart
// lib/models/notifications/comment_notification.dart
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class CommentNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String postId;
  final String commentText;

  CommentNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.username,
    required this.userAvatar,
    required this.postId,
    required this.commentText,
  }) : super(
    id: id,
    timestamp: timestamp,
    isRead: isRead,
    type: NotificationType.newCommentOnPost,
  );

  factory CommentNotification.fromFCMData(Map<String, dynamic> data) {
    return CommentNotification(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      isRead: false,
      username: data['username'] as String,
      userAvatar: data['userAvatar'] as String,
      postId: data['postId'] as String,
      commentText: data['commentText'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username commented: "$commentText"';

  @override
  String? getActionLabel() => 'Reply';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'new_comment',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'postId': postId,
      'commentText': commentText,
    };
  }

  @override
  String getNotificationTitle() => 'New Comment';
}
```

**3. Register in factory:**
```dart
// lib/models/notifications/base_notification.dart
static BaseNotification? fromRemoteMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type'];

  switch (type) {
    // ... existing cases
    case 'new_comment':
      return CommentNotification.fromFCMData(data);
    default:
      return null;
  }
}
```

**4. Send from backend:**
```python
send_notification_to_user(
    user_id='user_123',
    notification_type='new_comment',
    data={
        'username': 'alice',
        'userAvatar': 'https://example.com/alice.jpg',
        'postId': 'post_789',
        'commentText': 'Great post!'
    }
)
```

---

## Summary

### Key Characteristics

1. **Type-Safe**: Compile-time safety through abstract classes and enums
2. **Extensible**: Easy to add new notification types
3. **Real-Time**: Stream-based architecture for instant UI updates
4. **Platform-Agnostic**: Works across iOS, Android, and web
5. **FCM-Integrated**: Direct integration with Firebase Cloud Messaging
6. **Immutable**: All notification objects are immutable value objects

### Current Limitations

1. **No Persistence**: Notifications cleared on app restart
2. **No Sync**: Read state not synchronized across devices
3. **No History**: No database storage of notification history
4. **Limited Actions**: Actions are UI-only, no backend callbacks
5. **No Grouping**: No grouping of similar notifications

### Future Enhancements

- Database persistence for notification history
- Sync read state across devices
- Rich actions with backend integration
- Notification grouping and summarization
- Push notification preferences/settings
- Notification expiration and cleanup
