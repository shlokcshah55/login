from social_collection_redirects import (
    apply_social_post_action,
    find_social_post_action,
    normalize_social_url,
    save_collection_for_user,
    save_location_for_user,
)


def test_finds_social_post_action_by_normalized_url():
    supabase = _FakeSupabase(social_post_row={
        "url": "https://vm.tiktok.com/ZNRb3SMLF/",
        "normalized_url": "https://vm.tiktok.com/znrb3smlf",
        "platform": "tiktok",
        "location_ids": [101, 202],
        "eat_list_collection_id": "11111111-1111-4111-8111-111111111111",
    })

    assert find_social_post_action(
        supabase,
        " https://vm.tiktok.com/ZNRb3SMLF?sender_device=mobile ",
    ) == {
        "platform": "tiktok",
        "location_ids": [101, 202],
        "eat_list_collection_id": "11111111-1111-4111-8111-111111111111",
    }


def test_normalizes_instagram_shortcode_like_database_generated_column():
    assert normalize_social_url(
        "https://www.instagram.com/p/DZsd4QqCEN3/?igsh=d2R4cmJla2lxazZ1"
    ) == "https://www.instagram.com/p/dzsd4qqcen3"


def test_unmapped_url_does_not_return_social_post_action():
    supabase = _FakeSupabase(social_post_row=None)

    assert find_social_post_action(
        supabase,
        "https://www.tiktok.com/@someone/video/999",
    ) is None


def test_save_location_for_user_uses_platform_and_source_url():
    supabase = _FakeSupabase()

    result = save_location_for_user(
        supabase,
        user_id="target-user",
        location_id=101,
        platform="instagram",
        source_url="https://www.instagram.com/reel/abc123?igsh=abc",
    )

    assert result == {
        "success": True,
        "location_id": 101,
        "name": None,
        "already_saved": False,
    }
    assert supabase.rpc_calls == [
        (
            "save_location_with_tags",
            {
                "p_user_id": "target-user",
                "p_location_id": 101,
                "p_saved_method": "instagram",
                "p_acked": True,
                "p_source_video_url": "https://www.instagram.com/reel/abc123?igsh=abc",
            },
        )
    ]


def test_apply_social_post_action_saves_locations_and_collection():
    supabase = _FakeSupabase(collection_row={
        "collection_id": "55555555-5555-4555-8555-555555555555",
        "name": "Mapped Eat List",
        "created_by": "owner-user",
        "is_public": True,
    })

    result = apply_social_post_action(
        supabase,
        user_id="target-user",
        source_url="https://vm.tiktok.com/ZNRb3SMLF/",
        action={
            "platform": "tiktok",
            "location_ids": [101, 202],
            "eat_list_collection_id": "55555555-5555-4555-8555-555555555555",
        },
    )

    assert result["success"] is True
    assert [loc["location_id"] for loc in result["saved_locations"]] == [101, 202]
    assert result["collection"]["collection_id"] == (
        "55555555-5555-4555-8555-555555555555"
    )
    assert [call[1]["p_location_id"] for call in supabase.rpc_calls] == [101, 202]
    assert supabase.saved_rows == [{
        "user_id": "target-user",
        "collection_id": "55555555-5555-4555-8555-555555555555",
    }]


def test_save_collection_for_user_inserts_collection_save():
    supabase = _FakeSupabase(collection_row={
        "collection_id": "33333333-3333-4333-8333-333333333333",
        "name": "Best Date Spots",
        "created_by": "owner-user",
        "is_public": True,
    })

    result = save_collection_for_user(
        supabase,
        user_id="target-user",
        collection_id="33333333-3333-4333-8333-333333333333",
    )

    assert result == {
        "success": True,
        "collection_id": "33333333-3333-4333-8333-333333333333",
        "name": "Best Date Spots",
        "already_owned": False,
    }
    assert supabase.saved_rows == [
        {
            "user_id": "target-user",
            "collection_id": "33333333-3333-4333-8333-333333333333",
        }
    ]


def test_save_collection_for_owner_does_not_insert_duplicate_save():
    supabase = _FakeSupabase(collection_row={
        "collection_id": "44444444-4444-4444-8444-444444444444",
        "name": "My Eat List",
        "created_by": "target-user",
        "is_public": True,
    })

    result = save_collection_for_user(
        supabase,
        user_id="target-user",
        collection_id="44444444-4444-4444-8444-444444444444",
    )

    assert result["success"] is True
    assert result["already_owned"] is True
    assert supabase.saved_rows == []


class _Response:
    def __init__(self, data):
        self.data = data


class _FakeSupabase:
    def __init__(self, collection_row=None, social_post_row=None):
        self.collection_row = collection_row
        self.social_post_row = social_post_row
        self.saved_rows = []
        self.rpc_calls = []

    def table(self, table_name):
        return _FakeTable(self, table_name)

    def rpc(self, name, params):
        self.rpc_calls.append((name, params))
        return _FakeRpc()


class _FakeTable:
    def __init__(self, supabase, table_name):
        self.supabase = supabase
        self.table_name = table_name
        self.row = None
        self.filters = {}

    def select(self, *_args):
        return self

    def eq(self, column, value):
        self.filters[column] = value
        return self

    def maybe_single(self):
        return self

    def upsert(self, row, **_kwargs):
        self.row = row
        return self

    def execute(self):
        if self.table_name == "collections":
            return _Response(self.supabase.collection_row)
        if self.table_name == "collection_saves":
            self.supabase.saved_rows.append(self.row)
            return _Response([self.row])
        if self.table_name == "social_post_actions":
            expected = self.supabase.social_post_row
            if expected and self.filters.get("normalized_url") == expected.get("normalized_url"):
                return _Response(expected)
            return _Response(None)
        raise AssertionError(f"Unexpected table {self.table_name}")


class _FakeRpc:
    def execute(self):
        return _Response({"success": True})
