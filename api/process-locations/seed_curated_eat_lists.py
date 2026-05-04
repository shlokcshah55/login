import logging
import os
from pathlib import Path
import sys

from dotenv import load_dotenv
from supabase import create_client, Client

from main import LocationProcessor

def _load_env() -> None:
    base = Path(__file__).resolve()
    candidates = [
        base.parent / ".env",
        base.parent / ".env.local",
        base.parents[2] / ".env",
    ]
    for p in candidates:
        if p.exists():
            load_dotenv(dotenv_path=p, override=False)


_load_env()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

PINIT_USER_ID = "2f26688a-0e38-4a7a-9876-68bea3e57edd"

CURATED_LISTS = [
    {
        "collection_id": "e9f50774-b41a-4712-b230-2700aad37ebd",
        "name": "Date Night 🌹",
        "emoji": "🌹",
        "description": "Romantic, intimate, atmospheric — places that set the mood",
        "curated_city": "London",
        "places": [
            "The Dover",
            "Padella",
            "Noble Rot",
            "Andrew Edmunds",
            "Casse-Croûte",
            "Brunswick House",
            "Hakkasan Mayfair",
            "Humo",
            "The Barbary",
            "Chez Bruce",
            "Tiella",
            "Bottarga",
            "Quo Vadis",
            "Kitchen Table",
        ],
    },
    {
        "collection_id": "33df0d5e-1a26-4cbe-8356-9ea2b46ddece",
        "name": "Cheap Eats 💸",
        "emoji": "💸",
        "description": "Great food without the guilt trip on your wallet",
        "curated_city": "London",
        "places": [
            "Padella",
            "Tayyabs",
            "Roti King",
            "BAO",
            "Dishoom",
            "Flat Iron",
            "Beigel Bake",
            "Hoppers",
            "Pastaio",
            "Le Bab",
            "Kaosarn",
            "Sông Quê Café",
            "Dal Fiorentino",
            "Poppies Fish & Chips",
        ],
    },
    {
        "collection_id": "9e352f72-96b2-45dc-ae65-97e66a661262",
        "name": "Vegetarian & Vegan 🌿",
        "emoji": "🌿",
        "description": "Plant-forward spots that convert even the most committed carnivore",
        "curated_city": "London",
        "places": [
            "Bubala",
            "Mildreds",
            "Mallow",
            "Gauthier Soho",
            "Holy Carrot",
            "The Gate",
            "Persepolis",
            "Club Mexicana",
            "Tofu Vegan",
            "Rovi",
            "Jam Delish",
            "Acme Fire Cult",
            "Vanilla Black",
            "Kin Restaurant",
        ],
    },
    {
        "collection_id": "f1e64a86-ff68-4a95-a2c6-7d755bdd8485",
        "name": "Splurge / Special Occasion 🌟",
        "emoji": "🌟",
        "description": "Fine dining & Michelin stars for when cost is no object",
        "curated_city": "London",
        "places": [
            "The Ledbury",
            "Core by Clare Smyth",
            "Alain Ducasse at The Dorchester",
            "Gymkhana",
            "Brat",
            "Lyle's",
            "Trishna",
            "Elystan Street",
            "Trinity",
            "Bonheur by Matt Abé",
            "Endo at the Rotunda",
            "Brooklands",
            "Luca",
            "Kitchen Table",
        ],
    },
    {
        "collection_id": "17ce4d6a-8239-45fc-b129-7e03241c77a3",
        "name": "Group Dining / Big Night Out 🎉",
        "emoji": "🎉",
        "description": "Loud, lively, made for big tables and celebrations",
        "curated_city": "London",
        "places": [
            "Dishoom",
            "Tayyabs",
            "Bocca di Lupo",
            "Circolo Popolare",
            "Ave Mario",
            "Temper",
            "Brigadiers",
            "Albert's Schloss",
            "Chotto Matte",
            "Acme Fire Cult",
            "Parrillan",
            "ROKA",
            "The Wolseley",
            "Chishuru",
        ],
    },
    {
        "collection_id": "85eedbc1-69cc-4d67-99e6-9b898e026628",
        "name": "Hidden Gems / Under the Radar 🌍",
        "emoji": "🌍",
        "description": "Beloved by locals, under-discussed by tourists",
        "curated_city": "London",
        "places": [
            "Bubala",
            "Smokestak",
            "Tiella",
            "Caia",
            "Lao Dao",
            "Slowburn",
            "Chishuru",
            "AngloThai",
            "Restaurant St Barts",
            "64 Goodge Street",
            "The Tamil Prince",
            "Marathon",
            "Brawn",
            "Etles Uyghur Restaurant",
        ],
    },
    {
        "collection_id": "12c325c0-d0b5-4ee3-8327-838f0b7615cf",
        "name": "Comfort Food / Casual Classics 🍝",
        "emoji": "🍝",
        "description": "The spots you return to again and again",
        "curated_city": "London",
        "places": [
            "Dishoom",
            "Padella",
            "Hoppers",
            "BAO",
            "Flat Iron",
            "Pastaio",
            "Honest Burgers",
            "Poppies Fish & Chips",
            "Kaosarn",
            "Roti King",
            "Bancone",
            "Bocca di Lupo",
            "Tayyabs",
            "The Breakfast Club",
        ],
    },
    {
        "collection_id": "a897ae62-6ec0-4096-8e28-641554d8ab7e",
        "name": "Crowd Favourites / The London Essentials 🏆",
        "emoji": "🏆",
        "description": "The restaurants every Londoner has an opinion on — and usually loves",
        "curated_city": "London",
        "places": [
            "Dishoom",
            "Padella",
            "The Ledbury",
            "Gymkhana",
            "Hoppers",
            "Brat",
            "Noble Rot",
            "Ottolenghi",
            "Mildreds",
            "The Wolseley",
            "Quo Vadis",
            "Bubala",
            "Flat Iron",
            "Lyle's",
        ],
    },
]


