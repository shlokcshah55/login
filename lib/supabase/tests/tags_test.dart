import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../service.dart';
import '../supabase_client.dart';

void main() {
  late SupabaseService supabase;

  setUpAll(() async {
    // Load environment variables
    await dotenv.load(fileName: '.env');

    // Initialize Supabase client directly first
    await SupabaseClientManager.initialize();

    // Now create SupabaseService (which can safely access the client)
    supabase = SupabaseService();
    print('Supabase initialized');
  });

  group('Tags Helper Tests', () {
    test('getDietaryRequirementTags returns data', () async {
      print('\nTesting getDietaryRequirementTags...');

      final tags = await supabase.tags.getDietaryRequirementTags();

      print('   Total dietary tags: ${tags.length}');
      if (tags.isNotEmpty) {
        print('   Sample tag: ${tags[0]}');
      }

      // Assertions
      expect(tags, isNotEmpty, reason: 'Dietary tags should not be empty');
      expect(tags, isA<List<Map<String, dynamic>>>());

      // Check structure of first tag
      if (tags.isNotEmpty) {
        expect(tags[0], containsPair('tag_id', isA<String>()));
        expect(tags[0], containsPair('text', isA<String>()));
        expect(tags[0], containsPair('tag_type', isA<String>()));
      }

      print('   Dietary tags test passed');
    });

    test('getVibeTags returns data', () async {
      print('\nTesting getVibeTags...');

      final tags = await supabase.tags.getVibeTags();

      print('   Total vibe tags: ${tags.length}');
      if (tags.isNotEmpty) {
        print('   Sample tag: ${tags[0]}');
      }

      // Assertions
      expect(tags, isNotEmpty, reason: 'Vibe tags should not be empty');
      expect(tags, isA<List<Map<String, dynamic>>>());

      // Check structure of first tag
      if (tags.isNotEmpty) {
        expect(tags[0], containsPair('tag_id', isA<String>()));
        expect(tags[0], containsPair('text', isA<String>()));
        expect(tags[0], containsPair('tag_type', isA<String>()));
      }

      print('   Vibe tags test passed');
    });

    test('getCuisineTags returns data', () async {
      print('\nTesting getCuisineTags...');

      final tags = await supabase.tags.getCuisineTags();

      print('   Total cuisine tags: ${tags.length}');
      if (tags.isNotEmpty) {
        print('   Sample tag: ${tags[0]}');
      }

      // Assertions
      expect(tags, isNotEmpty, reason: 'Cuisine tags should not be empty');
      expect(tags, isA<List<Map<String, dynamic>>>());

      // Check structure of first tag
      if (tags.isNotEmpty) {
        expect(tags[0], containsPair('tag_id', isA<String>()));
        expect(tags[0], containsPair('text', isA<String>()));
        expect(tags[0], containsPair('tag_type', isA<String>()));
      }

      print('   Cuisine tags test passed');
    });

    test('getAllTags returns data', () async {
      print('\nTesting getAllTags...');

      final tags = await supabase.tags.getAllTags();

      print('   Total tags: ${tags.length}');

      // Assertions
      expect(tags, isNotEmpty, reason: 'All tags should not be empty');
      expect(tags, isA<List<Map<String, dynamic>>>());

      // Check we have multiple tag types
      final tagTypes = tags.map((t) => t['tag_type']).toSet().toList();
      print('   Tag types found: $tagTypes');
      expect(tagTypes.length, greaterThan(0), reason: 'Should have at least one tag type');

      print('   All tags test passed');
    });
  });
}
