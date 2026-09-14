provider "oci" {
  # Auth comes from ~/.oci/config or OCI_CLI_* environment variables — see
  # LABS.md's setup section. Do not hardcode tenancy_ocid, user_ocid,
  # fingerprint, or private_key_path here; each lab stack sets its own
  # provider block and reads region from a variable.
  region = "us-ashburn-1"
}
