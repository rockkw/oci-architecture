# OCI Architect Professional (1Z0-997-22) — Practice Questions

*Captured from Quizlet flashcard set (816295295)*

---

### Q2
A data analytics company has been building its next generation big data and analytics platform on Oracle Cloud Infrastructure (OCI). They need a storage service that provides the scale and performance that their big data applications require, such as high throughput to compute nodes with low latency file operations. In addition, their data needs to be stored redundantly across multiple nodes in a single availability domain and allows concurrent connections from multiple compute instances hosted on multiple availability domains. Which OCI storage service can you use to meet this requirement?

A. Object Storage
B. File System Storage
C. Archive Storage
D. Block Volume

---

### Q3
You are working as a cloud engineer for an IoT startup company which is developing a health monitoring pet collar for dogs and cats. The company collects biometric information of the pet every second and then sends it to Oracle Cloud Infrastructure (OCI). Your task is to come up with an architecture which will accept and process the monitoring data as well as provide complete trends and health reports to the pet owners. The portal should be highly available, durable, and scalable with an additional feature for showing real-time biometric data analytics. Which architecture will help you meet this requirement?

A. Use OCI Streaming Service to collect the incoming biometric data... *(still cut off in source PDF)*
B. Use Oracle Functions to process the data and show the results on a real-time dashboard, and store the results to OCI Object Storage. Store the data in OCI Autonomous Data Warehouse (ADW) to handle analytics.
C. Launch an open source Hadoop cluster to collect the incoming biometrics data. Use an open source Fluentd cluster to analyze the data, and send the results to OCI Autonomous Transaction Processing (ATP) to handle complex analytics.
D. Create an OCI Object Storage bucket to collect the incoming biometric data from the... *(still cut off in source PDF)*

**Answer: A** (confirmed directly in PDF source)

*(Note: options A and D remain cut off in the source PDF itself — this appears to be a genuine gap in the original material.)*

---

### Q4
Bot Management in OCI provides which of the features? **Select TWO correct answers.**

A. Good Bot Allowlist
B. CAPTCHA Challenge
C. IP Prefix Steering
D. Bad Bot Denylist

---

### Q5
Which IAM policy should be created to give XYZ the ability to list contents of a resource, excluding the ones that need to authenticate, in the prod compartment? Principle of least privilege should be used.

A. Allow group XYZ to read all resources in tenancy where target.compartment.name != prod
B. Allow group XYZ to use all resources in compartment != prod
C. Allow group XYZ to manage all resources in compartment != prod
D. Allow group XYZ to inspect all resources in tenancy where target.compartment.name != prod

---

### Q6
What is the use case for Oracle Cloud Infrastructure Logging Analytics service?

A. Automatically create instances to collect logs, analyze, and send reports
B. Labels data packets that pass through the internet gateway
C. Monitors, aggregates, indexes, and analyzes all log data from on-premises
D. Automatically and manage any log based on a subscription model

---

### Q7
Select the component that encompasses the overall configuration of your WAF service on OCI.

A. Protection rules
B. Bot Management
C. Web Application Firewall policy
D. Origin

---

### Q8
As a solutions architect, you need to assist the operations team to write an IAM policy to give users in group-uat1 and group-uat2 access to manage all resources in the compartment Uat. Which is the CORRECT IAM policy?

