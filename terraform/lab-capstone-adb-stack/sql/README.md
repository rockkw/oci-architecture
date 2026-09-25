# SQL for the MyMagnet Autonomous AI Database

Run these in order after `terraform apply`. The database has only a private
endpoint, so connect from inside the VCN: SQLcl on a MyMagnet instance, or a
Bastion port-forwarding session to `private_endpoint_ip:1522`.

| # | File | Run as | What it does |
|---|---|---|---|
| 1 | `01_create_app_user.sql` | ADMIN | Creates the `MAGNET` schema. Prompts for `&app_password`. |
| 2 | `02_load_onnx_model.sql` | ADMIN | Loads `all-MiniLM-L12-v2` as `MAGNET.ALL_MINILM_L12_V2`. Prompts for `&model_par_url`. |
| 3 | `03_schema.sql` | MAGNET | Creates the tables, translated from SQLite, plus the `title_vec VECTOR(384, FLOAT32)` column. |
| — | `app-patch/migrate_sqlite_to_adb.py` | MAGNET | One-time data copy. |
| 4 | `04_embeddings_and_index.sql` | MAGNET | Backfills embeddings and creates the HNSW vector index. |
| 5 | `05_similarity_query.sql` | MAGNET | Example similarity search. |
| opt | `select_ai_profile.sql` | ADMIN, then MAGNET | Phase 4: Select AI profile pointing at vLLM. |

## Step 2 prerequisites: getting the model into a bucket

`LOAD_ONNX_MODEL_CLOUD` reads a single `.onnx` object. Oracle publishes the
model as a zip, so it has to be unzipped and re-uploaded first:

```bash
# URL from Oracle's "Import Pretrained Models in ONNX Format" page (AI Vector Search guide)
curl -LO 'https://adwc4pm.objectstorage.us-ashburn-1.oci.customer-oci.com/p/TtH6hL2y25EypZ0-rrczRZ1aXp7v1ONbRBfCiT-BDBN8WLKQ3lgyW6RxCfIFLdA6/n/adwc4pm/b/OML-ai-models/o/all_MiniLM_L12_v2_augmented.zip'
unzip all_MiniLM_L12_v2_augmented.zip      # -> all_MiniLM_L12_v2.onnx

oci os object put --region us-phoenix-1 -bn mymagnet-onnx-models \
  --file all_MiniLM_L12_v2.onnx --name all_MiniLM_L12_v2.onnx

oci os preauth-request create --region us-phoenix-1 -bn mymagnet-onnx-models \
  --name onnx-load --access-type ObjectRead --object-name all_MiniLM_L12_v2.onnx \
  --time-expires "$(date -u -v+1d +%Y-%m-%dT%H:%M:%SZ)"
# PAR URL = https://objectstorage.us-phoenix-1.oraclecloud.com + the access-uri in the output
```

That Oracle download URL is itself a PAR, so it can be rotated. If it fails,
take the current link from the docs page. Checked 2026-09-25: the URL answers
(122,537,890 bytes, last modified 2025-10-30), and the zip's directory lists
`all_MiniLM_L12_v2.onnx`, `README-ALL_MINILM_L12_V2-augmented.txt` and
`LICENSE_ATTRIBUTION.txt`. The same `.onnx` name is in Oracle's
[SQL Quick Start](https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/sql-quick-start-using-vector-embedding-model-uploaded-database.html).
