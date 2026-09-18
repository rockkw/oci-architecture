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

# --- Networking: one Consumer VCN, five subnets, matching the MyLearn diagram exactly ---
# CONSUMER VCN 10.0.0.0/16:
#   APPLICATION-SUBNET        10.0.200.0/24  -- Web Servers
#   WEB-LB-SUBNET             10.0.30.0/24   -- WEB-LB + VTAP Source
#   FIREWALL-SUBNET           10.0.40.0/24   -- Network Firewall (receives BOTH in-line and out-of-band flows)
#   VTAP-TARGET-NLB-SUBNET    10.0.50.0/24   -- VTAP-TARGET-NETWORK LB
#   NETWORK-ANALYTICS-SUBNET  10.0.100.0/24  -- Wireshark

resource "oci_core_vcn" "consumer_vcn" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "consumer-vcn"
  dns_label      = "consumervcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  display_name   = "lab-fw-igw"
  enabled        = true
}

# --- Route tables ---
# Public route table: default route out via IGW. Used by the App and WEB-LB
# subnets for their own internet-facing needs (App subnet's egress; WEB-LB
# subnet is where public traffic first lands after the firewall).
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  display_name   = "lab-fw-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Firewall subnet route table: the firewall's own return path to the internet
# (Layer 2's "Firewall Subnet Route Table: 0.0.0.0/0 -> IGW" from Note 5).
resource "oci_core_route_table" "firewall_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  display_name   = "lab-fw-firewall-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# The critical steering rule for the OUT-OF-BAND flow: mirrored/VXLAN-
# encapsulated traffic destined for the VTAP-Target-NLB subnet must be routed
# to the firewall's private IP first, not straight to its destination -- this
# is the diagram's own route table entry (step 3): "Destination: 10.0.50.0/24,
# Target Type: Private IP, Target: 10.0.40.x (FW)". Attached to the WEB-LB
# subnet's route table, since that's where the VTAP-mirrored traffic
# originates from (the VTAP Source sits on the WEB-LB).
resource "oci_core_route_table" "web_lb_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  display_name   = "lab-fw-web-lb-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }

  route_rules {
    destination = "10.0.50.0/24"
    # Route tables do NOT accept a Network Firewall's OCID directly --
    # network_entity_id only accepts gateway/private-IP-shaped OCIDs
    # (confirmed against the provider's own route_table docs: valid targets
    # are DRG/IGW/NAT/SGW/LPG/Private IP, no "Network Firewall" target type).
    # oci_network_firewall_network_firewall exports ipv4address as a plain
    # string, not a private-IP OCID -- OCI auto-creates a private IP object
    # for the firewall when it's provisioned into its subnet, looked up here
    # via data.oci_core_private_ips rather than created as a new resource.
    network_entity_id = data.oci_core_private_ips.firewall_private_ip.private_ips[0].id
  }
}

data "oci_core_private_ips" "firewall_private_ip" {
  ip_address = oci_network_firewall_network_firewall.lab_firewall.ipv4address
  subnet_id  = oci_core_subnet.firewall_subnet.id
}

# --- Subnets ---

resource "oci_core_subnet" "application_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  cidr_block     = "10.0.200.0/24"
  display_name   = "application-subnet"
  dns_label      = "appsub"
  route_table_id = oci_core_route_table.public_rt.id
}

resource "oci_core_subnet" "web_lb_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  cidr_block     = "10.0.30.0/24"
  display_name   = "web-lb-subnet"
  dns_label      = "weblbsub"
  route_table_id = oci_core_route_table.web_lb_rt.id
}

resource "oci_core_subnet" "firewall_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  cidr_block     = "10.0.40.0/24"
  display_name   = "firewall-subnet"
  dns_label      = "fwsub"
  route_table_id = oci_core_route_table.firewall_rt.id
}

resource "oci_core_subnet" "vtap_target_nlb_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  cidr_block     = "10.0.50.0/24"
  display_name   = "vtap-target-nlb-subnet"
  dns_label      = "vtaptgtsub"
  route_table_id = oci_core_route_table.public_rt.id
}

resource "oci_core_subnet" "network_analytics_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.consumer_vcn.id
  cidr_block     = "10.0.100.0/24"
  display_name   = "network-analytics-subnet"
  dns_label      = "netanalysub"
  route_table_id = oci_core_route_table.public_rt.id
}

# --- Compute: web tier ---

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

resource "oci_core_instance" "web_server_1" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "web-server-1"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.application_subnet.id
    assign_public_ip = false
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

