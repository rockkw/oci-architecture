# AWS to OCI Exceptions

#certs #7_mystudy

Places where the AWS SAA-C03 → OCI Architect Professional analogy breaks down —
not a 1:1 service mapping, but a genuine structural or conceptual difference.
Referenced from [[Active OCI Architect Professional Certification Plan — 1Z0-997-26]]
Week 1 deliverable.

## Account/tenancy structure

**AWS account ≈ OCI tenancy — not compartments.** AWS has no single top-level
object that *is* the identity/billing root the way OCI's tenancy is; instead:

- **AWS account** = the fundamental isolation boundary. Each account has its own
  separate resource namespace, billing, and root user — closer to an OCI
  *tenancy* than to a compartment.
- **AWS Organizations** groups multiple peer accounts under a management
  account. This is the rough analog of having multiple OCI tenancies, not of
  OCI's tenancy-to-compartment nesting — member accounts are still separately
  rooted, not nested containers.
- **OCI tenancy** = the single root container for your whole cloud identity,
  created at signup — one IAM/identity root.
- **OCI compartments** are purely logical subdivisions *inside* one tenancy for
  organizing resources and scoping policy — no separate billing, no separate
  identity root; they all share the tenancy's identity domain.

**The gap: OCI compartments have no AWS equivalent.** AWS has no purely-logical,
same-account subdivision with IAM-scoped policies the way compartments work.
The nearest partial analog is resource tagging + tag-based IAM conditions,
which is materially weaker than compartment-scoped policy — don't reach for
"which AWS service is this" here; there isn't one.

## RAC and BYOL licensing

No direct AWS equivalent — Oracle Real Application Clusters and Bring-Your-Own-
License terms don't map onto any AWS service comparison. Don't try to force
this into the same "nearest AWS service" framing used elsewhere in this note;
treat it as pure Oracle-licensing domain knowledge. (Flagged in Week 2 of the
cert plan as a place where OCI Pro diverges hardest from AWS instincts.)

## Identity and access

- **Identity domains vs. legacy IAM.** OCI has two coexisting identity models —
  a legacy IAM layer and a newer "identity domains" layer — that are not
  interchangeable; a tenancy's behavior depends on which one is in play, with
  no AWS analog to this dual-model transition state. See
  [[OCI Architect Professional Tips]].
- **AssumeRole/instance profiles vs. dynamic groups.** AWS's AssumeRole /
  instance-profile pattern (a role you assume) has no OCI counterpart. OCI
  instead uses **dynamic groups** — a continuously-evaluated matching rule
  against resource attributes, not a membership list — so "membership" is
  computed at call time rather than assigned. There's no static "role" object
  being assumed at all. See [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]],
  [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]].
- **Implicit deny everywhere, no permissive defaults.** OCI has no equivalent
  of AWS's occasional permissive service defaults; every new
  compartment/dynamic group/user starts fully deny-all. The sole built-in
  exception is the tenancy's Administrators group.
- **IAM home-region replication lag.** OCI has exactly one home region where
  all IAM writes (users, groups, dynamic groups, policies) are authored, then
  replicated to every subscribed region — identity domains add a *second*,
  separately-observable propagation stage (domain-container replication vs.
  object-level propagation) on top of that. AWS IAM has no single-home-region
  replication architecture or two-stage propagation gap to reason about. See
  [[Lab 3 - OCI Architect Pro Exam - IAM Policies]] and
  [[OCI propagation delays]].

## Networking

- **Stateful/stateless is a per-rule property, not a per-construct one.** The
  clean AWS rule "security groups are stateful, NACLs are stateless" does not
  carry over: in OCI, *either* an NSG rule or a security-list rule can
  independently be configured stateful or stateless. See
  [[9. Networking — OCI VCN, DRG, Gateways, Load Balancers]].
- **Subnet IP reservation math differs.** OCI reserves the first two and last
  IP of each subnet CIDR (3 addresses), versus AWS's standard five-address
  reservation — applying the AWS calculation under/oversizes subnet planning.
  A `/30` is technically legal in OCI but yields only 1 usable IP — a trap for
  Functions/instance pools/OKE, which consume IPs close to linearly with
  concurrency (see Serverless entry below).
- **VPC peering splits into two gateway types, both routed through a DRG.**
  AWS VPC peering is one mechanism; OCI splits it into a Local Peering Gateway
  (same-region) vs. a Remote Peering Connection (cross-region), and the
  cross-region case must attach through a DRG. A DRG's attachment route
  tables/route distributions are a separate routing-policy layer — attaching
  two networks to the same DRG does not itself grant reachability.
