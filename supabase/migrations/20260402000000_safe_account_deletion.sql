-- Safe account deletion: anonymize instead of cascade-deleting everything.
--
-- Previous behavior: deleting auth.users cascaded to public.users, which
-- cascaded to trips, blocks, posts, bills — destroying all content for
-- every member of every trip the user owned or contributed to.
--
-- New behavior:
-- 1. Trips they own with other members → transfer ownership to earliest joiner
-- 2. Trips they own with no other members → delete (nobody affected)
-- 3. Membership in other trips → leave (posts/blocks/bills stay)
-- 4. Private posts → delete (invisible to others anyway)
-- 5. User record → anonymize as "Deleted User" (content still renders)
-- 6. Auth record → delete (can't log in again)

-- ============================================================
-- 1. Break the cascade from auth.users → public.users.
-- We keep public.users as an anonymized tombstone so existing
-- content (posts, blocks, bills) still renders with "Deleted User".
-- ============================================================
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_id_fkey;

-- ============================================================
-- 2. Safe account deletion RPC.
-- Runs as SECURITY DEFINER (postgres role) so it can access
-- auth.users and modify data across RLS boundaries.
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_trip record;
    v_new_owner_id uuid;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- A. Handle trips this user owns
    FOR v_trip IN
        SELECT t.id FROM trips t WHERE t.created_by = v_user_id
    LOOP
        -- Find the earliest joined member who isn't the deleting user
        SELECT tm.user_id INTO v_new_owner_id
        FROM trip_members tm
        WHERE tm.trip_id = v_trip.id
          AND tm.user_id != v_user_id
        ORDER BY tm.joined_at ASC
        LIMIT 1;

        IF v_new_owner_id IS NOT NULL THEN
            -- Transfer ownership: update trip creator + promote member to owner
            UPDATE trips SET created_by = v_new_owner_id WHERE id = v_trip.id;
            UPDATE trip_members SET role = 'owner'
            WHERE trip_id = v_trip.id AND user_id = v_new_owner_id;
        ELSE
            -- No other members — safe to delete the entire trip
            -- (cascades delete blocks, posts, post_media, bills, bill_shares, payments)
            DELETE FROM trips WHERE id = v_trip.id;
        END IF;
    END LOOP;

    -- B. Leave all remaining trips (remove membership, keep content)
    DELETE FROM trip_members WHERE user_id = v_user_id;

    -- C. Delete private posts (invisible to others, no reason to keep)
    -- First delete their media records, then the posts
    DELETE FROM post_media WHERE post_id IN (
        SELECT id FROM posts WHERE user_id = v_user_id AND visibility = 'private'
    );
    DELETE FROM posts WHERE user_id = v_user_id AND visibility = 'private';

    -- D. Anonymize the user record (tombstone for shared content)
    -- Shared posts, blocks, bills still reference this user_id and will
    -- display "Deleted User" in the UI.
    UPDATE public.users
    SET display_name = 'Deleted User',
        avatar_path = NULL
    WHERE id = v_user_id;

    -- E. Delete auth record (prevents future login)
    -- Safe because we dropped the CASCADE FK in step 1 of this migration.
    DELETE FROM auth.users WHERE id = v_user_id;
END;
$$;
