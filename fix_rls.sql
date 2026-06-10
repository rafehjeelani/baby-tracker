-- Run this in Supabase SQL Editor to fix the "create family" flow
-- The original policy blocked users from adding themselves as the first member

DROP POLICY IF EXISTS "Family members can insert members" ON family_members;
DROP POLICY IF EXISTS "Admins can insert members" ON family_members;
DROP POLICY IF EXISTS "Members can insert" ON family_members;

CREATE POLICY "Allow member insert" ON family_members
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND (
      -- Allow family creator to add themselves as admin
      (role = 'admin' AND EXISTS (
        SELECT 1 FROM families WHERE id = family_id AND created_by = auth.uid()
      ))
      OR
      -- Allow existing admins to add others
      is_family_admin(family_id)
    )
  );
