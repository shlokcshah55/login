-- Seed Pinit-owned curated collections that users can adopt (read-only).
-- These collections are referenced by stable UUIDs in the app onboarding wizard.

-- Create a dedicated "Pinit" owner row if it doesn't exist. This is a row in
-- the app users table (not a Supabase Auth user).
INSERT INTO public.users (supabase_id, email, name, username, wizard_completed)
VALUES (
  '2f26688a-0e38-4a7a-9876-68bea3e57edd',
  'curated@pinit.app',
  'Pinit',
  'pinit',
  true
)
ON CONFLICT (supabase_id) DO NOTHING;

-- Curated eat-lists (Pinit-owned, public, adoptable via collection_saves).
INSERT INTO public.collections (collection_id, name, description, emoji, created_by, is_curated, is_public, curated_city)
VALUES
  (
    'e9f50774-b41a-4712-b230-2700aad37ebd',
    'Date Night 🌹',
    'Romantic, intimate, atmospheric — places that set the mood',
    '🌹',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    '33df0d5e-1a26-4cbe-8356-9ea2b46ddece',
    'Cheap Eats 💸',
    'Great food without the guilt trip on your wallet',
    '💸',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    '9e352f72-96b2-45dc-ae65-97e66a661262',
    'Vegetarian & Vegan 🌿',
    'Plant-forward spots that convert even the most committed carnivore',
    '🌿',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    'f1e64a86-ff68-4a95-a2c6-7d755bdd8485',
    'Splurge / Special Occasion 🌟',
    'Fine dining & Michelin stars for when cost is no object',
    '🌟',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    '17ce4d6a-8239-45fc-b129-7e03241c77a3',
    'Group Dining / Big Night Out 🎉',
    'Loud, lively, made for big tables and celebrations',
    '🎉',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    '85eedbc1-69cc-4d67-99e6-9b898e026628',
    'Hidden Gems / Under the Radar 🌍',
    'Beloved by locals, under-discussed by tourists',
    '🌍',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    '12c325c0-d0b5-4ee3-8327-838f0b7615cf',
    'Comfort Food / Casual Classics 🍝',
    'The spots you return to again and again',
    '🍝',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  ),
  (
    'a897ae62-6ec0-4096-8e28-641554d8ab7e',
    'Crowd Favourites / The London Essentials 🏆',
    'The restaurants every Londoner has an opinion on — and usually loves',
    '🏆',
    '2f26688a-0e38-4a7a-9876-68bea3e57edd',
    true,
    true,
    'London'
  )
ON CONFLICT (collection_id) DO NOTHING;
