-- DROP FUNCTION core.fn_queue_normalization_suggestion(text, text, text, numeric, jsonb);

CREATE OR REPLACE FUNCTION core.fn_queue_normalization_suggestion(p_concept_type text, p_raw_text text, p_proposed_code text, p_confidence numeric, p_evidence jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO core.normalization_suggestions (
    concept_type, raw_text, proposed_code, confidence, evidence, status
  )
  VALUES (
    p_concept_type, p_raw_text, p_proposed_code, p_confidence, COALESCE(p_evidence,'{}'::jsonb), 'queued'
  )
  ON CONFLICT (concept_type, raw_text)
  DO UPDATE SET
    proposed_code = EXCLUDED.proposed_code,
    confidence = EXCLUDED.confidence,
    evidence = EXCLUDED.evidence;
END;
$function$
;

-- DROP FUNCTION core.fn_resolve_concept_code(text, text);

CREATE OR REPLACE FUNCTION core.fn_resolve_concept_code(p_concept_type text, p_raw_text text)
 RETURNS text
 LANGUAGE sql
AS $function$
  SELECT c.canonical_code
  FROM core.concept_aliases a
  JOIN core.concepts c ON c.concept_id = a.concept_id
  WHERE a.concept_type = p_concept_type
    AND lower(a.alias_text) = lower(trim(p_raw_text))
  LIMIT 1;
$function$
;

-- DROP FUNCTION core.fn_upsert_embedding(text, uuid, text, text, text, extensions.vector);

CREATE OR REPLACE FUNCTION core.fn_upsert_embedding(p_entity_type text, p_entity_id uuid, p_embedding_type text, p_content_hash text, p_source_text text, p_embedding vector)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO core.embeddings(entity_type, entity_id, embedding_type, content_hash, source_text, embedding)
  VALUES (p_entity_type, p_entity_id, p_embedding_type, p_content_hash, p_source_text, p_embedding)
  ON CONFLICT (entity_type, entity_id, embedding_type)
  DO UPDATE SET
    content_hash = EXCLUDED.content_hash,
    source_text  = EXCLUDED.source_text,
    embedding    = EXCLUDED.embedding,
    updated_at   = now();
END;
$function$
;

-- DROP FUNCTION core.set_updated_at();

CREATE OR REPLACE FUNCTION core.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$
;

-- DROP FUNCTION delivery.fn_claim_artifact_for_extraction(uuid);

CREATE OR REPLACE FUNCTION delivery.fn_claim_artifact_for_extraction(p_artifact_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_updated int;
BEGIN
  UPDATE delivery.artifacts
  SET status = 'extracting', error = NULL, updated_at = now()
  WHERE artifact_id = p_artifact_id
    AND status = 'registered';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RETURN (v_updated = 1);
END;
$function$
;

-- DROP FUNCTION delivery.fn_ensure_recruiter(text, text);

CREATE OR REPLACE FUNCTION delivery.fn_ensure_recruiter(p_email text, p_full_name text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO delivery.recruiters(email, full_name)
  VALUES (p_email, p_full_name)
  ON CONFLICT (email)
  DO UPDATE SET full_name = COALESCE(delivery.recruiters.full_name, EXCLUDED.full_name)
  RETURNING recruiter_id INTO v_id;

  RETURN v_id;
END;
$function$
;

-- DROP FUNCTION delivery.fn_fail_artifact(uuid, text);

CREATE OR REPLACE FUNCTION delivery.fn_fail_artifact(p_artifact_id uuid, p_error text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE delivery.artifacts
  SET status = 'failed', error = p_error
  WHERE artifact_id = p_artifact_id;
END;
$function$
;

-- DROP FUNCTION delivery.fn_finalize_artifact_extraction(uuid, text, jsonb);

CREATE OR REPLACE FUNCTION delivery.fn_finalize_artifact_extraction(p_artifact_id uuid, p_extracted_text text, p_extracted_json jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE delivery.artifacts
  SET
    extracted_text = p_extracted_text,
    extracted_json = COALESCE(p_extracted_json, '{}'::jsonb),
    status = 'extracted',
    error = NULL
  WHERE artifact_id = p_artifact_id;
END;
$function$
;

-- DROP FUNCTION delivery.fn_ingest_intake(text, text, timestamptz, text, text, text, text, jsonb);

CREATE OR REPLACE FUNCTION delivery.fn_ingest_intake(p_source text, p_source_message_id text, p_received_at timestamp with time zone, p_recruiter_email text, p_subject text, p_body_text text, p_body_html text, p_raw_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_intake_id uuid;
BEGIN
  INSERT INTO delivery.candidate_intakes (
    source, source_message_id, received_at,
    recruiter_email, subject, body_text, body_html, raw_payload,
    status
  )
  VALUES (
    p_source, p_source_message_id, p_received_at,
    p_recruiter_email, p_subject, p_body_text, p_body_html, p_raw_payload,
    'received'
  )
  ON CONFLICT (source, source_message_id)
  DO UPDATE SET updated_at = now()
  RETURNING intake_id INTO v_intake_id;

  RETURN v_intake_id;
END;
$function$
;

-- DROP FUNCTION delivery.fn_link_intake_candidate(uuid, uuid, text, numeric);

CREATE OR REPLACE FUNCTION delivery.fn_link_intake_candidate(p_intake_id uuid, p_candidate_id uuid, p_match_type text, p_confidence numeric)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO delivery.intake_candidate_links(intake_id, candidate_id, match_type, confidence)
  VALUES (p_intake_id, p_candidate_id, p_match_type, p_confidence)
  ON CONFLICT (intake_id)
  DO UPDATE SET
    candidate_id = EXCLUDED.candidate_id,
    match_type   = EXCLUDED.match_type,
    confidence   = EXCLUDED.confidence;
END;
$function$
;

-- DROP FUNCTION delivery.fn_list_registered_artifacts_backfill(int4);

CREATE OR REPLACE FUNCTION delivery.fn_list_registered_artifacts_backfill(p_limit integer DEFAULT 200)
 RETURNS TABLE(artifact_id uuid, storage_uri text, mime_type text, file_name text, artifact_type text)
 LANGUAGE sql
AS $function$
  SELECT a.artifact_id, a.storage_uri, a.mime_type, a.file_name, a.artifact_type
  FROM delivery.artifacts a
  JOIN delivery.candidate_intakes i ON i.intake_id = a.intake_id
  WHERE a.status = 'registered'
    AND i.source = 'import'
  ORDER BY a.created_at
  LIMIT p_limit;
$function$
;

-- DROP FUNCTION delivery.fn_list_registered_artifacts_live(int4);

CREATE OR REPLACE FUNCTION delivery.fn_list_registered_artifacts_live(p_limit integer DEFAULT 50)
 RETURNS TABLE(artifact_id uuid, storage_uri text, mime_type text, file_name text, artifact_type text)
 LANGUAGE sql
AS $function$
  SELECT a.artifact_id, a.storage_uri, a.mime_type, a.file_name, a.artifact_type
  FROM delivery.artifacts a
  JOIN delivery.candidate_intakes i ON i.intake_id = a.intake_id
  WHERE a.status = 'registered'
    AND COALESCE(i.source,'') <> 'import'
  ORDER BY a.created_at
  LIMIT p_limit;
$function$
;

-- DROP FUNCTION delivery.fn_register_artifact(uuid, text, text, text, text, text);

CREATE OR REPLACE FUNCTION delivery.fn_register_artifact(p_intake_id uuid, p_artifact_type text, p_file_name text, p_mime_type text, p_storage_uri text, p_sha256 text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_artifact_id uuid;
BEGIN
  INSERT INTO delivery.artifacts (
    intake_id, artifact_type, file_name, mime_type, storage_uri, sha256, status
  )
  VALUES (
    p_intake_id, p_artifact_type, p_file_name, p_mime_type, p_storage_uri, p_sha256, 'registered'
  )
  ON CONFLICT (intake_id, sha256)
  DO UPDATE SET
    storage_uri = COALESCE(EXCLUDED.storage_uri, delivery.artifacts.storage_uri),
    updated_at = now()
  RETURNING artifact_id INTO v_artifact_id;

  RETURN v_artifact_id;
END;
$function$
;

-- DROP FUNCTION delivery.fn_upsert_candidate(text, text, text, text, extensions.geography, jsonb);

CREATE OR REPLACE FUNCTION delivery.fn_upsert_candidate(p_phone_e164 text, p_email text, p_full_name text, p_timezone text, p_home_geo geography, p_facts_patch jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_candidate_id uuid;
BEGIN
  SELECT candidate_id INTO v_candidate_id
  FROM delivery.candidates
  WHERE (p_phone_e164 IS NOT NULL AND phone_e164 = p_phone_e164)
     OR (p_email IS NOT NULL AND email = p_email)
  ORDER BY created_at
  LIMIT 1;

  IF v_candidate_id IS NULL THEN
    INSERT INTO delivery.candidates (
      phone_e164, email, full_name, timezone, home_geo, facts, last_inbound_at
    )
    VALUES (
      p_phone_e164, p_email, p_full_name, p_timezone, p_home_geo, COALESCE(p_facts_patch,'{}'::jsonb), now()
    )
    RETURNING candidate_id INTO v_candidate_id;
  ELSE
    UPDATE delivery.candidates
    SET
      phone_e164      = COALESCE(phone_e164, p_phone_e164),
      email           = COALESCE(email, p_email),
      full_name       = COALESCE(p_full_name, full_name),
      timezone        = COALESCE(p_timezone, timezone),
      home_geo        = COALESCE(p_home_geo, home_geo),
      facts           = facts || COALESCE(p_facts_patch,'{}'::jsonb),
      last_inbound_at = now()
    WHERE candidate_id = v_candidate_id;
  END IF;

  RETURN v_candidate_id;
END;
$function$
;

create trigger trg_artifacts_updated before
update
    on
    delivery.artifacts for each row execute function core.set_updated_at();