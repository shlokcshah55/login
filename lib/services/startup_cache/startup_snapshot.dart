import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/models/video_extras.dart';
import 'package:login/supabase/constants.dart';

class StartupSnapshotFormatException implements Exception {
  const StartupSnapshotFormatException(this.message);

  final String message;

  @override
  String toString() => 'StartupSnapshotFormatException: $message';
}

class StartupSnapshotUnsupportedSchemaException
    extends StartupSnapshotFormatException {
  const StartupSnapshotUnsupportedSchemaException(super.message);
}

class StartupSnapshot {
  const StartupSnapshot({
    required this.schemaVersion,
    required this.userId,
    required this.writtenAt,
    required this.savedLocations,
    this.profile,
    this.acceptedConsentVersion,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String userId;
  final DateTime writtenAt;
  final UserModel? profile;
  final List<LocationModel> savedLocations;
  final String? acceptedConsentVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema_version': schemaVersion,
        'user_id': userId,
        'written_at': writtenAt.toUtc().toIso8601String(),
        'accepted_consent_version': acceptedConsentVersion,
        'profile': profile?.toJson(),
        'saved_locations': savedLocations.map(_encodeLocation).toList(),
      };

  factory StartupSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion != currentSchemaVersion) {
      throw StartupSnapshotUnsupportedSchemaException(
        'Unsupported schema: $schemaVersion',
      );
    }

    final userId = json['user_id'];
    final writtenAt = DateTime.tryParse(json['written_at']?.toString() ?? '');
    if (userId is! String || userId.isEmpty || writtenAt == null) {
      throw const StartupSnapshotFormatException(
        'Snapshot ownership metadata is invalid',
      );
    }

    final rawLocations = json['saved_locations'];
    return StartupSnapshot(
      schemaVersion: schemaVersion as int,
      userId: userId,
      writtenAt: writtenAt.toUtc(),
      profile: _decodeProfile(json['profile'], userId),
      savedLocations: rawLocations is List
          ? rawLocations
              .map(_decodeLocation)
              .whereType<LocationModel>()
              .toList(growable: false)
          : const <LocationModel>[],
      acceptedConsentVersion: json['accepted_consent_version'] as String?,
    );
  }

  static Map<String, dynamic> _encodeLocation(LocationModel location) {
    return <String, dynamic>{
      ...location.toJson(),
      '_cache_image_url': location.imageUrl,
      '_cache_match_score': location.matchScore,
      '_cache_saved_from': location.savedFrom,
      '_cache_saved_method': location.savedMethod,
      '_cache_saved_at': location.savedAt?.toUtc().toIso8601String(),
      '_cache_video_extras': _encodeVideoExtras(location.videoExtras),
    };
  }

  static LocationModel? _decodeLocation(Object? raw) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      final location = LocationModel.fromJson(
        json,
        json['_cache_image_url'] as String?,
      );
      final rawSavedAt = json['_cache_saved_at'];
      final rawVideoExtras = json['_cache_video_extras'];
      return location.copyWith(
        matchScore: (json['_cache_match_score'] as num?)?.toDouble(),
        savedFrom: json['_cache_saved_from'] as String?,
        savedMethod: json['_cache_saved_method'] as String?,
        savedAt: rawSavedAt == null
            ? null
            : DateTime.tryParse(rawSavedAt.toString())?.toUtc(),
        videoExtras: rawVideoExtras is Map
            ? VideoExtras.fromJson(Map<String, dynamic>.from(rawVideoExtras))
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static UserModel? _decodeProfile(Object? raw, String userId) {
    if (raw is! Map) return null;
    try {
      final json = Map<String, dynamic>.from(raw);
      if (json[SupabaseConstants.columnSupabaseId] != userId ||
          json[SupabaseConstants.columnEmail] is! String) {
        return null;
      }
      return UserModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _encodeVideoExtras(VideoExtras? extras) {
    if (extras == null) return null;
    return <String, dynamic>{
      'personal_notes': extras.personalNotes,
      'special_offers': extras.specialOffers
          ?.map(
            (offer) => <String, dynamic>{
              'offer': offer.offer,
              'valid_until': offer.validUntil,
              'code': offer.code,
            },
          )
          .toList(growable: false),
    };
  }
}
