-- DROP SCHEMA core;

CREATE SCHEMA core AUTHORIZATION postgres;
-- core.concepts definition

-- Drop table

-- DROP TABLE core.concepts;

CREATE TABLE core.concepts (
	concept_id uuid DEFAULT gen_random_uuid() NOT NULL,
	concept_type text NOT NULL,
	canonical_code text NOT NULL,
	canonical_label text NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT concepts_concept_type_canonical_code_key UNIQUE (concept_type, canonical_code),
	CONSTRAINT concepts_pkey PRIMARY KEY (concept_id)
);

-- Table Triggers

create trigger trg_concepts_updated before
update
    on
    core.concepts for each row execute function core.set_updated_at();


-- core.embeddings definition

-- Drop table

-- DROP TABLE core.embeddings;

CREATE TABLE core.embeddings (
	entity_type text NOT NULL,
	entity_id uuid NOT NULL,
	embedding_type text NOT NULL,
	content_hash text NOT NULL,
	source_text text NULL,
	embedding extensions.vector NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT embeddings_pkey PRIMARY KEY (entity_type, entity_id, embedding_type)
);
CREATE INDEX embeddings_hnsw_idx ON core.embeddings USING hnsw (embedding vector_cosine_ops);


-- core.normalization_suggestions definition

-- Drop table

-- DROP TABLE core.normalization_suggestions;

CREATE TABLE core.normalization_suggestions (
	suggestion_id uuid DEFAULT gen_random_uuid() NOT NULL,
	concept_type text NOT NULL,
	raw_text text NOT NULL,
	proposed_code text NOT NULL,
	confidence numeric NULL,
	evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
	status text DEFAULT 'queued'::text NOT NULL,
	reviewed_by text NULL,
	reviewed_at timestamptz NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT normalization_suggestions_concept_type_raw_text_key UNIQUE (concept_type, raw_text),
	CONSTRAINT normalization_suggestions_pkey PRIMARY KEY (suggestion_id)
);
CREATE INDEX idx_norm_suggestions_status ON core.normalization_suggestions USING btree (status, created_at);


-- core.concept_aliases definition

-- Drop table

-- DROP TABLE core.concept_aliases;

CREATE TABLE core.concept_aliases (
	alias_id uuid DEFAULT gen_random_uuid() NOT NULL,
	concept_type text NOT NULL,
	alias_text text NOT NULL,
	concept_id uuid NOT NULL,
	"source" text NULL,
	confidence numeric NULL,
	notes text NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT concept_aliases_concept_type_alias_text_key UNIQUE (concept_type, alias_text),
	CONSTRAINT concept_aliases_pkey PRIMARY KEY (alias_id),
	CONSTRAINT concept_aliases_concept_id_fkey FOREIGN KEY (concept_id) REFERENCES core.concepts(concept_id)
);
CREATE INDEX idx_concept_aliases_concept ON core.concept_aliases USING btree (concept_id);
CREATE INDEX idx_concept_aliases_type_text ON core.concept_aliases USING btree (concept_type, alias_text);

-- Table Triggers

create trigger trg_concept_aliases_updated before
update
    on
    core.concept_aliases for each row execute function core.set_updated_at();



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

-- DROP SCHEMA delivery;

CREATE SCHEMA delivery AUTHORIZATION postgres;
-- delivery.candidates definition

-- Drop table

-- DROP TABLE delivery.candidates;

CREATE TABLE delivery.candidates (
	candidate_id uuid DEFAULT gen_random_uuid() NOT NULL,
	phone_e164 text NULL,
	email text NULL,
	full_name text NULL,
	status text DEFAULT 'active'::text NOT NULL,
	availability_status text DEFAULT 'unknown'::text NOT NULL,
	timezone text NULL,
	home_geo extensions.geography(point, 4326) NULL,
	facts jsonb DEFAULT '{}'::jsonb NOT NULL,
	last_inbound_at timestamptz NULL,
	last_outbound_at timestamptz NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT candidates_phone_e164_key UNIQUE (phone_e164),
	CONSTRAINT candidates_pkey PRIMARY KEY (candidate_id)
);
CREATE INDEX idx_candidates_email ON delivery.candidates USING btree (email);
CREATE INDEX idx_candidates_facts_gin ON delivery.candidates USING gin (facts);
CREATE INDEX idx_candidates_home_geo ON delivery.candidates USING gist (home_geo);
CREATE INDEX idx_candidates_status_avail ON delivery.candidates USING btree (status, availability_status);