resource "oci_core_instance" "web_server_2" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "web-server-2"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.application_subnet.id
    assign_public_ip = false
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

# --- WEB-LB: the in-line application flow's public entry point ---

resource "oci_load_balancer_load_balancer" "web_lb" {
  compartment_id = var.compartment_ocid
  display_name   = "web-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.web_lb_subnet.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }
}

resource "oci_load_balancer_backend_set" "web_backend_set" {
  name             = "web-backend-set"
  load_balancer_id = oci_load_balancer_load_balancer.web_lb.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol = "HTTP"
    port     = 80
    url_path = "/"
  }
}

resource "oci_load_balancer_backend" "web_backend_1" {
  load_balancer_id = oci_load_balancer_load_balancer.web_lb.id
  backendset_name  = oci_load_balancer_backend_set.web_backend_set.name
  ip_address       = oci_core_instance.web_server_1.private_ip
  port             = 80
}

resource "oci_load_balancer_backend" "web_backend_2" {
  load_balancer_id = oci_load_balancer_load_balancer.web_lb.id
  backendset_name  = oci_load_balancer_backend_set.web_backend_set.name
  ip_address       = oci_core_instance.web_server_2.private_ip
  port             = 80
}

resource "oci_load_balancer_listener" "web_listener" {
  name                     = "web-listener"
  load_balancer_id         = oci_load_balancer_load_balancer.web_lb.id
  default_backend_set_name = oci_load_balancer_backend_set.web_backend_set.name
  port                     = 80
  protocol                 = "HTTP"
}

# --- Network Firewall Policy ---
# Like ZPR's namespace/attribute split, a Network Firewall Policy is NOT a
# monolithic resource: every rule/list type (security rules, tunnel
# inspection rules, address/service/URL lists) is its own standalone
# resource referencing this policy's ID, not an inline block.
resource "oci_network_firewall_network_firewall_policy" "lab_fw_policy" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-fw-policy"
}

# Address list: the Web Server tier, referenced by the security rule below.
resource "oci_network_firewall_network_firewall_policy_address_list" "app_servers" {
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  name                       = "app-servers"
  type                       = "IP"
  addresses                  = ["10.0.200.0/24"]
}

# Service list: HTTP/443 per Note 5's Layer 2 example rule
# ("Source: LB | Dest: App | Service: HTTPS | Action: Intrusion Prevention").
resource "oci_network_firewall_network_firewall_policy_service" "https_service" {
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  name                       = "https-443"
  port_ranges {
    minimum_port = 443
    maximum_port = 443
  }
  type = "TCP_SERVICE"
}

resource "oci_network_firewall_network_firewall_policy_service_list" "https_service_list" {
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  name                       = "https-service-list"
  services                   = [oci_network_firewall_network_firewall_policy_service.https_service.name]
}

# The IN-LINE prevention rule: WEB-LB -> App tier, HTTPS, allowed and
# inspected. This is the security rule Stage 2 of the four-stage pipeline
# (Note 5) actually evaluates for the red "In-Line Application Flow" path.
resource "oci_network_firewall_network_firewall_policy_security_rule" "allow_lb_to_app_https" {
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  name                       = "allow-lb-to-app-https"
  action                     = "ALLOW"
  # condition's list fields (destination_address, service, source_address,
  # application, url) are plain list(string) of names -- confirmed against
  # the provider's own example .tf, which passes resource .name references
  # directly, no jsonencode.
  condition {
    destination_address = [oci_network_firewall_network_firewall_policy_address_list.app_servers.name]
    service             = [oci_network_firewall_network_firewall_policy_service_list.https_service_list.name]
  }
}

# The OUT-OF-BAND tunnel inspection rule -- Stage 3 of the four-stage
# pipeline. Inspects VXLAN-encapsulated traffic mirrored from the VTAP
# Source (WEB-LB) and steered here by the web_lb_rt route table entry above.
resource "oci_network_firewall_network_firewall_policy_tunnel_inspection_rule" "inspect_vxlan_mirror" {
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  name                       = "inspect-vxlan-mirror"
  # protocol is REQUIRED and TOP-LEVEL on this resource (not inside
  # condition) -- confirmed against the provider's own doc/example; "VXLAN"
  # is currently the only valid value.
  protocol = "VXLAN"
  # Confirmed valid action values: INSPECT (no logging) or
  # INSPECT_AND_CAPTURE_LOG (matches the Console's "Inspect and capture log"
  # dropdown option) -- capturing logs here since this rule's whole purpose
  # is offline analysis via the Wireshark/NLB chain.
  action = "INSPECT_AND_CAPTURE_LOG"
  # condition here only accepts destination_address/source_address
  # (list(string) of address-list names) -- no protocol field inside it.
  condition {
    destination_address = []
    source_address      = []
  }
}

