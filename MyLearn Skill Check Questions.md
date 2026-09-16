# MyLearn Skill Check Questions — OCI Architect Professional (2026)

#7_mystudy #OCI

*Captured live from MyLearn course skill checks, as taken. Distinct from
[[practice-1-updated]], which is sourced from a Quizlet flashcard set —
keep these separate since they come from different sources.*

---

## Skill Check: Design Cloud-Native, Microservices, and Serverless Architecture

### Q1
What Kubernetes object can be used to store the Oracle Cloud Infrastructure credentials needed to pull an image from a private registry in OCI?

A. Ingress
B. ConfigMap
C. Secret
D. Service

**Answer: C** (initially selected ConfigMap — incorrect; corrected to Secret before submitting)

*Secret (specifically type `kubernetes.io/dockerconfigjson`) is what stores registry credentials, referenced via `imagePullSecrets` in a pod spec — this is a general Kubernetes concept, not OCI-specific. ConfigMap is for non-sensitive configuration only; it isn't designed for secret material. See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Managing OCIR images and security" section for the related kubectl-created registry secret mechanism for private OCIR pulls.*

---

### Q2
As a DevOps Engineer working on an OKE cluster, which file provides you access details to OKE cluster?

A. Kubernetes
B. Kubectl
C. Kube-proxy
D. Kubeconfig

**Answer: D** (selected correctly)

*Matches [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Accessing a cluster with kubectl" section and the hands-on `oci ce cluster create-kubeconfig --file ~/.kube/config` command run directly against `lab-oke-stack` earlier this session — generated via `oci ce cluster create-kubeconfig`, always lands at `$HOME/.kube/config` regardless of setup path (Cloud Shell vs. local install).*

---

### Q3
As a Cloud Engineer, you are asked to manage the OCI Container Registry, which hosts Docker container images. You are directed to delete all the images within a tenancy region that have not been pulled for over 72 hours to avoid billing charges for the storage space they consume. Which action should you perform to handle this requirement?

A. Periodically delete old, unused images using Docker CLI.
B. Set up local image retention policies to delete images automatically based on selection criteria.
C. Set up a global image retention policy to delete images automatically based on selection criteria.
D. For each old, unused image, select Delete Image from the Actions menu and confirm that you want to delete the image.

**Answer: C** (initially selected B — incorrect; corrected to C before submitting)

*The scenario's "within a tenancy region" scope is the tell — a global image retention policy applies to all repositories in a region by default. Verified against Oracle's docs directly (docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrymanagingimageretention.htm): the answer choices' term "local" is not the real OCIR term — Oracle's actual second policy type is called **custom**, scoped to specific repositories explicitly added to it (one custom policy per repo at a time), not "local." See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Lifecycle/retention policies" section for the corrected terminology.*

---

### Q4
You work as a DevOps engineer and are responsible for managing the container images stored in your team's Oracle Cloud Infrastructure Registry (OCIR) repository. One of your team members accidentally deletes an important container image from the repository. You need to recover the image as soon as possible. How long do you have to undelete the image from OCIR before it is permanently deleted?

A. 72 hours
B. 24 hours
C. 48 hours
D. 96 hours

**Answer: C** (initially selected B — incorrect; corrected to C before submitting)

*Verified against Oracle's docs directly (docs.oracle.com/en-us/iaas/Content/Registry/Tasks/undelete-image.htm): "You can undelete an image you've previously deleted, for up to 48 hours after you deleted it. After that time, the image is permanently removed from Container Registry." Restore via `oci artifacts container image restore --image-id <image-ocid>`. See [[12. Containers — OCI OKE, Container Instances, OCIR]]'s "Managing OCIR images and security" section for the corresponding delete/undelete coverage.*

---

## Result: Passed — 100% (4/4)

Two of four questions had an incorrect answer selected initially and were
corrected before submitting (Q1: ConfigMap → Secret; Q3: local → global
retention policy) — worth a review pass on OCIR retention policy
terminology (Global vs. Custom, not "Local") and Kubernetes Secret vs.
ConfigMap scope before the real exam.

---

## Skill Check: Deliver Infrastructure-as-code

### Q1
Your team lead has provided you with a Terraform configuration which includes variables (but not limited to) OCIDs, IP addresses, and CIDR blocks. You have been tasked with using Resource Manager to provision many versions of the environment with different values for some of these variables. Which two statements are true? **Select TWO correct answers.**

A. For each environment, you need to create a terraform.tfvars file that defines the variables. When you provision each stack, supply the respective variables file.
B. Resource Manager can automatically populate some variable values.
C. For each environment, you need to create a separate Terraform configuration with variables replaced by literals.
D. When you provision a stack, Resource Manager provides fields in the console to define all variables.
E. A schema document can be used to declare each of these environments and define the variables for each of them.

**Answer: B, D** (selected correctly)

*Directly matches the hands-on Resource Manager work done this session with `lab-network-stack`/`lab-nsg-stack`/`lab-func-stack` — the Configure Variables Console screen (option D) and Resource Manager's ability to auto-derive some OCID-type values via native pickers/data sources (option B). Option A describes the local-Terraform `.tfvars` workflow used for `lab-private-network-stack` onward, not Resource Manager's own variable-input model — a real, exam-relevant distinction between the two workflows this session used both of.*

---

### Q2
Which feature of the OCI Resource Manager service will you use to differentiate between the real-world state of your infrastructure and the stack's last executed configuration?

A. View State
B. Diff Detection
C. Apply or Import State
D. Drift Detection

**Answer: D** (selected correctly)

*Compares real-world provisioned infrastructure against the stack's last-executed Terraform configuration, surfacing manual/out-of-band changes made outside Terraform. Distinct from Apply (runs config forward) and Import State (brings existing resources under Terraform management) — drift detection diagnoses divergence, it doesn't fix it. Note "Diff Detection" (option B) is a plausible-sounding distractor, not the real Oracle term. See [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]]'s "Infrastructure as code" section, now expanded with this precise definition.*

