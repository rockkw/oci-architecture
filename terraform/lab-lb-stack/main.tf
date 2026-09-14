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

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance_configuration" "web_config" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-web-instance-config"

  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = var.compartment_ocid
      shape          = "VM.Standard.A1.Flex"

      shape_config {
        ocpus         = 1
        memory_in_gbs = 6
      }

      source_details {
        source_type = "image"
        image_id    = data.oci_core_images.oracle_linux.images[0].id
      }

      create_vnic_details {
        subnet_id        = var.subnet_id
        assign_public_ip = true
        nsg_ids          = [var.nsg_id]
      }

      metadata = {
        ssh_authorized_keys = var.ssh_public_key
      }
    }
  }
}

resource "oci_core_instance_pool" "web_pool" {
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.web_config.id
  display_name              = "lab-web-pool"
  size                      = var.pool_size

  placement_configurations {
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    primary_subnet_id   = var.subnet_id
  }

  load_balancers {
    load_balancer_id = oci_load_balancer_load_balancer.lab_lb.id
    backend_set_name = oci_load_balancer_backend_set.web_backend_set.name
    port             = 80
    vnic_selection   = "PrimaryVnic"
  }
}

resource "oci_load_balancer_load_balancer" "lab_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-lb"
  shape          = "flexible"
  subnet_ids     = [var.subnet_id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }
}

resource "oci_load_balancer_backend_set" "web_backend_set" {
  name             = "web-backend-set"
  load_balancer_id = oci_load_balancer_load_balancer.lab_lb.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    port     = 80
    url_path = "/"
  }
}

resource "oci_load_balancer_listener" "web_listener" {
  name                     = "web-listener"
  load_balancer_id         = oci_load_balancer_load_balancer.lab_lb.id
  default_backend_set_name = oci_load_balancer_backend_set.web_backend_set.name
  port                     = 80
  protocol                 = "HTTP"
}
