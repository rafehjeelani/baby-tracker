-- Run this in Supabase SQL Editor to add header colour to families
alter table families add column if not exists color text;
