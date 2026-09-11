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

## Recall exercises

- [ ] Explain why `--query "data[?is_home_region]"` returns an empty result against real OCI CLI JSON output, and what the corrected filter should look like.
- [ ] Walk through why `fn invoke` fails in Cloud Shell specifically, and which OCI CLI command replaces it for a quick health check.
- [ ] A docker login attempt fails with `invalid username/password` despite a freshly generated token. What two tenancy-model-dependent username formats should you check before assuming the token itself is bad?
