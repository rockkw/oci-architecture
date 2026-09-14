terraform {
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

resource "oci_functions_application" "lab_app" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-app"
  subnet_ids     = [var.subnet_ocid]
}

resource "oci_functions_function" "lab_func" {
  application_id     = oci_functions_application.lab_app.id
  display_name       = "lab-func"
  image              = var.function_image
  memory_in_mbs      = 128
  timeout_in_seconds = 30
}

resource "oci_apigateway_gateway" "lab_gw" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-gateway"
  endpoint_type  = "PUBLIC"
  subnet_id      = var.subnet_ocid
}

resource "oci_apigateway_deployment" "lab_deployment" {
  compartment_id = var.compartment_ocid
  gateway_id     = oci_apigateway_gateway.lab_gw.id
  display_name   = "lab-deployment"
  path_prefix    = "/lab"

  specification {
    routes {
      path    = "/hello"
      methods = ["GET"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.lab_func.id
      }
    }
  }
}