-- Table Triggers

create trigger trg_candidates_updated before
update
    on
    delivery.candidates for each row execute function core.set_updated_at();


-- delivery.recruiters definition

-- Drop table

-- DROP TABLE delivery.recruiters;

CREATE TABLE delivery.recruiters (
	recruiter_id uuid DEFAULT gen_random_uuid() NOT NULL,
	email text NOT NULL,
	full_name text NULL,
	status text DEFAULT 'active'::text NOT NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT recruiters_email_key UNIQUE (email),
	CONSTRAINT recruiters_pkey PRIMARY KEY (recruiter_id)
);

-- Table Triggers

create trigger trg_recruiters_updated before
update
    on
    delivery.recruiters for each row execute function core.set_updated_at();


-- delivery.candidate_intakes definition

-- Drop table

-- DROP TABLE delivery.candidate_intakes;

CREATE TABLE delivery.candidate_intakes (
	intake_id uuid DEFAULT gen_random_uuid() NOT NULL,
	"source" text NOT NULL,
	source_message_id text NOT NULL,
	received_at timestamptz NULL,
	recruiter_email text NULL,
	recruiter_id uuid NULL,
	subject text NULL,
	body_text text NULL,
	body_html text NULL,
	raw_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
	status text DEFAULT 'received'::text NOT NULL,
	"error" text NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT candidate_intakes_pkey PRIMARY KEY (intake_id),
	CONSTRAINT candidate_intakes_source_source_message_id_key UNIQUE (source, source_message_id),
	CONSTRAINT candidate_intakes_recruiter_id_fkey FOREIGN KEY (recruiter_id) REFERENCES delivery.recruiters(recruiter_id)
);
CREATE INDEX idx_candidate_intakes_recruiter_time ON delivery.candidate_intakes USING btree (recruiter_id, created_at);
CREATE INDEX idx_candidate_intakes_status ON delivery.candidate_intakes USING btree (status);

-- Table Triggers

create trigger trg_candidate_intakes_updated before
update
    on
    delivery.candidate_intakes for each row execute function core.set_updated_at();


-- delivery.intake_candidate_links definition

-- Drop table

-- DROP TABLE delivery.intake_candidate_links;

CREATE TABLE delivery.intake_candidate_links (
	intake_id uuid NOT NULL,
	candidate_id uuid NOT NULL,
	match_type text NOT NULL,
	confidence numeric NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT intake_candidate_links_pkey PRIMARY KEY (intake_id),
	CONSTRAINT intake_candidate_links_candidate_id_fkey FOREIGN KEY (candidate_id) REFERENCES delivery.candidates(candidate_id),
	CONSTRAINT intake_candidate_links_intake_id_fkey FOREIGN KEY (intake_id) REFERENCES delivery.candidate_intakes(intake_id)
);
CREATE INDEX idx_intake_candidate_links_candidate ON delivery.intake_candidate_links USING btree (candidate_id);


-- delivery.artifacts definition

-- Drop table

-- DROP TABLE delivery.artifacts;

CREATE TABLE delivery.artifacts (
	artifact_id uuid DEFAULT gen_random_uuid() NOT NULL,
	intake_id uuid NOT NULL,
	artifact_type text NOT NULL,
	file_name text NULL,
	mime_type text NULL,
	storage_uri text NULL,
	sha256 text NULL,
	extracted_text text NULL,
	extracted_json jsonb DEFAULT '{}'::jsonb NOT NULL,
	status text DEFAULT 'registered'::text NOT NULL,
	"error" text NULL,
	created_at timestamptz DEFAULT now() NOT NULL,
	updated_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT artifacts_pkey PRIMARY KEY (artifact_id),
	CONSTRAINT artifacts_intake_id_fkey FOREIGN KEY (intake_id) REFERENCES delivery.candidate_intakes(intake_id)
);
CREATE INDEX idx_artifacts_intake ON delivery.artifacts USING btree (intake_id);
CREATE INDEX idx_artifacts_sha ON delivery.artifacts USING btree (sha256);
CREATE UNIQUE INDEX uniq_artifacts_intake_sha ON delivery.artifacts USING btree (intake_id, sha256);

-- Table Triggers

create trigger trg_artifacts_updated before
update
    on
    delivery.artifacts for each row execute function core.set_updated_at();



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