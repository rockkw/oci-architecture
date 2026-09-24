"""Capstone Phase 3: enrich MyMagnet results with LLM tags and a summary.

Object Storage (createobject) -> Events -> this Function -> vLLM on OKE
(Phase 4, OpenAI-compatible /v1/chat/completions behind an internal LB)
-> enrichment JSON written to the output bucket.

Configuration comes from the function's config map (Fn exposes each key as
an environment variable), so pointing the pipeline at the real model in
Phase 4 is a config change, not a new image:

  INPUT_BUCKET         only objects in this bucket are enriched
  OUTPUT_BUCKET        where enrichment JSON is written
  OUTPUT_PREFIX        key prefix in OUTPUT_BUCKET (default "enriched/")
  LLM_ENDPOINT         base URL of the vLLM server, e.g. http://10.0.2.50:8000
                       Empty -> deterministic placeholder tags, no network call.
  LLM_MODEL            model name vLLM serves (the --served-model-name)
  LLM_API_KEY_SECRET_OCID  Vault secret holding vLLM's --api-key. Sent as a
                       Bearer token. Empty -> no Authorization header.
  LLM_TIMEOUT_SECONDS  HTTP timeout for the model call (default 60)
  MAX_INPUT_CHARS      how much of the object is sent to the model (default 8000)
  ADB_ENABLED          "true" turns on the Phase 2 database hook (not built yet)

`oci` and `fdk` are imported lazily so the unit tests run on a laptop with
only the standard library installed.
"""

import hashlib
import io
import json
import os
import socket
import urllib.error
import urllib.request
from datetime import datetime, timezone

CHAT_PATH = "/v1/chat/completions"

SYSTEM_PROMPT = (
    "You label search results from a media-library app. Reply with ONLY a JSON "
    'object of the form {"tags": ["short", "lowercase", "tags"], "summary": '
    '"one or two sentences"}. Use at most 8 tags.'
)


def load_config(env=None):
    env = os.environ if env is None else env
    return {
        "input_bucket": env.get("INPUT_BUCKET", ""),
        "output_bucket": env.get("OUTPUT_BUCKET", ""),
        "output_prefix": env.get("OUTPUT_PREFIX", "enriched/"),
        "llm_endpoint": env.get("LLM_ENDPOINT", "").strip(),
        "llm_model": env.get("LLM_MODEL", "").strip(),
        "llm_api_key_secret_ocid": env.get("LLM_API_KEY_SECRET_OCID", "").strip(),
        "llm_timeout": float(env.get("LLM_TIMEOUT_SECONDS", "60")),
        "max_input_chars": int(env.get("MAX_INPUT_CHARS", "8000")),
        "adb_enabled": env.get("ADB_ENABLED", "false").lower() == "true",
    }


def handler(ctx, data: io.BytesIO = None):
    from fdk import response

    body = json.loads(data.getvalue())
    result = process_event(body, load_config())
    return response.Response(
        ctx,
        response_data=json.dumps(result),
        headers={"Content-Type": "application/json"},
    )


def parse_event(event_body):
    """Pull (namespace, bucket, object) out of a createobject CloudEvent."""
    data = event_body.get("data", {}) or {}
    details = data.get("additionalDetails", {}) or {}
    return details.get("namespace"), details.get("bucketName"), data.get("resourceName")


def process_event(event_body, cfg, os_client=None, http_open=None, secret_fetcher=None):
    namespace, bucket, object_name = parse_event(event_body)
    if not all([namespace, bucket, object_name]):
        return {"status": "skipped", "reason": "event payload missing bucket/namespace/object"}

    # The Events rule already filters on bucketName; this second check stops
    # a loop if someone points the rule at the whole compartment, since this
    # function's own writes would otherwise trigger it again.
    if cfg["input_bucket"] and bucket != cfg["input_bucket"]:
        return {"status": "skipped", "reason": f"bucket {bucket} is not the input bucket"}
    if bucket == cfg["output_bucket"] and object_name.startswith(cfg["output_prefix"]):
        return {"status": "skipped", "reason": "object is an enrichment output"}

    if os_client is None:
        os_client = _object_storage_client()

    raw = os_client.get_object(namespace, bucket, object_name).data.content
    text = raw.decode("utf-8", errors="replace")

    api_key = None
    if cfg["llm_endpoint"] and cfg["llm_api_key_secret_ocid"]:
        api_key = (secret_fetcher or _read_secret)(cfg["llm_api_key_secret_ocid"])

    enrichment = enrich(text, object_name, cfg, http_open=http_open, api_key=api_key)
    record = {
        "source": {"namespace": namespace, "bucket": bucket, "object": object_name},
        "content_sha256": hashlib.sha256(raw).hexdigest(),
        "enriched_at": datetime.now(timezone.utc).isoformat(),
        **enrichment,
    }

    output_key = f"{cfg['output_prefix']}{object_name}.enrichment.json"
    os_client.put_object(
        namespace,
        cfg["output_bucket"],
        output_key,
        json.dumps(record, indent=2).encode("utf-8"),
        content_type="application/json",
    )

    write_to_adb(record, cfg)

    return {"status": record["status"], "object": object_name, "output": output_key}


