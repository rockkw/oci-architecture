# OCI Architect Professional (1Z0-997-26) — Udemy Practice Questions

*Captured from the Udemy course "1Z0-997-26 Oracle Cloud Infrastructure Architect Pro — 100 Questions With Explanations… June 2026, 2 practice exams". Third-party material: answers are checked against Oracle's docs where possible, with the analysis in [[MyLearn Skill Check Questions]] ("Udemy practice exam 1").*

---

## Practice exam 1 (50 questions)

### Q1
A large financial enterprise is designing a highly available and disaster-resilient database architecture using Oracle Base Database Service virtual machine DB systems across multiple Oracle Cloud Infrastructure (OCI) regions. The database handles sensitive customer transactions, uses OCI Vault for Transparent Data Encryption (TDE) key management, and must support automated failover and read-only workload offloading. When configuring Oracle Data Guard associations using OCI managed database automation, which two requirements or limitations must the architectural team consider? (Choose two.)

A. The OCI Base Database Service supports synchronous redo transport under the MAXIMUM_AVAILABILITY protection mode across different OCI regions to guarantee zero data loss for disaster recovery.
B. The only Oracle Data Guard protection mode currently supported and configured by the managed OCI Base Database Service database automation is MAXIMUM_PERFORMANCE, which operates asynchronously.
C. A managed Data Guard association can be dynamically established between an OCI virtual machine DB system and an on-premises physical database running Oracle Database Standard Edition.
D. The standby database can be deployed using a bare metal DB system shape to offload heavy reporting workloads while the primary database runs on a virtual machine shape.
E. When using OCI Vault for customer-managed TDE keys, the cross-region Data Guard configuration is restricted to a maximum of two regions: the primary region and one remote region.

**Answer: B, E** (verified against Oracle docs; Udemy key not yet seen). Cross-region = Maximum Performance / async only; Vault-keyed cross-region Data Guard = primary + one remote region; Standard Edition isn't supported by Data Guard.

---

### Q2
An enterprise architecture team is designing a highly resilient hybrid networking architecture to connect their on-premises data center to an OCI VCN housing critical workloads. The business continuity plan mandates a reliable backup connection that automatically takes over if the primary, high-bandwidth Oracle Cloud Infrastructure FastConnect circuit fails. To minimize recurring infrastructure expenses, the secondary path must only handle traffic during a failover event and utilize a completely distinct transport medium. As a solutions architect, which approach would you direct your team to follow to achieve this high availability design?

A. Provision a primary OCI FastConnect virtual circuit through a partner network, and establish an OCI Site-to-Site VPN over the public internet as the backup path connected to the same Dynamic Routing Gateway with appropriate routing weights.
B. Configure two identical OCI FastConnect virtual circuits deployed across completely different third-party telecommunication providers to run in a fully redundant, active-active configuration that balances all data center traffic using equal-cost multi-path routing.
C. Set up a single OCI FastConnect private peering circuit and configure an internet gateway within the virtual cloud network to automatically initiate a secure point-to-point tunneling protocol connection directly to on-premises hardware appliances.
D. Use OCI Traffic Management steering policies to dynamically map internal network interface components to an alternative Local Peering Gateway routed within a separate secondary virtual cloud network configured for the remote data center.

**Answer: A**

---

### Q3
A multicloud retail organization is deploying an application on OCI that is distributed across multiple private backend servers, fronted by a private OCI Flexible Load Balancer. The security policy mandates that all web traffic, including internal administrative traffic from other peered Virtual Cloud Networks (VCNs) in the same region, must undergo Web Application Firewall (WAF) inspection. Furthermore, the organization prohibits public DNS modifications and reverse-proxy routing for this internal traffic. As a solutions architect, which WAF deployment model and approach should you implement to satisfy these security constraints?

A. Deploy an OCI WAF Edge policy and configure DNS Traffic Management to route the internal VCN traffic to the edge nodes via a NAT Gateway.
B. Deploy OCI Network Firewall in a transit VCN and configure it to encapsulate internal HTTP headers before forwarding traffic to an OCI WAF Edge policy.
C. Create an OCI WAF Edge policy, map the private Load Balancer IP to a public DNS A record, and configure private DNS zones to resolve the record through the edge nodes.
D. Deploy an OCI WAF Regional policy and attach it directly to the private OCI Flexible Load Balancer as the policy enforcement point.

**Answer: D**

---
