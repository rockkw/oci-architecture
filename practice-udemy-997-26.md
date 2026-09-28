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

### Q4
A database administrator is reviewing the data protection health status of a critical production database backed up to OCI Database Autonomous Recovery Service. The database has real-time data protection enabled to ensure high-frequency transaction safety. During a routine audit, the administrator notices that the database health status in the protection summary has transitioned from Protected to Warning. As a solutions architect, how should you explain what this Warning status represents regarding potential data loss exposure and recovery capabilities?

A. The Recovery Service cannot recover the database within the current recovery window because the latest automated full and incremental backups have failed completely.
B. The backup retention period defined in the protection policy has expired, and all older backups have been automatically purged from the Object Storage bucket.
C. The database can still be recovered within the recovery window, but the potential data loss exposure since the last backup has exceeded 120 minutes.
D. The database can still be recovered within the recovery window, but the potential data loss exposure since the last backup is greater than 10 seconds.

**Answer: D**

---

### Q5
A company needs to execute a lightweight, short-lived containerized processing task on demand without managing servers or a Kubernetes cluster. Which OCI service should the solutions architect recommend to satisfy these requirements?

A. OCI DevOps, because it fully automates application provisioning and manages continuous deployment pipelines.
B. OCI Kubernetes Engine, because it scales and orchestrates containerized workloads across node pools.
C. OCI Functions, because it provides a serverless platform to execute transient, event-driven functions.
D. OCI Container Instances, because it runs containerized workloads on optimized, serverless infrastructure.

**Answer: D**

---

### Q6
A healthcare provider runs a critical application on OCI Compute instances that interact with an Oracle Database. The application generates proprietary transaction logs saved to a local directory that contain operational errors. The operations team requires these logs to be securely ingested into OCI Logging in near real-time for centralized troubleshooting. However, company security policies strictly prohibit these private instances from having direct public internet access. Which approach should the architect select to achieve this centralized log collection?

A. Install a third-party syslog forwarder on each instance, and configure it to transmit log packets across a public internet gateway directly to the OCI Logging ingestion endpoint.
B. Write a custom cron script on the instances that periodically uploads the log files via the OCI CLI over an attached NAT Gateway, bypassing the OCI Logging agent completely.
C. Install the OCI Unified Monitoring Agent on the instances, define a Custom Log with a log object configuration pointing to the local directory, and route traffic privately through a Service Gateway.
D. Create an OCI Service Log configuration targeted at the compute instances' compartment, which automatically mounts the local instance directories into a shared OCI Object Storage bucket.

**Answer: C**

---

### Q7
A company is using OCI Certificates to manage TLS certificates and wants to secure a fleet of Apache web servers running on OCI Compute instances. Which statement describes how certificate lifecycle management is handled in this scenario?

A. The OCI Certificates service automatically pushes the renewed certificates and private keys to the Compute instances via the Oracle Cloud Agent.
B. The web servers must use OCI Vault integration because OCI Certificates only supports certificate provisioning for OCI-managed Load Balancers.
C. The certificates are automatically renewed within OCI Certificates, but the new certificate version must be retrieved and installed on the Apache web servers manually or via a custom deployment script.
D. The OCI Certificates service automatically modifies the local Apache configuration files on the Compute instances to point to the newly renewed certificates.

**Answer: C**

---

### Q8
A database operations team needs to route high-volume diagnostic logs from multiple Autonomous Database instances to both an OCI Object Storage bucket for compliance archiving and an OCI Streaming pool for real-time security auditing. The team wants to achieve this with minimal architectural complexity and avoid redundant data pipeline components that inflate operational costs. Which two configurations are unsupported or impractical ways to distribute these logs to both destinations? (Choose two.)

A. Configure a single OCI Connector Hub instance with the database log group as the source, and specify both the Object Storage bucket and the Streaming pool as dual primary targets within that same connector's definition.
B. Deploy two separate OCI Connector Hub instances that both ingest data from the same source database log group, with one connector targeting the Object Storage bucket and the other targeting the Streaming pool.
C. Route the database logs into an OCI Streaming pool via a single connector, and leverage a second connector that uses that Streaming pool as a source to deliver the data to Object Storage.
D. Provision an OCI Search structured query cron job that continuously reads raw log text chunks from the source log groups and uses parallel multi-threaded worker threads to write the payloads to both destinations.
E. Create an OCI Service Log configuration that natively splits the internal database audit stream into two distinct output streams prior to reaching the OCI Logging service tier.

**Answer (likely key): D, E.** ⚠️ Disputed: per Oracle docs a connector has **one source and one target**, so **A is also unsupported**; B (two connectors) and C (chained connectors) are the supported designs.