- **DRG is a full virtual-router hub, not just a "VPN endpoint."** FastConnect,
  VPN, and peering all converge on the DRG as OCI's Transit Gateway analog —
  broader in scope than a single AWS Transit Gateway or VPN Gateway.
- **No single VPC-endpoint/PrivateLink analog.** OCI's private-access patterns
  (Service Gateway, private endpoints, Private Access Channel) vary per
  service rather than following one uniform mechanism the way AWS PrivateLink
  does.
- **Zero Trust Packet Routing (ZPR) has no AWS equivalent.** Security groups
  and NACLs — no matter how they're organized or referenced — are
  fundamentally address-and-port constructs: a rule always resolves to a
  CIDR/SG-ID and a port. ZPR instead tags resources directly with security
  attributes (e.g., `#app:science`, `#database:sensitive`) and writes policy
  against those attributes, so the policy survives the underlying resource's
  IP changing entirely — no equivalent rule-rewrite is needed the way it
  would be for an NSG/security-group rule referencing a specific address.
  AWS's nearest partial analogs — security group references and tag-based IAM
  conditions — don't unify network reachability and security intent into one
  declarative, address-independent construct the way ZPR does. See
  [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the
  worked example: a single mistyped CIDR digit in a hand-authored NSG rule
  went unnoticed through a two-person review process — the exact class of
  error ZPR's attribute model removes structurally.
  **Cross-VCN confirms this isn't just a same-VPC convenience gap:** AWS
  security group references are scoped to a single VPC, exactly like an OCI
  NSG — cross-VPC, AWS also has no choice but to fall back to CIDR ranges,
  the identical degradation OCI's own NSGs show once traffic crosses a VCN
  boundary (see the "Two Applications, One Spoke" scenario in Note 5's
  Cross-VCN ZPR section). Cross-VCN ZPR closes precisely the gap neither
  cloud's security-group/NSG referencing model can close on its own.

## Containers (OKE)

- **ECS has no OCI equivalent — orchestration means Kubernetes, full stop.**
  OCI has no proprietary non-Kubernetes container orchestrator, so the "ECS
  vs. EKS" decision AWS architects make doesn't exist here; it collapses to
  "OKE, or skip the cluster entirely (Container Instances)." AWS Copilot CLI
  and EKS Anywhere are likewise unmatched — OCI's nearest capabilities (OCI
  DevOps for CI/CD; Oracle Cloud Native Environment/Verrazzano for hybrid) are
  differences in kind, not just feature gaps. See
  [[12. Containers — OCI OKE, Container Instances, OCIR]].
- **OKE Basic → Enhanced is a one-way door.** Basic clusters carry only a
  Service Level Objective (no financial remedy); Enhanced adds a real SLA plus
  Virtual Nodes and workload identity. You can upgrade Basic→Enhanced but can
  **never** downgrade back — no EKS parallel. The Console defaults to
  Enhanced while the CLI/API defaults to Basic, an easy-to-invert trap.
- **`ARM64` vs. `AARCH64` enum naming.** A real bug hit in this vault's lab
  work: `node_pool_os_arch = "ARM64"` is not a valid enum for the OCI
  Terraform provider — the correct value is `"AARCH64"`. Pure naming
  divergence from the more common "ARM64" convention, concrete enough to break
  a Terraform plan. See `terraform/lab-oke-stack/main.tf`,
  [[terraform/LABS.md]].
- **Console cannot provision a custom-image managed node pool at all** — a
  genuine tool-capability gap, not just a differing default; CLI/API only.

## Serverless

- **OCI Functions has exactly one deployment model: container image, always.**
  There's no "just upload a zip" path the way Lambda defaults to — every
  Functions deployment is a container image pushed to OCIR first.
- **VNIC-per-invocation vs. Lambda's pooled ENIs.** Both use an
  attachable-NIC primitive (ENI / VNIC), so the concept transfers, but the
  IP-consumption model doesn't: post-2019 Lambda shares a pooled set of ENIs
  per subnet/security-group combo, so IP usage barely scales with concurrency.
  OCI Functions has no pooling layer — every invocation gets its own container
  and its own VNIC, so IP consumption scales roughly linearly with
  concurrency, forcing an explicit subnet-sizing calculation Lambda never
  requires. See [[14. Serverless — OCI Functions, Events, API Gateway]].

## Storage / content delivery

- **No first-party CDN control plane.** Unlike CloudFront, OCI has no
  first-party CDN service — you select an approved third-party CDN provider
  and design origin integration yourself. Signed URLs/cookies and
  CloudFront's Origin Access Control have no packaged OCI equivalent either;
  origin authorization must be modeled via application logic, signed
  URL/token patterns, and Object Storage/IAM policy. See
  [[2. Content Delivery — OCI CDN, WAF, DNS, Origin Protection]].