A. Allow any-user to manage all resources in tenancy where target.compartment = Uat
B. Allow group /group-uat*/ to manage all resources in compartment Uat
C. Allow group group-uat1, group-uat2 to manage all resources in compartment Uat
D. Allow any-user to manage all resources in compartment at where request.group=/group-uat/*

---

### Q9
On which option do you set Oracle Cloud Infrastructure Budget?

A. Instances
B. Tenancy
C. Compartments
D. Free-form tags

---

### Q10
What does an audit log event include?

A. Audit type
B. Type of input
C. Header
D. Footer

---

### Q11
A company needs to have some buckets as public in the compartment. You want Cloud Guard to ignore the problem associated with the public bucket. **Select TWO correct answers.**

A. Dismiss the issues associated with these resources
B. Make the bucket private so that Cloud Guard won't detect it
C. Configure conditional groups for the detector to fix baseline
D. First make the bucket private and after a few days make the bucket public again

---

### Q12
A company has an OCI tenancy which has a mount target associated with two File Systems, CG1 and CG2. These File Systems are accessed by IP-based clients AB1 and AB2 respectively. As CG1 and CG2 have Read/Write access on AB1/AB2, how can you provide access to both clients such that CG1 has Read-only access on AB1?

*(Note: question text was garbled/cut off in the screenshot — may need to revisit source for exact wording)*

A. NFS Export Option
B. Access Control Lists
C. NFS v3 Unix Security
D. Vault

---

### Q13
In which two ways can you improve data durability in Oracle Cloud Infrastructure Object Storage? **Select TWO correct answers.**

A. Setup volumes in a RAID1 configuration
B. Enable server-side encryption
C. Enable Versioning
D. Limit delete permissions
E. Enable client-side encryption

---

### Q14
Which statements are CORRECT about Security Zone policy in OCI? **Select TWO correct answers.**

A. Block volume can be moved from a security zone to a standard compartment
B. Bucket can't be moved from a security zone to a standard compartment
C. Resources in a security zone must be accessible from internet
D. Resources in a security zone must be encrypted using customer-managed keys

---

### Q15
As a Security Admin you want to inspect the metadata and actual data in your Oracle databases to discover sensitive data and provide comprehensive results listing the sensitive columns and related information. Which Data Safe feature will help you to achieve the above requirement?

A. Data Masking
B. Data Discovery
C. Security Assessment
D. User Assessment

---

### Q16
As a security architect, how can you prevent unwanted bots while desirable bots are allowed to enter?

A. Data Guard
B. Vault
C. Compartments
D. Web Application Firewall (WAF)

---

### Q17
Which storage type is most effective when you want to move some unstructured data, consisting of images and videos, to cloud storage?

A. Object Storage
B. File Storage
C. Archive Storage
D. Block Volume

---

### Q18
Which type of file system does File Storage use?

A. NFSv3
B. iSCSI
C. Paravirtualized
D. NVMe
E. SSD

---

### Q19
Which Oracle Data Safe feature minimizes the amount of personal data and allows internal test, development, and analytics teams to operate with reduced risk?

A. Data auditing
B. Data encryption
C. Security assessment
D. Data masking
E. Data discovery

---

### Q20
What do the features of OS Management Service do?

A. Add complexity in using multiple tools to manage mixed-OS environments
B. Provide paid service and support to OCI subscribers for fixes on priority
C. Increase security and reliability by regular bug fixes
D. Encourage manual setup to avoid machine-induced errors

---

### Q21
With regard to OCI Audit Log Service, which of the statement is INCORRECT?

A. Audit Events gets collected when modification within objects stored in an Object Storage bucket
B. Retention period for audit events cannot be modified
C. Events logged by the Audit service can be viewed by using the Console, API, or the SDK for Java
D. REST API calls can be recorded by Audit service

---

### Q22
You are using a custom application with third-party APIs to manage application and data hosted in an Oracle Cloud Infrastructure (OCI) tenancy. Although your third-party APIs don't support OCI's signature-based authentication, you want them to communicate with OCI resources. Which authentication option must you use to ensure this?

A. API Signing Key
B. Auth Token
C. OCI username and Password
D. SSH Key Pair with 2048-bit algorithm

---

### Q23
When using Management Agent to collect logs continuously, which is the required configuration for OCI Logging Analytics to retrieve data from numerous logs for an instance?

A. Source-Entity Association
B. Entity - Source Association
C. Entity - Agent Association
D. Agent - Entity Association

---

### Q24
You subscribe to a PaaS service that follows the Shared Responsibility model. Which type of security is your responsibility?

A. Data
B. Guest OS
C. Infrastructure
D. Network

---

### Q25
Which statements are CORRECT about Multi-Factor Authentication in OCI? **Select TWO correct answers.**

A. Members of the Administrators group can disable MFA for other users
B. A user can register multiple devices to use for MFA
C. Members of the Administrators group cannot enable MFA for another user
D. Users cannot enable MFA for themselves

---

### Q26
Which statement is true about using custom BYOI instances in Windows Servers that are managed by OS Management Service?

A. Windows Servers that already has the minimum agent version requires an agent update or installation
B. Windows Servers that does not have the minimum agent version requires an agent update or installation
C. Windows Servers that already has the minimum agent version does not require an agent update or installation
D. Windows Servers that does not have the minimum agent version does not require an agent update or installation

---

### Q27
As a security administrator, you found out that there are users outside your corporate network who are accessing OCI Object Storage Bucket. How can you prevent these users from accessing OCI resources in the corporate network?

A. Create an IAM policy and add a network source
B. Make OCI resources private instead of public
C. Create an IAM policy and create WAF rules
D. Create a PAR to restrict the access

---

### Q28
You want to make API calls against other OCI services from your instance without configuring user credentials. How would you achieve this?

A. Create a dynamic group and add a policy
B. Create a dynamic group and add your instance
C. Create a group and add a policy
D. No configuration is required for making API calls

---

### Q29
Which statement is true about Oracle Cloud Infrastructure (OCI) Object Storage server-side encryption?

A. All the traffic to and from object storage is encrypted by using Transport Layer Security
B. Encryption is not enabled by default
C. Customer-provided encryption keys are never stored in OCI Vault service
D. Each object in a bucket is always encrypted with the same data encryption key

---

### Q30
Which statement is true about origin management in WAF?

Statement A: Multiple origins can be defined.
Statement B: Only a single origin can be active for a WAF.

A. Only statement B is true
B. Both the statements are false
C. Both the statements are true
D. Only statement A is true

---

### Q32
What is the minimum active storage duration for logs used by Logging Analytics to be archived?

A. 60 days
B. 10 days
C. 30 days
D. 15 days

---

### Q33
Which components are a part of the OCI Identity and Access Management service?

A. Policies
B. Regional subnets
C. Compute instances
D. VCN

---

### Q34
An E-commerce company which sells computers, tablets, and other electronics items has recently decided to move all of their on-premises infrastructure to Oracle Cloud Infrastructure (OCI). One of their on-premises applications is running on an NGINX server and the Oracle Database is running in a 2 node Oracle Real Application Clusters (RAC) configuration. They cannot afford to have any application down time when they do the migration. What is an effective mechanism to migrate the customer application to OCI and set up regular automated backups?

A. Launch a compute instance and run an NGINX server to host the application. Deploy a 2 node VM DB Systems with Oracle RAC enabled. Import the on-premises database to OCI VM DB Systems using Oracle Data Pump and then enable automatic backups.
B. Launch a compute instance for both the NGINX application server and the database server. Attach block volumes on the database server compute instance and enable backup policy to backup the block volumes.
C. Launch a compute instance and run an NGINX server to host the application. Deploy a 2 node VM DB Systems with Oracle RAC enabled. Setup Oracle GoldenGate to synchronize data from their on-premises database to OCI VM Database. Export and Import the on-premises database to OCI VM DB Systems using Oracle Data Pump, apply the GoldenGate trail files to sync up the OCI database with the on-premises database. Enable automatic backups for the OCI VM database and then cut over the application from on-premises to OCI.
D. Launch a compute instance and run an NGINX server to host the application. Deploy Exadata Quarter Rack, enable automatic backups and import the database using Oracle Data Pump.

**Answer: C** (confirmed directly in PDF source)

---

### Q35
When creating an OCI Vault, which factors may lead to select the Virtual Private Vault? **Select TWO correct answers.**

A. Need for more than 9211 key versions
B. Greater degree of isolation
C. To mask PII data for non-production environment
D. Ability to back up the vault

---

### Q36
Cloud Guard detected a risk score of zero in the dashboard, what does this mean?

A. Risk score doesn't say anything. These are just numbers
B. LOW or MINOR issues
C. Larger number of problems that have high risk levels (HIGH or CRITICAL)
D. No problem detected for any resource

---

### Q37
With regard to vulnerability and cloud penetration testing, which rules of engagement apply? **Select TWO correct answers.**

A. Any port scanning must be performed in an aggressive mode
B. Physical penetration and vulnerability testing of Oracle facilities is prohibited
C. Testing should target any other subscription or any other Oracle Cloud customer resources
D. You are responsible for any damages to Oracle Cloud customers that are caused by your testing activities

---

### Q38
How can you establish private connectivity over two VCN within same OCI region without traversing the traffic over public internet?

A. NAT Gateway
B. Data Guard
C. Remote VCN Peering
D. Local VCN Peering

**Answer: D**

---

### Q39
Which security issues can be identified by Oracle Vulnerability Scanning Service? **Select TWO correct answers.**

A. Distributed Denial of Service (DDoS)
B. Ports that are unintentionally left open can be a potential attack vector for cloud resources
C. SQL Injection
D. CIS published Industry-standard benchmarks

---

### Q40
What are the security recommendations and best practices for Oracle Functions?

A. Grant privileges to UID and GID 1000, such that the functions running within a container acquire the default root capabilities
B. Add applications to network security groups for fine-grained ingress/egress rules
C. Define a policy statement that enables access to functions for requests coming from multiple IP addresses
D. Ensure that functions in a VCN have restricted access to resources and services

---

### Q44
You have configured the Management Agent on an Oracle Cloud Infrastructure (OCI) Linux instance for log ingestion purposes. Which is a required configuration for OCI Logging Analytics service to collect data from multiple logs of this Instance?

A. Log - Log Group Association
B. Log Group - Source Association
C. Entity - Log Association
D. Source - Entity Association

---

### Q45
Which of the following features is NOT supported by Oracle Cloud Infrastructure Multi-factor authentication (MFA)?

A. Users can disable MFA for their own accounts
B. Only the user can enable MFA for their own account
C. Members of the Administrators group can enable MFA for other users
D. Members of the Administrators group can disable MFA for other users

---

### Q46
Which of the following is NOT a good use case for the Oracle Cloud Infrastructure (OCI) Streaming service?

A. Meeting compliance requirements for data to remain unchanged over a long time, so that it can be retrieved for audit purposes
B. Ingesting metric and log data to help make critical operational data more quickly available for indexing, analysis, and visualization
C. Messaging with a pull-based communication model and the ability to feed multiple consumers with the same data independently
D. Providing a unified entry point for cloud components to report their life cycle events for audit, accounting, and related activities

---

### Q47
An Oracle Cloud Infrastructure (OCI) load balancer is configured with three listeners and one path route set:

Listener 1 — Virtual hostname: none, Default backend set: A, Path route set: PathRouteSet1
Listener 2 — Virtual hostname: captive.com, Default backend set: B, Path route set: PathRouteSet1
Listener 3 — Virtual hostname: wild.com, Default backend set: C, Path route set: PathRouteSet1

Path Route Set — Path route set name: PathRouteSet1
- Exact match on path string /tame/ routes to backend set B.
- Exact match on path string /feral/ routes to backend set C.

You need to validate the destination for each of the following URLs:
U1: http://captive.com/
U2: http://wild.com/tame/

Which statement is true?

A. U1 will be routed to backend set B, and U2 will be routed to backend set C.
B. U1 and U2 will be routed to backend set A.
C. U1 will be routed to backend set A, and U2 will be routed to backend set B.
D. U1 and U2 will be routed to backend set B.

**Answer: D** (confirmed directly in PDF source)

---

### Q48
A developer is using Oracle Functions to deploy her code as part of an event-driven solution in Oracle Cloud Infrastructure (OCI). When she invokes her function, Oracle Functions returns a FunctionInvokeImageNotAvailable message and a 502 error:

```
{"code":"FunctionInvokeImageNotAvailable","message":"Failed to pull function image"}
Fn: Error invoking function. status: 502 message: Failed to pull function image
```

Which of the following options is NOT a plausible reason for this error?

A. The function does not exist in the specified location in OCI Registry
B. The VCN being used does not have an internet gateway or a service gateway configured for Oracle Functions to be able to access OCI Registry
C. OCI Events service rule is not configured with the correct location of the function in OCI Registry
D. Missing or invalid IAM policy to give Oracle Functions read access to images stored for functions in repositories in OCI Registry

---

### Q49
As an administrator you want to give users of ObjectWriters group full access to bucket Bucket-A and its objects in compartment comp-images. You want users of ObjectWriters to not be able to access or modify properties of any other buckets and its objects in the compartment comp-images. Select the statement(s) below that will best define your IAM policies.

A. Allow group ObjectWriters to inspect buckets in compartment comp-images. Allow group ObjectWriters to read buckets in compartment comp-images where target.bucket.name=Bucket-A. Allow group ObjectWriters to manage objects in compartment comp-images where target.bucket.name=Bucket-A
B. Allow group ObjectWriters to manage buckets in compartment comp-images. Allow group ObjectWriters to manage objects in compartment comp-images where target.bucket.name=Bucket-A
C. Allow group ObjectWriters to read buckets in compartment comp-images. Allow group ObjectWriters to manage objects in compartment comp-images where target.bucket.name=Bucket-A
D. Allow group ObjectWriters to manage buckets in compartment comp-images where target.bucket.name=Bucket-A

**Answer: A** (confirmed directly in PDF source)

---

### Q50
You are tasked with backing up your data using Oracle Cloud Infrastructure Block Volume service. When you are finalizing your block volume backup schedule, which of the following two are valid considerations for your backup plan? **(Choose Two)**

A. Governance: Tagging of backups so you can capture backup related API calls through the Audit service
B. Location: Determine the Object Store Bucket where the backups will be stored
C. Number of stored backups: How many backups you need to keep available and the deletion schedule for those you no longer need
D. Encryption: Whether to use your own key to encrypt your volume backups
E. Frequency: How often you want to back up your data

---

### Q51
You are responsible for migrating your on-premises legacy databases on 11.2.0.4 version to Autonomous Transaction Processing - Dedicated (ATP-D) in Oracle Cloud Infrastructure (OCI). As a solution architect, you need to plan your migration approach. Which three options do you need to implement together to migrate your on-premises databases to OCI?

A. Convert on-premises databases to PDB, upgrade to 19c, and encrypt
B. Use Oracle Data Guard to keep on-premises database always active during migration
C. Use Oracle GoldenGate replication to keep on-premises database online during migration
D. Retain all legacy structures and unsupported features (e.g. legacy LOBs) in the on-premises databases for migration
E. Launch Autonomous Transaction Processing - Dedicated database in OCI
F. Retain changes to Oracle shipped privileges, stored procedures or views in the on-premises databases

---

### Q52
You have configured backups for your Oracle Cloud Infrastructure (OCI) 2-node RAC DB systems on virtual machines. In the console, the database backup displays a Failed status. Which of the following options is the most likely reason for this backup issue?

A. The auth token being used by the Object Store Swift endpoint is incorrect
B. The master key stored in OCI Key Management for encryption and decryption of data in the database is not accessible to the backup service
C. The RMAN backup agent is not compatible with the version of database being used
D. The allocated storage on the OCI File Storage service file system attached with the database is full

---

### Q53
Which of the following is NOT a good use case for the volume backup feature of the Oracle Cloud Infrastructure Block Volume service?

A. Meet compliance and regulatory requirements for data to remain unchanged over time, so that it can be retrieved for audit purposes
B. Support business continuity requirements of reducing the risk of outages or data mutation over time
C. Rapidly duplicate an environment in seconds to test configuration changes without impacting your production environment
D. Retain a copy of data in a volume, so that you can duplicate an environment later or preserve the data for future use

---

### Q54
A company is running High Performance Computing workloads on Oracle Cloud Infrastructure and are using OCI bare metal compute shape. They have decided to create a custom image of the bare metal instance's boot disk and use it to launch other instances. Which of the following is NOT a true statement?

A. Before you create a custom image of an instance, you must disconnect all iSCSI attachments and remove all iscsid node configurations from the instance
B. Custom images do not include the data from any attached block volumes
C. Editing custom Windows images is not supported due to hardware differences between shapes
D. You can create additional custom images of an instance while the instance is engaged in the image creation process

---

### Q55
A cloud consultant is working on an implementation project on Oracle Cloud Infrastructure (OCI). As part of the compliance requirements, the objects placed in OCI Object Storage should be automatically archived first and then deleted. He is testing a lifecycle policy on Object Storage and created a policy as below:

```
[
{ "name": "Archive_doc", "action": "ARCHIVE", "objectNameFilter": { "inclusionPrefixes": ["doc"] }, "timeAmount": 5, "timeUnit": "DAYS", "isEnabled": true },
{ "name": "Delete_doc", "action": "DELETE", "objectNameFilter": { "inclusionPrefixes": ["doc"] }, "timeAmount": 5, "timeUnit": "DAYS", "isEnabled": true }
]
```

What will happen after this policy is applied?

A. All the objects having file extension "doc" will be archived for 5 days and will be deleted 10 days after object creation
B. All the objects having file extension "doc" will be archived 5 days after object creation
C. All the objects with names starting with "doc" will be archived 5 days after object creation and will be deleted 5 days after archival
D. All objects with names starting with "doc" will be deleted after 5 days of object creation

---

### Q56
A manufacturing company is planning to migrate their on-premises database to Oracle Cloud Infrastructure and has hired you for the migration. Customer has provided following information regarding their existing on-premises database: Database version, database character set, storage for data staging, acceptable length of system outage. What additional information do you need from customer in order to recommend a suitable migration method? **(Choose Two)**

A. Data types used in the on-premises database
B. Number of active connections
C. Elapsed time since database was last patched
D. Top 5 longest running queries
E. On-Premises host operating system and version

---

### Q57
As a solution architect, you are designing a web application to be deployed across multiple Oracle Cloud Infrastructures (OCI) regions for a global audience. Your goal is that users from each region should access the application web servers deployed in their own geographical OCI location. Which OCI feature can be used to achieve this?

A. OCI Public Load Balancers
B. OCI Global Load balancers
C. OCI Traffic Management GeoLocation steering policy
D. OCI Traffic Management IP Prefix steering policy

---

### Q59
Many development engineers are deploying new instances as part of their projects in Oracle Cloud Infrastructure tenancy, but majority of these instances have not been tagged. You as an administrator of this tenancy want to enforce tagging to identify owners who are launching these instances. Which option below should be used to implement this requirement?

A. Create a default tag for each compartment which ensure appropriate tags are allowed at resource creation
B. Create a predefined tag with tag variables to automatically tag a resource with username
C. Create tag variables for each compartment to automatically tag a resource with user name
D. Create an IAM policy to automatically tag a resource with the username

---

### Q60
An online gaming application is deployed to multiple Availability Domains in the Oracle Cloud Infrastructure (OCI) us-ashburn-1 region. Considering the high volume of traffic that the gaming application handles, the company has hired you to ensure that the data stored by the application is scalable, highly available, and disaster resilient. In the event of failure, the Recovery Time Objective (RTO) and Recovery Point Objective (RPO) must be less than 2 hours. Which Disaster Recovery strategy should be used to achieve the RTO and RPO requirements in the event of a system failure?

A. Create a user defined backup policy with a schedule of generating daily backups for block volumes.
B. Create a user defined backup policy with a schedule of generating hourly backups for block volumes.
C. Configure hourly block volume backups through the OCI Storage Gateway service.
D. Configure hourly block volume backups using the OCI Command Line Interface (CLI).

**Answer: D** (confirmed directly in PDF source — note this seems like an odd "best" answer versus B, but it's what the source key states)

---

### Q1
You are designing the network infrastructure for an application consisting of a web server (server-1) and a Domain Name Server (server-2) running in two different subnets inside the same Virtual Cloud Network (VCN) in Oracle Cloud Infrastructure (OCI). You have a requirement where your end users will access server-1 from the internet and server-2 from your customers on-premises network. The on-premises network is connected to your VCN over a FastConnect virtual circuit.

How should you design your routing configuration to meet these requirements?

A. Configure two routing tables: first one with a route to internet via an Internet gateway associate this route table to the subnet containing server-1. Configure the second route table to propagate specific routes to the on-premises network via a Dynamic Routing Gateway associate this route table to subnet containing server-2
B. Configure two routing tables that have rules to route all traffic via a Dynamic Routing Gateway. Associate the two routing tables with all the VCN subnets
C. Configure a single routing table with two set of rules: one that has route to internet via an Internet Gateway and another that propagates specific routes to the on-premises network via a Dynamic Routing Gateway; associate this single table to both subnets

**Answer: A** (confirmed directly in PDF source)

*(Note: option C is still cut off mid-sentence in the source PDF itself, and no option D is visible in that source either — this appears to be a genuine gap in the original material, not just our capture.)*

---

### Q61
Your security team has informed you that there are a number of malicious requests for your web application coming from a set of IP addresses originating from a country in Europe. Which of the following methods can be used to mitigate these type of unauthorized requests?

A. Delete Internet Gateway from Virtual Cloud Network
B. Web Application Firewall policy using access control rules
C. Deny rules in Virtual Cloud Network Security Lists for the specific set of IP addresses
D. Deny rules in Virtual Cloud Network Security Group for the specific set of IP addresses

---

### Q62
You are building a demo for a customer that showcases Oracle Cloud Infrastructure (OCI) Events service and Oracle Functions. You plan to create an event every time an image is uploaded to an OCI Object Storage bucket. You have also created a function that is listening to the event and processes the image for face recognition. Choose the two actions from below that are NOT required to run the demo successfully.

A. You must specify an action type while creating an Event service and specify the function you want to trigger
B. You must deploy the function that does facial recognition for the demo to work
C. The function must be deployed only to Oracle Kubernetes Engine (OKE)
D. You have to enable Object Storage buckets to emit events for state changes
E. Creating an event rule is not permitted for OCI Object storage **(marked correct in source)**

---

### Q63
You have been asked to create a mobile application which will be used for submitting orders by users of a popular E-Commerce site. The application is built to work with Autonomous Transaction Processing - Serverless (ATP-S) database as the backend and HTML5 on Oracle Application Express as the front end. During the peak usage of the application you notice that the application response time is very slow. ATP-S database is deployed with 3 CPU cores and 1 TB of memory. Which two options are expensive or impractical ways to improve the application response times?

A. Scale up CPU core count and memory during peak times **(marked correct in source)**
B. Identify the maximum CPU capacity needed for peak times and scale the CPU core count for the ATP-S database to that number. ATP-S will scale the CPU core count down when not needed **(marked correct in source)**
C. Enable auto scaling for CPU cores on ATP-S database
D. Use the Machine Learning (ML) feature of the ATP-S database iteratively to tune the SQL queries used by the application
E. Identify the maximum memory capacity needed for peak times and scale the memory for the ATP-S database to that number. ATP-S will scale the memory down when not needed

---

### Q65
A customer has a Virtual Machine instance running in their Oracle Cloud Infrastructure tenancy. They realized that they wrongly picked a smaller shape for their compute instance. They are reaching out to you to help them fix the issue. Which of the below options is best recommended to suggest to the customer?

A. Change the shape of instance without reboot, but stop all the applications running on instance beforehand to prevent data corruption
B. OCI doesnt allow such an operation
C. Delete the running instance and spin up a new instance with the desired shape
D. Change the shape of the virtual machine instance using the Change Shape feature available in the console

---

### Q66
You have an application running in Microsoft Azure and want to use Oracle Autonomous Data warehouse (ADW) instance for running business analytics. How can you build a secure solution for such a use-case?

A. Connect the Oracle ADW in your VCN to the Microsoft Azure VNet over the internet
B. Create a software Remote Peering Connection between Oracle Cloud Infrastructure (OCI) Virtual Cloud Network (VCN) and Microsoft Azure Virtual Network (VNet) and connect the application with Oracle ADW instance
C. Setup an interconnect between OCI and Microsoft Azure using FastConnect and ExpressRoute. Use a Service Gateway in OCI Virtual Cloud Network to provide connectivity to the Oracle ADW instance for the application in Microsoft Azure VNet
D. Create a software VPN connection between Oracle Cloud Infrastructure (OCI) Virtual Cloud Network (VCN) and Microsoft Azure Virtual Network (VNet) and connect the application with Oracle ADW instance.

**Answer: C** (confirmed directly in PDF source)

---

### Q67
Which of the below options for private access to services within Oracle Cloud Infrastructure (OCI) is NOT valid?

A. Traffic from an OCI compute instance going through a Service Gateway to Object Storage is routed without being sent over the internet
B. You cannot use the private endpoint for hosts in the on-premises network
C. The private endpoint gives hosts within your Virtual Cloud Network access to a given service within Oracle Cloud Infrastructure
D. You can enable private access to certain services within OCI from your Virtual Cloud Network by using either a private endpoint or a service gateway

---

### Q68
You have deployed an application server in a private subnet in your virtual cloud network (VCN). For the database, you have provisioned an Autonomous Transaction Processing (ATP) serverless instance. However, you are unable to connect to the database instance from your application server. Which two steps would you need to enable this connectivity?

A. Add a stateful egress rule to the security list associated with your private subnet. Destination CIDR: 0.0.0.0/0, Protocols: All Protocols
B. Add an internet gateway to your VCN and add a route rule to your private subnet route table. CIDR: 0.0.0.0/0, Target: Internet Gateway
C. Add a remote peering connection from your VCN to the ATP VCN
D. Create a NAT Gateway and add the following route rule to the route table of private subnet. CIDR: 0.0.0.0/0, Target: NAT Gateway

---

### Q69
There are two compartments: Networks and DevInstances. There are two groups: NetworkAdmins with a user named Nick, and Devs with a user named Dave. The following IAM policies are being used:

- Allow group NetworkAdmins to manage virtual-network-family in compartment Networks
- Allow group NetworkAdmins to manage instance-family in compartment Networks
- Allow group Devs to use virtual-network-family in compartment Networks
- Allow group Devs to manage all-resources in compartment DevInstances

Nick creates a VCN in Networks compartment. Dave creates a VCN in DevInstances compartment. Which of the following statements is INCORRECT?

A. Dave launches instances in DevInstances using the VCN in Networks compartment
B. Nick cannot launch new instances in DevInstances compartment
C. Nick launches instances in Networks using VCN in DevInstances compartment
D. Dave cannot launch new instances in Networks compartment

---

### Q70
You want to automate the processing of new image files to generate thumbnails. The expected rate is 10 new files every hour. Which of the following is the most cost effective option to meet this requirement in Oracle Cloud Infrastructure (OCI)?

A. Upload files to an OCI Object storage bucket. Every time a file is uploaded, trigger an event with an action to provision a compute instance with a cloud-init script to access the file, process it and store it back in an Object storage bucket. Terminate the instance using Autoscaling policy after the processing is finished
B. Build a web application to ingest the files and save them to a NoSQL Database. Configure OCI Events service to trigger a notification using Oracle Notification Service (ONS). ONS invokes a custom application to process the image files to generate thumbnails. Store thumbnails in a NoSQL Database table
C. Upload all files to an Oracle Streaming Service (OSS) stream. Set up a cron job to invoke a function in Oracle Functions to fetch data from the stream. Invoke another function to process the image files and generate thumbnails. Store thumbnails in another OSS stream.
D. Upload files to an OCI Object storage bucket. Every time a file is uploaded, an event is emitted. Write a rule to filter these events with an action to trigger a function in Oracle Functions. The function processes the image in the file and stores the thumbnails back in an Object storage bucket.

**Answer: D** (confirmed directly in PDF source)

---

## Newly Added Questions (found in PDF, missing from original capture)

### Q31
Which of these protects customer data at rest and in transit in a way that allows customers to meet their security and compliance requirements for cryptographic algorithms and key management?

A. Security controls
B. Customer isolation
C. Data encryption
D. Identity Federation

**Answer: C**

---

### Q41
Which is true regarding importing a symmetric key into Vault (Bring Your Own Key)?

A. The key must be wrapped using an RSA asymmetric key provided by the Vault.
B. The user performing the import must have the "import" permission via an IAM Policy.
C. The user must use the Command Line Interface (CLI) for importing the key into the Vault.
D. The key must be 1024 bits.

**Answer: A**

---

### Q42
Which two Cloud Guard tasks can be configured using API or Console? **Select TWO correct answers.**

A. Create targets against your compartments to monitor resources within those.
B. Create your own rules within existing recipes.
C. Clone Config detector recipes to customize your security policies.
D. Run behavior analytics on your users.

**Answer: A, C**

---

### Q43
You know that a few buckets in your compartment should stay public, and you do not want Cloud Guard to detect these as problems. In which two ways would you handle this? **Select TWO correct answers.**

A. A public bucket is a security risk, so Cloud Guard will keep detecting it.
B. Fix the baseline by configuring the Conditional groups for the detector.
C. Resolve or remediate those problems and you should not see Cloud Guard triggering on these resources ever again.
D. Dismiss the problems associated with those resources.

**Answer: B, D**

*(Note: this is functionally a duplicate of the existing Q11 in this deck — same concept, near-identical wording, same answer pattern.)*

---

### Q63 (hybrid network / DR variant — distinct from the existing Q63 already in this deck)
Design and implement hybrid network architectures to meet high availability, bandwidth and latency requirements.

Your Oracle database is deployed on-premises and has produced 100 TB database backup locally. You have a disaster recovery plan that requires you to create redundant database backups in Oracle Cloud Infrastructure (OCI). Once the initial backup is completed, the backup must be available for retrieval in less than 30 minutes to support the Recovery Time Objective (RTO) of your solution. Which is the most cost effective option to meet these requirements?

A. Setup a FastConnect connection between on-premises data center and OCI. Then use OCI CLI command to upload database backups to OCI Object Storage Standard tier as the final destination.
B. Setup an IPsec VPN Connect between on-premises data center and OCI. Then use OCI CLI command to upload database backups to OCI Object Storage Archive tier as the final destination.
C. Use OCI Storage Gateway to transfer the backup files to OCI Object Storage Standard tier as the final destination.
D. Use OCI Storage Gateway to transfer the backup files to OCI Object Storage Archive tier as the final destination.

**Answer: C**

*(Note: the existing "Q63" already in this deck — the ATP-S mobile app scaling question — is actually labeled Q64 in the PDF source. The numbering differs slightly between the two source captures; no content was lost, this hybrid-network question was simply never captured before.)*

---

### Q71
A fast growing E-commerce company has deployed their online shopping application on Oracle Cloud Infrastructure. The application was deployed on compute instances with Autoscaling configuration for application servers fronted by a load balancer and OCI Autonomous Transaction Processing (ATP) in the backend. In order to promote their e-commerce platform, a 50% discount was announced on all products for a limited period. On day 1 of the promotional period it was observed that the application is running slow and the company's hotline is flooded with complaints. What could be two possible reasons for this situation? **Select TWO correct answers.**

A. The health check on some of the backend servers has failed and the load balancer was rebooting these servers.
B. As part of Autoscaling, the load balancer shape has dynamically changed to a larger shape to handle more incoming traffic and the system was slow for a short time during this change.
C. Autoscaling has already scaled to the maximum number of instances specified in the configuration and there is no room for scaling further.
D. The health check on some of the backend servers has failed and the load balancer has taken those servers temporarily out of rotation.

**Answer: C, D**

---

### Q72
An eCommerce company is running on Oracle Cloud Infrastructure (OCI) and many compute instances remain unused for most of the year except during Black Friday and Christmas. You suggest they use OCI's Autoscaling feature and present a slide to showcase the features of Autoscaling. Which option below is inaccurate in your presentation to the customer?

A. Autoscaling requires an instance pool as a prerequisite so that it can automatically adjust the number of compute instances in an instance pool.
B. A cooldown period between Autoscaling events lets the system stabilize at the updated level.
C. Autoscaling relies on performance metrics such as CPU utilization that are collected by OCI Monitoring service to trigger an Autoscaling event.
D. When an instance pool scales in, instances are terminated in this order: the number of instances is balanced across Availability Domains, and then balanced across Fault Domains. Finally, within a Fault Domain, the newest instance is terminated first.

**Answer: D**

---

### Q73
You have decided to migrate your application to Oracle Cloud Infrastructure and use Oracle Functions to deploy your microservices. Which monitoring metrics are available to help you calculate your total cost for using Oracle Functions per month? **(Choose Two)**

A. Number of times a function is invoked
B. Amount of storage used by your functions.
C. Network bandwidth used by your functions.
D. Length of time a function runs
E. Amount of RAM used by your functions

**Answer: A, D**

---

### Q74
As per Oracle Cloud Infrastructure (OCI) Connectivity Redundancy recommendations, you have decided to deploy two 10 GB FastConnect Virtual Circuits going from on-premises to OCI. One of these is active and the other is in stand-by mode. One of the virtual circuits is provided by OCI FastConnect partner A, while the other is provided by OCI FastConnect partner B. Despite implementing this recommended architecture, you encounter complete unavailability of connectivity between OCI and on-premises. What is the most likely reason for this issue?

A. OCI partner B leases infrastructure from partner A and both digital circuits run over the same physical line. Partner A went down.
B. The 10 GB bandwidth was not sufficient for the amount of traffic being sent, causing FastConnect to overflow.
C. The Dynamic Routing Gateway on OCI froze, bringing down both circuits.
D. The two edge routers on-premises malfunctioned simultaneously, causing both circuits to go down.

**Answer: A**

---

### Q75
Which of the following is NOT a good use case for using the functionality available in the Oracle Cloud Infrastructure (OCI) Events service?

A. Publish all events in a specific compartment to Oracle Streaming service for later analysis.
B. Capture Monitoring Alarms and invoke Autoscaling of compute instances.
C. Trigger a Function using Oracle Functions when new files are uploaded in an OCI Object Storage bucket.
D. Trigger a notification when a function completes its execution.
E. Publish a notification when long-lived tasks complete, such as OCI Autonomous Database backup completion.

**Answer: B**

---

### Q76
Your organization is planning on using Oracle Cloud Infrastructure (OCI) File Storage Service (FSS). You will be deploying multiple compute instances in OCI and mounting the file system to these compute instances. The file system will hold payment data processed by a Database instance and utilized by compute instances to create an overall inventory report. You need to restrict access to this data for specific compute instances and must be allowed/blocked per compute instance CIDR block. Which option can you use to secure access?

A. Use stateless Security List rule to restrict access from known IP addresses only.
B. Use the Export option feature of FSS to restrict access to the mounted file systems.
C. Create a new VCN security list, choose SOURCE TYPE as Service and SOURCE SERVICE as FSS. Add stateless ingress and egress rules for specific IP addresses and CIDR blocks.
D. Create and configure OCI Web Application Firewall service with built-in DNS based intelligent routing.

**Answer: B**

---

### Q77
You have to migrate your application to Oracle Cloud Infrastructure (OCI). The database is constantly being updated and needs to be online without interruptions. How can you transition the database to OCI without interrupting its use?

A. It is impossible to migrate without interruption.
B. Use an on-premises database with two-way synchronization to a cloud-based database and allow clients to connect to either database.
C. Use an on-premises database with one-way synchronization to a cloud-based database and allow clients to connect only to the on-premises database until it is synchronized.
D. Use an on-premises database with one-way synchronization to a cloud-based database and allow clients to connect only to the cloud database.

**Answer: C**

---

### Q78
You are working as a solution architect for a customer in Frankfurt, which uses multiple compute instance VMs spread among three Availability Domains in the eu-frankfurt-1 region. The compute instances do not have public IP addresses and are running in private subnets inside a VCN. You have set up OCI Autoscaling for the compute instances, but find that instances cannot be auto scaled. You have enabled monitoring on the instances. What could be wrong in this situation?

A. You need to set up a Service Gateway to send metrics to the OCI Monitoring service.
B. You need to assign a reserved public IP address to the compute instances.
C. Autoscaling only works for instances with public IP addresses.
D. Autoscaling only works with single availability domains.

**Answer: A**

---

### Q79
You are creating an Oracle Cloud Infrastructure Dynamic Group. To determine the members of this group you are defining a set of matching rules. Which of the following are the supported variables to define conditions in the matching rules? **(Choose Two)**

A. instance.compartment.id — the OCID of the compartment where the instance resides
B. instance.tenancy.id — the OCID of the tenancy where the instance resides
C. iam.policy.id — the OCID of the IAM policy to apply to the group
D. tag.\<tagnamespace\>.\<tagkey\>.value — the tag namespace and tag key

**Answer: A, D**

---

### Q80
A global media organization is working on a project which lets users upload their videos to the site. After upload is complete, the video should be automatically processed by an AI algorithm that recognizes certain actions, used later to show related advertisements. The development team wants to focus on writing AI code and not worry about underlying infrastructure for high availability, scalability, security, and monitoring. Which OCI services would meet these requirements?

A. OCI Events, Oracle Container Engine for Kubernetes, and OCI Digital Assistant.
B. OCI Resource Manager, OCI Functions, and OCI Events service.
C. OCI Object Storage, OCI Events service, and OCI Functions.
D. Oracle Container Engine for Kubernetes, OCI Notifications, and OCI Object Storage.

**Answer: C**

---

### Q81
As part of planning the network design on Oracle Cloud Infrastructure, you have been asked to create a VCN with 3 subnets, one in each Availability Domain. Each subnet needs a minimum of 64 usable IP addresses. What is the smallest subnet and VCN size you should use? (The requirements are static, no growth expected.)

A. /22 for the VCN, /25 for the subnets
B. /22 for the VCN, /24 for the subnets
C. /23 for the VCN, /25 for the subnets
D. /24 for the VCN, /24 for the subnets

**Answer: C**

---

### Q82
You have been asked to review some network proposals by a major client. The client's IT director needs to provision two VCNs for a major application. Both applications use a large number of VM instances, and so will ideally occupy VCNs with as many address spaces as possible. Additionally, in the future, VCN peering will be required to allow communication between the VCNs. Which of the following are valid IP ranges to consider for the VCNs?

A. 10.0.0.0/16 and 10.0.64.0/24
B. 10.0.1.0/24 and 10.0.1.0/27
C. 10.0.0.0/8 and 11.0.0.0/8
D. 10.0.0.0/24 and 10.0.1.0/24

**Answer: D**

---

### Q83
You have deployed a multi-tier application with multiple compute instances in OCI. You want to back up these volumes using the Volume Groups feature. The Block Volume and Compute instances exist in different compartments within your tenancy. Periodically, a few child compartments are moved under different parent compartments, and you notice that sometimes volume group backup fails. What should be the cause?

A. You have the same block volume attached to multiple compute instances; if these compute instances are in different compartments, then all concerned compartments must be moved at the same time.
B. The IAM policy allowing backup failed to move when the compartment was moved.
C. A compute instance with multiple block volumes attached cannot move when a compartment is moved.
D. You are exceeding your volume group backup quota.

**Answer: B**

---

### Q84
You are a solution architect working with a startup moving their workload to OCI. Since the workload is small, you decide it's sufficient to use 8 compute instances. The company wants common storage for their instances, so you propose attaching a block volume to multiple instances. Which of the below options is NOT true for such a solution?

A. Once you attach a block volume to an instance as read-only, it can only be attached to other instances as read-only.
B. Block volumes attached as read-only are configured as shareable by default.
C. You can delete a block volume from one instance without detaching it from all other instances, thereby keeping other instances' storage intact.
D. If the block volume is already attached to an instance as read/write non-shareable, you can't attach it to another instance until you detach it from the first instance.

**Answer: C**

---

### Q85
You are part of a project team in a development environment on OCI. You realize the CIDR block for one of the subnets in a VCN is incorrect and want to delete the subnet. While deleting, you get an error indicating there are still resources you must delete first. The error includes the OCID of the VNIC in the subnet. What action will you take to troubleshoot this issue?

A. Use OCI CLI to delete the VNIC first and then delete the subnet.
B. Use OCI CLI to call "network vnic" and "compute vnic-attachment" operations to find out the parent resource of the VNIC.
C. Copy and paste the OCID of the VNIC in the search box of the OCI Console to find out the parent resource of the VNIC.
D. Use OCI CLI to delete the subnet using the --force option.

**Answer: B**

---

### Q86
You are troubleshooting your OCI Load Balancing service configuration. You have a backend HTTP service with a backend set in the load balancer and health checks configured. Although the health checks appear good, customers sometimes experience transaction failures. Which of the following will definitely lead to this problem?

A. You are NOT using regional subnets in your VCN. With Availability Domain (AD) specific subnets, the compute instances of the backend service have issues when the AD is down.
B. You are using OCI DNS and have misconfigured the 'A' record with the wrong IP address, leading to requests not getting routed correctly.
C. You are using iSCSI for block volume attachment; TCP/IP configuration of the block volume attachment is not configured correctly, leading to issues in your backend service.
D. You are running a TCP-level health check against your HTTP service. The TCP handshake can succeed and indicate the service is up even when the HTTP service has issues.

**Answer: D**

---

### Q87
You are migrating your web application infrastructure from on-premises to OCI. You need to ensure DNS cache entries of external clients will not direct them to the on-premises infrastructure after switching to the new infrastructure. Which option will minimize this problem?

A. Reduce the TTL of the DNS records after the switch.
B. Increase the TTL of the DNS records before the switch.
C. Reduce the TTL of the DNS records before the switch.
D. DNS changes propagate fast enough that no action is necessary.
E. Increase the TTL of the DNS records after the switch.

**Answer: C**

---

### Q88
You are working as a security consultant with a global insurance organization using Microsoft Azure Active Directory as an identity provider to manage user login/passwords. When a user logs in to the OCI console, it should get authenticated by Azure AD. Which set of steps are required in OCI to meet this requirement?

A. Setup Azure AD as an Identity Provider, map Azure AD groups to OCI groups, set up IAM policies to govern access to Azure AD groups.
B. Setup Azure AD as an Identity Provider, import users and groups from Azure AD to OCI, set up IAM policies to govern access to Azure AD groups.
C. Setup Azure AD as an Enterprise Application, map Azure AD users, groups, and policies to OCI groups and users.
D. Setup Azure AD as an Enterprise Application, configure OCI for single sign-on, map Azure AD groups to OCI groups, set up IAM policies to govern access to Azure AD groups.

**Answer: A**

---

### Q89
An E-Commerce company wants to deploy their web application for Oracle Database on OCI DB Systems. In compliance with the business continuity program, they need an RPO of 1 hour and RTO of 5 minutes. The web application should be highly available within the region and meet the RTO/RPO requirements in case of a region outage. Which approach is most suitable and cost effective?

A. Deploy an Autonomous Transaction Processing (Serverless) database in one region and replicate it to another region using Oracle GoldenGate.
B. Deploy a 1-node VM Oracle database in one region. Manually configure RMAN hourly backups. Asynchronously copy backups to object storage in another region. If the primary region is unavailable, launch a new 1-node VM Database in the other region and restore from backup.
C. Deploy a 2-node VM Oracle RAC database in one region and replicate to a 2-node VM Oracle RAC database in another region using a manual setup of Oracle Data Guard.
D. Deploy a 1-node VM Oracle database in one region and replicate to a 1-node VM Oracle database in another region using a manual setup of Oracle Data Guard.

**Answer: C**

---

### Q90
You have been asked to implement a bespoke financial application in OCI using VM instances controlled by Autoscaling across multiple Availability Domains. The application stores transaction logs, intermediate transaction data, and audit data on a persistent, durable data store accessible from all application servers, mounted in the /audit folder on Linux. The system needs to tolerate the failure of two or more Fault Domains and still maintain data integrity. The solution should be as low-maintenance as possible. What storage architecture should you suggest?

A. Use locally attached NVMe instances and configure RAID 0 replication between servers.
B. Use File Storage Service (FSS). Configure FSS to operate from all Availability Domains the application servers operate in and mount the file system in the /audit folder.
C. Implement a single instance and install an NFS server, configure and create an NFS share, and mount this as /audit on the application instances.
D. Store the data on Oracle Object Storage mounted at the /audit mount point on all Linux instances using default mount options.

**Answer: B**

---

### Q91
An insurance company is storing critical financial data in an OCI block volume, currently encrypted using Oracle-managed keys. Due to regulatory compliance, the customer wants to encrypt the data using keys they control instead. Which series of tasks is required to encrypt the block volume using customer-managed keys?

A. Create a master encryption key, create a new version of the encryption key, decrypt the block volume using the existing Oracle-managed keys, and encrypt using the new version of the encryption key.
B. Create a vault, create a master encryption key in the vault, and assign this master encryption key to the block volume.
C. Create a master encryption key, create a data encryption key, decrypt the block volume using the existing Oracle-managed keys, and encrypt the block volume using the data encryption key.
D. Create a vault, import your master encryption key into the vault, generate a data encryption key, and assign the data encryption key to the block volume.

**Answer: B**

---

## Notes
- **Cross-checked against a second source (Quizlet-derived PDF export) that includes verified answer keys for most items.** This resolved almost all previously-flagged gaps.
- **Fully completed** (previously cut off, now have full option text + confirmed answer): Q1 (option C still trails off in that source PDF itself, and it never showed an option D either — this is a gap in the original material, not our capture), Q3 (options A and D still trail off in that source PDF itself), Q34, Q47, Q49, Q60, Q66, Q70.
- **Newly added** (existed in the PDF source but were entirely missing from this deck): Q31, Q41, Q42, Q43, a second/distinct Q63 (hybrid network DR scenario), and Q71–Q91. See "Newly Added Questions" section above.
- Q43 is essentially a duplicate of Q11 already in this deck (same scenario, same two correct answers) — kept both since they come from different sources, but treat as one concept for study purposes.
- The PDF source's own question numbering skips Q9→Q14 (i.e., it has no Q10, Q11, Q12, Q13) and skips Q58 — those numbers simply don't exist in that source; Q10–Q13 in this deck came from the original Quizlet capture only.
- One numbering mismatch between sources: what this deck calls "Q63" (the ATP-S mobile app / CPU-scaling question) is labeled "Q64" in the PDF source. No content is missing — just a numbering offset between the two source captures.
- Q12 remains genuinely incomplete — garbled/cut-off in the original Quizlet capture and not present in the cross-check PDF either. Still flagged for manual re-check if needed.
- Still fully captured with answers as of this update: Q1–Q91 (accounting for the Q10–13/Q58 numbering gaps noted above), with only Q12 still needing manual verification.

---

## Answer Key

*Researched against Oracle's official OCI documentation where possible. Confidence is noted for each; items marked "Uncertain" or "Insufficient info" should be verified independently — especially since some source questions were cut off (see Notes above) or based on wording that may not exactly match Oracle's live documentation.*

Q1: A — confirmed directly in PDF source (option C/D text still incomplete in that source)
Q2: B — File Storage (NFS supports concurrent multi-AD access with high throughput/low latency)
Q3: A — confirmed directly in PDF source (option A/D text still incomplete in that source)
Q4: A, B — Good Bot Allowlist, CAPTCHA Challenge (confirmed OCI WAF Bot Management sub-features; "IP Prefix Steering" is a Traffic Management feature, not Bot Management)
Q5: D (likely) — "inspect" is the correct least-privilege IAM verb for listing without needing authentication; exact compartment condition in the source had OCR artifacts, so verify wording
Q6: C — Logging Analytics monitors/aggregates/indexes/analyzes log data from on-prem and cloud
Q7: C — Web Application Firewall policy
Q8: C — comma-separated groups in a single policy statement is valid IAM syntax
Q9: C — Compartments
Q10: C — Header (Oracle docs: "Each log event includes a header ID, target resources, timestamp...")
Q11: A, C — Dismiss the issue + configure conditional groups to exempt the resource from the detector baseline
Q12: A (likely) — NFS Export Options control per-client (per-IP) read/write access on File Storage; question text was garbled in the source
Q13: C, D — Enable Versioning + Limit delete permissions (protect against overwrite/delete; encryption options address confidentiality, not durability)
Q14: B, D — Bucket can't be moved out of a security zone + resources must use customer-managed keys (confirmed via Oracle Security Zone docs)
Q15: B — Data Discovery
Q16: D — Web Application Firewall (Bot Management is a WAF capability)
Q17: A — Object Storage
Q18: A — NFSv3
Q19: D — Data Masking (confirmed via Oracle Data Safe docs)
Q20: C — Increase security and reliability by regular bug fixes
Q21: B (likely) — "Retention period cannot be modified" is the incorrect statement; current Oracle docs state retention is configurable from 90 up to 365 days
Q22: B — Auth Token (for services/APIs that don't support OCI signature-based auth)
Q23: A — Source-Entity Association (confirmed exact Oracle terminology)
Q24: A — Data (customer's responsibility under Shared Responsibility for PaaS)
Q25: A, C — Admins can disable MFA for others but cannot enable it for others (confirmed verbatim in Oracle docs)
Q26: B (best guess, medium confidence) — Windows Servers without the minimum agent version require an update/installation
Q27: A — Create an IAM policy and add a network source
Q28: A — Create a dynamic group and add a policy (matching instance + granting access)
Q29: A — All traffic to/from Object Storage is encrypted via TLS
Q30: C — Both statements are true (confirmed verbatim in legacy OCI WAF Origin Management docs: "Multiple origins can be defined, but only a single origin can be active for a WAF")
Q31: C — Data encryption (confirmed directly in PDF source)
Q32: C (medium confidence) — 30 days
Q33: A — Policies
Q34: C — confirmed directly in PDF source (GoldenGate sync + Data Pump export/import + cutover)
Q35: A, B (medium confidence on exact number in A due to OCR garbling) — need for more key versions than the shared vault limit + greater degree of isolation
Q36: D — No problem detected for any resource
Q37: B, D — Physical testing of Oracle facilities is prohibited + you're liable for damages caused to other customers
Q38: D — Local VCN Peering (confirmed — shown directly in source)
Q39: B, D — Open ports + CIS benchmark compliance (confirmed via Oracle VSS docs; VSS does not detect DDoS or SQL injection)
Q40: D (medium confidence; B is also plausible) — Ensure functions in a VCN have restricted access to resources/services
Q41: A — confirmed directly in PDF source (BYOK symmetric key must be wrapped using an RSA key from the Vault)
Q42: A, C — confirmed directly in PDF source
Q43: B, D — confirmed directly in PDF source (matches Q11's answer pattern)
Q44: D — Source-Entity Association (confirmed)
Q45: C — Members of the Administrators group can enable MFA for other users (this is the unsupported/false statement — confirmed via Oracle docs)
Q46: A — Long-term unchanged data retention for audit is an Object Storage/Archive use case, not Streaming (Streaming has limited retention)
Q47: D — confirmed directly in PDF source
Q48: C — An OCI Events service misconfiguration wouldn't cause a "failed to pull image" error; that's a registry/network/IAM issue
Q49: A — confirmed directly in PDF source
Q50: C, E — Number of stored backups/retention + backup frequency (confirmed as the two configurable elements of a user-defined Block Volume backup policy)
Q51: A, C, E — Convert to PDB/upgrade to 19c/encrypt + use GoldenGate for near-zero-downtime replication + launch the ATP-D target database (confirmed via Oracle upgrade/migration documentation)
Q52: A (medium-high confidence) — Incorrect/expired auth token for the Object Storage Swift endpoint is the most commonly documented cause of DB backup failures
Q53: C — Rapid environment duplication in seconds describes the Volume Clone feature, not Backup
Q54: D — You cannot create additional custom images while an instance is already engaged in an image-creation process (this is the false/NOT-true statement)
Q55: D (medium confidence) — Lifecycle policy timeAmounts are calculated independently from each object's own creation/last-modified time (not sequentially), so archive and delete both trigger ~5 days after creation, making the practical outcome equivalent to deletion 5 days after creation
Q56: A, E — Data types used (for replication-method compatibility) + on-premises host OS/version (for platform/endian considerations)
Q57: C — OCI Traffic Management GeoLocation steering policy
Q59: B — Create a predefined tag with tag variables to auto-populate username
Q60: D — confirmed directly in PDF source
Q61: B — WAF policy with access control rules (supports country-based blocking)
Q62: C, E — Function does NOT need to be deployed to OKE + an event rule is not "not permitted" for Object Storage (both are NOT required/false statements; E was marked correct directly in the source)
Q63 (ATP-S scaling question, as it appears in this deck): A, B — Both marked correct directly in the source (scaling manually or via a fixed high-water-mark are the impractical options; auto-scaling and SQL tuning are the practical ones). Note: this is labeled Q64 in the cross-check PDF source.
Q63 (hybrid network DR question, newly added): C — confirmed directly in PDF source (Storage Gateway to Standard tier balances the 30-minute retrieval RTO against cost, vs. Archive tier's slow retrieval)
Q65: D — Use the Change Shape feature in the console
Q66: C — confirmed directly in PDF source
Q67: B — "You cannot use the private endpoint for hosts in the on-premises network" is the NOT valid statement; on-premises hosts connected via DRG/FastConnect can reach a private endpoint's private IP
Q68: A, D — Add a stateful egress rule + create a NAT Gateway with a route to reach ATP's endpoint from a private subnet
Q69: C — "Nick launches instances in Networks using VCN in DevInstances" is INCORRECT — Nick's NetworkAdmins group has no permissions at all in the DevInstances compartment
Q70: D — confirmed directly in PDF source
Q71: C, D — confirmed directly in PDF source
Q72: D — confirmed directly in PDF source
Q73: A, D — confirmed directly in PDF source
Q74: A — confirmed directly in PDF source
Q75: B — confirmed directly in PDF source
Q76: B — confirmed directly in PDF source
Q77: C — confirmed directly in PDF source
Q78: A — confirmed directly in PDF source
Q79: A, D — confirmed directly in PDF source
Q80: C — confirmed directly in PDF source
Q81: C — confirmed directly in PDF source
Q82: D — confirmed directly in PDF source
Q83: B — confirmed directly in PDF source
Q84: C — confirmed directly in PDF source
Q85: B — confirmed directly in PDF source
Q86: D — confirmed directly in PDF source
Q87: C — confirmed directly in PDF source
Q88: A — confirmed directly in PDF source
Q89: C — confirmed directly in PDF source
Q90: B — confirmed directly in PDF source
Q91: B — confirmed directly in PDF source

**Confirmed directly from Oracle documentation (highest confidence):** Q4, Q10, Q14, Q19, Q21 (partial), Q23/Q44, Q25, Q30, Q39, Q45, Q50, Q51, Q52 (partial)
**Confirmed directly against the PDF source's answer key (highest confidence):** Q1, Q3 (partial — options still incomplete), Q31, Q34, Q38, Q41, Q42, Q43, Q47, Q49, Q60, Q62, Q63 (both versions), Q64, Q66, Q70, Q71–Q91
**Reasoned from strong domain knowledge (high confidence):** Q2, Q6, Q7, Q8, Q9, Q13, Q15, Q16, Q17, Q18, Q20, Q22, Q24, Q27, Q28, Q29, Q33, Q36, Q37, Q46, Q48, Q53, Q54, Q57, Q59, Q61, Q65, Q67, Q68, Q69
**Best-guess / lower confidence — recommend double-checking:** Q5, Q11, Q26, Q32, Q35, Q40, Q55, Q56
**Still genuinely incomplete (garbled/cut off in both sources checked so far):** Q12

---

## Currency Check Notes (verified against live Oracle docs, 2026)

### Q30 — WAF Origin Management
Checked against Oracle's current WAF documentation (Origin Management page). The underlying facts still hold in 2026:
- **Multiple origins can be defined** — confirmed true, via a feature called **Origin Groups**.
- An origin must be defined in a WAF policy before protection rules or other features can be set up.
- When at least two origins are configured in an Origin Group, **load balancing is enabled** across them — this is a bit more nuanced than the original question's flat "only a single origin can be active" framing, but the net effect (both statements true → **Answer: C**) still lines up.

**Caveat:** OCI's WAF product has evolved since this question was written for the 2022 exam version — the console flow and terminology now center on "Origin Groups" rather than a simple single-active-origin model. The concept tested is still valid, but if this appears on a current exam, expect the newer terminology. Worth a quick skim of the live docs directly: https://docs.oracle.com/iaas/Content/WAF/Tasks/originmanagement.htm