---

### Q9
Which capability is NOT natively supported as an automatic, built-in feature of OCI Resource Manager?

A. Generating a detailed execution plan prior to applying any infrastructure changes to a resource stack.
B. Detecting configuration drift by comparing the deployed infrastructure against the last applied state.
C. Automatically running a complete rollback job to revert resource states if a standard apply job fails.
D. Importing existing deployed infrastructure resources into a new stack using a resource discovery job.

**Answer: C**

---

### Q10
A company wants to orchestrate the recovery of a multi-tier application using OCI Full Stack Disaster Recovery (FSDR) and is setting up the necessary OCI resources. Which requirement must be met when configuring OCI DR Protection Groups (DRPGs) to enable automated cross-region DR operations?

A. You must deploy both peered DR Protection Groups in the same primary region and establish policy replication rules across target compartments.
B. You must create the DR Protection Groups in different OCI regions, peer them together, and associate one as the primary and the other as the standby.
C. You must install a specialized Full Stack DR agent on all member resources to establish the initial cross-region peer relationship.
D. You must deploy both peered DR Protection Groups in separate tenant organizations and register them with dedicated Oracle Cloud Agents.

**Answer: B**

---

### Q11
Your company has built a continuous integration and deployment pipeline using the OCI DevOps service to deploy microservices. To comply with strict enterprise security policies, the deployment team is required to verify the integrity and origin of all Helm charts before they are deployed to your OKE clusters. The security policy also strictly mandates that any PGP keys used for signature verification must be secured centrally and never stored in cleartext. As a solutions architect, which deployment configuration should you recommend to meet these requirements?

A. Store signed Helm charts in OCI Container Registry, configure the DevOps Helm stage to verify them, and reference the public PGP key stored in OCI Vault.
B. Store signed Helm charts in OCI Artifact Registry, configure the DevOps deploy stage to verify them, and embed the public PGP key in the static config map.
C. Store signed Helm charts in OCI Object Storage, configure the DevOps command stage to verify them, and download the public PGP key from a public git repo.
D. Store signed Helm charts in OCI File Storage, configure the DevOps custom stage to verify them, and write the public PGP key in decrypted environment files.

**Answer: A**

---

### Q12
A multinational organization enforces a strict compliance policy requiring all infrastructure components to maintain unbroken, historical metric visibility for auditing purposes. The operations team has a scheduled 4-hour maintenance window for a database cluster, during which application workloads will fluctuate drastically and trigger standard high-utilization alarms. To comply with the audit mandates, the architect must ensure that performance metrics continue to be collected and evaluated normally throughout the window, but no actual notifications are dispatched to the operations center. Which approach should the solutions architect direct the team to implement?

A. Disable the affected OCI Alarms prior to the maintenance window and re-enable them immediately upon completion of the database updates.
B. Modify the MQL expressions within the existing alarms to artificially raise the trigger threshold during the maintenance window, then revert the thresholds afterward.
C. Delete the existing OCI Notifications subscriptions for the duration of the maintenance window and manually recreate them once the cluster stabilizes.
D. Create an OCI Alarm Suppression rule specifying the exact alarm names and the 4-hour maintenance window duration to stop notification delivery while leaving the alarms active.

**Answer: D**

---

### Q13
Your enterprise database team has deployed several single-node development databases in Oracle Cloud Infrastructure (OCI) Base Database Service. They selected the 'fast provisioning' option, which uses Logical Volume Manager (LVM) as the storage management software instead of the standard Grid Infrastructure with Automatic Storage Management (ASM). Over time, these databases have grown significantly, and the team needs to scale up the storage beyond the limit determined by the initial provisioning size. As a solutions architect, which constraint should you explain to your team regarding LVM storage scaling, and what is the correct migration path?

A. LVM allows online scaling of block volumes up to 80 TB regardless of the initial storage size, but it requires a database reboot to expand the local ext4 file system.
B. The storage management software can be dynamically converted from LVM to Grid Infrastructure with ASM via the OCI Console, which will instantly lift the storage scaling boundaries without any downtime.
C. LVM storage can only be scaled up if the virtual machine DB system is migrated to a high-density bare metal shape, because block volume resizing is completely unsupported on LVM-based VMs.
D. Storage scaling under LVM is constrained by the initial storage size specified during provisioning; to exceed this limit, they must provision a new DB system using ASM and migrate.

**Answer: D**

---

### Q14
Which is NOT a valid capability or constraint of Oracle Cloud Infrastructure (OCI) Container Instances?

