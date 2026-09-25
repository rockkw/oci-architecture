-- Run as ADMIN. Creates the MAGNET schema the app connects as.
--
-- Password: the mymagnet-adb-app-password Vault secret (Terraform output
-- app_secret_id). Fetch it with:
--   oci secrets secret-bundle get --secret-id <app_secret_id> \
--     --query 'data."secret-bundle-content".content' --raw-output | base64 -d
-- SQL*Plus / SQLcl prompt for &app_password; don't hard-code it here.

CREATE USER magnet IDENTIFIED BY "&app_password"
  DEFAULT TABLESPACE data
  QUOTA UNLIMITED ON data;

-- DB_DEVELOPER_ROLE is the 23ai+ bundle for application schemas (CREATE
-- SESSION, TABLE, SEQUENCE, VIEW, PROCEDURE, ...). It already includes
-- CREATE MINING MODEL (verified 2026-09-25 in the 26ai Security Guide's
-- DB_DEVELOPER_ROLE privilege list), so the explicit grant below is
-- redundant. It's kept so the need is visible: the ONNX model is a
-- mining-model object in this schema.
GRANT DB_DEVELOPER_ROLE TO magnet;
GRANT CREATE MINING MODEL TO magnet;

-- Only needed for sql/select_ai_profile.sql (optional, Phase 4).
-- GRANT EXECUTE ON DBMS_CLOUD_AI TO magnet;
-- GRANT EXECUTE ON DBMS_CLOUD TO magnet;