---

### Q3
As a DevOps Engineer you have created a Terraform configuration for an infrastructure automation project on the OCI platform. You have been tasked with using OCI Resource Manager to automate the process of provisioning your OCI resources. Which two things happen when you apply Terraform configuration? **Select TWO correct answers.**

A. Terraform corrects formatting errors in your configuration.
B. Terraform makes any infrastructure changes defined in your configuration.
C. Terraform updates the state file with any configuration changes it made.
D. Terraform gets the plugins that the configuration requires.
E. Terraform destroys and recreates all your infrastructure from scratch.

**Answer: B, C** (selected correctly)

*Directly observed dozens of times this session across every `terraform apply` run in `terraform/` — infrastructure changes applied, `.tfstate` updated to match. The three distractors each belong to a different command: A is `terraform fmt`, D is `terraform init`, E is `terraform destroy` (a normal `apply` can still force a full resource *replacement* for a single resource when a change requires it — e.g. adding `nsg_ids` forced `lab-oke-stack`'s node pool to recreate — but that's targeted replacement, not "all infrastructure from scratch").*

---

### Q5
You are a DevOps engineer and as part of hybrid cloud infrastructure automation for a new project, you have been tasked to create Terraform stacks using Oracle Cloud Infrastructure (OCI) Resource Manager. Which two statements about Terraform are **FALSE**? **Select TWO correct answers.**

A. You configure multiple provider instances with the help of an alias.
B. Terraform CLI versions and provider versions are independent of each other.
C. Terraform is an IaaS.
D. Resource names in Terraform are provider specific.
E. Terraform codifies cloud APIs into declarative configuration files.

**Answer: C, D** — confirmed by MyLearn's own grading (initially selected A, C — A was marked incorrect; corrected pair per the grader is C and D)

*A real, non-obvious trap in the wording of D — worth understanding exactly why it's false, not just memorizing it: Terraform's `resource "<TYPE>" "<NAME>" {}` syntax has two separate naming layers. The resource **type** (e.g. `oci_core_vcn`, `oci_containerengine_cluster`) genuinely is provider-namespaced — this session's code used the `oci_` prefix on every single resource. But the resource **name** (e.g. `"lab_vcn"` — the local identifier you invent to reference the resource elsewhere in config) is entirely arbitrary, chosen by the author, and has nothing to do with the provider. D conflates these two layers — "resource names" (plural, generic) reads as the type prefix, but Terraform's own docs distinguish type from name precisely because the name is never provider-specific.

C ("Terraform is an IaaS") is false for a category reason: Terraform is IaC (Infrastructure as **Code**) tooling — it calls a provider's APIs to create/manage infrastructure, but provides no infrastructure of its own. IaaS (Infrastructure as a **Service**, e.g. OCI Compute) means the provider hosts infrastructure you consume; Terraform hosts nothing — stopping Terraform doesn't remove any resources it created, since it was never the thing running them.

A ("alias") and B (CLI/provider version independence) are both **true**, confirmed directly from this session's own `main.tf` files (`provider "oci" { alias = "home" }` used in `lab-storage-stack`/`lab-oke-official-module-stack`; `required_version` and `required_providers { oci = { version = ... } }` are separate, uncoupled fields in every stack) and cross-checked against HashiCorp's own docs on CLI/provider version independence before submitting.*

---
