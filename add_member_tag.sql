-- Run this in Supabase SQL Editor to add role tags to family members
alter table family_members add column if not exists tag text;
