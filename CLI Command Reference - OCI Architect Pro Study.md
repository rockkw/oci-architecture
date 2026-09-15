# CLI Command Reference — OCI Architect Pro Study

#7_mystudy #OCI  
**Running log of Cloud Shell / OCI CLI / Fn CLI / Docker commands used across labs.** Add to this as new commands come up — treat it as a lookup, not a tutorial. Companion to [[8.1 - Terraform & OCI Resource Manager - Hands-On Reference]] and [[Lab 1 - OCI Architect Pro Exam]].

---

## Identity / IAM checks

**List which groups a user belongs to:**
```bash
oci iam user list-groups --user-id <user-ocid>
```

**Find a user's OCID by name filter:**
```bash
oci iam user list --query "data[?contains(name,'<partial-name>')].{name:name,id:id}" --output table
```

**List compartments (including nested, across the whole tenancy):**
```bash
oci iam compartment list --compartment-id-in-subtree true --all --query "data[*].{name:name,id:id}" --output table
```

**Check tenancy's home region (critical for troubleshooting IAM propagation delays — see Note 5):**
```bash
oci iam region-subscription list --output table
```
Look for `is-home-region: True`. Note: JSON keys in OCI CLI output are hyphenated (`is-home-region`, `region-name`), not underscored — a `--query` filter using underscores will silently return an empty result rather than erroring.

---

## Object Storage

**Get the tenancy's Object Storage namespace (needed for OCIR registry paths):**
```bash
oci os ns get
```

---

## Fn CLI (Functions) setup and usage

**One-time context setup:**
```bash
fn create context oci-lab --provider oracle
fn use context oci-lab
fn update context oracle.compartment-id <compartment-ocid>
fn update context api-url https://functions.<region>.oci.oraclecloud.com
fn update context registry <region-key>.ocir.io/<tenancy-namespace>/<repo-name>
```

**Build and push a function:**
```bash
fn init --runtime python <function-name>
cd <function-name>
fn build
fn push
```
Prints the full image path on success, e.g. `phx.ocir.io/idtlmgo3jgde/lab-repo/lab-func:0.0.1` — needed as the `function_image` Terraform variable.

**Known gap: `fn invoke` doesn't work from Cloud Shell.** It expects a classic `~/.oci/config` file with an API key, but Cloud Shell authenticates via a delegation token instead — that file doesn't exist. Use the OCI CLI's own invoke command instead (below) rather than troubleshooting `fn invoke` auth in Cloud Shell.

---

## OCI CLI — Functions (direct invoke, bypassing Fn CLI)

**Get a Function's OCID (chained lookup — Application then Function):**
```bash
oci fn function list --application-id $(oci fn application list --compartment-id <compartment-ocid> --query "data[0].id" --raw-output) --query "data[0].id" --raw-output
```

**Invoke a Function directly (useful for isolating Function health from Gateway/API issues):**
```bash
oci fn function invoke --function-id <function-ocid> --body '' --file -
```
Note: `--body` is a required flag even for a payload-less test invoke — pass an empty string, not nothing.

---

## Docker / OCIR

**Login to OCIR (region-specific registry):**
```bash
docker login <region-key>.ocir.io
```
Username format depends on your identity model:
- **Identity Domains tenancies (current default):** `<tenancy-namespace>/<domain-name>/<username>` — e.g. `idtlmgo3jgde/Default/rock.whitney@oracle.com`. Find the domain name at Console → Identity & Security → Domains.
- **Legacy federated IDCS tenancies (older):** `<tenancy-namespace>/oracleidentitycloudservice/<username>` — the literal string `oracleidentitycloudservice` only applies here, not to Identity Domains tenancies. Using the wrong format for your tenancy type produces `invalid username/password` even with a correct, freshly generated token.

Password: an Auth Token generated at Console → profile icon → User Settings → Auth Tokens → Generate Token. **Never paste the actual token value into a chat or shared doc** — generate it, use it directly at the password prompt, and revoke/regenerate immediately if it's ever been exposed.

---

## Terraform (local zip prep for Resource Manager)

**Write a `.tf` file directly from Cloud Shell (avoids a separate editor):**
```bash
cat > main.tf << 'EOF'
<file contents here>
EOF
```

**Zip a stack's `.tf` files for Resource Manager upload (contents at zip root, not nested):**
```bash
zip -j <stack-name>.zip <folder-name>/*.tf
```
The `-j` flag strips the folder path so files land at the zip root — Resource Manager requires at least one `.tf` file at the root of the zip; nesting inside a subfolder causes variables to show blank on the Configure Variables screen.

**Re-zip after editing (updates in place):**
```bash
cd ~ && zip -j <stack-name>.zip <folder-name>/*.tf
```
(`zip` will report `updating: <file> (deflated N%)` for files that already existed in the archive.)

---

## OCI Container Engine for Kubernetes (OKE)

**Get cluster status:**
```bash
oci ce cluster get --cluster-id <cluster-ocid> --query "data.{name:name, state:\"lifecycle-state\"}" --output table
```

**List node pools under a cluster:**
```bash
oci ce node-pool list --compartment-id <compartment-ocid> --cluster-id <cluster-ocid> --all --query "data[].{name:name, id:id, state:\"lifecycle-state\"}" --output table
```

