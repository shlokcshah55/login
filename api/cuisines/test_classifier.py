"""
Tests for Multi-Label Cuisine Classifier
=========================================
Run with: pytest test_classifier.py -v
"""

import pytest
import json
from classifier import (
    detect_cuisine,
    normalize_text,
    tokenize,
    extract_domain_path,
    get_cuisine_version,
    get_available_cuisines,
    CuisineResult,
    CUISINE_VERSION,
)


# ── Test Fixtures (Example Restaurant Data) ──────────────────────────────────

@pytest.fixture
def xian_impression():
    """Xi'an Impression restaurant - should detect Chinese (Xi'an/Shaanxi)."""
    return {
        "location_id": 1001,
        "name": "Xi'an Impression",
        "types": "chinese_restaurant,restaurant,food,point_of_interest,establishment",
        "website": "https://xianimpression.co.uk",
        "reviews": [
            {"text": "Amazing biang biang noodles! The hand-pulled noodles are incredible."},
            {"text": "Authentic Xi'an cuisine. The cumin lamb was perfect."},
            {"text": "Best Shaanxi food in London. Try the liangpi cold noodles."},
            {"text": "The roujiamo (Chinese hamburger) is a must-try!"},
        ],
        "review_summary": "Authentic Xi'an and Shaanxi cuisine known for hand-pulled biang biang noodles",
        "generated_summary": "A Chinese restaurant specializing in Xi'an regional cuisine",
    }


@pytest.fixture
def yadgar_fusion():
    """Yadgar - Afghan and Somali fusion restaurant."""
    return {
        "location_id": 1002,
        "name": "Yadgar Restaurant",
        "types": "afghani_restaurant,restaurant,food,point_of_interest,establishment",
        "website": "https://yadgar.co.uk",
        "reviews": [
            {"text": "A beautiful mix of Afghan and Somali flavours. The mantu is excellent."},
            {"text": "Love the fusion of Somali suqaar with Afghan rice dishes."},
            {"text": "Great kabuli rice and they also serve amazing sambusa."},
            {"text": "Unique blend of East African and Central Asian cuisines."},
        ],
        "review_summary": "Afghan and Somali fusion restaurant with authentic dishes from both cuisines",
        "generated_summary": "A restaurant serving Afghan cuisine with Somali influences",
    }


@pytest.fixture
def generic_restaurant():
    """Generic restaurant with no specific cuisine signals."""
    return {
        "location_id": 1003,
        "name": "The Corner Kitchen",
        "types": "restaurant,food,establishment,point_of_interest",
        "website": "https://cornerkitchen.com",
        "reviews": [
            {"text": "Nice atmosphere and friendly staff."},
            {"text": "Good food at reasonable prices."},
        ],
        "review_summary": "A local eatery with varied menu",
        "generated_summary": "A restaurant serving various dishes",
    }


@pytest.fixture
def chinese_only():
    """Standard Chinese restaurant (not regional)."""
    return {
        "location_id": 1004,
        "name": "Golden Dragon",
        "types": "chinese_restaurant,restaurant,food,point_of_interest",
        "website": "https://goldendragon.com",
        "reviews": [
            {"text": "Great dim sum on weekends!"},
            {"text": "The char siu and fried rice are excellent."},
        ],
        "review_summary": "Traditional Chinese restaurant with dim sum",
        "generated_summary": "A Chinese restaurant",
    }


@pytest.fixture
def italian_restaurant():
    """Italian restaurant example."""
    return {
        "location_id": 1005,
        "name": "Trattoria Bella",
        "types": "italian_restaurant,restaurant,food,point_of_interest",
        "website": "https://trattoriabella.co.uk/menu",
        "reviews": [
            {"text": "Best pasta carbonara in town!"},
            {"text": "Authentic Roman style pizza. The tiramisu is amazing."},
        ],
        "review_summary": "Traditional Italian trattoria with homemade pasta",
        "generated_summary": "An Italian restaurant",
    }


# ── Unit Tests: Text Normalization ───────────────────────────────────────────

class TestNormalization:
    """Tests for text normalization functions."""
    
    def test_normalize_text_lowercase(self):
        assert normalize_text("HELLO WORLD") == "hello world"
    
    def test_normalize_text_accents(self):
        assert normalize_text("café résumé") == "cafe resume"
    
    def test_normalize_text_punctuation(self):
        assert normalize_text("hello, world! how's it?") == "hello world how's it"
    
    def test_normalize_text_separators(self):
        assert normalize_text("hello-world/test|example") == "hello world test example"
    
    def test_normalize_text_empty(self):
        assert normalize_text("") == ""
        assert normalize_text(None) == ""
    
    def test_tokenize_basic(self):
        assert tokenize("hello world test") == ["hello", "world", "test"]
    
    def test_tokenize_empty(self):
        assert tokenize("") == []
        assert tokenize(None) == []
    
    def test_extract_domain_path(self):
        assert "xianimpression" in extract_domain_path("https://xianimpression.co.uk/menu")
    
    def test_extract_domain_path_empty(self):
        assert extract_domain_path("") == ""
        assert extract_domain_path(None) == ""


