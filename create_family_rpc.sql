-- Run this in Supabase SQL Editor
-- This creates a secure function that handles family creation in one step

create or replace function public.create_family(
  p_name text,
  p_babies jsonb
) returns json
language plpgsql security definer
set search_path = public
as $$
declare
  v_family_id uuid;
  v_baby jsonb;
begin
  -- Must be logged in
  if auth.uid() is null then
    return json_build_object('error', 'Not authenticated');
  end if;

  -- Create the family
  insert into families (name, created_by)
  values (p_name, auth.uid())
  returning id into v_family_id;

  -- Add creator as admin
  insert into family_members (family_id, user_id, role)
  values (v_family_id, auth.uid(), 'admin');

  -- Add babies
  if p_babies is not null then
    for v_baby in select * from jsonb_array_elements(p_babies)
    loop
      if (v_baby->>'name') is not null and trim(v_baby->>'name') != '' then
        insert into babies (family_id, name, emoji, dob)
        values (
          v_family_id,
          trim(v_baby->>'name'),
          coalesce(v_baby->>'emoji', '🌸'),
          nullif(trim(v_baby->>'dob'), '')::date
        );
      end if;
    end loop;
  end if;

  return json_build_object('ok', true, 'family_id', v_family_id);
exception when others then
  return json_build_object('error', sqlerrm);
end;
$$;