**Check individual node states/errors within a node pool** (the key diagnostic for a stuck/failed node pool — `lifecycle-details` shows the actual node-level status, e.g. `configuring`, not just the pool's overall state):
```bash
oci ce node-pool get --node-pool-id <node-pool-ocid> --query "data.nodes[].{name:name, state:\"lifecycle-state\", details:\"lifecycle-details\"}" --output table
```

**Query supported node pool images/shapes** (direct CLI counterpart to Terraform's `oci_containerengine_node_pool_option` data source):
```bash
oci ce node-pool-options get --node-pool-option-id all
```

**Generate a kubeconfig for `kubectl`** — merges into an existing `~/.kube/config` by default (does **not** clobber other contexts like `minikube`); pass `--overwrite` only if you actually want to replace the whole file:
```bash
oci ce cluster create-kubeconfig \
  --cluster-id <cluster-ocid> \
  --file ~/.kube/config \
  --region <region> \
  --token-version 2.0.0
kubectl config get-contexts   # confirm the new context landed without wiping existing ones
kubectl get nodes
```

**Known gotcha: nodes reaching `ACTIVE` doesn't mean `kubectl` can reach the cluster.** These are two separate network paths — node registration needs NSG rules between the control plane and worker nodes (ports 6443/10250/12250/10256), while external `kubectl` access needs a *separate* rule allowing your client's IP (or `0.0.0.0/0`) to reach the control plane's public endpoint on 6443. A `dial tcp <ip>:6443: i/o timeout` from `kubectl` after nodes are already `Ready` means the second path, not the first, is missing.

---

## Instance Cloud Agent plugins

**Check plugin status on an instance** (e.g. confirming the Bastion plugin is actually `RUNNING`, not just configured):
```bash
oci instance-agent plugin list --instanceagent-id <instance-ocid> --compartment-id <compartment-ocid> --query "data[].{name:name, status:status}" --output table
```

**Enable/disable a plugin:**
```bash
oci compute instance update --instance-id <instance-ocid> --agent-config file://agent-config.json --force
```
where `agent-config.json` is:
```json
{
  "isMonitoringDisabled": false,
  "isManagementDisabled": false,
  "pluginsConfig": [
    {"name": "Bastion", "desiredState": "ENABLED"}
  ]
}
```
Setting desired state to `ENABLED` does not mean the plugin is immediately `RUNNING` — the Cloud Agent picks up config changes on its own polling cycle, which can take several minutes for a first-time enable. Poll the plugin list command above rather than assuming it's active right after the update call returns.

---

## Network Monitoring / Path Analyzer

**Trace an actual network path between two endpoints** (the real diagnostic tool for "why can't A reach B," distinct from manually reasoning about route tables/NSGs/security lists by hand):
```bash
oci vn-monitoring path-analysis get-path-analysis-adhoc \
  --compartment-id <compartment-ocid> \
  --protocol 6 \
  --source-endpoint file://source.json \
  --destination-endpoint file://dest.json \
  --protocol-parameters file://protocol.json \
  --wait-for-state SUCCEEDED --wait-for-state FAILED
```
`source.json`/`dest.json` are typed endpoint objects — a `SUBNET` type needs **both** `subnetId` and an `address` within that subnet's CIDR, not just the subnet OCID:
```json
{"type": "SUBNET", "subnetId": "<subnet-ocid>", "address": "10.0.2.50"}
```
`protocol.json` for a TCP port check:
```json
{"type": "TCP", "destinationPort": 6443}
```
**Known gotcha: `oci vn-monitoring` is its own service group, not under `oci network`.** Also, a request can be perfectly well-formed and still fail with `"Not Authorized for Source or Destination Endpoint"` — this is a missing IAM policy grant for Path Analyzer's specific resource type, not a malformed request. Check `oci iam policy list` for a statement covering it before assuming the request itself is wrong.

---

## Service limits / quota checks

**List current limit values for a service** (requires the **tenancy** OCID as `--compartment-id`, not a sub-compartment — this trips people up):
```bash
oci limits value list --compartment-id <tenancy-ocid> --service-name <service-name> --region <region> --all --query "data[].{name:name, value:value, scope:\"scope-type\"}" --output table
```
Common `--service-name` values: `compute`, `block-storage`, `load-balancer`, `vcn`. Filter `name` with `contains()` for a specific shape family, e.g. `--query "data[?contains(name,'a1')]..."` for Ampere A1 limits.

---

## GitHub (via `gh` CLI)

**Fetch a single file's contents from a repo** (useful for reading a specific Terraform module file without cloning the whole repo):
```bash
gh api repos/<owner>/<repo>/contents/<path/to/file> --jq '.content' | base64 -d
```

**List files in a directory:**
```bash
gh api repos/<owner>/<repo>/contents/<path/to/dir> --jq '.[] | .name'
```

**Create a private repo from the current directory and push:**
```bash
gh repo create <name> --private --source=. --remote=origin --description "<description>"
git push -u origin main
```
**Known gotcha:** if `gh auth status` shows `Git operations protocol: ssh` but this machine has no SSH key set up for git (push fails with `Permission denied (publickey)`), switch the remote to HTTPS and let `gh` supply credentials instead:
```bash
gh auth setup-git
git remote set-url origin https://github.com/<owner>/<repo>.git
```

---

## Recall exercises

- [ ] Explain why `--query "data[?is_home_region]"` returns an empty result against real OCI CLI JSON output, and what the corrected filter should look like.
- [ ] Walk through why `fn invoke` fails in Cloud Shell specifically, and which OCI CLI command replaces it for a quick health check.
- [ ] A docker login attempt fails with `invalid username/password` despite a freshly generated token. What two tenancy-model-dependent username formats should you check before assuming the token itself is bad?
