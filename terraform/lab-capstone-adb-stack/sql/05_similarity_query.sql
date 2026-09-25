-- Run as MAGNET. "Find titles like this phrase", ranked by cosine distance
-- between the phrase's embedding and each title's embedding.
-- Smaller distance = more similar. Both embeddings come from the same
-- in-database model, so nothing leaves the database.

DEFINE q = 'ubuntu server installer'

SELECT t.title,
       t.best_seeds,
       ROUND(VECTOR_DISTANCE(
               t.title_vec,
               VECTOR_EMBEDDING(all_minilm_l12_v2 USING '&q' AS data),
               COSINE), 4) AS distance
FROM   torrents t
WHERE  t.title_vec IS NOT NULL
ORDER  BY VECTOR_DISTANCE(
            t.title_vec,
            VECTOR_EMBEDDING(all_minilm_l12_v2 USING '&q' AS data),
            COSINE)
FETCH  APPROX FIRST 10 ROWS ONLY;

-- FETCH APPROX lets the optimizer use torrents_title_hnsw (the metric,
-- COSINE, matches the index). APPROXIMATE is the default when neither
-- keyword is given, so to compare against an exact scan use FETCH EXACT
-- FIRST (both verified 2026-09-25 in the 26ai SQL Reference, SELECT,
-- row_limiting_clause). rowcount may be "an expression that evaluates to a
-- numeric value", so the app's FETCH APPROX FIRST :n bind is valid.
--
-- Check the plan uses the index:
-- EXPLAIN PLAN FOR <query above>;
-- SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Look for a VECTOR INDEX ... SCAN step (exact operation name unverified).
--
-- Same query from Python (what the patched webserver.py /api/similar runs):
--   SELECT ... VECTOR_EMBEDDING(all_minilm_l12_v2 USING :1 AS data) ...
