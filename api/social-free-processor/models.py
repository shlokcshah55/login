"""
Data models for the social share extraction pipeline.
"""
from dataclasses import dataclass, field


@dataclass
class URLMetadata:
    """Raw signals extracted cheaply from a URL without any video download."""
    title: str = ""
    description: str = ""
    hashtags: list[str] = field(default_factory=list)
    thumbnail_url: str | None = None
    location_tag: str | None = None   # Instagram/TikTok tagged location
    creator_handle: str | None = None
    # Plain-text transcript parsed from the platform's subtitle track.
    # Populated by the pipeline's subtitle stage; held in memory only.
    transcript: str = ""


@dataclass
class Candidate:
    """A restaurant/venue candidate extracted from text signals."""
    name: str
    area: str | None
    search_query: str
    source: str   # 'caption' | 'hashtag' | 'thumbnail_ocr' | 'slideshow_ocr' | 'frame_ocr' | 'location_tag'
    reasoning: str = ""


@dataclass
class ResolvedPlace:
    """A Google Places result matched against a candidate."""
    place_id: str
    name: str
    address: str
    lat: float | None
    lng: float | None
    types: list[str] = field(default_factory=list)
    rating: float | None = None


@dataclass
class EvidenceFlags:
    """Which extraction methods contributed to the result."""
    caption: bool = False
    thumbnail_ocr: bool = False
    frame_ocr: bool = False
    slideshow_ocr: bool = False
    subtitles: bool = False

    def to_dict(self) -> dict:
        return {
            "caption": self.caption,
            "thumbnail_ocr": self.thumbnail_ocr,
            "frame_ocr": self.frame_ocr,
            "slideshow_ocr": self.slideshow_ocr,
            "subtitles": self.subtitles,
        }


@dataclass
class ConfidenceResult:
    """Confidence score for a single (candidate, place) pairing."""
    overall: float       # 0.0–1.0
    tier: str            # 'high' | 'medium' | 'low'
    name_similarity: float = 0.0
    area_match: float = 0.0
    category_match: float = 0.0


@dataclass
class CandidateMatch:
    """A fully scored (candidate, resolved place) pair."""
    candidate: Candidate
    place: ResolvedPlace
    score: ConfidenceResult

    def to_dict(self) -> dict:
        return {
            "place_id": self.place.place_id,
            "name": self.place.name,
            "address": self.place.address,
            "types": self.place.types,
            "rating": self.place.rating,
            "score": self.score.overall,
            "tier": self.score.tier,
            "candidate_name": self.candidate.name,
            "candidate_area": self.candidate.area,
            "source": self.candidate.source,
        }


@dataclass
class PipelineResult:
    """
    Final output of the pipeline.

    status:
      - resolved          → high confidence, auto-save
      - needs_confirmation → medium confidence, show user 2-4 choices
      - pending           → low confidence, save post; user adds place later
      - failed            → fatal error, nothing to show
    """
    status: str
    source_url: str
    platform: str
    evidence_flags: EvidenceFlags = field(default_factory=EvidenceFlags)
    top_match: CandidateMatch | None = None
    candidate_matches: list[CandidateMatch] = field(default_factory=list)
    # URLMetadata is included so callers can run insight extraction without
    # re-fetching the URL. Never persisted — used only in the same request cycle.
    meta: "URLMetadata | None" = None
    error: str | None = None
