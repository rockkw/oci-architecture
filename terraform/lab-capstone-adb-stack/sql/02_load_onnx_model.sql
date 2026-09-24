-- Run as ADMIN (or MAGNET). Loads Oracle's prebuilt all-MiniLM-L12-v2
-- embedding model (384 dimensions) into the MAGNET schema, so embeddings are
-- computed inside the database with VECTOR_EMBEDDING() and no external
-- model or API is needed.
--
-- Before running (see README.md, step 2):
--   1. Download Oracle's augmented model zip (link from the "Import
--      Pretrained Models in ONNX Format" page of the AI Vector Search
--      guide, file all_MiniLM_L12_v2_augmented.zip, ~117 MB) and unzip it.
--      It contains all_MiniLM_L12_v2.onnx.
--   2. Upload all_MiniLM_L12_v2.onnx to the mymagnet-onnx-models bucket.
--   3. Create a read-only pre-authenticated request (PAR) on that object.
--      Pass the PAR URL as &model_par_url.
--
-- credential => NULL is Oracle's documented form for a PAR URI
-- (LOAD_ONNX_MODEL_CLOUD docs: "When the value of uri is a pre-authenticated
-- URI, the credential argument should be passed as NULL").
--
-- The metadata below is the procedure's documented default. Oracle's
-- prebuilt model was prepared with the OML4Py utility, whose models "have
-- default input and output names and can be loaded without JSON
-- parameters"; it's written out here so the contract is visible.

BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD(
    model_name => 'MAGNET.ALL_MINILM_L12_V2',
    credential => NULL,
    uri        => '&model_par_url',
    metadata   => JSON('{"function" : "embedding", "embeddingOutput" : "embedding", "input": {"input": ["DATA"]}}')
  );
END;
/

-- Check: the model exists and returns a 384-dimension vector.
SELECT owner, model_name, mining_function, algorithm
FROM   all_mining_models
WHERE  model_name = 'ALL_MINILM_L12_V2';

SELECT VECTOR_DIMENSION_COUNT(
         VECTOR_EMBEDDING(magnet.all_minilm_l12_v2 USING 'Ubuntu 24.04 server ISO' AS data)
       ) AS dims
FROM   dual;
-- Expect: DIMS = 384

-- The PAR can be deleted once the model is loaded; the model is now a
-- database object and no longer reads the bucket.
