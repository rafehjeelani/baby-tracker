-- ============================================================
-- Baby Tracker – Supabase Setup SQL
-- ============================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 2. Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id         uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  email      text,
  full_name  text,
  avatar     text DEFAULT '👤',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS families (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  created_by uuid REFERENCES profiles ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS family_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES profiles ON DELETE CASCADE,
  role       text NOT NULL DEFAULT 'member',
  joined_at  timestamptz DEFAULT now(),
  UNIQUE(family_id, user_id)
);

CREATE TABLE IF NOT EXISTS babies (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  name       text NOT NULL,
  emoji      text NOT NULL DEFAULT '🌸',
  dob        date,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  baby_id    uuid NOT NULL REFERENCES babies ON DELETE CASCADE,
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  date       text NOT NULL,
  time       text NOT NULL,
  type       text NOT NULL,
  ml         integer,
  note       text,
  created_by uuid REFERENCES profiles ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS measurements (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  baby_id    uuid NOT NULL REFERENCES babies ON DELETE CASCADE,
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  date       text NOT NULL,
  mtype      text NOT NULL,
  value      numeric NOT NULL,
  created_by uuid REFERENCES profiles ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vaccines (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  baby_id    uuid NOT NULL REFERENCES babies ON DELETE CASCADE,
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  date       text NOT NULL,
  name       text NOT NULL,
  note       text,
  created_by uuid REFERENCES profiles ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS daily_notes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  date       text NOT NULL,
  content    text NOT NULL DEFAULT '',
  updated_by uuid REFERENCES profiles ON DELETE SET NULL,
  updated_at timestamptz DEFAULT now(),
  UNIQUE(family_id, date)
);

CREATE TABLE IF NOT EXISTS invitations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id  uuid NOT NULL REFERENCES families ON DELETE CASCADE,
  token      text UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
  invited_by uuid REFERENCES profiles ON DELETE SET NULL,
  role       text NOT NULL DEFAULT 'member',
  status     text NOT NULL DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + INTERVAL '30 days')
);

-- ============================================================
-- 3. Auto-create profile trigger
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', '')
  )
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 4. Enable RLS
-- ============================================================

ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE families       ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE babies         ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries        ENABLE ROW LEVEL SECURITY;
ALTER TABLE measurements   ENABLE ROW LEVEL SECURITY;
ALTER TABLE vaccines       ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_notes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE invitations    ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 5. Helper functions
-- ============================================================

CREATE OR REPLACE FUNCTION is_family_member(fam_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = fam_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION is_family_admin(fam_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = fam_id AND user_id = auth.uid() AND role = 'admin'
  );
$$;

-- ============================================================
-- 6. RLS Policies
-- Drop existing policies first to avoid conflicts
-- ============================================================

DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- profiles
CREATE POLICY "profiles: own all" ON profiles
  FOR ALL TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY "profiles: co-members select" ON profiles
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1 FROM family_members fm1
      JOIN family_members fm2 ON fm1.family_id = fm2.family_id
      WHERE fm1.user_id = auth.uid() AND fm2.user_id = profiles.id
    )
  );

-- families
CREATE POLICY "families: members select" ON families
  FOR SELECT TO authenticated USING (is_family_member(id));

CREATE POLICY "families: admins update" ON families
  FOR UPDATE TO authenticated USING (is_family_admin(id));

CREATE POLICY "families: auth insert" ON families
  FOR INSERT TO authenticated WITH CHECK (created_by = auth.uid());

-- family_members
CREATE POLICY "family_members: members select" ON family_members
  FOR SELECT TO authenticated USING (is_family_member(family_id));

CREATE POLICY "family_members: admins all" ON family_members
  FOR ALL TO authenticated USING (is_family_admin(family_id)) WITH CHECK (is_family_admin(family_id));

CREATE POLICY "family_members: creator inserts self as admin" ON family_members
  FOR INSERT TO authenticated WITH CHECK (
    user_id = auth.uid() AND role = 'admin' AND
    EXISTS (SELECT 1 FROM families WHERE id = family_id AND created_by = auth.uid())
  );

CREATE POLICY "family_members: leave own" ON family_members
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- babies
CREATE POLICY "babies: members all" ON babies
  FOR ALL TO authenticated USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));

-- entries
CREATE POLICY "entries: members all" ON entries
  FOR ALL TO authenticated USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));

-- measurements
CREATE POLICY "measurements: members all" ON measurements
  FOR ALL TO authenticated USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));

-- vaccines
CREATE POLICY "vaccines: members all" ON vaccines
  FOR ALL TO authenticated USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));

-- daily_notes
CREATE POLICY "daily_notes: members all" ON daily_notes
  FOR ALL TO authenticated USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));

-- invitations
CREATE POLICY "invitations: public preview" ON invitations
  FOR SELECT TO anon, authenticated USING (status = 'pending' AND expires_at > now());

CREATE POLICY "invitations: admins manage" ON invitations
  FOR ALL TO authenticated USING (is_family_admin(family_id)) WITH CHECK (is_family_admin(family_id));

-- ============================================================
-- 7. RPC: accept_invitation
-- ============================================================

CREATE OR REPLACE FUNCTION accept_invitation(invite_token text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  inv  invitations%ROWTYPE;
  fam  families%ROWTYPE;
BEGIN
  SELECT * INTO inv
  FROM invitations
  WHERE token = invite_token
    AND status = 'pending'
    AND expires_at > now()
  LIMIT 1;

  IF inv.id IS NULL THEN
    RETURN json_build_object('error', 'Invalid or expired invitation');
  END IF;

  INSERT INTO family_members (family_id, user_id, role)
  VALUES (inv.family_id, auth.uid(), inv.role)
  ON CONFLICT (family_id, user_id) DO NOTHING;

  UPDATE invitations SET status = 'accepted' WHERE id = inv.id;

  SELECT * INTO fam FROM families WHERE id = inv.family_id;

  RETURN json_build_object('ok', true, 'family_id', inv.family_id, 'family_name', fam.name);
END;
$$;

GRANT EXECUTE ON FUNCTION accept_invitation(text) TO authenticated;
