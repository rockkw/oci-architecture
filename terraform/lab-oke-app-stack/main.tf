terraform {
  required_version = ">= 1.5.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  region = var.region
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

# cluster_id isn't referenced below — it's a required input purely to encode this
# stack's dependency on lab-oke-stack existing first, since there's a cluster to push
# images to and deploy against before this repository is useful.
resource "oci_artifacts_container_repository" "lab_app_repo" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-app"
  is_public      = false
}
