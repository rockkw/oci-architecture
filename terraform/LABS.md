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

**Net result:** the NSG-requirements theory is still the leading unconfirmed
suspect for the node registration timeout — Path Analyzer would have been the fastest
way to confirm or rule it out with a real trace, but is currently unavailable due to
the missing IAM grant above.

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