- **No AWS Global Accelerator or QLDB analog.** Global traffic acceleration
  must be composed from DNS Traffic Management + regional load balancers +
  CDN, rather than one anycast-accelerator product; immutable/ledger
  requirements must be built from database + audit primitives rather than a
  packaged ledger service. See
  [[10. Global Delivery and Data Services — OCI Traffic, Cache, NoSQL, Graph]].
- **OS-level firewall blocks 80/443 by default, on top of the NSG layer.**
  Oracle's base Ubuntu image ships its own default-deny iptables ruleset (SSH
  + established only) *in addition to* the NSG/security-list layer. AWS
  EC2/Lightsail rely on the cloud-level security group as the sole inbound
  gate — this caused a real, diagnosed outage (curl worked on localhost,
  failed externally) in `lab-mymagnet-stack`. See [[terraform/LABS.md]].

## Database

- **No direct Aurora/Aurora Serverless analog.** The choice spans Autonomous
  Database / Base Database / Exadata Database Service by engine, autonomy,
  isolation, and licensing — not a single serverless-relational product.
- **DynamoDB → Oracle NoSQL is not a drop-in swap.** API, data model,
  consistency, and query patterns must be independently re-validated —
  treating it as client-compatible is a named false-equivalence trap. See
  [[6. Databases — OCI Database, NoSQL, Caching, DR]].
- **Active Data Guard is a distinct licensed capability, not just "the DR
  feature."** A plain physical standby can only be opened read-only if redo
  apply is *stopped* first. Active Data Guard is a separate licensed add-on
  permitting simultaneous redo apply *and* read-only access — AWS RDS
  Multi-AZ/read-replica framing has no equivalent licensing-gated distinction
  between "replica that can't serve reads while replicating" and "replica
  that can."
- **No bundled Schema Conversion Tool.** Schema conversion lives in the free
  desktop Oracle SQL Developer IDE, not an OCI console/managed service, and
  heterogeneous replication is a separate GoldenGate product — AWS bundles SCT
  conceptually alongside DMS; OCI's Database Migration Service does not bundle
  an equivalent. AWS DataSync likewise has no single managed-service
  equivalent — must be assembled from Rclone/rsync+fpsync/Resilio Connect plus
  FastConnect/VPN as the connectivity layer. See
  [[13. Migration and Transfer — Oracle Cloud Migrations, Data Transfer, Database Migration]].
- **Oracle Database@Azure/@AWS/@GCP runs in the other cloud's datacenter —
  there's no reverse AWS equivalent.** AWS does not natively host another
  vendor's fully managed database inside its own console/VPC. Oracle
  Database@Azure is real Exadata infrastructure colocated in Azure's
  datacenter, provisioned from the Azure console/VNet, reached via an
  Oracle-managed private network you don't build yourself — structurally the
  reverse of anything AWS offers, not a missing feature. See
  [[7. Multicloud and Hybrid — Oracle Database@Azure, FastConnect, DRG]].

## DevOps / IaC / governance

- **Terraform (via Resource Manager) is a different tool category than
  CloudFormation, not a renamed one.** CloudFormation is AWS-native templating
  with intrinsic functions (`!Ref`, `!GetAtt`); Terraform is a third-party,
  multi-cloud, resource-graph-based tool that OCI wraps as a managed service —
  no implicit "stack outputs," explicit state-file management, none of which
  maps onto CloudFormation's model. Resource Manager's `schema.yaml`
  guided-UI (a form-based Console UI generated from a stack's variables) has
  no CloudFormation equivalent in this form. See
  [[8.1 Terraform & OCI Resource Manager - Hands-On Reference]].
- **No CodeGuru or unified Trusted Advisor equivalent.** No packaged
  code-review/scanning-in-pipeline product exists — bring your own SAST/SCA
  tooling. Governance/cost advice is likewise composed of separate services
  (Cloud Advisor, Cloud Guard, budgets, quotas, Cost Analysis) rather than one
  unified advisor product. See
  [[8. Management and Governance — OCI Resource Manager, OS Management Hub, Observability]].
- **CloudWatch/X-Ray split into three separate, non-unified signals.**
  Monitoring (metrics), Logging (logs), and APM (traces) are architecturally
  separate OCI services with no single combined observability product —
  repeatedly a trap for anyone expecting one unified service.

## (carry forward — add further entries here as found)

- VPC → VCN, IAM roles → dynamic groups/policies, Direct Connect → FastConnect,
  S3/EBS/EFS → Object/Block/File Storage, CloudWatch → Monitoring/Logging/APM
  were the baseline translations done in the Week 1 session; this note is for
  the *exceptions* to that mapping, not the mapping itself (see the relevant
  numbered service notes for those).
