# OCI Terraform Labs

A progression of small, independent Terraform stacks for learning OCI. Each stack is
its own root module (own provider block, own state) and takes its dependencies as
input variables rather than via `terraform_remote_state` — so outputs from one stack
are passed by hand into the next.

## Dependency order

```
lab-network-stack
├── lab-nsg-stack
│   ├── lab-lb-stack
│   └── lab-storage-stack (needs an instance OCID, e.g. from lab-nsg-stack)
└── lab-private-network-stack
    ├── lab-bastion-stack (needs lab-nsg-stack's public subnet too)
    └── lab-oke-stack (needs lab-network-stack's public subnet too)
        ├── lab-oke-app-stack (needs lab-oke-stack's cluster_id, dependency-only)
        └── lab-oke-gpu-stack (needs lab-oke-stack's cluster_id)

lab-func-stack   (standalone — only depends on lab-network-stack's subnet)
```

Apply order: `lab-network-stack` → `lab-nsg-stack` → everything else, in any order.

### Tearing down

Destroy in the **reverse** of apply order — a downstream stack must go before the
stack it depends on, since Terraform/OCI will block deleting a subnet, VCN, or
cluster that a dependent stack's resources still live in:

```
lab-oke-gpu-stack
lab-oke-app-stack           (no dependents — can go anytime, before or after lab-oke-stack)
lab-oke-stack
lab-bastion-stack
lab-storage-stack           (no dependents — can go anytime)
lab-lb-stack                (no dependents — can go anytime)
lab-private-network-stack
lab-nsg-stack
lab-func-stack               (no dependents — can go anytime)
lab-network-stack
```

For each stack applied locally, run `terraform destroy` from its directory with the
same `-var` flags used to apply it — the stack's own `.tfstate` already knows what to
delete, so there's no need to look up OCIDs again:

```bash
cd lab-oke-stack
terraform destroy \
  -var="compartment_ocid=..." \
  -var="tenancy_ocid=..." \
  -var="vcn_id=..." \
  -var="public_subnet_id=..." \
  -var="private_subnet_id=..." \
  -var="ssh_public_key=$(cat ~/.ssh/id_ed25519.pub)"
```

**Stacks applied via OCI Resource Manager instead of local Terraform** have no local
`.tfstate`, so `terraform destroy` from a laptop won't touch them (no state means
nothing to destroy). Tear those down through Resource Manager instead — either run a
destroy job (`oci resource-manager job create-destroy-job --stack-id ...`) or delete
the stack in the Console/CLI, which prompts a destroy first.

---

## Existing labs

### lab-network-stack
Foundational public networking: a VCN (`10.0.0.0/16`), an internet gateway, a public
route table (`0.0.0.0/0` → IGW), and one public subnet (`10.0.1.0/24`).

Outputs: `vcn_id`, `subnet_id`

### lab-nsg-stack
A Network Security Group allowing inbound HTTPS (443) from anywhere, plus a test
Oracle Linux 8 ARM (A1.Flex) compute instance on the public subnet with a public IP.

Depends on: `lab-network-stack` (`subnet_id`)
Outputs: `instance_public_ip`

### lab-func-stack
Serverless: an OCI Functions application/function fronted by an API Gateway with a
`/lab/hello` GET route.

Depends on: `lab-network-stack` (`subnet_id`)
Outputs: `gateway_hostname`

---

### lab-document-understanding-stack
Event-driven document OCR pipeline: an input Object Storage bucket, an output
bucket, an OCI Functions application/function, an Events rule that invokes the
function on `com.oraclecloud.objectstorage.createobject` in the compartment, and
a dynamic group + IAM policy authorizing the function (via resource principal) to
read/write both buckets and run OCI **Document Understanding** processor jobs.

The function itself (`func.py`) uses
`oci.auth.signers.get_resource_principals_signer()` — the same pattern documented
in [[14. Serverless — OCI Functions, Events, API Gateway]] — to call
`AIServiceDocumentClient.create_processor_job()` with a `GeneralProcessorConfig` /
`DocumentTextExtractionFeature`, pointing at the uploaded object as
`input_location` and writing OCR results to `output_location` in the output
bucket under a `results/<object-name>` prefix.

**Why Terraform doesn't create the processor job resource directly:**
`oci_ai_document_processor_job` exists as a Terraform resource, but it needs to
know the specific object key at `apply` time — it can't react to objects
uploaded *after* the stack is applied. The job itself has to be created at
runtime, per-upload, which is exactly what the Function's code does instead.

**Not yet applied — same category of caveat as `lab-func-stack`:** `function_image`
is a placeholder pointing at an image that doesn't exist in OCIR yet. Needs
`fn build && fn push` from this directory before `terraform apply` can succeed on
the `oci_functions_function` resource. IAM policy statements were written from
Oracle's documented `ai-service-document-family` / `ai-service-document-processor-job`
resource types (verified via search, not yet dry-run planned against the live
tenancy the way the original lab batch was).

Depends on: `lab-network-stack` (`subnet_id`)
Outputs: `input_bucket_name`, `output_bucket_name`, `function_id`, `dynamic_group_id`

---

