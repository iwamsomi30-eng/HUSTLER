-- MFUKO WA KANISA — peer-device sync migration
-- Run this once in the EXISTING Supabase project before testing the updated app.
-- It keeps every linked device as a full peer. Legacy viewer memberships remain valid.

DROP POLICY IF EXISTS sync_insert_editor ON public.sync_records;
CREATE POLICY sync_insert_editor ON public.sync_records FOR INSERT TO authenticated
WITH CHECK (
  public.is_church_member(church_id)
  AND public.church_role(church_id) IN ('admin','treasurer','editor','viewer')
  AND updated_by = auth.uid()
);

DROP POLICY IF EXISTS sync_update_editor ON public.sync_records;
CREATE POLICY sync_update_editor ON public.sync_records FOR UPDATE TO authenticated
USING (
  public.is_church_member(church_id)
  AND public.church_role(church_id) IN ('admin','treasurer','editor','viewer')
)
WITH CHECK (
  public.is_church_member(church_id)
  AND public.church_role(church_id) IN ('admin','treasurer','editor','viewer')
  AND updated_by = auth.uid()
);

CREATE OR REPLACE FUNCTION public.upsert_sync_record(
  p_church_id uuid,
  p_entity_type text,
  p_sync_id uuid,
  p_payload jsonb,
  p_updated_at timestamptz,
  p_deleted boolean,
  p_device_id text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  old_updated timestamptz;
  r text;
BEGIN
  IF NOT public.is_church_member(p_church_id) THEN
    RAISE EXCEPTION 'NO_ACCESS';
  END IF;

  r := public.church_role(p_church_id);
  IF r NOT IN ('admin','treasurer','editor','viewer') THEN
    RAISE EXCEPTION 'READ_ONLY';
  END IF;

  SELECT updated_at INTO old_updated
  FROM public.sync_records
  WHERE church_id=p_church_id
    AND entity_type=p_entity_type
    AND sync_id=p_sync_id;

  IF old_updated IS NOT NULL AND old_updated >= p_updated_at THEN
    RETURN false;
  END IF;

  INSERT INTO public.sync_records(
    church_id, entity_type, sync_id, payload, updated_at,
    deleted, device_id, updated_by
  )
  VALUES(
    p_church_id, p_entity_type, p_sync_id, p_payload, p_updated_at,
    p_deleted, p_device_id, auth.uid()
  )
  ON CONFLICT (church_id, entity_type, sync_id) DO UPDATE SET
    payload=excluded.payload,
    updated_at=excluded.updated_at,
    deleted=excluded.deleted,
    device_id=excluded.device_id,
    updated_by=excluded.updated_by;

  RETURN true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_sync_record(uuid,text,uuid,jsonb,timestamptz,boolean,text) TO authenticated;