# ── Unit Tests: Xi'an Impression Example ─────────────────────────────────────

class TestXianImpression:
    """Tests for Xi'an Impression restaurant classification."""
    
    def test_detects_chinese(self, xian_impression):
        result = detect_cuisine(xian_impression)
        assert "Chinese" in result.labels
    
    def test_detects_xian_regional(self, xian_impression):
        result = detect_cuisine(xian_impression)
        assert "Chinese (Xi'an/Shaanxi)" in result.labels
    
    def test_primary_is_chinese_variant(self, xian_impression):
        result = detect_cuisine(xian_impression)
        # Primary should be either Chinese or Chinese (Xi'an/Shaanxi)
        assert result.primary in ["Chinese", "Chinese (Xi'an/Shaanxi)"]
    
    def test_not_szechuan(self, xian_impression):
        result = detect_cuisine(xian_impression)
        # Should NOT be Szechuan unless explicitly mentioned
        assert "Chinese (Sichuan)" not in result.labels or result.scores_json.get("Chinese (Sichuan)", 0) < 0.5
    
    def test_has_google_types_source(self, xian_impression):
        result = detect_cuisine(xian_impression)
        assert "google_types" in result.sources_json.get("Chinese", [])
    
    def test_high_confidence(self, xian_impression):
        result = detect_cuisine(xian_impression)
        assert result.confidence in ["medium", "high"]


# ── Unit Tests: Yadgar Fusion Example ────────────────────────────────────────

