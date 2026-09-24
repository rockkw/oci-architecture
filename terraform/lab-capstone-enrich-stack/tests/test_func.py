"""Unit tests for func.py. Run from the stack directory:

    python3 -m unittest discover -s tests -v

No OCI account, fdk or oci SDK needed: Object Storage and the LLM are fakes.
"""

import io
import json
import os
import socket
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import func  # noqa: E402

NS = "testns"


def event(bucket="mymagnet-results", obj="scan-2026-09-24.txt"):
    return {
        "eventType": "com.oraclecloud.objectstorage.createobject",
        "data": {
            "resourceName": obj,
            "additionalDetails": {"namespace": NS, "bucketName": bucket},
        },
    }


def config(**overrides):
    env = {
        "INPUT_BUCKET": "mymagnet-results",
        "OUTPUT_BUCKET": "mymagnet-enrichment",
        "OUTPUT_PREFIX": "enriched/",
        "LLM_ENDPOINT": "",
        "LLM_MODEL": "",
    }
    env.update(overrides)
    return func.load_config(env)


class _Resp:
    def __init__(self, content):
        self.data = type("D", (), {"content": content})()


class FakeObjectStorage:
    def __init__(self, objects):
        self.objects = objects
        self.puts = {}

    def get_object(self, namespace, bucket, name):
        return _Resp(self.objects[(bucket, name)])

    def put_object(self, namespace, bucket, name, body, content_type=None):
        self.puts[(bucket, name)] = json.loads(body.decode("utf-8"))


class FakeHTTP:
    """Stands in for urllib.request.urlopen."""

    def __init__(self, reply=None, exc=None):
        self.reply, self.exc, self.requests = reply, exc, []

    def __call__(self, req, timeout=None):
        self.requests.append((req, timeout))
        if self.exc:
            raise self.exc
        body = {"choices": [{"message": {"role": "assistant", "content": self.reply}}]}
        return _Ctx(io.BytesIO(json.dumps(body).encode()))


class _Ctx:
    def __init__(self, f):
        self.f = f

    def __enter__(self):
        return self.f

    def __exit__(self, *a):
        return False


CONTENT = b"Ubuntu 24.04 LTS desktop ISO\nseeders: 1200\n"


class PlaceholderPath(unittest.TestCase):
    def test_no_endpoint_writes_deterministic_placeholder(self):
        store = FakeObjectStorage({("mymagnet-results", "scan-2026-09-24.txt"): CONTENT})
        http = FakeHTTP(reply="should not be called")

        result = func.process_event(event(), config(), os_client=store, http_open=http)

        self.assertEqual(result["status"], "placeholder")
        self.assertEqual(http.requests, [], "placeholder path must not call the network")
        record = store.puts[("mymagnet-enrichment", "enriched/scan-2026-09-24.txt.enrichment.json")]
        self.assertEqual(record["tags"], ["placeholder", "ext:txt"])
        self.assertEqual(record["summary"], "Ubuntu 24.04 LTS desktop ISO")
        self.assertEqual(record["source"]["bucket"], "mymagnet-results")

        # Deterministic: a second run gives the same tags and summary.
        again = func.placeholder_enrichment(CONTENT.decode(), "scan-2026-09-24.txt")
        self.assertEqual((again["tags"], again["summary"]), (record["tags"], record["summary"]))

    def test_other_bucket_is_skipped(self):
        store = FakeObjectStorage({})
        result = func.process_event(event(bucket="mymagnet-backups"), config(), os_client=store)
        self.assertEqual(result["status"], "skipped")
        self.assertEqual(store.puts, {})

    def test_incomplete_event_is_skipped(self):
        result = func.process_event({"data": {}}, config(), os_client=FakeObjectStorage({}))
        self.assertEqual(result["status"], "skipped")


class LLMPath(unittest.TestCase):
    def cfg(self):
        return config(LLM_ENDPOINT="http://10.0.2.50:8000", LLM_MODEL="qwen2.5-7b",
                      LLM_TIMEOUT_SECONDS="5")

    def test_mocked_llm_reply_is_written(self):
        store = FakeObjectStorage({("mymagnet-results", "scan-2026-09-24.txt"): CONTENT})
        http = FakeHTTP(reply='```json\n{"tags": ["Linux", "iso"], "summary": "An Ubuntu ISO."}\n```')

        result = func.process_event(event(), self.cfg(), os_client=store, http_open=http)

        self.assertEqual(result["status"], "enriched")
        req, timeout = http.requests[0]
        self.assertEqual(req.full_url, "http://10.0.2.50:8000/v1/chat/completions")
        self.assertEqual(timeout, 5.0)
        sent = json.loads(req.data)
        self.assertEqual(sent["model"], "qwen2.5-7b")
        self.assertIn("Ubuntu 24.04", sent["messages"][1]["content"])

        record = store.puts[("mymagnet-enrichment", "enriched/scan-2026-09-24.txt.enrichment.json")]
        self.assertEqual(record["tags"], ["linux", "iso"])
        self.assertEqual(record["summary"], "An Ubuntu ISO.")
        self.assertEqual(record["model"], "qwen2.5-7b")

    def test_api_key_from_secret_is_sent_as_bearer(self):
        store = FakeObjectStorage({("mymagnet-results", "scan-2026-09-24.txt"): CONTENT})
        http = FakeHTTP(reply='{"tags": [], "summary": "x"}')
        cfg = config(LLM_ENDPOINT="http://10.0.2.50", LLM_MODEL="m",
                     LLM_API_KEY_SECRET_OCID="ocid1.vaultsecret.oc1.phx.test")
        seen = []

        func.process_event(event(), cfg, os_client=store, http_open=http,
                           secret_fetcher=lambda ocid: seen.append(ocid) or "s3cret")

        self.assertEqual(seen, ["ocid1.vaultsecret.oc1.phx.test"])
        self.assertEqual(http.requests[0][0].get_header("Authorization"), "Bearer s3cret")

    def test_timeout_still_writes_error_record(self):
        store = FakeObjectStorage({("mymagnet-results", "scan-2026-09-24.txt"): CONTENT})
        http = FakeHTTP(exc=socket.timeout("timed out"))

        result = func.process_event(event(), self.cfg(), os_client=store, http_open=http)

        self.assertEqual(result["status"], "llm_error")
        record = store.puts[("mymagnet-enrichment", "enriched/scan-2026-09-24.txt.enrichment.json")]
        self.assertIn("timed out", record["error"])

    def test_non_json_reply_falls_back_to_text(self):
        tags, summary = func.parse_model_output("Just some prose.")
        self.assertEqual((tags, summary), ([], "Just some prose."))


class ADBHook(unittest.TestCase):
    def test_hook_is_off_by_default(self):
        self.assertFalse(func.write_to_adb({}, config()))

    def test_hook_not_implemented_yet(self):
        with self.assertRaises(NotImplementedError):
            func.write_to_adb({}, config(ADB_ENABLED="true"))


if __name__ == "__main__":
    unittest.main()
