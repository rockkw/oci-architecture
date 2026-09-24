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
    ├── lab-basedb-stack (needs lab-network-stack's vcn_id + lab-private-network-stack's private_subnet_id)
    └── lab-oke-stack (needs lab-network-stack's public subnet too)
        ├── lab-oke-app-stack (needs lab-oke-stack's cluster_id, dependency-only)
        ├── lab-oke-gpu-stack (needs lab-oke-stack's cluster_id, workers_nsg_id)
        └── lab-capstone-vllm-stack (needs lab-oke-stack's workers_nsg_id; runs on lab-oke-gpu-stack)

lab-func-stack       (standalone — only depends on lab-network-stack's subnet)
lab-zpr-stack        (standalone — own VCN/subnet, no dependency on any other stack)
lab-firewall-stack   (standalone — own VCN/subnet, no dependency on any other stack)
lab-capstone-enrich-stack (needs lab-network-stack's vcn_id + lab-private-network-stack's private_subnet_id)
```

Apply order: `lab-network-stack` → `lab-nsg-stack` → everything else, in any order.

### Tearing down

Destroy in the **reverse** of apply order — a downstream stack must go before the
stack it depends on, since Terraform/OCI will block deleting a subnet, VCN, or
cluster that a dependent stack's resources still live in:

```
lab-capstone-vllm-stack     (delete the vllm Service first so the LB releases its NSG)
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

**APPLIED — this stack was actually restructured from one instance to a
2-node, LB-fronted design and applied against real infrastructure (the
original single-instance stack was `terraform destroy`'d first, then this
design `apply`'d fresh), following the same LB/backend-set/listener pattern
`lab-lb-stack` and `lab-firewall-stack`'s `web_lb` already use in this repo.
Real, mixed results — the network/LB/compute layer succeeded; the HTTPS/
Certificates layer and end-to-end app reachability did not. See "Real apply
results and two unresolved blockers" below before assuming this lab works
end to end.

- **Two explicitly-named backend instances** (`mymagnet_1`/`mymagnet_2`,
  not `count`/`for_each` — matching this file's existing style and
  `lab-firewall-stack`'s `web_server_1`/`web_server_2`), each an
  independent, functionally-duplicate MyMagnet install with its own local
  SQLite DB and **no replication between them**. Accepted risk, not an
  oversight: the user explicitly chose 2 nodes plus LB session persistence
  (sticky sessions) over solving real data consistency, since this is a
  study lab, not production. Neither instance gets its own public IP
  anymore.
- **`oci_load_balancer_load_balancer`** is now the sole public entry
  point, reusing the *same* Reserved Public IP that used to sit directly
  on the instance's VNIC via its `reserved_ips { id = ... }` block, rather
  than provisioning a new ephemeral IP — same "stable IP for the DNS A
  record" property as before, one hop further out.
- **`oci_load_balancer_backend_set`** uses
  `session_persistence_configuration { cookie_name = "*" }` for sticky
  sessions (confirmed argument name/shape against the provider's website
  docs — mutually exclusive with `lb_cookie_session_persistence_configuration`
  per that same doc). Health check/backend port: `var.backend_port = 80`
  (nginx's plain-HTTP listener), confirmed **live** before the original
  single-instance stack was torn down (`curl http://<old public_ip>/`
  returned 200 on port 80; 443 and 8080 both timed out — 443 wasn't
  actually serving TLS despite the NSG allowing it, and 8080/`MAGNET_PORT`
  is 127.0.0.1-only). Correct default, not the blocker below.
- **HTTPS listener** on port 443 attaches a cert via `ssl_configuration {
  certificate_ids = [...] }` — the OCI-Certificates-managed-cert argument,
  confirmed against the provider's website docs, deliberately not the
  legacy inline-PEM `certificate_name` pattern. No existing
  `oci_kms_vault`/`oci_certificates_*` resource was found anywhere else in
  this repo (grepped `terraform/`), so this stack provisions its own
  minimal `oci_kms_vault` → `oci_kms_key` → `oci_certificates_management_
  certificate_authority` (`ROOT_CA_GENERATED_INTERNALLY`) →
  `oci_certificates_management_certificate` (`ISSUED_BY_INTERNAL_CA`)
  chain, rather than taking Vault/CA OCIDs as input variables — there's no
  other stack in this repo to source them from. **This entire chain is the
  first of the two unresolved blockers below — the CA never successfully
  reaches `ACTIVE`, so `certificate_ids` never resolves and the HTTPS
  listener was never actually created.**
- **NSG split in two**: `mymagnet` (backend instances — SSH from
  `var.ssh_allowed_cidr`, app port from `var.lb_subnet_cidr` only, no more
  direct 0.0.0.0/0 on 80/443) and `mymagnet_lb` (the LB itself — 80/443
  open to 0.0.0.0/0, attached via the LB's own
  `network_security_group_ids`, since that attaches at the LB level, not
  the VNIC level like `oci_core_instance` does).
- **Dynamic group matching rule** updated to `ANY {instance.id = '...',
  instance.id = '...'}` to match both instances (previously a single
  `resource.id`). Multi-`instance.id` `ANY{}` is OCI's documented pattern
  for matching several specific resources (same structure as Oracle's
  documented multi-`instance.compartment.id` example) — **flagged as
  unverified** in this exact multi-`instance.id` form specifically, since
  no official worked example for that precise variant was found while
  writing this.

`terraform validate` passed cleanly against provider `oracle/oci` v9.2.0
(upgraded from v9.1.0 mid-investigation, see below). This design **was**
applied against real infrastructure: the original single-instance stack was
destroyed first (`terraform destroy`, 10 resources), then this design was
applied fresh (`terraform apply`, 24 resources planned). 23 of those 24
succeeded on the first pass — both instances, the LB, the HTTP listener,
both NSGs, the KMS vault/key, the dynamic group, the policy, the backup
bucket. Only `oci_core_vtap`-style CA/cert/HTTPS-listener chain failed; see
below.

### Real apply results and two unresolved blockers

> **Update 2026-09-24:** likely root cause found (the CA needs its own dynamic
> group, not a `service certificates` grant). Fix is written but not yet applied;
> see [CAPSTONE.md](CAPSTONE.md), Phase 1.

**Blocker 1 — OCI Certificates CA creation, root cause still unresolved.**
`oci_certificates_management_certificate_authority.mymagnet` never
successfully applies. Investigation history, in order:

1. First failure: `400-InvalidParameter, "Unable to process JSON input"`
   from `terraform apply`. Traced (via `terraform show -json` on the saved
   plan) to `timeadd(timestamp(), "8760h")` — a genuine Terraform gotcha:
   `timestamp()` is unknown at plan time, and the resulting value was
   silently absent from the planned request body rather than deferred.
   **Fixed**: replaced with a static literal via a new `var.cert_valid_until`
   variable. Confirmed via `terraform show -json` that the value was
   correctly present in the plan after the fix — but the apply still failed
   with the identical error.
2. Upgraded the provider 9.1.0 → 9.2.0 on the theory this was a provider
   serialization bug. Same error, unchanged.
3. Bisected directly against the raw OCI API (bypassing both Terraform and
   the OCI CLI's own SDK wrapper) with `oci certs-mgmt certificate-authority
   create-root-ca-by-generating-config-details --from-json`, adding fields
   back one at a time from a minimal payload. Found the real (different)
   bug: `timeOfValidityNotAfter` requires **millisecond precision** —
   `2027-09-18T17:14:17Z` (bare seconds, otherwise fully valid RFC3339) is
   silently rejected; `2027-09-18T17:14:17.000Z` succeeds. Not documented
   as a requirement anywhere in the provider docs, the CLI's own generated
   example values, or the API reference fetched during this investigation.
   **Fixed** `var.cert_valid_until` to include explicit `.000` milliseconds.
4. Re-applied via Terraform with the corrected value (confirmed present and
   millisecond-precise in the plan) — **still failed, identical error.**
   This means the Terraform provider is doing something to the timestamp
   between HCL and the wire that the raw CLI doesn't do — a real,
   unconfirmed provider bug, distinct from the two fixes above.
5. Created the CA directly via the OCI CLI instead (bypassing Terraform
   entirely) using the exact millisecond-precise payload — this time the
   API *accepted* the request and returned `CREATING`. **But the CA then
   settled into `FAILED`** (confirmed by polling `lifecycle-state`, not by
   trusting the initial response) with `lifecycle_details: "Authorization
   failed or requested resource not found: Key Id <the KMS key's OCID>."`
   — a completely different, IAM-shaped problem the earlier "Unable to
   process JSON input" error never surfaced.
6. Tried two real IAM policies against the live tenancy to fix the
   authorization gap, both in the home region (`us-ashburn-1`, required for
   all IAM writes — see [[OCI propagation delays]]), each confirmed
   propagated to `us-phoenix-1` before retrying:
   - `Allow service certificates to use keys in compartment id <compartment>`
     — failed, identical authorization error.
   - `Allow service certificates to use key-delegate in compartment id
     <compartment>` — matches Oracle's documented semantics for a service
     acting on a customer's key on the customer's behalf (`key-delegate`,
     not `keys`, per the Vault policy reference) — **also failed, identical
     error.**
   Both policies were deleted afterward since neither fixed the problem.

**Root cause remains unresolved.** Three real, confirmed, separately-fixed
bugs were found and corrected along the way (the `timestamp()` gotcha, the
millisecond-precision requirement, the provider upgrade ruled out as
irrelevant) — but the underlying `FAILED`/"Authorization failed... Key Id"
error persisted through all of them, including two different IAM policy
grants that should have addressed it per Oracle's own documented policy
model. Candidates not yet tested: whether `vault_type = "DEFAULT"` (used
here) is actually incompatible with Certificates-service CA issuance and a
`VIRTUAL_PRIVATE` (dedicated HSM) vault is required instead; whether the
policy needs `where target.key.id = '...'` scoping rather than a
compartment-wide grant; whether the OCI Console UI surfaces a clearer error
than either the CLI or Terraform does. **The HTTPS listener, and both
`oci_certificates_management_*` resources, remain in `main.tf` as correct,
schema-valid Terraform — they are not in state and were never created.**

**Blocker 2 — RESOLVED.** The app is reachable through the LB and serving
real content (`curl http://137.131.32.68/` returns `200` with the actual
Magnet Library HTML, not an error page). Originally: `curl` returned `502`
and `oci lb backend-set-health get` showed both backends `CRITICAL` with
`health-check-status: CONNECT_FAILED` on port 80 — the LB couldn't even
establish a TCP connection to either instance, despite a correct health
checker config (port 80, HTTP, path `/`).

**Diagnosis path.** No bastion, no public IP on either instance, so direct
SSH isn't possible. `oci instance-agent command create` (Run Command) was
tried first — commands sat at `lifecycle-state: ACCEPTED` indefinitely and
`oci instance-agent plugin list` returned empty, meaning Oracle Cloud
Agent's management/Run-Command plugin never checked in at all (consistent
with the root cause below: an instance that can't reach the internet also
can't reach OCI's agent control-plane endpoints). Instance Console
Connection (`oci compute instance-console-connection create`, RSA key
required — the stack's existing `mymagnet-key` is ed25519 and was rejected
with `InvalidParameter, "Invalid ssh public key type"`, so a separate
throwaway RSA keypair was generated for the console only) reached a real
`login:` prompt over serial — confirming the kernel/systemd/getty stack
booted fine — but Ubuntu cloud images have no password set, so interactive
login wasn't possible without credentials nobody has (correctly not
attempted/guessed). What actually worked: `oci compute console-history
capture` + `get-content` (with `--offset`/`--length`, since the CLI default
only returns the first 10KB — the plain kernel boot log, cut off before
cloud-init even starts) pulled real cloud-init runcmd output off the serial
console ring buffer, no login required. A `SOFTRESET` (graceful reboot) on
instance 1 was used partway through to force a clean, fully-buffered boot
log rather than digging through a 2+-hour-old rotated buffer; the instance
came back up in under a minute and cloud-init's original (Sep 18) boot
output was still present in the captured history.

**Root cause: the backend instances have no route to the internet at
all — an OCI networking gap, not an app/OS-level bug.** Confirmed directly
in the captured console log for **both** instances:

```
[  102.030149] cloud-init[1617]: Cloning into '/opt/mymagnet-src'...
[  238.561280] cloud-init[1617]: fatal: unable to access 'https://github.com/rockkw/MyMagnet.git/':
  Failed to connect to github.com port 443 after 136479 ms: Couldn't connect to server
[  238.579810] cloud-init[1617]: sed: can't read /opt/mymagnet-src/deploy/setup.sh: No such file or directory
[  238.587215] cloud-init[1617]: bash: /opt/mymagnet-src/deploy/setup.sh: No such file or directory
```

preceded by every apt/InRelease fetch failing the same way (`Network is
unreachable` against both IPv4 and IPv6 mirror addresses). The very first
`runcmd` step — cloning the MyMagnet repo — times out after ~136s with no
route out, so `setup.sh` never exists to `sed`/run, nginx/venv/systemd
units never get installed, and that's why the LB sees `CONNECT_FAILED`: no
listener on port 80 was ever going to start. This is **not** the
previously-fixed `awscli` bug (never reached — moot, since the clone that
precedes it already failed) and **not** an iptables problem — the
`iptables -I INPUT ... ACCEPT` / `netfilter-persistent save` runcmd steps
are visible running successfully right after the failed clone/sed/setup.sh
lines, proving cloud-init's `runcmd` has no `set -e` and kept going past
each failure. Both instances hit the identical failure signature
independently, ruling out a one-off transient blip.

**Why there's no route:** `var.subnet_id` (both backend instances'
subnet, `lab-network-stack`'s `lab-subnet`, `10.0.1.0/24`) has a route
table sending `0.0.0.0/0` to an **Internet Gateway**
(`oci_core_internet_gateway` in `lab-network-stack/main.tf`). An IGW only
provides egress for a VNIC that itself holds a public IP. The 2-node/LB
redesign set `assign_public_ip = false` on both `oci_core_instance`
resources (correct, per that redesign's whole point — no direct public
entry point anymore) but never repointed the instances at a NAT-routed
subnet instead — so they went from "public IP + IGW" straight to "no
public IP + still IGW," which is no egress at all. The LB itself is
unaffected (it gets its own public IP via `reserved_ips`, independent of
instance-level `assign_public_ip`) and was in fact applied into the same
`lab-subnet` as the instances for this run (`lb_subnet_id` == `subnet_id`,
both the same OCID in state) — that part is fine and doesn't need to
change.

**Fix (written, not applied):** `lab-private-network-stack` (already
applied in this repo, real state) provisions exactly the missing piece —
a NAT Gateway + private subnet (`10.0.2.0/24`, `lab-private-subnet`,
`prohibit_public_ip_on_vnic = true`) with a route table sending `0.0.0.0/0`
to the NAT gateway. Its live `private_subnet_id` output:
`ocid1.subnet.oc1.phx.aaaaaaaag4oejcez5n7w77ixbt7qchi35wjulh7ear7o3htwkssroxo74b5a`.
Added a new `var.instance_subnet_id` variable (distinct from `lb_subnet_id`,
which must stay IGW/public-IP-capable for the LB) and pointed both
`oci_core_instance.mymagnet_1`/`mymagnet_2`'s `create_vnic_details.subnet_id`
at it instead of the old `var.subnet_id` (left declared but now unused, for
tfvars/CI backward-compat). `terraform validate` passes.

**Applied, with the user's explicit approval** (this was deliberately held
back from autonomous apply — `subnet_id` isn't mutable in-place on
`oci_core_instance`, so the fix forces replacement of both instances: new
private IPs, an `oci_load_balancer_backend` update to match, and fresh
per-instance SQLite state, a real visible change beyond "restart a
service"). Applied as two scoped `terraform apply -target=` runs (not a
full reapply, to avoid touching the still-broken Blocker 1 Certificates
chain in the same operation):
1. `-target=oci_core_instance.mymagnet_1 -target=oci_core_instance.mymagnet_2
   -target=oci_load_balancer_backend.mymagnet_1 -target=oci_load_balancer_backend.mymagnet_2`
   — replaced both instances onto the NAT-routed subnet (new private IPs
   `10.0.2.227`/`10.0.2.102`), but errored before creating the two
   `oci_load_balancer_backend` resources, on an **unrelated pre-existing
   drift** on `oci_core_public_ip.mymagnet`: real state still carried
   `private_ip_id` from this stack's pre-redesign single-instance
   deployment, and every plan since wanted to null it (correct, since the
   IP is LB-managed now via `reserved_ips`), but the live API rejects that
   update outright — `404-NotAuthorizedOrNotFound, "PublicIp cannot be
   assigned to or unassigned from PrivateIp ... as it is managed by
   <the LB>"`. **Fixed** with `lifecycle { ignore_changes = [private_ip_id] }`
   on that resource — the field is genuinely stale and the API won't let it
   change anyway, so telling Terraform to stop tracking it was the correct
   fix, not a workaround.
2. Re-ran the same targeted apply for just the two `oci_load_balancer_backend`
   resources — succeeded cleanly this time.

Verified end to end: `curl http://137.131.32.68/` → `200`, real HTML
(`<title>🧲 Magnet Library</title>`) confirmed in the response body — not a
placeholder or error page. `oci lb backend-set-health get` moved from
`CRITICAL`/`CONNECT_FAILED` to `WARNING` (both backends past the connect
failure; `WARNING` rather than immediate `OK` is expected right after a
fresh backend attaches, before the health checker's success-threshold
window elapses — not a new failure). A full `terraform plan` afterward
shows zero drift outside the still-open Blocker 1 resources below.

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

Depends on: `lab-network-stack` (`vcn_id`, `subnet_id`, and — per the
DESIGN-ONLY addition above — `lb_subnet_id`/`lb_subnet_cidr` for the LB)
Outputs (single-instance, applied version): `instance_id`, `public_ip`,
`backup_bucket_name`
Outputs (DESIGN-ONLY LB version, not yet applied): `instance_1_id`,
`instance_2_id`, `load_balancer_public_ip`, `load_balancer_id`,
`backup_bucket_name`, `certificate_authority_id`, `certificate_id`

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

### lab-basedb-stack

Lab 6 — Oracle Base Database Service, **applied and verified live**: a
single-instance VM DB System plus a ZPR policy protecting the database
listener — confirms ZPR applies to database resources directly, not just
compute, per the "ZPR applied to a database" section added to Note 6 from
this same MyLearn module.

**Builds on:** `lab-network-stack` (`vcn_id`, plus its VCN's own
`display_name` for the ZPR VCN-scope attribute) and
`lab-private-network-stack` (`private_subnet_id`) — the DB system gets no
public IP and reaches Object Storage (patching/backups) via the Service
Gateway `lab-private-network-stack` already provisions, not the internet.
Reuses `lab-zpr-stack`'s ZPR pattern (namespace/attribute, then a policy)
with its own separate `BaseDbLabRole` namespace, so this stack stays
independently destroyable without touching `lab-zpr-stack`'s own tags.

Depends on: `lab-network-stack` (`vcn_id`, VCN `display_name`),
`lab-private-network-stack` (`private_subnet_id`)
Outputs: `db_system_id`, `db_home_id`, `private_ip`, `scan_dns_name`

**Applied successfully — 10 resources, confirmed live against the real
API** (`oci db system get`, not just Terraform's own state):
`lifecycle-state: AVAILABLE`, shape `VM.BaseDB.x86`, hostname `basedblab`.
`terraform.tfstate` intentionally not committed (matches this repo's
existing pattern for every other lab).

**Four real bugs found and fixed across the design and apply passes, in
order — worth reading as a genuine debugging trail, not a single
"corrected the config" note:**
1. **`storage_management` isn't a top-level argument.** `terraform validate`
   rejected it directly on `oci_database_db_system` — confirmed via
   `terraform providers schema -json` that it's nested inside a
   `db_system_options` block. LVM chosen to match the Console's own
   default ("Recommended for quick deployments").
2. **`VM.Standard.E5.Flex` (the AMD *compute* shape shown in MyLearn's own
   slide) is not a valid DB System shape** — a real 400 InvalidParameter
   on first apply. DB System shapes are a **separate namespace** from
   compute instance shapes entirely; `oci db system-shape list` returned
   only `Exadata*`/`ExadataCC*`/`VM.BaseDB.x86`/`ExaDbXS` — no
   `VM.Standard.*` shapes at all. Corrected to **`VM.BaseDB.x86`**.
3. **`compute_model` isn't actually inferred despite being schema-marked
   "optional, computed."** Leaving it unset produced a real 400
   ("Invalid computeModel null for shape VM.BaseDB.x86") — "computed"
   here means the API reports a value back after creation, not that it
   will pick one for you. `oci db system-shape list` reports
   `compute-model=ECPU` for this shape; set explicitly.
4. **ECPU-based shapes take core count via a separate `compute_count`
   argument, not the legacy `cpu_core_count`.** With `compute_model =
   "ECPU"` set, `cpu_core_count` alone still failed ("computeCount cannot
   be null") — both attributes exist on the provider schema, but only one
   applies per compute model. Set `compute_count = 4` (this shape's
   `minimum-core-count`/`core-count-increment`, confirmed via the same
   `system-shape list` output) and dropped `cpu_core_count` entirely.
5. **Admin password complexity is stricter than the commonly-quoted
   rule.** An alphanumeric-only password (9-30 chars, upper/lower/digit,
   no username substring — the documented floor) was rejected: "The
   database admin password should contain at least two special
   characters." Base Database Service's real floor requires **≥2 special
   characters** on top of the usual rules.
6. **`oci_zpr_configuration` as a `resource` breaks when `lab-zpr-stack`
   has already applied** — ZPR tenancy onboarding is a real, tenancy-wide
   **singleton**; a second stack trying to `resource`-own it hit a real
   409 Conflict ("Configuration already exists"). Importing it into this
   stack's state was considered and rejected (a future `terraform destroy`
   here would then try to tear down onboarding `lab-zpr-stack` still
   depends on). Fixed by switching to a **`data` source** — a read-only
   confirmation ZPR is enabled, with no create/destroy lifecycle of its
   own.

**Deliberately narrow sizing, not a production reference**: 4 ECPUs (this
shape's real minimum, not a chosen value), 256 GB data storage (well
under the platform's 80 TB ceiling), Standard Edition licensing,
LICENSE_INCLUDED (no BYOL complexity), single node, Balanced storage
performance — see Note 6 for the full single-instance-vs-RAC ceiling
numbers this lab deliberately stays well under.

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

Depends on: `lab-oke-stack` (`cluster_id`, `kubernetes_version`, `workers_nsg_id`), `lab-private-network-stack` (`private_subnet_id`)
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

### lab-zpr-stack

Zero Trust Packet Routing, provisioned entirely via Terraform. Mirrors the
MyLearn "Scenario" lab exactly: two Compute instances (VM-01, VM-02) on one
public subnet, a security list wide open on port 22 from `0.0.0.0/0` (the
scenario's own deliberately-over-permissive starting point), an NSG fix
restricting VM-02's SSH ingress to VM-01's private IP only (the scenario's
first stated remediation), and a ZPR policy layered on top that holds
regardless of what the security list or NSG say. See
[[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the full
concept writeup — the Science App and CarCo scenarios this stack's ZPR layer
is modeled on — and [[Lab 5 - OCI Architect Pro Exam - Zero Trust Packet Routing]]
for this stack's full lab writeup (checklist, verification steps, recall
exercises).

**Standalone** — its own VCN/subnet, not built on `lab-network-stack` or
`lab-nsg-stack`, so it has no apply-order dependency on any other stack.

Outputs: `vm_01_public_ip`, `vm_01_private_ip`, `vm_02_public_ip`, `zpr_policy_id`

**Four-part ZPR layer, none of which existed as a single `oci_zpr_*` resource
the way the earlier "candidate" note assumed:**

1. `oci_zpr_configuration` — one-time tenancy (root compartment) onboarding.
2. `oci_security_attribute_security_attribute_namespace` — a custom
   namespace (`ZprLabRole`), since a real tenancy must define its own rather
   than relying on the sample `Oracle-DataSecurity-ZPR` namespace shown in
   Oracle's own provider docs.
3. `oci_security_attribute_security_attribute` — an `ENUM`-validated
   attribute (`SshRole`, values `trusted-source` / `ssh-target`) inside that
   namespace. This pairing (namespace + attribute) is the ZPR-specific
   analog of `oci_identity_tag_namespace`/`oci_identity_tag` for regular
   defined tags — a separate `Security Attribute` service, not `Identity`.
4. `oci_core_instance.security_attributes` — a map argument directly on
   each instance (`"ZprLabRole.SshRole.value" = "trusted-source"` /
   `"ssh-target"`), **not** inside `create_vnic_details` — the OCI API
   rejects `security_attributes` supplied in both places on one launch
   request, so this stack sets it only on the top-level instance resource.

`oci_zpr_zpr_policy.ssh_lockdown`'s single statement then ties it together:
```
endpoint type='compute' from security_attribute='ZprLabRole.SshRole.trusted-source'
to security_attribute='ZprLabRole.SshRole.ssh-target' with protocol='tcp/22' allow
```

**Verification history — this took two research passes to get right, worth
recording since the wrong syntax still produces a schema-valid `terraform
validate` pass:**
- First pass used freeform, unnamespaced strings
  (`security_attribute='vm:trusted-source'`) based only on the MyLearn
  slides' `#app:science`-style tag syntax, which is UI shorthand, not the
  underlying data model. `terraform validate` accepted this silently — it
  only checks HCL syntax, not whether a string argument matches the OCI
  API's expected format.
- Second research pass confirmed against the provider's own doc source
  (raw `core_instance.html.markdown`) that `security_attributes` values are
  namespaced exactly like defined tags: `"<Namespace>.<AttributeName>.value"
  = "<value>"`. This surfaced the further fact that the namespace/attribute
  are themselves real, separately-provisioned resources
  (`oci_security_attribute_security_attribute_namespace` /
  `oci_security_attribute_security_attribute`), not implicit strings — the
  original "candidate" note in this file didn't know these existed.
- `terraform plan` against the live tenant (compartment `sandbox`) with this
  corrected syntax succeeded cleanly: **13 resources to add, 0 errors** —
  confirms schema/argument-shape correctness, though the ZPR Policy
  Language *statement string itself* remains free text to Terraform and the
  API would only reject a semantically malformed statement at `apply` time,
  which this lab has not yet done (see `## Notes` below).

**Known unresolved question, flagged rather than guessed:** the exact
complete grammar of ZPR Policy Language (e.g. the full enum of valid `mode`
values beyond `audit`, whether `with protocol=` is the correct clause name
versus something else) was not confirmed against Oracle's own ZPR conceptual
docs, which returned only high-level text on repeated fetch attempts. If
`terraform apply` is ever run against this stack, treat the `statements`
line as the most likely single point of failure and be ready to revise its
exact wording against the real API error message.

### lab-firewall-stack

Network Firewall in-line + out-of-band inspection, provisioned entirely via
Terraform and **applied and verified against real OCI** (not just dry-run).
Mirrors the MyLearn diagram exactly: a Consumer VCN with five subnets
(Application, Web-LB, Firewall, VTAP-Target-NLB, Network-Analytics), a Web LB
fronting two web-server instances, a Network Firewall sitting in its own
subnet handling both flows, a VTAP mirroring the Web-LB's live traffic to a
Network Load Balancer, and a Wireshark instance as the out-of-band flow's
final offline-analysis destination. See
[[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the full
four-stage packet-pipeline writeup (Decryption → Security → Tunnel Inspection
→ NAT), the SNAT rationale, VXLAN encapsulation mechanics, and the tunnel
inspection two-stage handoff this stack's policy resources implement.

**Standalone** — its own VCN/subnet, no apply-order dependency on any other
stack.

Outputs: `web_lb_public_ip`, `web_server_1_private_ip`, `web_server_2_private_ip`

**Applied resource count: 30**, confirmed via `terraform state list` and
independently verified against the live OCI API (not just Terraform's local
state) — `oci network-firewall network-firewall get` returns
`lifecycle-state: ACTIVE` for the firewall itself, and
`oci network vtap get` confirms `is-vtap-enabled: true`,
`lifecycle-state: AVAILABLE` for the VTAP.

**Real gotchas confirmed against the live API, not just provider docs:**

1. **Route tables cannot take a Network Firewall's OCID directly.** OCI
   auto-creates a private IP object for the firewall when it's provisioned
   into its subnet; `network_entity_id` on a route rule only accepts
   gateway/private-IP-shaped OCIDs (DRG/IGW/NAT/SGW/LPG/Private IP — no
   "Network Firewall" target type), so the firewall's own private IP has to
   be looked up via `data.oci_core_private_ips`, not referenced as a
   resource attribute.
2. **`nat_configuration { must_enable_private_nat = false }` is a required
   block**, not optional, on `oci_network_firewall_network_firewall`.
3. **A tunnel inspection rule's `condition` block only accepts
   `destination_address`/`source_address` (address-list names) — no
   `protocol` field inside it.** `protocol` is top-level on the resource
   itself (currently only `"VXLAN"` is valid), separate from the match
   condition.
4. **Valid tunnel inspection `action` values: `INSPECT` or
   `INSPECT_AND_CAPTURE_LOG`** — matches the Console's "Inspect and capture
   log" dropdown option exactly.
5. **`oci_core_vtap` rejects `is_vtap_enabled = true` at creation outright** —
   confirmed by a real `terraform apply` failure: `400-InvalidParameter, VTap
   cannot be enabled at creation`. The real OCI API requires creating the
   VTAP disabled first, then a separate `UpdateVtap` call to enable it. Fixed
   with a two-phase apply: create with `is_vtap_enabled = false`
   (`-target=oci_core_vtap.web_lb_vtap`), then flip the config to `true` and
   re-apply, which Terraform correctly resolves as an in-place update rather
   than a replacement. This is the one resource in the whole 30-resource plan
   that couldn't be created in a single `apply` — every other resource
   (including the Network Firewall itself, which took **36m38s** to reach
   `ACTIVE` — by far the slowest single resource in any lab stack here)
   applied cleanly on the first pass.

### lab-capstone-vllm-stack
Phase 4 of the [MyMagnet capstone](CAPSTONE.md): serves `Qwen/Qwen2.5-7B-Instruct`
with vLLM on `lab-oke-gpu-stack`'s A10 node, behind an **internal** OCI load
balancer in the private subnet `10.0.2.0/24`. vLLM exposes an OpenAI-compatible API
(`/v1/chat/completions`, `/v1/models`), so the Phase 3 Function and, possibly, Phase 2
Select AI can call it like any OpenAI endpoint.

Split the same way as `lab-oke-app-stack`: Terraform owns only OCI resources, and
the Kubernetes objects are plain YAML applied with `kubectl`. The YAML lives in
[`vllm.yaml.tftpl`](lab-capstone-vllm-stack/vllm.yaml.tftpl) and Terraform renders it
into the `vllm_manifest` output, so the NSG and subnet OCIDs don't have to be pasted in
by hand.

**Builds on:** `lab-oke-stack` (cluster, `lab-oke-workers-nsg`), `lab-oke-gpu-stack`
(the A10 pool), `lab-private-network-stack` (the LB's subnet).

Depends on: `lab-oke-stack` (`workers_nsg_id`), `lab-network-stack` (`vcn_id`), `lab-private-network-stack` (`private_subnet_id`)
Outputs: `lb_nsg_id`, `vllm_manifest`

**Region and VCN (checked against state and the live API, 2026-09-24).**
`lab-oke-cluster` is in **us-phoenix-1**, in `lab-vcn`
(`ocid1.vcn.oc1.phx.amaaaaaafr5ivrya…hpbea`). That's the **same VCN** as
`lab-mymagnet-stack`, and the CPU workers (`10.0.2.12`, `10.0.2.205`) are in the
**same subnet** as the MyMagnet instances (`lab-private-subnet`, `10.0.2.0/24`). So
none of the cross-VCN options are needed:

| Option | When it would apply | Verdict |
|---|---|---|
| Build the LB in the MyMagnet VCN | Cluster in another VCN, same region | Already the case: nothing to do |
| Peer with a Local Peering Gateway, or a DRG | Cluster in another VCN (LPG same region, DRG + RPC cross-region) | Not needed |
| Move/rebuild the cluster | Cluster in another region | Not needed |

`oci ce cluster list` shows the cluster `ACTIVE` and `lab-node-pool` (2 × A1.Flex)
`ACTIVE`; `kubectl get nodes` shows both nodes `Ready`. No GPU pool exists yet
(`lab-oke-gpu-stack` has no state).

**GPU quota (Phoenix, 2026-09-24):** `gpu-a10-count` is 32 per AD, and
`oci limits resource-availability get … --limit-name gpu-a10-count --availability-domain bXWp:PHX-AD-1`
returns 32 available, 0 used. The pool goes in AD-1, so no limit increase is needed.

**What the stack creates** (plan: 6 to add, 0 to change, 0 to destroy):
- `lab-capstone-vllm-lb-nsg`, attached to the LB through the
  `oci.oraclecloud.com/oci-network-security-groups` annotation.
  - Ingress TCP 80 from `client_cidr` (`10.0.2.0/24`).
  - Egress to the workers NSG on the NodePort range (30000–32767) and kube-proxy's
    health-check port 10256.
- Two ingress rules added to `lab-oke-workers-nsg` (from the LB NSG, same ports).
  The stack references that NSG by OCID and doesn't own it, so `destroy` only removes
  these two rules.

The Service sets `oci.oraclecloud.com/security-rule-management-mode: "None"`, so the
cloud controller manager doesn't edit security lists or create its own NSG; every rule
is in Terraform. The private subnet's security list only opens 22/443/ICMP, so these
NSG rules are what let the traffic through (NSG and security-list rules are combined).

**Changes to the upstream stacks, needed for Phase 4:**
- `lab-oke-stack` gets a `workers_nsg_id` output (output only; no resource change).
- `lab-oke-gpu-stack` now puts the GPU nodes in the workers NSG (`nsg_ids` and
  `pod_nsg_ids`, new required variable `workers_nsg_id`). Without it, GPU nodes
  would hit the same "register timeout" the CPU pool did before the NSG fix.
- `lab-oke-gpu-stack` also raises the boot volume to 150 GB and adds Oracle's
  documented cloud-init (fetch `oke_init_script`, run `oci-growfs -y`, run the init
  script). The vLLM image is about 20 GB unpacked, which is tight on the default 50 GB
  boot volume. Plan: 1 to add, with the image resolved to
  `Oracle-Linux-9.8-Gen2-GPU-2026.08.14-0-OKE-1.36.1-1699`.

**Model: `Qwen/Qwen2.5-7B-Instruct`, pinned to revision `a09a3545…8bc28`.**
- Apache-2.0 and not gated (checked with the Hugging Face API), so no HF token or
  Secret is needed.
- 7.6B parameters is about 15.2 GB in bf16. The A10 supports bf16.
- With `--gpu-memory-utilization=0.90`, vLLM gets about 21.6 GB of the A10's 24 GB.
  That leaves roughly 4–5 GB for KV cache after weights and CUDA graphs.
- Qwen2.5-7B uses GQA (28 layers, 4 KV heads × 128), about 56 KB of KV per token, so
  that's room for tens of thousands of cached tokens.
- `--max-model-len=8192` (the model's native context is 32K) keeps one long request
  from claiming the whole cache. It's plenty for enrichment prompts.
- Fallback if it runs out of memory: `Qwen/Qwen2.5-1.5B-Instruct` (also Apache-2.0,
  about 3 GB). Avoid `Qwen2.5-3B-Instruct`, which uses the Qwen Research license
  rather than Apache-2.0.
- Llama 3.x and Gemma are gated behind a license click-through, so they'd need an HF
  token.

**Deployment details** (`vllm.yaml.tftpl`):

| Setting | Value | Why |
|---|---|---|
| Image | `vllm/vllm-openai:v0.30.0-x86_64-cu129` | Pinned release (2026-09-22). The cu129 build runs on older drivers than the default CUDA 13 build; check `nvidia-smi` on the node before moving to CUDA 13 |
| GPU | `nvidia.com/gpu: 1` (request and limit) | OKE's `nvidia-gpu-device-plugin` DaemonSet is already in `kube-system` and schedules onto A10 shapes |
| Node selector | `beta.kubernetes.io/instance-type: VM.GPU.A10.1` | The same label OKE's device plugin uses for node affinity |
| Toleration | `nvidia.com/gpu` Exists / NoSchedule | OKE doesn't taint GPU nodes by default (Oracle's GPU page shows no toleration). This only matters if a taint is added later |
| Probes | `startupProbe` (up to 20 min), `readinessProbe` and `livenessProbe` on `/health` | The first start downloads 15 GB of weights. `/health` isn't behind the API key |
| Model cache | 50 Gi `oci-bv` PVC at `/models` (`HF_HOME=/models/hf`) | Keeps weights off the boot volume and across pod restarts. 50 GB is the `oci-bv` minimum |
| `/dev/shm` | 2 Gi memory `emptyDir` | vLLM uses shared memory; the container runtime's default is small |
| Strategy | `Recreate` | There's only one GPU, so the old pod must release it before the new one starts |
| Auth | `--api-key=$(VLLM_API_KEY)` from Secret `vllm-api-key` | Anything in `10.0.2.0/24` can reach the LB, including every OKE pod (VCN-native pod IPs come from the same subnet). The key is the only thing separating MyMagnet from any other workload in the subnet |

**Service annotations**, checked against Oracle's
[Configuring Load Balancers and Network Load Balancers](https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengconfiguringloadbalancersnetworkloadbalancers-subtopic.htm)
page rather than written from memory:

| Annotation | Value |
|---|---|
| `oci.oraclecloud.com/load-balancer-type` | `"lb"` (a Layer 7 LB rather than an NLB) |
| `service.beta.kubernetes.io/oci-load-balancer-internal` | `"true"` |
| `service.beta.kubernetes.io/oci-load-balancer-subnet1` | `lab-private-subnet` OCID. Without this, the LB would go in the cluster's `service_lb_subnet_ids` (the **public** subnet) |
| `service.beta.kubernetes.io/oci-load-balancer-shape` | `"flexible"`, with `-shape-flex-min`/`-shape-flex-max` = `"10"` |
| `oci.oraclecloud.com/security-rule-management-mode` | `"None"`. Other values are `NSG` (the CCM creates its own NSG), `SL-All` (the default for LBs) and `SL-Frontend` |
| `oci.oraclecloud.com/oci-network-security-groups` | The stack's `lb_nsg_id` |

Optional, not used: `oci.oraclecloud.com/reserved-private-ips` would pin the LB to a
fixed IP in `10.0.2.0/24`. It's supported on Kubernetes 1.32+ (the cluster runs
1.36.1) and would save updating the Function config after every rebuild.

**Validation (2026-09-24):**
- `terraform fmt -check` and `terraform validate`: pass, for this stack and for
  `lab-oke-gpu-stack`.
- `terraform plan` against the live tenant: 6 to add here, 1 to add for
  `lab-oke-gpu-stack`.
- The manifest was rendered with a placeholder NSG OCID, and
  `kubectl apply --dry-run=client` created all four objects in dry-run mode:
  Namespace, PVC, Deployment and Service.
- Nothing has been applied.

**Cost.** `VM.GPU.A10.1` is roughly $2/hour at list price (confirm on Oracle's price
list) and bills whenever the instance runs, even with no traffic. The 150 GB boot
volume, the 10 Mbps flexible LB and the 50 GB PVC are small next to that. Only keep
the GPU pool while testing; a 2-hour session is about $4–5.

#### Runbook: bring up

```bash
cd terraform
export SUPPRESS_LABEL_WARNING=True

# 0. Confirm A10 capacity in PHX-AD-1 (read-only)
oci limits resource-availability get --compartment-id <compartment_ocid> \
  --service-name compute --limit-name gpu-a10-count \
  --availability-domain bXWp:PHX-AD-1 --region us-phoenix-1

# 1. Publish the workers NSG output (no resource changes)
(cd lab-oke-stack && terraform apply)          # same -var flags as before
(cd lab-oke-stack && terraform output workers_nsg_id)

# 2. GPU pool: about 10-20 min. Billing starts here.
(cd lab-oke-gpu-stack && terraform plan && terraform apply)
kubectl get nodes -l beta.kubernetes.io/instance-type=VM.GPU.A10.1
kubectl describe node <gpu-node-ip> | grep nvidia.com/gpu   # expect Capacity 1

# 3. LB NSG and rules, then render the manifest
(cd lab-capstone-vllm-stack && terraform plan && terraform apply)
(cd lab-capstone-vllm-stack && terraform output -raw vllm_manifest > /tmp/vllm.yaml)

# 4. API key Secret first, then everything else
kubectl create namespace vllm
kubectl -n vllm create secret generic vllm-api-key \
  --from-literal=api-key="$(openssl rand -hex 32)"
kubectl apply -f /tmp/vllm.yaml
kubectl -n vllm rollout status deploy/vllm --timeout=30m
kubectl -n vllm logs deploy/vllm | tail          # model loaded, "Application startup complete"
kubectl -n vllm get svc vllm                     # EXTERNAL-IP should be a 10.0.2.x address
```

#### Runbook: smoke test

Clients must be in `10.0.2.0/24`. A throwaway pod on the CPU nodes counts, because
VCN-native pod IPs come from that subnet. Otherwise run the same `curl` from a
MyMagnet instance.

```bash
LB_IP=$(kubectl -n vllm get svc vllm -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
KEY=$(kubectl -n vllm get secret vllm-api-key -o jsonpath='{.data.api-key}' | base64 -d)

kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s http://$LB_IP/v1/chat/completions \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"qwen2.5-7b-instruct","messages":[{"role":"user","content":"Reply with exactly five words."}],"max_tokens":32}'

# Negative checks
kubectl run curl --rm -it --restart=Never --image=curlimages/curl -- \
  curl -s -o /dev/null -w '%{http_code}\n' http://$LB_IP/v1/models   # expect 401 (no key)
curl -m 5 http://$LB_IP/health    # from the laptop: should time out (internal LB, private IP)
```

#### Runbook: tear down (the same day)

Order matters. The LB's VNIC holds the LB NSG, so the Service has to go before
`terraform destroy` can delete the NSG.

```bash
# 1. Delete the Service (the CCM deletes the LB) and the Deployment
kubectl -n vllm delete svc vllm
kubectl -n vllm delete deploy vllm
oci lb load-balancer list --compartment-id <compartment_ocid> --region us-phoenix-1 \
  --query 'data[]."display-name"'    # wait until the vLLM LB is gone

# 2. Remove the GPU pool. This is the step that stops the ~$2/h.
(cd lab-oke-gpu-stack && terraform destroy)
oci ce node-pool list --compartment-id <compartment_ocid> --region us-phoenix-1 \
  --query 'data[].{name:name,shape:"node-shape",state:"lifecycle-state"}' --output table
# expect only lab-node-pool

# 3. Optional: keep or drop the model cache and the NSG rules
kubectl delete namespace vllm                       # also deletes the PVC and its block volume
(cd lab-capstone-vllm-stack && terraform destroy)   # NSGs are free, so this can wait
```

Keeping the `vllm` namespace (and PVC) between sessions avoids re-downloading 15 GB.
The PVC's block volume costs only a little per month and stays in PHX-AD-1, the same
AD the GPU pool uses.

**Select AI (Phase 2) as a client.** The ADB private endpoint will be in
`10.0.2.0/24`, so `client_cidr` already covers it. Its NSG needs egress to the LB IP on
port 80, and the database needs a network ACL for the host
(`DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE`). **Unconfirmed: whether Select AI's
`provider_endpoint` accepts plain `http://`.** It may require HTTPS. Test before
relying on it.

**HTTPS later (not built).** The listener is plain HTTP on purpose. The earlier
attempt to issue a private CA certificate from OCI Certificates failed on IAM (see
CAPSTONE.md, Phase 1). Two ways to add TLS once a certificate exists:
1. Terminate TLS at the LB, using the CCM's SSL-port and TLS-secret annotations
   (check the exact names on the same Oracle page first), with port 443 on the LB
   NSG.
2. Pass TCP through to vLLM, started with `--ssl-certfile`/`--ssl-keyfile` from a
   mounted Secret.

Option 1 keeps certificates out of the pod and matches how `lab-mymagnet-stack`'s
public LB was set up.

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
| `lab-zpr-stack` | 13 to add | Real values (`sandbox` compartment, real tenancy OCID) — standalone, no placeholders needed. First attempt used unnamespaced `security_attribute` strings guessed from MyLearn's UI-level tag syntax; `terraform validate` passed but the syntax didn't match the real API. Corrected after confirming the provider's actual `security_attributes` map format against its doc source, which also surfaced that the namespace/attribute are their own resources (`oci_security_attribute_security_attribute_namespace`/`oci_security_attribute_security_attribute`) not implicit strings. The ZPR Policy Language statement text itself is unverified beyond schema-level string validity — flagged as the most likely failure point if this is ever applied. |
| `lab-firewall-stack` | **Applied**: 30 added, 0 errors (after one fix) | `terraform validate`/`plan` passed cleanly on the first attempt — config was schema-correct throughout. `terraform apply` itself hit one real API-level rejection `terraform plan` couldn't have caught: `oci_core_vtap` with `is_vtap_enabled = true` fails at creation (`400-InvalidParameter, VTap cannot be enabled at creation`), since the real API requires create-disabled-then-enable. Fixed with a two-phase apply (create `false`, flip to `true`, re-apply). Every other resource, including the Network Firewall itself (36m38s to `ACTIVE`), applied on the first pass. Independently verified against the live API post-apply via `oci network-firewall network-firewall get` and `oci network vtap get`, not just Terraform's own state. |

---

### lab-capstone-observability-stack

Capstone Phase 5 (see [CAPSTONE.md](CAPSTONE.md)): logs, alarms and log
archiving for the running `lab-mymagnet-stack` deployment in us-phoenix-1.
IAM resources use a `home` provider alias (us-ashburn-1). **Not applied.**

**Depends on `lab-mymagnet-stack`**: pass `instance_1_id`, `instance_2_id` and
`load_balancer_id` from its `terraform output`. `alarm_email` has no default.

- **Logging**: one log group, three custom logs (`app` =
  `/opt/magnetlookup/data/logs/*`, `nginx-access` with the `APACHE2` parser,
  since nginx's default `combined` format matches it, and `nginx-error`), and
  one `oci_logging_unified_agent_configuration` per log (a config has one
  destination log). The host group is a new dynamic group
  `mymagnet-uma-dyn-grp` matching both instance OCIDs, with
  `use log-content` on the compartment. That verb is from Oracle's Logging docs:
  it covers downloading the agent config, sending logs and searching them.
- **Ampere caveat, verified**: Oracle's Oracle Cloud Agent plugin docs state
  that the **Custom Logs Monitoring plugin is not supported on Ampere A1
  shapes**, and both instances are `VM.Standard.A1.Flex`. The agent
  configuration alone collects nothing. Workaround: install the standalone
  Unified Monitoring Agent by hand. Oracle ships an aarch64 `.deb` for
  Ubuntu 24.04 (`unified-monitoring-agent-ub-24-<ver>.aarch64.deb`) from the
  public `unified-monitoring-agent-ub-bucket` in namespace `axmjwnk4dzjv`
  ([Installing the Agent](https://docs.oracle.com/en-us/iaas/Content/Logging/Task/installing_the_agent.htm)),
  then `dpkg -i` it on each instance. **Unverified:** the install page lists
  "Custom Logs Monitoring plugin enabled" as a prerequisite, which contradicts
  the A1 restriction. Test on one instance before relying on it. Fallbacks:
  move to `VM.Standard.E5.Flex` (x86, plugin supported), or have the app call
  the Logging `PutLogs` API with its instance principal.
- **Alarms → Notifications topic `mymagnet-alarms`** (email subscription;
  OCI sends a confirmation link first):
  `unhealthyBackendServers[1m]{…backendSetName}.max() > 0` (CRITICAL, 5 min
  pending); `httpResponses5xx[5m]{…backendSetName}.sum() > 5` (backend-generated
  5xx); `CpuUtilization[5m]{resourceId =~ "id1|id2"}.mean() > 80` with
  per-dimension notifications. `oci_lbaas` metric names and the `=~` `|` OR
  syntax were checked against Oracle's LB metrics and MQL references.
  `CpuUtilization` needs the Compute Instance Monitoring plugin. That plugin
  *is* supported on A1 and is enabled in state (`is_monitoring_disabled = false`).
- **Optional Connector Hub archive** (`enable_log_archive`, default `true`):
  `oci_sch_service_connector` from the whole log group to the
  `mymagnet-log-archive` bucket, rolling files every 7 min (the documented
  limit). A lifecycle policy moves objects to ARCHIVE at 30 days and deletes them
  at 365 days. Archive tier has a 90-day minimum charge, so keep
  delete ≥ archive + 90. It needs two policies: Oracle's `any-user … where
  request.principal.type='serviceconnector'` bucket template, and the
  `Allow service objectstorage-us-phoenix-1 to manage object-family`
  service permission that lifecycle rules need. The Oracle docs say to put the
  second one in the tenancy root. No such policy existed for Phoenix; checked
  with `oci iam policy list`.

`terraform validate` passes (provider 9.3.0). `terraform plan`: **19 to add**
(14 with `-var enable_log_archive=false`). 4 of those are IAM resources (1 dynamic
group, 3 policies; 2 without the archive), so a person has to run the apply.

---

## Capstone labs

See [CAPSTONE.md](CAPSTONE.md) for how these fit together.

### lab-capstone-enrich-stack

Capstone Phase 3: event-driven enrichment of MyMagnet results. A results bucket
(`mymagnet-results`, with `object_events_enabled = true`), an Events rule on
`com.oraclecloud.objectstorage.createobject` filtered to that bucket, a Python
(fdk) Function that reads the new object, asks an LLM for tags and a summary, and
writes `enriched/<object>.enrichment.json` to a second bucket
(`mymagnet-enrichment`). A dynamic group + policy give the function resource-principal
access scoped to the two buckets.

**Builds on:** `lab-document-understanding-stack` (same Events → Function shape,
same resource-principal dynamic group) and `lab-func-stack` (Functions application).
Differences, and why:

- **Private subnet.** The function runs in MyMagnet's NAT-routed `10.0.2.0/24`
  subnet, not a public one, because Phase 4's vLLM sits behind an *internal* LB.
  That subnet also routes Oracle services through a service gateway, so Object
  Storage and OCIR traffic stays off the internet (checked read-only 2026-09-24).
  The function gets its own NSG (`function_nsg_id` output). Phase 4's LB NSG
  can later allow ingress from that NSG instead of the whole subnet.
- **The model is a config value, not code.** `LLM_ENDPOINT` / `LLM_MODEL` come from
  the function's config map (`llm_endpoint` / `llm_model` variables). While
  `llm_endpoint` is empty, the function writes a deterministic placeholder
  (`tags = ["placeholder", "ext:<extension>"]`, summary = first line), so the whole
  pipeline can be tested before any GPU exists. The model call uses stdlib
  `urllib` against the OpenAI-compatible `/v1/chat/completions`. A timeout or bad
  reply still writes a record with `status = "llm_error"`, so a failure leaves
  something visible in the bucket.
- **API key from Vault.** `lab-capstone-vllm-stack` starts vLLM with `--api-key`.
  Set `llm_api_key_secret_ocid` to a Vault secret holding the same value. The
  function reads it via resource principal and sends it as `Authorization:
  Bearer`, and the policy gains `read secret-bundles` on that one secret only.
  This keeps the key out of the function's config map and out of plan output.
- **Events actually fire.** Object Storage emits object events only when the bucket
  has `object_events_enabled = true` (default false).
  `lab-document-understanding-stack` doesn't set it, so its rule would never fire.
- **Events needs its own grant.** `Allow service cloudEvents to use functions-family
  in compartment ...`. Without it, the rule matches but the invocation is denied.
  No such statement existed in the tenancy yet.
- **Rule filters on the bucket.** `condition_details.data` matches
  `additionalDetails.bucketName`. func.py checks the bucket again, and output
  goes to a separate bucket, so the function's writes can't re-trigger it.
- **ADB hook.** `write_to_adb()` in func.py is a marked no-op (`ADB_ENABLED=false`)
  until Phase 2's Autonomous DB exists. For now the output bucket holds the results.
- **`source_details { source_type = "CONTAINER_IMAGE" }`** replaces the top-level
  `image` argument the older labs use. Provider 9.x deprecates `image`.

Depends on: `lab-network-stack` (`vcn_id`), `lab-private-network-stack`
(`private_subnet_id` → `subnet_ocid`), `lab-mymagnet-stack` (its instance dynamic
group is granted write on the results bucket via `writer_dynamic_group_name`)
Outputs: `input_bucket_name`, `output_bucket_name`, `function_id`, `function_nsg_id`,
`events_rule_id`, `dynamic_group_id`

**Status (2026-09-24): not applied.** `terraform validate` is clean. `terraform plan`
against the live tenant shows 9 to add, 0 to change, 0 to destroy (with a placeholder
image path). 9 unit tests pass (`python3 -m unittest discover -s tests -v`): the
placeholder path, bucket and event skips, a mocked LLM reply (including a
Markdown code-fenced JSON reply), the Bearer token from a mocked secret, a mocked
timeout, and the ADB hook.

**Build and push the image first.** `oci_functions_function` needs the image to
exist in OCIR in the function's region (Phoenix):

```bash
cd terraform/lab-capstone-enrich-stack
python3 -m unittest discover -s tests -v

# Auth token: Console → Profile → Auth tokens. Username is
# <namespace>/<username>, or <namespace>/<identity-domain>/<username>
# for a non-Default identity domain.
docker login phx.ocir.io -u 'idtlmgo3jgde/<username>'

# Functions shape is GENERIC_X86, so build amd64 even on Apple Silicon.
docker build --platform linux/amd64 -t phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1 .
docker push phx.ocir.io/idtlmgo3jgde/capstone/enrich:0.0.1
# (The push auto-creates a private repo in the root compartment. To put it
# in the lab compartment, create it first:
#  oci artifacts container repository create --compartment-id <compartment> \
#    --display-name capstone/enrich --region us-phoenix-1)

# Or with the fn CLI (it generates its own Dockerfile from func.yaml):
#   fn create context phx --provider oracle
#   fn use context phx
#   fn update context registry phx.ocir.io/idtlmgo3jgde/capstone
#   fn build && fn push     # then set function_image to the pushed tag
```

**Apply and test (placeholder mode):** `terraform.tfvars` (gitignored) holds the
OCIDs, copied from `lab-mymagnet-stack/terraform.tfvars`. Apply creates IAM in the
home region, and IAM changes can take a minute or two to propagate. If the first
upload fails, wait and retry.

```bash
terraform plan && terraform apply
echo "Ubuntu 24.04 LTS desktop ISO" > r.txt
oci os object put -bn mymagnet-results --file r.txt --region us-phoenix-1
oci os object get -bn mymagnet-enrichment --name enriched/r.txt.enrichment.json \
  --file - --region us-phoenix-1
```

**Phase 4 hookup:** `lab-capstone-vllm-stack`'s LB NSG already admits
`10.0.2.0/24` on port 80, which covers this function. Put the `vllm-api-key` value
in a Vault secret, then:

```bash
terraform apply -var llm_endpoint=http://<internal-lb-ip> \
  -var llm_model=qwen2.5-7b-instruct \
  -var llm_api_key_secret_ocid=<vault-secret-ocid>
```

This changes config and IAM only, so no image rebuild is needed. The LLM timeout
defaults to 60s. The function timeout is that plus 60s, and OCI caps it at 300s.

### lab-capstone-adb-stack

Capstone Phase 2: MyMagnet's library moves from a separate SQLite file on each
node to one **Autonomous AI Database** (Serverless, Transaction Processing,
`db_version = "26ai"`). **AI Vector Search** runs on embeddings computed inside
the database by Oracle's prebuilt ONNX `all-MiniLM-L12-v2` model. The stack
creates a private endpoint in the instance subnet, an NSG that opens 1522 to
`10.0.2.0/24` only, generated passwords stored as Vault secrets, a bucket for
the ONNX file, and one IAM policy. It also contains `sql/` scripts and a drafted
app patch (`app-patch/`).

**Builds on:** `lab-basedb-stack`'s pattern (private subnet, an NSG on the
listener port only, no public IP) and `lab-mymagnet-stack` (its Vault, and its
instance dynamic group for the secret-read policy). Differences, and why:

- **26ai, not 23ai.** A read-only `oci db autonomous-db-version list
  --db-workload OLTP` in us-phoenix-1 (2026-09-24) returned 19c, 23ai and 26ai,
  with **26ai as `is-default-for-paid`**. Oracle now calls the service
  "Autonomous AI Database". The vector features (the `VECTOR` type,
  `VECTOR_EMBEDDING`, vector indexes) are the same from 23ai onwards. 23ai
  still works via `-var db_version=23ai`.
- **Why not Always Free.** Oracle's Always Free docs rule it out for this
  design. Always Free ADB is **home-region only** (Ashburn, while MyMagnet runs
  in Phoenix). It "cannot be provisioned as a private endpoint and cannot
  reside within a VCN". It stops after 7 idle days and may be reclaimed after
  90. Using it would mean public, cross-region traffic from the NAT gateway,
  allowed by an ACL. The private endpoint + NSG pattern is the part worth
  studying, so this stack uses the smallest paid database instead: **2 ECPUs
  (the minimum), 20 GB, auto-scaling off for both CPU and storage.** Stop it
  between study sessions; a stopped ADB bills storage only.
- **Port 1522 only.** Oracle's private-endpoint docs say mTLS uses 1522 and TLS
  uses 1521 **or** 1522. `is_mtls_connection_required = false` (TLS without a
  wallet is allowed once the database has a private endpoint) lets
  python-oracledb Thin mode connect with just user, password and DSN, and 1521
  stays closed. The NSG has no egress rule: the rules are stateful, so replies
  are allowed. Phase 4's Select AI will need an egress rule to the vLLM LB.
- **The ADMIN password comes from a Vault secret, not a plain argument.**
  `random_password` produces the value, `oci_vault_secret` stores it, and the ADB
  uses `secret_id`. The person running the apply needs `read secret-bundles` on
  that secret; the Administrators group already has it. The password is still in
  this stack's local, gitignored state, because `random_password` puts it there.
  The special characters are limited to `- _ #`. ADB's documented rule is
  looser (12–30 chars, upper/lower/digit, no `"`, doesn't contain "admin"), but
  `lab-basedb-stack` hit a 400 with other special characters on Base DB, and
  these three are also safe in shells and DSNs.
- **A new AES key.** Vault secrets must be encrypted with an AES key. The
  existing `mymagnet-cert-key` is RSA (it was made for the Phase 1 CA), so this
  stack adds `mymagnet-secrets-key` (AES-256, `length = 32` bytes) to the same
  Vault. The Vault OCID and management endpoint come in as variables.
- **The model is loaded from a PAR, with no credential.**
  `DBMS_VECTOR.LOAD_ONNX_MODEL_CLOUD` reads one `.onnx` object, but Oracle ships
  the model as a zip. So the file is unzipped, uploaded to `mymagnet-onnx-models`,
  and read through a read-only PAR with `credential => NULL`, which Oracle's docs
  show for PAR URIs. Without `ROUTE_OUTBOUND_CONNECTIONS = ENFORCE_PRIVATE_ENDPOINT`,
  `DBMS_CLOUD`-family traffic uses Oracle's service network, so the load needs no
  VCN route.
- **The instances can read the app password.** The policy
  `mymagnet-adb-secret-read` (home region) lets `mymagnet-instance-dyn-grp` read
  `mymagnet-adb-app-password`, and only that secret. The app connects as
  `MAGNET`, not ADMIN.

**SQL (`sql/`):** `01` creates the app user; `02` loads the ONNX model;
`03` is the SQLite schema translated to Oracle; `04` backfills embeddings and
creates the HNSW index; `05` is an example similarity query;
`select_ai_profile.sql` is optional (Phase 4). Translation notes:

- `SIZE` is an Oracle reserved word, so `torrents.size` becomes `torrent_size`.
- Timestamps stay as ISO strings, as in SQLite.
- `AUTOINCREMENT` becomes `GENERATED BY DEFAULT ON NULL AS IDENTITY`, so the
  migration can keep the existing ids.
- `magnet` is `VARCHAR2(32767)`. ADB defaults to `MAX_STRING_SIZE = EXTENDED`.
- `title_vec` is `VECTOR(384, FLOAT32)`.

The index is HNSW with `DISTANCE COSINE`. On ADB-S the vector pool is sized
automatically. An IVF alternative is commented out in `04`.

**App patch (`app-patch/mymagnet-adb.patch`, against MyMagnet `e2641e0`,
not pushed):** a new `magnet_db.py` provides a python-oracledb Thin-mode pool
behind a sqlite3-shaped wrapper. The SQL moves to Oracle syntax: `MERGE`,
`RETURNING`, `FETCH FIRST`, `LISTAGG`, and `UPPER()` for case-insensitive
`LIKE`. There's a new `/api/similar?q=` endpoint, and
`migrate_sqlite_to_adb.py` does the one-time copy: instance 1 as-is, then
instance 2 with `--merge`. The patch applies cleanly and compiles. Both scripts
passed an offline smoke test with a stubbed database; none of it has run
against a real database. Once both nodes share one database: run the scraper
timer on **one** node only, and LB sticky sessions are no longer needed.

Depends on: `lab-network-stack` (`vcn_id`), `lab-private-network-stack`
(`private_subnet_id` → `instance_subnet_id`), and `lab-mymagnet-stack`
(`vault_id` and `vault_management_endpoint` from `oci_kms_vault.mymagnet`,
plus the `mymagnet-instance-dyn-grp` name).
Outputs: `autonomous_database_id`, `private_endpoint_ip`, `private_endpoint_host`,
`connection_profiles`, `admin_secret_id`, `app_secret_id`, `models_bucket`

**Status (2026-09-24): not applied.** `terraform validate` is clean
(oracle/oci 9.3.0, hashicorp/random). `terraform plan` against the live tenant
shows **10 to add**, 0 to change, 0 to destroy: NSG + rule, AES key, 2 secrets,
ADB, bucket, 1 IAM policy, and 2 `random_password`. `terraform.tfvars`
(gitignored) holds real OCIDs from `lab-mymagnet-stack` and a read-only vault list.

**Verified against Oracle docs:**

- Always Free limits.
- The TLS/mTLS ports on private endpoints.
- ADB password rules.
- The `LOAD_ONNX_MODEL_CLOUD` signature, and `credential => NULL` for PARs.
- `CREATE VECTOR INDEX` syntax for HNSW and IVF.
- `FETCH APPROX` behaviour on ADB-S.
- ADB's automatic vector pool.
- `SIZE` being reserved.
- `MAX_STRING_SIZE = EXTENDED`.
- `ROUTE_OUTBOUND_CONNECTIONS` behaviour.
- `APPEND_HOST_ACE(private_target => TRUE)`.

**Unverified:**

- The `.onnx` file name inside Oracle's zip.
- Whether `DB_DEVELOPER_ROLE` includes `CREATE MINING MODEL`.
- DML behaviour on HNSW-indexed tables in 26ai.
- `VECTOR_EMBEDDING` inside a `MERGE ... INSERT`.
- A bind variable in `FETCH APPROX FIRST ? ROWS`.
- `START WITH LIMIT VALUE` on 26ai.
- Whether Select AI requires HTTPS for `provider_endpoint`.
- The 20 GB minimum storage for ECPU. If the API rejects it, the error will
  name the real minimum.

**Apply and use:** see `sql/README.md`, then `app-patch/README.md`.

```bash
cd terraform/lab-capstone-adb-stack
terraform plan && terraform apply        # ADB provisioning takes a few minutes
terraform output connection_profiles     # use the _tp TLS string; check it says port 1522
# ...sql/01-03, migrate, sql/04, per the READMEs
oci db autonomous-database stop --autonomous-database-id "$(terraform output -raw autonomous_database_id)"
```
