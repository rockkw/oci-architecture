# Lab 3 - OCI Architect Pro Exam - IAM Policies

#7_mystudy #OCI  
**Plan item:** Build and test 2-3 compartment-scoped IAM policies, including a dynamic group. Explain least privilege, policy scope, and identity-domain versus IAM use.

**Companion references:** [[5. Security — OCI IAM, WAF, Certificates, Vault, Cloud Guard]] for the underlying concepts (dynamic group mechanics, verb hierarchy, default-deny posture, the Default-vs-secondary-domain replication distinction); [[Lab 1 - OCI Architect Pro Exam]] for the tenancy context.

**Redesign note:** the original plan for this lab reused Lab 1's `sandbox`-domain API Gateway dynamic group as a least-privilege narrowing exercise. That dynamic group turned out to sit in a `SECONDARY` identity domain that had never been replicated to `us-phoenix-1` — a multi-hour investigation (see "Investigation log" below) that never reached a working state even after fixing the actual root cause. Lab 3 is redesigned to be fully self-contained: every policy here uses the **Default** domain and needs no working API Gateway, no Function, and no dependency on Lab 1's still-unresolved Gateway issue.

---

## Policy 1 — Dynamic group in the Default domain, demonstrating zero-membership-by-default

A dynamic group matching Compute instances in `sandbox`, created in the **Default** identity domain — before any matching instance exists. This needs no compute cost and no dependency on anything from Lab 1.

**Matching rule:**
```
ALL {resource.type = 'instance', resource.compartment.id = 'ocid1.compartment.oc1..aaaaaaaa7s64nst5is7tmveri2ymuenrjrcg5h5n2lxnvamdtk7cuazg32da'}
```

**Policy statement (paired with it):**
```
Allow dynamic-group compute-instance-dg to use object-family in compartment sandbox
```

**Test:** confirm zero members before any instance exists, and confirm the dynamic group is actually visible via the classic API (unlike the `sandbox`-domain object from the investigation, which never appeared here despite being correctly configured):
```bash
oci iam dynamic-group list --compartment-id ocid1.tenancy.oc1..aaaaaaaag5dosbtiqa3kvncf5c3hlbpp3ip5tolvponbtrvwh5ch6dbmwq4q --query "data[?contains(name,'compute-instance-dg')].{name:name,id:id}" --output table
```
This alone demonstrates two things at once: "zero dynamic groups exist by default" (Note 5) *and* "a correctly configured but empty dynamic group still grants nothing to nobody" — no resource has matched yet, so there's nothing to authorize regardless of how permissive the policy statement is.

**Optional extension:** launch a throwaway Compute instance in `sandbox` and confirm it becomes a member automatically, with no manual add step — proving the matching-rule mechanism live rather than just by description.