A. Launching container workloads instantly without provisioning or managing any actual virtual machine infrastructure.
B. Allocating dedicated CPU and memory resources per container instance to ensure predictable, VM-grade performances.
C. Configuring containers to automatically scale horizontally based on custom CPU and memory utilization thresholding.
D. Securing container execution by leveraging hypervisor-level isolation to prevent any cross-container interference.

**Answer: C**

---

### Q15
An enterprise operates a high-frequency payment gateway using OCI Compute instances and wishes to optimize its operational response to sudden spikes in API errors. The current architecture employs an OCI Alarm that sends an email via OCI Notifications every time a 1-minute metric evaluation window detects more than 50 failed transactions. During major network disruptions, this setup floods the executive team's inboxes with thousands of individual emails, leading to severe notification fatigue and delayed remediation. Which two approaches are expensive or impractical ways to resolve this notification storm while maintaining architectural integrity? (Choose two.)

A. Adjust the alarm configuration by increasing the pending duration window and defining a reasonable repeat notification frequency to throttle subsequent messages.
B. Create a script that uses the OCI CLI to continuously delete and recreate the OCI Alarm every 60 seconds during an outage to clear the firing state history.
C. Transition all application components to publish logs to an external storage tier and configure a continuous polling loop that executes every second across all raw log objects.
D. Leverage the split notifications feature grouped by a high-level application ID dimension while setting up a suppression window immediately when a known systemic outage begins.
E. Route the OCI Alarm notifications to an OCI Notification topic backed by an Oracle Functions subscription that aggregates errors and pushes a consolidated summary to an internal chat channel.

**Answer: B, C**

---

### Q16
A government agency is migrating its central licensing databases to OCI Base Database Service virtual machine DB systems. To satisfy national archiving regulations, the agency must maintain annual database backups for a period of seven years while ensuring that archive creation does not degrade production database performance. As a lead solutions architect, you are designing a compliance archiving strategy utilizing the long-term retention (LTR) backup feature of OCI Database Autonomous Recovery Service. Which two statements are true regarding the behavior and capabilities of long-term retention (LTR) backups in OCI Database Autonomous Recovery Service? (Choose two.)

A. To guarantee backup consistency, the Recovery Service initiates a heavy full backup operation on the active production database at the exact moment the LTR backup is requested.
B. To avoid production performance overhead, the Recovery Service creates the LTR backup by utilizing already existing operational backups in the system within the defined recovery window.
C. LTR backups can be used to perform standard in-place restore operations to quickly roll back the production database to a specific compliance checkpoint.
D. LTR backups are stored in the high-performance Object Storage Standard tier to ensure the fastest possible database restore and cloning times.
E. LTR backups do not support in-place restore operations and are exclusively intended to be restored as a new database (out-of-place restore).

**Answer: B, E**

---

### Q17
An enterprise cloud operations team needs to build an automated asset inventory report that tracks all database resources deployed across their entire OCI tenancy. The report must explicitly capture the exact resource type, its compartment location, and its creation timestamp, filtering out all non-database infrastructure components. The architect must choose a solution that minimizes API rate-limiting issues associated with sequential, multi-compartment SDK polling loops. Which approach should the solutions architect direct the team to implement?

A. Implement an OCI Connector Hub that streams all tenancy resource state changes directly into an OCI Notifications topic, parsing the emails manually to compile the report.
B. Configure a custom OCI Logging Analytics parser to run continuous text regex queries over all standard infrastructure access logs across the tenancy compartments.
C. Use the OCI Search service to execute a single structured search query filtering by specific database resource types across all compartments within the region.
D. Set up an OCI Monitoring query that aggregates CPU utilization metrics from all compartments and uses the resource name dimension to reconstruct the asset inventory.

**Answer: C**

---

### Q18
Your organization utilizes OCI Resource Manager to manage its cloud-native infrastructure stacks using Terraform. To satisfy strict corporate compliance and security guidelines, all Terraform configuration files must be stored on an on-premises, nonpublic Git server that is only accessible via site-to-site VPN. Additionally, any communication between OCI Resource Manager and this private Git server must be secure and fully authenticated. As a solutions architect, which sequential approach must you recommend to configure this integration?

A. Import your Git server SSL certificate inside OCI Certificates, create a Resource Manager Private Endpoint, and configure the Configuration Source Providers referencing the two.
B. Upload your Git server SSL certificate inside OCI Vault Secrets, create a Resource Manager Service Gateway, and configure the Configuration Source Providers referencing the two.
C. Register your Git server public keys inside OCI Identity Domains, create a Resource Manager NAT Gateway, and configure the Configuration Source Providers referencing those two.
D. Deploy your Git server SSL certificate inside OCI API Gateway, create a Resource Manager Dynamic Group, and configure the Configuration Source Providers referencing those two.

