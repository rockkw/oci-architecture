-- OPTIONAL, Phase 4. Not needed for vector search (01-05 work without it).
-- Points Select AI (DBMS_CLOUD_AI) at the self-hosted vLLM server from
-- lab-capstone-vllm-stack instead of a hosted LLM, since the capstone doesn't use
-- OCI Generative AI.
--
-- Placeholder: &vllm_host is lab-capstone-vllm-stack's internal LB private
-- IP (listener on port 80, var.listener_port). It doesn't exist until
-- Phase 4 is applied. That LB's NSG already admits 10.0.2.0/24, which
-- includes this ADB's private endpoint IP.
--
-- UNVERIFIED: whether Select AI requires HTTPS for provider_endpoint. A blog
-- hints it does; Oracle's UTL_HTTP/private-endpoint page shows an 'http'
-- ACL privilege but doesn't say either way for DBMS_CLOUD_AI. If a plain
-- http:// endpoint is rejected, put TLS on the internal LB (an OCI
-- Certificates cert, like Phase 1's) and use https://.

-- 1. Run as ADMIN: send outbound connections through the private endpoint,
--    so the database can reach a host inside the VCN. PRIVATE_ENDPOINT (not
--    ENFORCE_PRIVATE_ENDPOINT) leaves DBMS_CLOUD/Object Storage traffic on
--    Oracle's service network, so the ONNX model load in 02 keeps working.
--    The ADB NSG (mymagnet-adb-nsg) then also needs an EGRESS rule to the
--    vLLM LB's IP on port 80; it has none today (add it to
--    lab-capstone-adb-stack/main.tf when Phase 4 is live).
ALTER DATABASE PROPERTY SET ROUTE_OUTBOUND_CONNECTIONS = 'PRIVATE_ENDPOINT';

SELECT property_value FROM database_properties
WHERE  property_name = 'ROUTE_OUTBOUND_CONNECTIONS';

-- 2. Run as ADMIN: allow MAGNET to connect to that host. private_target =>
--    TRUE marks it as a private-endpoint target. Oracle's docs say it's
--    not required once ROUTE_OUTBOUND_CONNECTIONS is set; kept for clarity.
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => '&vllm_host',
    ace  => xs$ace_type(privilege_list => xs$name_list('http'),
                        principal_name => 'MAGNET',
                        principal_type => xs_acl.ptype_db),
    private_target => TRUE);
END;
/

-- 3. Run as MAGNET (needs EXECUTE on DBMS_CLOUD and DBMS_CLOUD_AI; see the
--    commented grants in 01). OpenAI-compatible providers authenticate
--    with a bearer key stored as a credential. lab-capstone-vllm-stack
--    starts vLLM with --api-key, so &vllm_api_key is that same value (the
--    vllm-api-key Kubernetes Secret).
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'VLLM_CRED',
    username        => 'OPENAI',
    password        => '&vllm_api_key');
END;
/

-- 4. The profile. provider_endpoint is the base URL WITHOUT
--    /v1/chat/completions (Oracle's Fireworks example strips that suffix).
--    model must match the name vLLM serves (--served-model-name; Phase 4
--    uses qwen2.5-7b-instruct).
--    Unverified: Oracle's page says to use provider_endpoint "instead of
--    the provider parameter", but a summary of its example also showed
--    "provider": "openai" next to it. If CREATE_PROFILE rejects this, add
--    "provider": "openai".
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'MAGNET_VLLM',
    attributes   => '{
      "provider_endpoint": "http://&vllm_host",
      "credential_name":   "VLLM_CRED",
      "model":             "&vllm_model",
      "object_list":       [{"owner": "MAGNET", "name": "TORRENTS"},
                            {"owner": "MAGNET", "name": "SEARCH_TERMS"},
                            {"owner": "MAGNET", "name": "SEARCHES"}]
    }');
END;
/

-- 5. Try it.
EXEC DBMS_CLOUD_AI.SET_PROFILE('MAGNET_VLLM');
SELECT AI showsql how many torrents have more than 100 seeds;