- [ ] Dynamic group created in Default domain, confirmed empty
- [ ] Confirmed visible via `oci iam dynamic-group list` (contrast with the investigation's `sandbox`-domain failure)
- [ ] (Optional) test instance launched, membership confirmed automatic

---

## Policy 2 — Compartment-scoped, read-only human-group policy

Demonstrates the `read` verb (visibility without modification rights) and compartment scoping (a group can see into `sandbox` but has zero visibility into `rocklz-*` compartments, since OCI's default-deny posture means no grant = no access, not partial/inherited access from being in the same tenancy).

**Statement:**
```
Allow group <group-name> to read all-resources in compartment sandbox
```

**Honest limitation on testing this one:** a full behavioral test requires logging in as a non-Administrators user to confirm the boundary actually holds (Administrators' tenancy-wide `manage all-resources` grant would mask any scoping problem in this new policy — you'd never see it fail even if the compartment scope were wrong). Options: create a test user with only this group membership, or reason through the design without a live behavioral test and note that as a limitation rather than pretending it was verified.

- [ ] Statement created
- [ ] Tested as non-admin user (or explicitly noted as untested due to Administrators-only access)

---

## Investigation log — what the sandbox-domain dynamic group taught us, now resolved

This ran for hours across a real troubleshooting arc before finally resolving — the sequence of eliminated hypotheses is worth more to the exam than a clean first-try success would have been, since it surfaces a genuine, hard-won distinction most study material never covers.

**Sequence of eliminated hypotheses, in order:**
1. Cross-region IAM propagation lag (Note 5's original theory) — waited repeatedly, re-saved the matching rule, no change
2. `resource.type` case sensitivity — found Oracle's own docs specify lowercase `apigateway`, not the community-blog `ApiGateway` — fixed, no change
3. Missing statements — found a walkthrough showing three required statements (`virtual-network-family`, `public-ips`, `functions-family`), not just one — added all three, no change
4. Domain-prefix syntax for non-default-domain subjects (`sandbox/dynamic-group-name`) — confirmed correct syntax per Oracle docs, applied, no change
5. Stale deployment backend reference — verified via CLI the deployment's route pointed at the current, live Function — ruled out
6. **Actual root cause found**: `oci iam domain get` showed the `sandbox` domain as `"type": "SECONDARY"` with `"replica-regions": null` — never replicated to any region beyond its home (`us-ashburn-1`)
7. Enabled replication via `oci iam domain enable-replication-to-region`, confirmed `SUCCEEDED` via the work request — retried immediately, **still failed**, with a genuinely fresh, post-replication log entry showing the identical error
8. Classic `oci iam dynamic-group list` still could not see the dynamic group even after domain replication succeeded, for a further stretch of time
9. **Resolved on a later retry, no further configuration changes** — the domain-level replication was the correct fix all along; the work request's `SUCCEEDED` status marked the domain container's arrival in the new region, not the immediate enforceability of objects inside it

**What this actually demonstrates:** the work request status for `enable-replication-to-region` reports on **domain-container replication only**. Object-level propagation — the dynamic group and its matching rule actually becoming visible to classic IAM APIs and enforceable by services like API Gateway — is a **separate, unreported completion point** that happens sometime after. Oracle's tooling gives you a checkable signal for the first stage but not the second, which makes the second stage functionally indistinguishable from Rule 1's ordinary propagation delay — you just have to wait it out, the same as any other IAM change, except now on top of a domain-replication step that already took its own meaningful time.

**Practical takeaway carried into this lab's redesign:** for anything you need working reliably and quickly, prefer the **Default** domain unless there's a specific reason to isolate objects in a secondary one. If you do use a secondary domain, budget for two sequential waits, not one: domain-container replication (checkable via work request), then object-level propagation inside that container (not directly checkable — treat it like ordinary IAM propagation and just wait).

---

## Written explanation: least privilege, policy scope, and identity-domain vs. IAM

### Least privilege
OCI's default is implicit deny everywhere — nothing can do anything until explicitly granted (Note 5). Least privilege in this model isn't about writing deny rules (OCI has no general explicit-deny); it's entirely about **how narrowly you choose to grant**. Policy 1's empty dynamic group is a related but distinct demonstration: a resource-type/compartment scope that currently matches nothing is the tightest possible "grant" — narrower than any verb choice, since there's no member to exercise the permission at all yet.

### Policy scope
Scope is set by the `in compartment <name>` / `in compartment id <ocid>` / `in tenancy` clause, and by the resource-type/verb combination. Policy 2 demonstrates compartment scope specifically: a grant scoped to `sandbox` has no bearing on `rocklz-app-cmp`, `rocklz-network-cmp`, etc. — compartments are not exposed to each other by default the way, for example, resources in the same AWS account might be reachable across services without an explicit deny.

### Identity domains vs. IAM
- **IAM policies** are the authorization layer — they answer "can this principal do this action on this resource." This is what both policies above are.
- **Identity domains** are the authentication/identity-lifecycle layer — they manage users, groups, MFA, SSO, and federation (SAML 2.0/OIDC), as covered in Note 5's core model. A dynamic group's *matching rule* and a policy's *grant* both sit downstream of identity domains: the domain establishes who/what a principal is and how it authenticates; IAM policy then decides what that already-authenticated principal is allowed to do.
- **The investigation log above is the real answer, not the textbook one:** in theory, "which domain an object lives in" should be transparent to policy evaluation as long as syntax is correct, once that domain is replicated where needed. In practice, replication to a new region has **two sequential completion points** — the domain container itself, and the objects inside it — and Oracle's tooling only gives you a checkable status for the first. The exam-safe answer is the clean conceptual model (domains authenticate, policies authorize); the field-tested answer is "a `SUCCEEDED` replication work request means the domain has arrived, not that everything inside it is immediately usable — budget a further, unmonitored wait."

---

## Recall / design exercises

- [ ] Explain why a dynamic group with zero matching resources is a stronger demonstration of "least privilege" than a narrow verb grant on a populated one.
- [ ] A teammate says "identity domains are OCI's version of IAM." Correct this — what's the actual division of responsibility between the two?
- [ ] Policy 2 was designed but its compartment-scoping behavior couldn't be behaviorally verified under an Administrators-only test account. Explain why Administrators membership specifically masks this kind of test, and what a valid test setup would require instead.
- [ ] Walk through the investigation log's nine steps from memory. At which step would checking `replica-regions` first have saved the most time, and which step's delay was fundamentally unavoidable even with perfect diagnosis?
- [ ] A `SECONDARY` domain replicates successfully (confirmed via work request) but its dynamic group still isn't visible to `oci iam dynamic-group list` for some time afterward. Explain why "domain container replication" and "object-level propagation" are two separate completion points, and why only the first is reported by tooling.
- [ ] Explain the practical rule this lab settled on for choosing between Default and a secondary domain for a new dynamic group or policy subject, and the two-wait budgeting rule for when a secondary domain is used anyway.

## Official references

- [How OCI IAM Policies Work](https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/policies.htm)
- [Managing Dynamic Groups](https://docs.oracle.com/en-us/iaas/Content/Identity/dynamicgroups/managingdynamicgroups.htm)
- [IAM with Identity Domains](https://docs.oracle.com/en-us/iaas/Content/Identity/)
- [Managing Regions for Identity Domains](https://docs.oracle.com/en-us/iaas/Content/Identity/domains/to-manage-regions-for-domains.htm)