# --- Network Firewall itself ---
# Sits in FIREWALL-SUBNET (10.0.40.0/24), receiving both the in-line
# application flow and the out-of-band tunnel inspection flow -- exactly
# the diagram's single firewall box serving both paths.
resource "oci_network_firewall_network_firewall" "lab_firewall" {
  compartment_id             = var.compartment_ocid
  display_name               = "lab-network-firewall"
  network_firewall_policy_id = oci_network_firewall_network_firewall_policy.lab_fw_policy.id
  subnet_id                  = oci_core_subnet.firewall_subnet.id
  availability_domain        = data.oci_identity_availability_domains.ads.availability_domains[0].name

  nat_configuration {
    must_enable_private_nat = false
  }
}

# --- VTAP: mirrors live traffic from the WEB-LB (the VTAP Source in the diagram) ---

# Capture filter: which traffic gets mirrored. Rules are inline blocks on
# this resource, not a separate resource type -- captures all TCP ingress
# to the WEB-LB, matching "VTAP mirrors live traffic from the Web Load
# Balancer" (Note 5's Cross-VCN/Tunnel Inspection section).
resource "oci_core_capture_filter" "vtap_capture_filter" {
  compartment_id = var.compartment_ocid
  display_name   = "lab-vtap-capture-filter"
  filter_type    = "VTAP"

  vtap_capture_filter_rules {
    traffic_direction = "INGRESS"
    rule_action       = "INCLUDE"
    protocol          = "6" # TCP
  }
}

# VTAP-TARGET-NETWORK LB: the mirrored-traffic destination (step 6 in the
# diagram: "Traffic is routed to the NLB (VTAP Target)").
resource "oci_network_load_balancer_network_load_balancer" "vtap_target_nlb" {
  compartment_id = var.compartment_ocid
  display_name   = "vtap-target-network-lb"
  subnet_id      = oci_core_subnet.vtap_target_nlb_subnet.id
}

resource "oci_network_load_balancer_backend_set" "vtap_target_backend_set" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.vtap_target_nlb.id
  name                     = "vtap-target-backend-set"
  policy                   = "FIVE_TUPLE"

  health_checker {
    protocol = "TCP"
    port     = 4789 # standard VXLAN port
  }
}

resource "oci_network_load_balancer_backend" "vtap_target_backend" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.vtap_target_nlb.id
  backend_set_name         = oci_network_load_balancer_backend_set.vtap_target_backend_set.name
  target_id                = oci_core_instance.wireshark_analytics.id
  port                     = 4789
}

# The VTAP itself: source = WEB-LB, target = the VTAP-Target NLB above,
# encapsulated in VXLAN (Note 5's "What is VXLAN Encapsulation?" section --
# VNI-based tunnel, default protocol used by OCI VTAP).
#
# is_vtap_enabled is deliberately omitted here (defaults to false) -- the real
# OCI API rejects CreateVtap with is_vtap_enabled=true outright ("400
# InvalidParameter, VTap cannot be enabled at creation", confirmed against a
# real apply). It must be created disabled, then enabled via a separate
# UpdateVtap call -- in Terraform terms, a second `apply` after this resource
# exists, once is_vtap_enabled is set to true below.
resource "oci_core_vtap" "web_lb_vtap" {
  compartment_id    = var.compartment_ocid
  display_name      = "web-lb-vtap"
  vcn_id            = oci_core_vcn.consumer_vcn.id
  capture_filter_id = oci_core_capture_filter.vtap_capture_filter.id
  source_id         = oci_load_balancer_load_balancer.web_lb.id
  source_type       = "LOAD_BALANCER"
  target_type       = "NETWORK_LOAD_BALANCER"
  target_id         = oci_network_load_balancer_network_load_balancer.vtap_target_nlb.id
  is_vtap_enabled   = true
}

# --- Network analytics: Wireshark instance, the final stop for offline analysis ---
# Step 7 in the diagram: "NLB forwards the traffic to Wireshark/TCP dump for
# deep offline analysis."
resource "oci_core_instance" "wireshark_analytics" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "wireshark-analytics"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.network_analytics_subnet.id
    assign_public_ip = false
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}
