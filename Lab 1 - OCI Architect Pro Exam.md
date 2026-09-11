# Lab 1 - OCI Architect Pro Exam

#7_mystudy #OCI  
**Plan item:** Deploy one small reference workload in a non-production tenancy: API Gateway → Function or OKE service; provision at least one component through [Resource Manager](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm), not click-ops.

**Chosen path:** API Gateway → Function (not OKE) — a working end-to-end reference workload in ~20 minutes vs. the longer cluster provisioning time OKE requires. The API Gateway piece transfers directly if the OKE version gets built later.

**Companion references:** [[8.1 - Terraform & OCI Resource Manager - Hands-On Reference]] for Resource Manager mechanics; this note is the applied lab log.

---

## Why this can't be 100% Terraform

Terraform (and therefore Resource Manager) can provision the Functions Application, the Function resource shell, the API Gateway, and the Deployment — but it cannot **build or push a container image**. That step is unavoidably CLI/click work via the Fn CLI and Docker. The plan item's requirement ("at least one component through Resource Manager, not click-ops") is satisfied by provisioning the Application, Function, Gateway, and Deployment as a stack — the image build/push is infrastructure-adjacent tooling, not itself an OCI resource.

## Step 0 — Prerequisites

Functions needs a subnet with internet egress (to pull its image from OCIR) — either a public subnet with an Internet Gateway, or a private subnet with a NAT Gateway. Reused the `lab-vcn`/`lab-subnet` built in the earlier Resource Manager walkthrough (Note 8.1) — confirmed it has internet egress via a public subnet.

Collected beforehand:
- Compartment OCID
- VCN OCID and target subnet OCID

(Console → Networking → Virtual Cloud Networks → click in to get these.)

## Step 1 — Open Cloud Shell

Console → top-right icon bar → Developer Tools icon → **Cloud Shell**. Comes with Fn CLI, Docker, OCI CLI, and Terraform pre-installed.

## Step 2 — One-time Functions setup in Cloud Shell

```bash
# Set your context
fn create context oci-lab --provider oracle
fn use context oci-lab
fn update context oracle.compartment-id <your-compartment-ocid>
fn update context api-url https://functions.<your-region>.oci.oraclecloud.com
fn update context registry <region-key>.ocir.io/<your-tenancy-namespace>/lab-repo
```
Region key examples: `iad` for us-ashburn-1, `phx` for us-phoenix-1 — match your actual region. Tenancy namespace: Console → Governance → Tenancy Details → Object Storage Namespace.

Authenticate Docker to OCIR:
```bash
docker login <region-key>.ocir.io
# username: <tenancy-namespace>/oracleidentitycloudservice/<your-username>
# password: an auth token — generate under Console → Identity → Users → your user → Auth Tokens → Generate Token
```

## Step 3 — Build and push a minimal function

```bash
fn init --runtime python lab-func
cd lab-func
fn build
fn push
```
Produces a "hello world" function image pushed to OCIR. Note the full image path printed (`<region-key>.ocir.io/<namespace>/lab-repo/lab-func:0.0.1`) — needed in the Terraform config next.

## Step 4 — Terraform config for Resource Manager

Folder `lab-func-stack/`:

**`main.tf`**
```hcl
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
```

**`variables.tf`**
```hcl
variable "compartment_ocid" { type = string }
variable "subnet_ocid"      { type = string }
variable "function_image"   { type = string }
variable "region" {
  type    = string
  default = "us-ashburn-1"
}
```

**`outputs.tf`**
```hcl
output "gateway_hostname" {
  value = oci_apigateway_gateway.lab_gw.hostname
}
```

Zip the three files (contents at the zip root, not nested in a subfolder).

## Step 5 — Create the stack in Resource Manager

Console → Developer Services → **Resource Manager → Stacks → Create Stack**
- Upload the zip
- Name: `lab-func-stack`
- Compartment: wherever the stack itself should be tracked
- Terraform version: default unless flagged as a mismatch
- Next

## Step 6 — Configure variables

- `compartment_ocid` → compartment OCID
- `subnet_ocid` → subnet OCID
- `function_image` → exact image path from `fn push` output (Step 3)
- `region` → confirm region

Next → Create.

## Step 7 — Plan, then Apply

Terraform Actions → **Plan** → review diff (expect 4 resources to add: application, function, gateway, deployment). Terraform Actions → **Apply**. Watch job log; on success, check **Outputs** tab for `gateway_hostname`.

## Step 8 — Test end to end

```bash
curl https://<gateway_hostname>/lab/hello
```
Expected: the function's default "Hello World" response, returned through the gateway.

## Step 9 — Clean up

Terraform Actions → **Destroy** on the stack (tears down gateway, deployment, function, application). The `lab-repo` OCIR repository is **not** managed by this stack — delete it separately for a fully clean tenancy.

---

## Lab log / results

- [ ] Step 0-2 completed — Cloud Shell, Fn context, Docker login
- [ ] Step 3 completed — image built and pushed: `_____________________`
- [ ] Step 4-6 completed — stack created in Resource Manager
- [ ] Step 7 completed — Plan reviewed, Apply succeeded
- [ ] Step 8 completed — curl test result: `_____________________`
- [ ] Step 9 completed — stack destroyed, OCIR repo cleaned up
- [ ] Gotchas hit during this run: `_____________________`

## Recall exercises

- [ ] Explain why Terraform/Resource Manager can provision the Function *resource* but not build the *image* — what's the actual division of labor between Fn CLI/Docker and Terraform here?
- [ ] What would need to change in this stack if the subnet were private instead of public? (Hint: NAT Gateway, and whether the API Gateway endpoint type can still be PUBLIC.)
- [ ] Walk through what breaks if `function_image` is wrong or the image was never pushed — what does the Apply job log look like in that failure case?
- [ ] Redo this lab targeting OKE instead of Functions as the backend — what API Gateway backend `type` changes, and what additional OKE-side provisioning has to exist first?

## Official OCI references

- [Functions Quickstart](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartguidestop.htm)
- [API Gateway - Creating a Function Backend](https://docs.oracle.com/en-us/iaas/Content/APIGateway/Tasks/apigatewaycreatingdeployment.htm)
- [Resource Manager — Terraform Configuration](https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager.htm)
- [OCI Terraform Provider — oci_functions_function](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/functions_function)
- [OCI Terraform Provider — oci_apigateway_deployment](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/apigateway_deployment)