**Answer: A**

---

### Q19
Which requirement must be met to enable automatic key rotation for master encryption keys in the Oracle Cloud Infrastructure (OCI) Key Management service?

A. The master encryption key must be an asymmetric RSA key stored in either a default or virtual private vault.
B. The key must reside in a virtual private vault, and the rotation interval must be configured between 60 and 365 days.
C. The key must be imported via Bring Your Own Key (BYOK) with a custom wrapping key, and the rotation interval must be exactly 90 days.
D. The key must belong to a default vault, and the next rotation date must be scheduled within 30 days of key creation.

**Answer: B**

---

### Q20
A financial services company uses an OCI Connector Hub to route operational logs from an Exadata Database Service instance located in a Production compartment to an OCI Streaming pool in a Security compartment for third-party analysis. After a recent compartment reorganization, the connector stopped transferring logs, and operators observed authorization errors in the connector's metric data. The security policy mandates that minimum necessary privileges must be maintained across these distinct administrative boundaries. Which modification should the architect direct the team to perform to restore log integration?

A. Grant full tenancy-level administrator access to the user account who originally created the OCI Connector Hub resource to bypass all compartment checks.
B. Add an IAM policy that allows the source database instances to directly push log arrays into the target compartment's streaming pool via instance principals.
C. Update the OCI Search service index configurations across both compartments to automatically map the streaming pool's resource ID to the database's log group identifier.
D. Configure an IAM policy that explicitly permits the specific connector resource or its dynamic group to read logs from the source compartment and produce messages to the target streaming pool.

**Answer: D**

---

### Q21
An enterprise uses OCI Full Stack Disaster Recovery (FSDR) to orchestrate cross-region failover of its production application from Region A to Region B. The application runs on OCI Compute instances, with their associated boot and block volumes actively replicated to the standby region. The operations team requires that when these instances are launched in Region B during a failover, they must mount to a pre-defined subnet and use a cost-optimized compute shape. Which approach should the solutions architect select to satisfy these specific resource mapping requirements?

A. Apply specific OCI compartment-level IAM policies that enforce default compute shapes and virtual cloud network constraints for instances created in the target standby region.
B. Set up an OCI Compute Instance Pool in the standby region with the desired configurations, and configure it as a non-managed Protection Group resource.
C. Develop a custom OCI Function that calls core compute APIs to dynamically override instance launch metadata, and register it as a plan pre-check step.
D. Configure the target virtual cloud network, subnet, and compute shape within the DR properties of the compute instance member in the DR Protection Group.

**Answer: D**

---

### Q22
A global consulting firm recently acquired a boutique agency that has an active OCI child tenancy with its own independent Universal Credits subscription (Subscription B). The parent tenancy of the consulting firm's organization is associated with the primary corporate subscription (Subscription A). After the agency's tenancy accepts the invitation and joins the OCI Organization, the finance team wants to immediately align the agency's resource consumption with Subscription A's preferential rate card and credit pool, while preserving Subscription B's credits. As a solutions architect, which approach should you direct your team to implement?

A. Use the parent tenancy's Subscription Mapping page to map the newly joined child tenancy to Subscription A, which shifts its consumption and rate card terms to the primary corporate subscription.
B. Initiate a cross-tenancy migration to clone all child compartments into the parent tenancy, as subscription mapping cannot reassign consumption paths dynamically.
C. Configure a cross-tenancy IAM policy that authorizes the child tenancy to assume the billing administrator role of Subscription A.
D. Submit a service request to Oracle Support to merge Subscription B's credits directly into Subscription A, as subscription mapping can only be applied to newly created child tenancies.

**Answer: A**

---

### Q23
A healthcare application must meet strict compliance standards regarding data protection, requiring that all healthcare information be encrypted both when stored on disk and during transmission across networks. The application team plans to deploy an OCI Cache with Redis cluster to cache user session profiles containing sensitive health data. As a solutions architect, which approach must you select to ensure full compliance with these encryption mandates?

A. Rely on OCI Cache's built-in capabilities, which automatically enforce encryption-at-rest using Oracle-managed keys and require TLS encryption for all data-in-transit.
B. Deploy the OCI Cache cluster inside a public subnet and use custom iptables rules to encrypt all data payloads before they reach the cluster.
C. Implement client-side application encryption layers because OCI Cache only supports encryption-at-rest and does not provide native transit encryption.
D. Use OCI Vault to manually generate an asymmetric key pair and configure the application to pass this key in the connection string of every Redis command.