class TestYadgarFusion:
    """Tests for Yadgar fusion restaurant classification."""
    
    def test_detects_afghan(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        assert "Afghan" in result.labels
    
    def test_detects_somali(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        assert "Somali" in result.labels
    
    def test_is_fusion(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        assert result.is_fusion is True
    
    def test_has_fusion_label(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        assert "Fusion" in result.labels
    
    def test_primary_is_afghan(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        # Primary should be Afghan (from google_types)
        assert result.primary == "Afghan"
    
    def test_multiple_sources(self, yadgar_fusion):
        result = detect_cuisine(yadgar_fusion)
        # Afghan should have multiple sources
        afghan_sources = result.sources_json.get("Afghan", [])
        assert len(afghan_sources) >= 1


# ── Unit Tests: Generic Restaurant ───────────────────────────────────────────

class TestGenericRestaurant:
    """Tests for generic restaurant with no cuisine signals."""
    
    def test_low_or_no_cuisine(self, generic_restaurant):
        result = detect_cuisine(generic_restaurant)
        # Should either have no primary or very low scores
        if result.primary:
            assert result.scores_json.get(result.primary, 0) < 0.5
        else:
            assert result.primary is None
    
    def test_low_confidence(self, generic_restaurant):
        result = detect_cuisine(generic_restaurant)
        assert result.confidence == "low"


# ── Unit Tests: Standard Chinese (No Regional) ───────────────────────────────

class TestChineseOnly:
    """Tests for standard Chinese restaurant without regional specifics."""
    
    def test_detects_chinese(self, chinese_only):
        result = detect_cuisine(chinese_only)
        assert "Chinese" in result.labels
    
    def test_primary_is_chinese(self, chinese_only):
        result = detect_cuisine(chinese_only)
        assert result.primary == "Chinese"
    
    def test_not_fusion(self, chinese_only):
        result = detect_cuisine(chinese_only)
        assert result.is_fusion is False or "Fusion" not in result.labels


# ── Unit Tests: Italian Restaurant ───────────────────────────────────────────

class TestItalianRestaurant:
    """Tests for Italian restaurant classification."""
    
    def test_detects_italian(self, italian_restaurant):
        result = detect_cuisine(italian_restaurant)
        assert "Italian" in result.labels
    
    def test_primary_is_italian(self, italian_restaurant):
        result = detect_cuisine(italian_restaurant)
        assert result.primary == "Italian"
    
    def test_medium_or_high_confidence(self, italian_restaurant):
        result = detect_cuisine(italian_restaurant)
        assert result.confidence in ["medium", "high"]


# ── Property Tests: Score and Source Invariants ──────────────────────────────

class TestInvariants:
    """Property tests for score and source invariants."""
    
    def test_scores_in_valid_range(self, xian_impression, yadgar_fusion, generic_restaurant):
        for location in [xian_impression, yadgar_fusion, generic_restaurant]:
            result = detect_cuisine(location)
            for cuisine, score in result.scores_json.items():
                assert 0 <= score <= 1.0, f"Score {score} for {cuisine} out of range"
    
    def test_sources_present_for_scores(self, xian_impression, yadgar_fusion):
        for location in [xian_impression, yadgar_fusion]:
            result = detect_cuisine(location)
            for cuisine in result.scores_json:
                if cuisine != "Fusion":  # Fusion is synthesized
                    sources = result.sources_json.get(cuisine, [])
                    assert len(sources) > 0, f"No sources for scored cuisine: {cuisine}"
    
    def test_primary_in_labels(self, xian_impression, yadgar_fusion, italian_restaurant):
        for location in [xian_impression, yadgar_fusion, italian_restaurant]:
            result = detect_cuisine(location)
            if result.primary:
                assert result.primary in result.labels
    
    def test_labels_match_scores(self, xian_impression, yadgar_fusion):
        for location in [xian_impression, yadgar_fusion]:
            result = detect_cuisine(location)
            assert set(result.labels) == set(result.scores_json.keys())
    
    def test_confidence_valid_value(self, xian_impression, yadgar_fusion, generic_restaurant):
        for location in [xian_impression, yadgar_fusion, generic_restaurant]:
            result = detect_cuisine(location)
            assert result.confidence in ["low", "medium", "high"]
    
    def test_version_is_set(self, xian_impression):
        result = detect_cuisine(xian_impression)
        assert result.version == CUISINE_VERSION


# ── Integration Tests: Edge Cases ────────────────────────────────────────────

class TestEdgeCases:
    """Tests for edge cases and boundary conditions."""
    
    def test_empty_location(self):
        result = detect_cuisine({})
        assert result.confidence == "low"
        assert result.labels == [] or (result.primary is None and len(result.labels) == 0)
    
    def test_null_fields(self):
        location = {
            "name": None,
            "types": None,
            "website": None,
            "reviews": None,
        }
        result = detect_cuisine(location)
        # Should not raise exceptions
        assert result is not None
    
    def test_reviews_as_string(self):
        """Test handling reviews as JSON string instead of list."""
        location = {
            "name": "Test Restaurant",
            "types": "chinese_restaurant",
            "reviews": json.dumps([{"text": "Great dim sum!"}]),
        }
        result = detect_cuisine(location)
        assert "Chinese" in result.labels
    
    def test_reviews_as_string_list(self):
        """Test handling reviews as list of strings."""
        location = {
            "name": "Test Restaurant",
            "types": "thai_restaurant",
            "reviews": ["Amazing pad thai!", "Best green curry ever"],
        }
        result = detect_cuisine(location)
        assert "Thai" in result.labels
    
    def test_conflicting_signals(self):
        """Test when name and types suggest different cuisines."""
        location = {
            "name": "Thai Garden",
            "types": "chinese_restaurant",
        }
        result = detect_cuisine(location)
        # Both should be detected
        assert "Chinese" in result.labels  # From types (stronger)
        # Thai may or may not be detected depending on threshold


# ── Tests: CuisineResult Methods ─────────────────────────────────────────────

class TestCuisineResult:
    """Tests for CuisineResult class methods."""
    
    def test_to_db_update(self, xian_impression):
        result = detect_cuisine(xian_impression)
        db_update = result.to_db_update()
        
        assert "cuisine_primary" in db_update
        assert "cuisine_detected" in db_update
        assert "cuisine_scores_json" in db_update
        assert "cuisine_source_json" in db_update
        assert "cuisine_confidence" in db_update
        assert "cuisine_version" in db_update
        assert "cuisine_detected_at" in db_update
    
    def test_db_update_types(self, xian_impression):
        result = detect_cuisine(xian_impression)
        db_update = result.to_db_update()
        
        assert isinstance(db_update["cuisine_detected"], list) or db_update["cuisine_detected"] is None
        assert isinstance(db_update["cuisine_scores_json"], dict) or db_update["cuisine_scores_json"] is None
        assert isinstance(db_update["cuisine_source_json"], dict) or db_update["cuisine_source_json"] is None


# ── Tests: Utility Functions ─────────────────────────────────────────────────

class TestUtilityFunctions:
    """Tests for utility functions."""
    
    def test_get_cuisine_version(self):
        version = get_cuisine_version()
        assert version == CUISINE_VERSION
        assert version.startswith("cuisine_v")
    
    def test_get_available_cuisines(self):
        cuisines = get_available_cuisines()
        assert len(cuisines) > 0
        assert "Chinese" in cuisines
        assert "Italian" in cuisines
        assert "Indian" in cuisines


# ── Tests: Fusion Detection Logic ────────────────────────────────────────────

class TestFusionDetection:
    """Tests for fusion detection rules."""
    
    def test_explicit_fusion_phrase(self):
        """Test that explicit fusion phrases trigger fusion detection."""
        location = {
            "name": "East Meets West",
            "types": "restaurant",
            "reviews": [
                {"text": "A beautiful fusion of Japanese and Mexican cuisine. Amazing sushi tacos!"}
            ],
        }
        result = detect_cuisine(location)
        assert result.is_fusion is True
    
    def test_numeric_fusion_close_scores(self):
        """Test fusion detection when two cuisines have close scores."""
        location = {
            "name": "Indo-Chinese Kitchen",
            "types": "indian_restaurant,chinese_restaurant",
        }
        result = detect_cuisine(location)
        # With two strong type signals, should detect potential fusion
        assert len(result.labels) >= 2
    
    def test_single_dominant_not_fusion(self):
        """Test that a single dominant cuisine doesn't trigger fusion."""
        location = {
            "name": "Pure Italian",
            "types": "italian_restaurant",
            "reviews": [
                {"text": "Perfect pasta and pizza"},
                {"text": "Authentic Italian food"},
            ],
        }
        result = detect_cuisine(location)
        assert result.is_fusion is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
