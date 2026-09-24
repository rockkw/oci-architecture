-- Run as MAGNET, after 02 (model) and 03 (schema), and after the SQLite
-- data has been migrated (app-patch/migrate_sqlite_to_adb.py).

-- 1. Backfill embeddings for every row that doesn't have one yet. The
--    patched app fills title_vec itself on insert, so after this one-time
--    backfill new rows arrive with a vector already.
--    Syntax: VECTOR_EMBEDDING(<model> USING <expr> AS data) -- "data" is
--    the model's input name from the metadata in 02_load_onnx_model.sql.
UPDATE torrents
SET    title_vec = VECTOR_EMBEDDING(all_minilm_l12_v2 USING title AS data)
WHERE  title_vec IS NULL;
COMMIT;

-- 2. Vector index. HNSW (in-memory neighbor graph) is the faster search
--    structure; on Autonomous Database Serverless the vector pool it lives
--    in is managed automatically (it can't be sized by hand and grows when
--    an HNSW index is created). Rough memory: 1.3 x rows x 384 x 4 bytes,
--    so ~20 MB for 10,000 titles.
--    DISTANCE COSINE matches how MiniLM embeddings are meant to be
--    compared, and must match the metric used in queries for the optimizer
--    to use the index.
CREATE VECTOR INDEX torrents_title_hnsw
  ON torrents (title_vec)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95;

-- Alternative: IVF (neighbor partitions) lives on disk rather than in the
-- vector pool. Use it instead if the HNSW create fails for memory, or if
-- DML against an HNSW-indexed table turns out to be restricted in the
-- database version you get (unverified here for 26ai; the app inserts
-- continuously).
-- CREATE VECTOR INDEX torrents_title_ivf
--   ON torrents (title_vec)
--   ORGANIZATION NEIGHBOR PARTITIONS
--   DISTANCE COSINE
--   WITH TARGET ACCURACY 95;