def _require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise ValueError(f"{name} environment variable is not set")
    return val


def _supabase_client() -> Client:
    url = _require_env("SUPABASE_URL")
    key = _require_env("SUPABASE_SERVICE_KEY")
    return create_client(url, key)


def ensure_curated_owner(supabase: Client) -> None:
    supabase.table("users").upsert(
        {
            "supabase_id": PINIT_USER_ID,
            "email": "curated@pinit.app",
            "name": "Pinit",
            "username": "pinit",
            "wizard_completed": True,
        }
    ).execute()


def ensure_collections(supabase: Client) -> None:
    rows = []
    for c in CURATED_LISTS:
        rows.append(
            {
                "collection_id": c["collection_id"],
                "name": c["name"],
                "description": c["description"],
                "emoji": c["emoji"],
                "created_by": PINIT_USER_ID,
                "is_curated": True,
                "is_public": True,
                "curated_city": c.get("curated_city"),
            }
        )
    supabase.table("collections").upsert(rows).execute()


def link_location_to_collection(
    supabase: Client, collection_id: str, location_id: int
) -> None:
    supabase.table("collection_locations").insert(
        {
            "collection_id": collection_id,
            "location_id": location_id,
            "added_by": PINIT_USER_ID,
        }
    ).execute()


def main() -> int:
    # Optional single-collection filter for incremental runs.
    only = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    selected = (
        [c for c in CURATED_LISTS if c["collection_id"] == only]
        if only
        else CURATED_LISTS
    )
    if only and not selected:
        logger.error("Unknown collection id: %s", only)
        return 2

    supabase = _supabase_client()
    ensure_curated_owner(supabase)
    ensure_collections(supabase)

    processor = LocationProcessor()

    for c in selected:
        logger.info("Seeding curated collection: %s (%s)", c["name"], c["collection_id"])
        for name in c["places"]:
            result = processor.get_place_info(name)
            if not result:
                logger.warning("Skipping %r — could not resolve place_id", name)
                continue

            place_id, rating, user_ratings_total, lat, lng = result

            # Ingest into the core locations table via the existing pipeline.
            location_id = processor.add_location(
                place_id, rating, user_ratings_total, lat, lng
            )
            if not location_id:
                logger.warning(
                    "No location_id found for place_id %s — skipping link", place_id
                )
                continue

            try:
                link_location_to_collection(supabase, c["collection_id"], location_id)
            except Exception as exc:
                # Unique violations are fine; the goal is idempotency.
                logger.info("Link already exists or failed (%s -> %s): %s", c["collection_id"], location_id, exc)

    logger.info("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