### lab-mymagnet-stack
Single-VM lift-and-shift of a real app
([rockkw/MyMagnet](https://github.com/rockkw/MyMagnet)'s `deploy/` directory),
from its existing AWS EC2/Lightsail deployment to OCI. One Ubuntu 24.04
`VM.Standard.A1.Flex` instance (matching the AWS README's `t4g.small`
sizing), a Reserved Public IP (stable across stop/start, needed for the
README's DNS/Certbot TLS step), an NSG mirroring the README's security-group
guidance exactly (80/443 public, 22 restricted to `var.ssh_allowed_cidr`,
explicitly **not** 8080 — `webserver.py` binds to `127.0.0.1` only, nginx is
the sole public entry point), an Object Storage bucket for future backups,
and a dynamic group + policy granting the instance itself (not a Function)
instance-principal access to that bucket.

**cloud-init (`cloud-init.yaml.tftpl`) does the actual app install and
config** — clones the repo, runs the existing `deploy/setup.sh` (the
GitHub-hosted script itself is never edited), then writes real config
instead of leaving `setup.sh`'s own placeholders in place:
- `/etc/magnetlookup/env` is written by cloud-init's `write_files` *before*
  `setup.sh` runs, so `setup.sh`'s own `[ ! -f /etc/magnetlookup/env ]` seed
  check finds it already present and skips its placeholder.
- `search_term.txt` is written by a `runcmd` step *after* `setup.sh` (which
  creates the `/opt/magnetlookup/data` directory as a side effect of
  running), overwriting the placeholder terms `setup.sh` seeds first — real
  terms come from the `search_terms` Terraform variable via
  `templatefile()`, not a manual post-boot edit.

End-to-end: `terraform apply` → Compute instance boots → cloud-init runs
automatically (no SSH step required) → real app, real config, running
systemd services, fully wired from Terraform variables to a live instance.

**Three real bugs surfaced across the first several `apply`s, none visible
from `terraform plan`/`validate` — all three only showed up after SSHing
into a live instance, since the app is intentionally deployed via cloud-init
rather than a provisioner:**

1. **Silent YAML parse failure.** An early draft interpolated the
   multi-line `search_terms` variable directly into a shell heredoc nested
   inside the `#cloud-config` YAML document. The default terms include the
   line `Ubuntu 24.04`, which at column 1 of the *rendered* YAML parses as
   an invalid mapping key. Cloud-init's failure mode here is silent: it logs
   a WARNING to `cloud-init-output.log` and treats the whole cloud-config as
   empty — `packages`, `write_files`, and `runcmd` all silently do nothing,
   with no boot failure and no external signal beyond a plain TCP reset on
   port 80 (nginx never installed). Confirmed three separate `apply`s hit
   this identically before it was diagnosed via direct SSH. Fixed by
   base64-encoding `search_terms` in the template and decoding with
   `base64 -d` in a single-line `runcmd` entry — base64 has no characters
   that can break YAML or shell parsing, regardless of the terms' content.
2. **`awscli` isn't an apt package on Ubuntu 24.04 ARM.** `setup.sh`
   installs `awscli` via `apt-get` alongside nginx/python/etc, but that
   package doesn't exist on the `ubuntu-ports` (ARM) repos — only on
   x86_64. `setup.sh` runs under `set -euo pipefail`, so this one missing
   package aborted the entire script before nginx, the venv, or any systemd
   unit was installed. Since backups to S3 are already deliberately out of
   scope for this OCI deployment (see below), a real `awscli` install isn't
   needed at all — cloud-init `sed`-patches the `awscli \` line out of the
   *local checkout's* `deploy/setup.sh` (not the upstream repo file) in a
   `runcmd` step, right after cloning and before running the script.
3. **OCI's default per-instance firewall blocks 80/443 even though the NSG
   allows it.** Oracle's base Ubuntu image ships its own `iptables`
   ruleset — separate from, and in addition to, the OCI Network Security
   Group — that only allows inbound SSH (22) and established connections by
   default. This has no EC2/Lightsail equivalent (those rely on the cloud
   security group as the only inbound gate), so it wasn't something the
   original `deploy/README.md` needed to mention. `curl http://localhost/`
   worked while `curl http://<public-ip>/` reset, which was the tell.
   Fixed with explicit `iptables -I INPUT ... ACCEPT` rules for 80/443 plus
   `netfilter-persistent save` (already installed on the base image) so the
   rules survive reboots.

**Deliberately deferred, not ported:** `deploy/backup_to_s3.sh` calls the
`aws` CLI directly and won't work against OCI Object Storage as-is — the
bucket and IAM policy are provisioned so it's ready for a future
`backup_to_oci.sh` (using `oci os object put`) plus a new systemd timer
unit, but that script itself hasn't been written yet. The `magnetlookup-backup`
timer from the original repo isn't installed/enabled by this stack.

**Verified before writing:** `oci_core_public_ip`'s reserved-IP-to-instance
attachment pattern needs the instance's *primary private IP OCID*
specifically (via `oci_core_vnic_attachments` → `oci_core_private_ips`), not
the instance ID directly — checked against the Terraform provider docs
before use, since an earlier draft of this resource block had that wrong.

Depends on: `lab-network-stack` (`vcn_id`, `subnet_id`)
Outputs: `instance_id`, `public_ip`, `backup_bucket_name`

---

## New labs

Everything so far was public-facing. These four labs round out the picture: private
networking, zero-trust access, horizontal scaling, and identity-based access to
storage — the parts of OCI that don't show up until you stop building single public
VMs.

### lab-private-network-stack
Adds the private half of the VCN that `lab-network-stack` didn't need: a NAT Gateway
(outbound internet for instances with no public IP), a Service Gateway (private,
in-VCN access to OCI services like Object Storage — no NAT hop required), a private
route table, and a private subnet (`10.0.2.0/24`, `prohibit_public_ip_on_vnic = true`).

**Builds on:** `lab-network-stack` — reuses its VCN (`vcn_id`) rather than creating a
new one, and its route table pattern is the private-tier mirror of `lab-network-stack`'s
public route table.

Depends on: `lab-network-stack` (`vcn_id`)
Outputs: `private_subnet_id`, `nat_gateway_id`

### lab-bastion-stack
Adds a private compute instance (same A1.Flex/Oracle Linux 8 shape as
`lab-nsg-stack`'s instance, but no public IP, and an NSG that only allows SSH from the
public subnet's CIDR — not the internet), an OCI Bastion service instance sitting in
the public subnet, and a managed SSH session resource connecting through it.

This replaces "public IP + firewall rule" with "no public IP + broker-mediated,
time-boxed session" — the pattern real OCI environments use instead of
`lab-nsg-stack`'s directly-exposed test instance.

**Builds on:** `lab-network-stack` (public subnet, for the bastion's `target_subnet_id`)
and `lab-private-network-stack` (private subnet, for the instance itself). Reuses
`lab-nsg-stack`'s instance-provisioning shape (image lookup, shape_config, metadata
SSH key) almost verbatim, just without `assign_public_ip`.

Depends on: `lab-network-stack` (`vcn_id`, public `subnet_id`), `lab-private-network-stack` (`private_subnet_id`)
Outputs: `bastion_id`, `private_instance_private_ip`, `session_ssh_metadata`

### lab-lb-stack
Adds an instance configuration, a 2-instance pool built from that configuration, and a
flexible-shape Load Balancer (backend set + HTTP listener on port 80) attached to the
pool. Replaces `lab-nsg-stack`'s single directly-reachable instance with a scalable,
load-balanced pair.

**Builds on:** `lab-network-stack` (subnet) and `lab-nsg-stack` (NSG) — the instance
configuration's `launch_details` block is the same image/shape/VNIC/metadata pattern
as `lab-nsg-stack`'s single `oci_core_instance`, just wrapped for reuse by the pool.

Depends on: `lab-network-stack` (`subnet_id`), `lab-nsg-stack` (`nsg_id`)
Outputs: `load_balancer_ip`

### lab-storage-stack
Adds an Object Storage bucket, a dynamic group matching a specific compute instance
by OCID, and an IAM policy granting that dynamic group `manage objects` scoped to
just that bucket. Demonstrates instance-principal authentication — no API keys baked
into the instance — as an alternative to the user/key auth `provider.tf` uses for
Terraform itself.

**Builds on:** `lab-nsg-stack` — takes its instance's OCID as `instance_id` to define
the dynamic group's matching rule, wiring IAM access to a lab instance you already
have running instead of a new one.

Depends on: `lab-nsg-stack` (an instance OCID, e.g. `instance_public_ip`'s resource ID)
Outputs: `bucket_name`, `dynamic_group_id`

### lab-oke-stack
Adds a managed Kubernetes cluster: an OKE "basic" cluster with a public API endpoint
on the public subnet, plus a 2-node pool (same A1.Flex shape as `lab-nsg-stack`'s
instance) placed in the private subnet. Both the cluster and node pool use VCN-native
pod networking (`OCI_VCN_IP_NATIVE`) instead of the older flannel overlay CNI, so pods
get real VCN IPs out of the private subnet. The Kubernetes version and node image are
looked up live via the `oci_containerengine_cluster_option` and
`oci_containerengine_node_pool_option` data sources instead of being hardcoded, so the
stack doesn't go stale as Oracle ships new versions.

**Builds on:** `lab-network-stack` (public subnet, for the cluster's API endpoint and
service load balancers) and `lab-private-network-stack` (private subnet, for worker
nodes and pods) — this is the first stack to need both a public and a private subnet
at once, tying the two earlier networking labs together. The node pool's shape/OCPU/
memory config mirrors `lab-nsg-stack`'s instance almost exactly.

Depends on: `lab-network-stack` (`vcn_id`, public `subnet_id`), `lab-private-network-stack` (`private_subnet_id`)
Outputs: `cluster_id`, `kubernetes_version`, `cluster_public_endpoint`

**Cluster/node type used, confirmed against `main.tf`:**
- **Cluster type: `BASIC_CLUSTER`** — explicit in `oci_containerengine_cluster`'s
  `type` argument. Per [[12. Containers — OCI OKE, Container Instances, OCIR]]'s
  Basic-vs-Enhanced coverage, this means no Virtual Nodes, no fine-grained add-on
  config, no workload identity, and only an SLO (not a financially-backed SLA) —
  none of these were needed for this lab's scope, so Basic was the right (and, via
  the CLI/API default, the automatic) choice.
- **Node type: Managed node pool** (`oci_containerengine_node_pool`), **not**
  Virtual Nodes and **not** a self-managed Instance Pool — confirmed by
  `node_shape = "VM.Standard.A1.Flex"` plus `node_source_details { source_type =
  "IMAGE" }`, which only a managed NodePool uses (Virtual Nodes don't take an
  image source; a self-managed pool wouldn't be an `oci_containerengine_node_pool`
  resource at all).
- **Why this matters for the registration-timeout issue below:** since this is
  Basic + Managed Nodes (not Virtual Nodes), the "Virtual Nodes require Enhanced"
  tier constraint documented in Note 12 does **not** apply here — that's ruled out
  as a cause. And because these are real Managed Nodes, each node's own
  **Kubelet** (see Note 12's Managed Nodes section) has to successfully register
  with the control plane over the network — consistent with "2 nodes register
  timeout" being a genuine network-reachability problem at the Kubelet level,
  not a cluster-tier or node-type misconfiguration.

**Known issue hit in practice: node pool registration timeout.** Applying this stack
against the tenant, the cluster (`oci_containerengine_cluster`) created successfully
and went `ACTIVE`, but `oci_containerengine_node_pool` failed after ~71 minutes with:

> Work Request error ... Message: 2 nodes(s) register timeout. First, confirm that
> network prerequisites have been met. ...

OCI cleaned up the failed node pool server-side (it no longer exists — `oci ce
node-pool get` on its OCID returns `404 NotAuthorizedOrNotFound`), but the local
`.tfstate` still tracked it, causing a state/reality mismatch. Fixed with
`terraform state rm oci_containerengine_node_pool.lab_node_pool` (safe — this only
edits local state, it doesn't touch anything in OCI).

Checked as candidate causes, both came back clean — **not the problem this time**:
- The private subnet's route table (`lab-private-rt`) correctly routes `0.0.0.0/0` →
  the NAT gateway and the OCI-services CIDR → the service gateway.
- The private subnet's security list allows all egress (`protocol: all` to
  `0.0.0.0/0`) and has the expected ingress (SSH, ICMP, 443).

Since a security list alone can be insufficient for OKE — Oracle's docs call for
specific **NSG** rules for reliable control-plane-to-worker-node communication, not
just an open security list — that's the leading unconfirmed suspect.

**Update: reproduced on a second attempt.** Retried the node pool apply from a clean
state; it failed again with the identical "2 nodes(s) register timeout" error, this
time in ~24 minutes instead of ~71. Two failures with the same message rules out a
one-off OCI-side flake as the primary explanation — this is a real, reproducible
config gap. Next time this comes up, don't blind-retry a third time; investigate
OCI's documented NSG requirements for OKE node registration first (see the
Containerengine troubleshooting links in the error message itself, and Oracle's node
pool networking docs) before applying again.

**Tried Network Path Analyzer to get a real trace instead of guessing — blocked by
IAM, not by the tool itself.** `oci vn-monitoring path-analysis get-path-analysis-adhoc`
is the correct CLI for this (Console: Networking → Network Command Center → Path
Analyzer). Built a working request (source: private subnet `10.0.2.0/24` at
`10.0.2.50`; destination: the public subnet hosting the OKE cluster's public endpoint,
at its IP `129.153.222.108`; protocol TCP, destination port 6443 — the Kubernetes API
server port a node must reach to register) — the request shape itself was accepted
by the API (work request created, ran to completion), but failed with **"Not
Authorized for Source or Destination Endpoint"** on every attempt, including with
both endpoints as real subnets already fully accessible to this identity otherwise.

Checked every IAM policy in the tenancy (`oci iam policy list` across the whole
tenancy) for anything granting Path Analyzer's resource family — found nothing. No
statement anywhere mentions Path Analyzer or its underlying `vnca`/network-analysis
resource type, even though this identity has broad `manage`/`read` grants across
most other network resource families. This looks like a genuine gap in the `rocklz-*`
Landing Zone's policy set, not a config mistake on our end — Path Analyzer commonly
needs its own explicit policy verb beyond the generic `virtual-network-family`
grants. Whoever administers the Landing Zone's IAM policies (see the tenancy-wide
groups: `rocklz-network-admin-group`, `rocklz-iam-admin-group`) would need to add a
statement granting this identity's group access to Path Analyzer's resource type
before it's usable — not something to self-grant from `sandbox`.

**Update (2026-09-15): course confirms OKE wants purpose-built subnets, not a
generic pair.** OKE's Quick Create workflow auto-provisions **three distinct
regional subnets** — one each for the Kubernetes API, worker nodes, and load
balancers — not a generic public/private split. `lab-oke-stack` instead reuses
`lab-network-stack`'s public subnet and `lab-private-network-stack`'s private
subnet, both built for earlier, non-OKE labs. This is now the leading, sharpened
theory: the shared private subnet likely lacks NSG/security-list rules specific
to worker-node-to-API-subnet communication that a purpose-built, auto-created
subnet would carry by default. See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s
"Prerequisites to create an OKE cluster" section for the full writeup.

**Confirmed directly against `main.tf` (2026-09-15): this stack used Custom
Create's shape, not Quick Create — exactly 2 subnets, not 3.**
- `oci_containerengine_cluster.endpoint_config.subnet_id` = `var.public_subnet_id`
  — the Kubernetes API endpoint sits on the **public** subnet.
- `options.service_lb_subnet_ids` = `[var.public_subnet_id]` — the **same**
  public subnet also serves load balancers. Quick Create would give this its
  own dedicated subnet, separate from the API endpoint's.
- `oci_containerengine_node_pool.node_config_details.placement_configs.subnet_id`
  = `var.private_subnet_id` — worker nodes on the private subnet (also used by
  `pod_subnet_ids` for `OCI_VCN_IP_NATIVE` pod networking).

So this stack collapses what Quick Create splits into 3 purpose-built subnets
(API, workers, load balancers) down to 2 general-purpose subnets doing double
duty (API + LB sharing one; workers + pods sharing the other) — both originally
built for prior, non-OKE labs (`lab-network-stack`, `lab-private-network-stack`),
not configured with OKE's specific traffic needs in mind.

**Correction from the course's Custom Create slide: reusing existing subnets is
not itself the problem.** Custom Create explicitly supports "precise network
resource selection using **existing** public or private subnets for Kubernetes
API, worker nodes, and load balancers" — reuse is a first-class, supported path,
not a workaround. The sharpened theory is specifically about **collapsed roles**,
not reuse: `lab-oke-stack` gives the load balancer role the *same* subnet as the
Kubernetes API role instead of a distinct one for each of the three roles. Two
concrete next steps, either of which is a real test rather than more theorizing:
(1) give the load balancer role its own distinct subnet and see if that alone
changes node registration behavior, or (2) find the specific NSG/security-list
rules Quick Create's auto-created subnets carry and diff them against what
`lab-private-network-stack`'s subnet actually has.

**Better source found for (2), from the course (2026-09-15): Oracle's own
official Terraform module for OKE.**
[`oracle-terraform-modules/terraform-oci-oke`](https://github.com/oracle-terraform-modules/terraform-oci-oke)
— actively maintained (626 commits, latest release v5.0.1), the closest thing
to an authoritative answer for exactly this open question, since it's Oracle's
own reference implementation rather than something reverse-engineered from
course slides. Its file layout is directly relevant:
- `module-network.tf` — almost certainly the actual answer to what
  subnets/NSGs/security rules OKE needs, in working Terraform rather than
  prose.
- `module-iam.tf` — likely resolves the open `CLUSTER_MANAGE` vs.
  `manage cluster-family` question too.
- `module-cluster.tf`, `module-bastion.tf`, `module-operator.tf`,
  `module-extensions.tf` — worth a look for comparison against
  `lab-oke-stack`'s hand-rolled approach generally.

**Next time this is picked up: read `module-network.tf` and `module-iam.tf`
directly before doing more manual trial-and-error** — this is a faster,
more authoritative path to the answer than tests (1)/(2) above.

**RESOLVED (2026-09-15): found the actual missing rules.** Fetched
`modules/network/nsg-controlplane.tf` and `modules/network/nsg-workers.tf`
from the official module (`gh api repos/oracle-terraform-modules/terraform-oci-oke/contents/...`).
Oracle's own module creates two dedicated NSGs — one for the control plane,
one for workers — with a specific bidirectional rule set between them. The
exact ports (from `modules/network/locals.tf`): `apiserver_port = 6443`,
`kubelet_api_port = 10250`, `oke_port = 12250`, `health_check_port = 10256`.

**`lab-oke-stack` has none of this.** It creates no NSG at all — the node
pool's `placement_configs` just places nodes in `lab-private-network-stack`'s
subnet, which only carries the default security list confirmed earlier in
this doc (SSH/22, ICMP, HTTPS/443 — see the `lab-bastion-stack` section
above). Comparing against Oracle's module, the specific missing rules are:

| Direction | Rule (per Oracle's module) | Port |
|---|---|---|
| workers → control plane | egress to Kubernetes API server | 6443 |
| workers → control plane | egress to OKE control plane | 12250 |
| workers → control plane | egress for **health check** (this is the Kubelet registration path) | **10250** |
| control plane → workers | ingress from worker nodes | 6443 |
| control plane → workers | egress to Kubelet on worker nodes | **10250** |
| control plane ↔ workers | bidirectional OKE control plane traffic | 12250 |

None of these ports (6443, 10250, 12250, 10256) are open anywhere in
`lab-private-network-stack`'s security list. **This is almost certainly the
root cause of the "2 nodes register timeout" error** — the worker nodes launch
successfully (Compute-level provisioning works fine) but their Kubelet can't
reach the control plane's registration/health-check endpoints on 10250, and
the control plane can't reach back to the workers either, so registration
times out rather than failing fast with a clear connection-refused error
(consistent with a silent network-layer drop, not an application-level
rejection).

**Fix, next time this is applied:** add an NSG (or extend the private
subnet's security list) with, at minimum, TCP 6443/10250/12250 bidirectional
between the control plane and worker nodes — either hand-roll these
specific rules in [[terraform/lab-oke-stack]], or migrate to using the
official `oracle-terraform-modules/terraform-oci-oke` module directly, which
gets this (and everything else — bastion, operator, pod networking, FSS)
right by construction instead of needing to be manually replicated rule by
rule.

**CONFIRMED RESOLVED (2026-09-15).** Applied the fix directly to
`lab-oke-stack`: added `oci_core_network_security_group` resources for
`control_plane` and `workers`, with the 8 bidirectional rules covering ports
6443/10250/12250/10256, attached to the cluster's `endpoint_config.nsg_ids`
and the node pool's `node_config_details.nsg_ids`/`pod_nsg_ids`. Terraform
recreated the node pool (adding `nsg_ids` forced replacement, not an
in-place update). Both nodes reached `ACTIVE` cleanly — no timeout, no error,
first successful `lab-oke-stack` apply after 3 total attempts (71 min
failure, 24 min failure, then this fix). Root cause and fix both fully
verified, not just diagnosed. `lab-oke-stack`'s `main.tf` now includes these
NSGs permanently as of this commit — no further action needed for this
stack.

A separate, isolated comparison stack, `lab-oke-official-module-stack`, was
also built (using Oracle's official module directly) specifically to
cross-validate this diagnosis before applying the hand-fix — its planned NSG
rules independently matched the hand-written fix rule for rule. It has not
been applied (user asked to wait pending the hand-fix result, now confirmed
successful) — still available for a real side-by-side comparison whenever
useful (e.g., checking whether the official module's extra subnets/NSGs for
bastion/operator/load-balancer roles matter for future labs).

**Second, distinct gap found (2026-09-15): nodes registering ≠ kubectl
working.** With both nodes `ACTIVE`, tried actually connecting with
`kubectl` (`oci ce cluster create-kubeconfig --cluster-id <id> --file
~/.kube/config --region us-phoenix-1 --token-version 2.0.0`, merges cleanly
into an existing kubeconfig without `--overwrite`) — got
`dial tcp 129.153.222.108:6443: i/o timeout`. Root cause: the
`cp_ingress_from_workers` rule added for the registration-timeout fix above
only allows port 6443 from the **workers NSG** — nothing allowed an
**external client** (a laptop, not a cluster-internal resource) to reach the
API endpoint. The public subnet's security list has 443 open from
`0.0.0.0/0` but not 6443, and the control-plane NSG had no CIDR-based rule at
all for 6443, only the NSG-to-NSG one.

**Fix:** added `cp_ingress_from_internet` — TCP 6443 from `0.0.0.0/0` on
`lab-oke-control-plane-nsg`, mirroring how 443 is already handled on the same
subnet. Applied cleanly (1 resource, no recreate needed this time). Confirmed
working immediately after:
```
$ kubectl get nodes
NAME         STATUS   ROLES   AGE     VERSION
10.0.2.12    Ready    node    7m39s   v1.36.1
10.0.2.205   Ready    node    7m1s    v1.36.1
```
All `kube-system` pods `Running` (CoreDNS, `vcn-native-ip-cni`,
`csi-oci-node`, `kube-proxy`, `oke-node-problem-detector`), `kubectl
cluster-info` resolves correctly. `lab-oke-stack` is now fully working
end-to-end, not just "nodes registered" — verified all the way through actual
`kubectl` access, matching [[12. Containers — OCI OKE, Container Instances, OCIR]]'s
"Accessing a cluster with kubectl" section.

**Lesson for future labs:** "nodes reached ACTIVE" and "external tooling can
reach the cluster" are two separate network paths that can each be broken
independently — don't assume one working implies the other.

**Quota/service-limits ruled out (2026-09-15).** The MyLearn course's OKE module
lists four prerequisite quota categories for cluster creation: Compute instance
quota, Block Volume quota (min. 50GB per persistent volume claim), Load Balancer
quota, and VCN/Subnet quota. Checked all four directly via `oci limits value list`
against the tenancy (not just `sandbox` — the Limits API requires the tenancy OCID):

| Quota | Checked value | Needed | Verdict |
|---|---|---|---|
| `standard-a1-core-count` (compute) | 13,888 cores/AD | 2 nodes × 1 OCPU | Not the cause |
| `total-storage-gb` / `volume-count` (block volume) | 500,000 GB / 100,000 vols per AD | 2 small boot volumes | Not the cause |
| Load Balancer (`lb-flexible-count`, etc.) | up to 12,291/region | 0 (this stack creates no LB) | Not the cause |
| `vcn-count` / `subnet-count` | 50 / 300 per region | 1 VCN, 2 subnets already exist | Not the cause |

All four are ruled out with wide margin — this was never a quota problem.

**New lead from the course, sharpens the NSG theory (2026-09-15).** The same
module's prerequisites slide states that when you **designate existing network
resources** for a cluster (VCN, subnets, IGW, route table, security lists) instead
of letting OKE auto-create them, **"these must be pre-configured appropriately"** —
without the slide detailing exactly what "appropriately" requires. This is exactly
`lab-oke-stack`'s situation: it reuses `lab-network-stack`'s and
`lab-private-network-stack`'s pre-existing VCN/subnets rather than using OKE's
auto-create-network option. Strengthens the working theory that the private
subnet's security list (or a missing NSG OKE would have auto-created for you) is
under-provisioned relative to what an auto-created network would have set up —
worth explicitly diffing what OKE's "automatically create and configure new network
resources" option provisions against what `lab-private-network-stack` actually has,
next time this is picked up.

**IAM policy also ruled out (2026-09-15).** The course lists the specific policy
statements OKE cluster creation needs: `manage cluster-family`, `use subnets`,
`use network-security-groups`, `use vnics`, `use private-ips`, `manage
instance-family`, `read virtual-network-family`, `inspect compartments`, and
`manage public-ips`. Checked the tenancy's actual policies
(`oci iam policy list`) for whether the identity applying `lab-oke-stack` has
these — it does, via the built-in `Allow group Administrators to manage
all-resources in tenancy` policy (documented in
[[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]]'s "What a policy
actually does" section), which is a strict superset of every statement in this
checklist. **IAM policy is not the cause** — this narrows the remaining
candidates specifically to network/NSG configuration on the private subnet, not
identity/authorization.

**Where to check egress in the Console:** Networking → Virtual Cloud Networks →
`lab-vcn` → Subnets → `lab-private-subnet` — the subnet detail page links directly to
its attached Security List (Egress Rules tab) and Route Table without having to hunt
through the VCN's full resource list.

### lab-oke-app-stack
Adds an OCI Container Registry (OCIR) repository (`lab-app`, private) for pushing an
image to deploy on `lab-oke-stack`'s cluster. Scoped deliberately narrow — this repo
only creates the OCI-side resource; it does not build/push an image, generate a
kubeconfig, or apply any Kubernetes manifests. Every other lab stack in this repo
stays scoped to OCI resources rather than driving app-level state, and this one
follows the same pattern instead of pulling in the Kubernetes/Helm Terraform
providers just to deploy one example workload.

**Builds on:** `lab-oke-stack` — takes `cluster_id` as a required input purely to
express the dependency (there's no cluster to deploy to otherwise); the resource
itself doesn't reference `cluster_id` directly.

Depends on: `lab-oke-stack` (`cluster_id`, dependency-only — not consumed directly)
Outputs: `repository_id`, `repository_path` (e.g. `phx.ocir.io/<tenancy-namespace>/lab-app`)

**Manual steps to actually deploy an example app** (not automated by Terraform):

1. **Get cluster credentials** (writes a kubeconfig you can point `kubectl` at):
   ```bash
   oci ce cluster create-kubeconfig \
     --cluster-id <cluster_id> \
     --file ~/.kube/config \
     --region us-phoenix-1 \
     --token-version 2.0.0
   kubectl get nodes   # confirms kubectl can reach the cluster and see the node pool
   ```

2. **Authenticate Docker/Podman to OCIR** — use an [Auth Token](https://docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrypushingimagesusingthedockercli.htm)
   (Console: Identity → Users → your user → Auth Tokens → Generate Token), not your
   OCI API key:
   ```bash
   docker login phx.ocir.io -u '<tenancy-namespace>/<username>' -p '<auth-token>'
   ```

3. **Build, tag, and push a trivial image** (any "hello world" HTTP server works —
   e.g. `docker.io/library/httpd` or `nginxdemos/hello` re-tagged is enough to prove
   the pipeline; a from-scratch image isn't necessary for this lab):
   ```bash
   docker tag nginxdemos/hello:latest phx.ocir.io/<tenancy-namespace>/lab-app:v1
   docker push phx.ocir.io/<tenancy-namespace>/lab-app:v1
   ```

4. **Apply a minimal Deployment + Service** referencing that image:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: lab-app
   spec:
     replicas: 2
     selector:
       matchLabels: { app: lab-app }
     template:
       metadata:
         labels: { app: lab-app }
       spec:
         containers:
           - name: lab-app
             image: phx.ocir.io/<tenancy-namespace>/lab-app:v1
             ports: [{ containerPort: 80 }]
   ---
   apiVersion: v1
   kind: Service
   metadata:
     name: lab-app
   spec:
     type: LoadBalancer
     selector: { app: lab-app }
     ports: [{ port: 80, targetPort: 80 }]
   ```
   ```bash
   kubectl apply -f lab-app.yaml
   kubectl get svc lab-app   # wait for an external IP from the OCI Load Balancer
   ```

If the pod stays `ImagePullBackOff`, the node pool's worker nodes need network access
to `phx.ocir.io` (the same NAT gateway / service gateway path `lab-oke-stack`'s worker
nodes already need) and, for a **private** repository, a Kubernetes
`imagePullSecret` built from the same OCIR auth token — the cluster's node principal
alone doesn't grant pull access to a private repo without one.

### lab-oke-gpu-stack
Adds a second, GPU-shaped node pool (default `VM.GPU.A10.1`, 1 node) to an existing
OKE cluster, alongside — not replacing — `lab-oke-stack`'s CPU node pool. Same
placement/pod-networking pattern as the CPU pool (private subnet, `OCI_VCN_IP_NATIVE`),
but the node image is looked up by filtering `oci_containerengine_node_pool_option`
for a GPU-flavored Oracle Linux image instead of the ARM64 one. OKE's GPU platform
images ship with NVIDIA drivers and the device plugin preinstalled, so pods can
request `nvidia.com/gpu` in resource limits with no extra Helm chart or DaemonSet.

**Builds on:** `lab-oke-stack` directly — takes its `cluster_id` and attaches a new
node pool to the same cluster rather than standing up a second cluster. Kept as a
separate stack (instead of a second pool resource inside `lab-oke-stack`) so the
expensive GPU nodes can be applied/destroyed independently of the base cluster.

Depends on: `lab-oke-stack` (`cluster_id`, `kubernetes_version`), `lab-private-network-stack` (`private_subnet_id`)
Outputs: `gpu_node_pool_id`, `node_shape`

**Before applying:** GPU shapes need a GPU service limit increase in your tenancy
(default quota is usually 0) — `apply` will fail on a capacity/limit error otherwise.

**Available GPU shapes** — `node_shape` defaults to `VM.GPU.A10.1`; the full option
list is documented as a comment above the `node_shape` variable in
[`lab-oke-gpu-stack/variables.tf`](lab-oke-gpu-stack/variables.tf). Current as of the
[OCI GPU shapes reference](https://docs.oracle.com/en-us/iaas/Content/Compute/References/computeshapes.htm):

VM shapes (no RDMA/cluster networking — drop-in for this stack):

| Shape | GPU | Count |
|---|---|---|
| `VM.GPU2.1` | NVIDIA P100 | 1 |
| `VM.GPU3.1` / `.2` / `.4` | NVIDIA V100 | 1 / 2 / 4 |
| `VM.GPU.A10.1` / `.2` | NVIDIA A10 | 1 / 2 |

Bare metal shapes (support RDMA cluster networking via `compute_cluster_id` for
multi-node training — not configured by this stack):

| Shape | GPU | Count |
|---|---|---|
| `BM.GPU2.2` | NVIDIA P100 | 2 |
| `BM.GPU3.8` | NVIDIA V100 | 8 |
| `BM.GPU4.8` | NVIDIA A100 | 8 |
| `BM.GPU.A10.4` | NVIDIA A10 | 4 |
| `BM.GPU.A100-v2.8` | NVIDIA A100 | 8 |
| `BM.GPU.L40S.4` | NVIDIA L40S | 4 |
| `BM.GPU.H100.8` | NVIDIA H100 | 8 |
| `BM.GPU.H200.8` | NVIDIA H200 | 8 |
| `BM.GPU.B200.8` / `BM.GPU.B300.8` | NVIDIA B200 / B300 (Blackwell) | 8 |
| `BM.GPU.GB200.4` / `BM.GPU.GB300.4` | NVIDIA Grace-Blackwell GB200 / GB300 | 4 |
| `BM.GPU.MI300X.8` / `BM.GPU.MI355X.8` | AMD MI300X / MI355X | 8 |
| `BM.GPU.RTXPRO.8` | NVIDIA RTX PRO 6000 Blackwell | 8 |

Region/tenancy availability and quota vary per shape — check the live catalog and
your service limits before picking one.

---

## Notes

- All stacks have been dry-run with `terraform plan` against a live, authenticated
  OCI tenant (not just offline `validate`) but have **not** been applied — no OCI
  resources exist for them yet.
- Like the existing stacks, none of these use `terraform_remote_state`; you pass
  outputs from one stack in as `-var` values (or a `.tfvars` file) for the next.
- `lab-oke-gpu-stack` is by far the most expensive lab here to leave running (GPU VM
  shapes bill per-hour even idle), followed by `lab-oke-stack` (managed Kubernetes
  control plane plus 2 compute nodes) and `lab-lb-stack` (2 compute instances plus a
  load balancer) — tear these down first if you're optimizing for cost.

### Plan dry-run results

Ran with real auth against the tenant; downstream stacks used placeholder OCIDs
for not-yet-applied dependencies (real values once earlier stacks are applied).

| Stack | Result | Notes |
|---|---|---|
| `lab-network-stack` | 4 to add | Real values, no placeholders needed |
| `lab-func-stack` | 4 to add | Placeholder `subnet_ocid` |
| `lab-nsg-stack` | 3 to add | Placeholder `vcn_id`/`subnet_id` |
| `lab-private-network-stack` | 4 to add | Placeholder `vcn_id` |
| `lab-bastion-stack` | 5 to add | Placeholder subnets |
| `lab-lb-stack` | 5 to add | Placeholder `subnet_id`/`nsg_id` |
| `lab-storage-stack` | 3 to add | Placeholder `instance_id` |
| `lab-oke-stack` | 2 to add | Found and fixed a bug: `node_pool_os_arch = "ARM64"` isn't a valid enum for this provider version — corrected to `AARCH64`. Plan then resolved a live Kubernetes version (`v1.36.1`) and a real ARM64 node image. |
| `lab-oke-gpu-stack` | not fully verifiable yet | Its GPU image lookup queries `node_pool_option_id = var.cluster_id` directly (not `"all"`), so it needs a real cluster to return image sources — a placeholder `cluster_id` yields `sources = null`, which is expected, not a bug. Fully dry-runnable only after `lab-oke-stack` is applied.