**Answer: A**

---

### Q24
A financial services institution deploys an enterprise application on OCI that utilizes multiple dependent block volumes for database storage, logs, and application configuration. To satisfy regulatory disaster recovery constraints, the company requires a solution that guarantees point-in-time consistency across all these volumes during a replication event. Furthermore, the recovery point objective (RPO) requires these volumes to be backed up to a secondary remote OCI region at least once every 24 hours with minimal management overhead. Which approach should the architect select to meet these resiliency requirements?

A. Configure individual, manual cron-based snapshot scripts on each compute instance to back up each block volume independently and copy them to the remote region using the OCI CLI.
B. Establish a real-time OCI File Storage service mount across both regions using a remote VCN peering connection to synchronously mirror file system blocks at the OS level.
C. Implement an OCI Data Guard configuration between the compute instances to replicate block sector changes over an encrypted TLS connection directly to an object storage bucket located in the destination region.
D. Group the dependent block volumes into a single OCI Volume Group and apply a backup policy that automatically executes cross-region replication of the volume group backups to the designated secondary region daily.

**Answer: D**

---

### Q25
Your enterprise deploys microservices to an OCI Kubernetes Engine (OKE) cluster, pulling images from private repositories in the OCI Container Registry (OCIR). The security team requires all container images to be automatically scanned for security vulnerabilities whenever they are pushed, and re-scanned automatically whenever new definitions are added to the Common Vulnerabilities and Exposures (CVE) database. They also insist that the operations team must minimize manual configuration for new repositories. As a solutions architect, which approach should you recommend to implement this security requirement?

A. Configure OCI Vulnerability Scanning service targets for repositories, ensuring local image scanning remains enabled, and rely on automatic re-scans when new CVEs are added.
B. Deploy a custom OCI Events rule triggered by push events to invoke an Oracle Function that pulls the image, runs local scanning, and writes results to Object Storage.
C. Configure your OCI DevOps build pipeline to execute a custom docker scan script using a shell stage, and then manually publish the exported report to active OKE nodes.
D. Implement a Kubernetes cronjob within OKE that runs hourly to pull down new images, run open-source scanning tools inside a pod, and upload reports to OCI Registry.

**Answer: A**

---

### Q26
A medical systems provider is planning a Globally Distributed Autonomous AI Database deployment. The security team initially selects OCI Vault Service (KMS) but plans to transition to Oracle Key Vault later during expansion. As a solutions architect, which critical design limitation regarding encryption key management must you share with the team?

A. The encryption key type cannot be changed from OCI Vault Service (KMS) to Oracle Key Vault once the database is created.
B. Oracle Key Vault (OKV) can only be enabled if the central catalog database is migrated to an on-premises Exadata environment first.
C. Changing encryption key managers requires a database reboot and manually recreating the OCI private endpoint for every active database shard.
D. Both key managers can be run concurrently, but each database shard must be temporarily stopped to rotate the master keys.

**Answer: A**

---

### Q27
A company is configuring an OCI Kubernetes Engine (OKE) deployment to pull images from a private repository in the OCI Container Registry (OCIR). Which username format should the administrator specify in the Kubernetes image pull secret for a federated user to authenticate successfully?

A. The username format configured as <username>@<tenancy-namespace> where the namespace is a static tenancy name.
B. The username format configured as <tenancy-namespace>/<username> which uses the specific main identity domain.
C. The username format configured as <identity-provider>/<tenancy-namespace>/<username> for the federated users.
D. The username format configured as <tenancy-namespace>/oracleidentitycloudservice/<username> for authentication.

**Answer: D**

---

### Q28
An enterprise replicates its Oracle Cloud Infrastructure (OCI) File Storage service (FSS) file system from Region A to Region B for disaster recovery. During a regional outage in Region A, the operations team needs to failover and immediately enable read-write access to the replicated data in Region B. However, OCI File Storage constraints prevent directly exporting or writing to a file system that is currently configured as a replication target. As a solutions architect, which approach must you direct your team to follow to resolve this issue and restore application services in Region B?

A. Temporarily delete the replication target resource, which automatically converts the target file system into a standard read-write file system.
B. Configure reverse replication from Region B back to Region A, which automatically unlocks the target file system for write operations.
C. Edit the replication target settings to change the target file system access mode from Read-Only to Read-Write.
D. Create a clone of the last applied replication snapshot on the target file system to a new file system, and then export the cloned file system.

**Answer: D** (A is a garbled version of "delete the replication"; confirm with the Udemy explanation)

---