def enrich(text, object_name, cfg, http_open=None, api_key=None):
    """Return {status, model, tags, summary[, error]} for one object."""
    if not cfg["llm_endpoint"]:
        return placeholder_enrichment(text, object_name)

    try:
        content = call_llm(text[: cfg["max_input_chars"]], cfg, http_open=http_open, api_key=api_key)
    except (urllib.error.URLError, socket.timeout, TimeoutError, ConnectionError) as e:
        # Still write a record: a missing output object is harder to debug
        # than one that says the model was unreachable.
        return {"status": "llm_error", "model": cfg["llm_model"], "tags": [], "summary": "",
                "error": f"{type(e).__name__}: {e}"}
    except (ValueError, KeyError, IndexError) as e:
        return {"status": "llm_error", "model": cfg["llm_model"], "tags": [], "summary": "",
                "error": f"bad response from model: {e}"}

    tags, summary = parse_model_output(content)
    return {"status": "enriched", "model": cfg["llm_model"], "tags": tags, "summary": summary}


def placeholder_enrichment(text, object_name):
    """Deterministic stand-in used until Phase 4's GPU model exists.

    Same input -> same output, so tests and a re-upload can check it exactly.
    """
    ext = object_name.rsplit(".", 1)[-1].lower() if "." in object_name else "none"
    first_line = text.strip().splitlines()[0][:200] if text.strip() else ""
    return {
        "status": "placeholder",
        "model": "placeholder",
        "tags": ["placeholder", f"ext:{ext}"],
        "summary": first_line,
    }


def call_llm(text, cfg, http_open=None, api_key=None):
    """POST to vLLM's OpenAI-compatible chat endpoint; return the reply text.

    Standard library only (urllib) so the image carries no extra HTTP
    dependency. `timeout` covers connect and each socket read.
    """
    http_open = http_open or urllib.request.urlopen
    url = cfg["llm_endpoint"].rstrip("/")
    if not url.endswith(CHAT_PATH):
        url += CHAT_PATH

    payload = {
        "model": cfg["llm_model"],
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": text},
        ],
        "temperature": 0,
        "max_tokens": 300,
    }
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with http_open(req, timeout=cfg["llm_timeout"]) as resp:
        body = json.loads(resp.read().decode("utf-8"))
    return body["choices"][0]["message"]["content"]


def parse_model_output(content):
    """Parse the model's JSON reply; fall back to raw text if it isn't JSON."""
    cleaned = content.strip()
    # Small models often wrap JSON in a ```json fence despite being told not to.
    if cleaned.startswith("```"):
        cleaned = cleaned.strip("`")
        cleaned = cleaned[4:] if cleaned.lower().startswith("json") else cleaned
    try:
        parsed = json.loads(cleaned)
        tags = [str(t).lower() for t in parsed.get("tags", [])][:8]
        return tags, str(parsed.get("summary", ""))
    except (ValueError, AttributeError):
        return [], content.strip()[:1000]


# --- Phase 2 hook: Autonomous DB ------------------------------------------
# Phase 2 (Autonomous DB 23ai) is being built in parallel. When it exists,
# implement this with python-oracledb over the ADB private endpoint (thin
# mode, wallet or TLS from Vault), e.g. an UPDATE on the results table keyed
# by object name that sets TAGS/SUMMARY. Until then, Object Storage is the
# system of record and this is a no-op. Adding oracledb here also means
# adding it to requirements.txt and an IAM grant for the Vault secret.
def write_to_adb(record, cfg):
    if not cfg["adb_enabled"]:
        return False
    raise NotImplementedError("ADB write is a Phase 2 hook; set ADB_ENABLED=false until it exists")


def _object_storage_client():
    import oci

    # Resource principal: the function authenticates as itself, matched by
    # the dynamic group in main.tf. No keys in the image or config.
    signer = oci.auth.signers.get_resource_principals_signer()
    return oci.object_storage.ObjectStorageClient({}, signer=signer)


_SECRET_CACHE = {}


def _read_secret(secret_ocid):
    """Fetch vLLM's API key from Vault, cached for the life of the container.

    Phase 4 runs vLLM with --api-key, since anything in 10.0.2.0/24 can reach
    its internal LB. Keeping the key in Vault rather than in the function's
    config map keeps it out of `terraform plan` output and the Console.
    """
    if secret_ocid not in _SECRET_CACHE:
        import base64

        import oci

        signer = oci.auth.signers.get_resource_principals_signer()
        client = oci.secrets.SecretsClient({}, signer=signer)
        bundle = client.get_secret_bundle(secret_ocid).data
        _SECRET_CACHE[secret_ocid] = base64.b64decode(
            bundle.secret_bundle_content.content
        ).decode("utf-8").strip()
    return _SECRET_CACHE[secret_ocid]
