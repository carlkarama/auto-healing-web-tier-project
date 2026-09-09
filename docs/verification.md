# Test results — 9 September 2026

The live results below cover the native-NGINX deployment before containerisation, in `us-east-1`, workspace `budget-constraint`, using Terraform 1.16.0. Container checks are recorded separately at the end.

| Check | Result |
| --- | --- |
| `terraform fmt -recursive` | Passed; no formatting changes needed. |
| `terraform validate` | Passed. |
| Fresh plan and apply | 20 resources created; none changed or destroyed. |
| Plan after apply | No changes; exit code 0. |
| Second apply | 0 added, 0 changed, 0 destroyed. |
| Plan after both VM replacements | No changes; exit code 0. |
| Final infrastructure | Two healthy `t4g.nano` VMs, two encrypted 8 GiB gp3 disks, no public IPv4 addresses. |

## Self-healing test

Two concurrent curl probes recorded HTTP status, response time, NGINX page content and the `X-Web-Instance` header. After both VMs were serving, each was terminated directly through the EC2 API, one at a time. ASG desired capacity stayed at one. The first replacement was serving before the second VM was terminated.

| Test | Successful responses | First response from replacement | Slowest response |
| --- | ---: | ---: | ---: |
| Terminate VM A | 325/325 | 145.61 seconds | 2.47 seconds |
| Terminate VM B | 446/446 | 140.58 seconds | 2.46 seconds |

All 771 requests in the termination/recovery windows returned HTTP 200 with the NGINX page. Each response was a CloudFront cache miss. The initial healthy baseline served 58 requests from A and 76 from B; the final baseline served 84 from replacement A and 79 from replacement B.

| Slot | Terminated instance | Replacement instance |
| --- | --- | --- |
| A | `i-00913034df3bf03ec` | `i-07fc304e1b3d69f16` |
| B | `i-0ceb579636195daff` | `i-0ff7a217a3fbc300d` |

AWS scaling activity records confirm automatic replacement after EC2 health checks detected termination. Both replacements reused their original ENI, IPv6 address and public DNS name. The original VMs and their root disks were removed.

Initial startup took roughly four minutes. The warmup probe recorded 260 HTTP 504s while NGINX was installing; these are excluded from the failure tests, which began only after both VMs served HTTP 200. Across the healthy baselines and failure tests, all 1,193 sampled GET requests succeeded.

Raw request logs, ASG activity, before/after resource details and Terraform outputs are stored locally in `artifacts/live-test-20260909T042726Z` (ignored by Git). The [creation plan](terraform-plan.txt) remains available for review.

The `us-east-1` VPC `vpc-07c58bf7107a3f944` and both healthy VMs were preserved. Its state was unchanged, and the final Terraform plan reported `No changes` (exit code 0).

The new site returned HTTP 200 for all 1356 requests sampled during cleanup, with responses from both VMs.

## Containerisation checks

Checked on 9 September 2026, on `feat/implement-optional-tasks`.

| Check | Result |
| --- | --- |
| ARM64 image build | Passed using the pinned NGINX 1.30.4 Alpine base image. |
| Container smoke test | Passed: HTTP 200, welcome page, instance header, `no-store`, IPv6 loopback, Docker health and automatic restart after NGINX exits. |
| Resource limits | Smoke test passed with 64 MiB container memory and 64 PIDs. |
| Publication | Pushed `nginx-1.30.4-arm64-v1` to `ecr-public.aws.com/n0l2m0r6/auto-healing-web-tier`. |
| Anonymous pull | Succeeded using an empty Docker configuration; the published image matched the tested local image. |
| Terraform checks | Root and registry validation passed; formatting, rendered bootstrap shell syntax and all four routing tests passed. |
| Web-tier plan and apply | Applied successfully: 0 additions, 4 in-place updates, 0 deletions. Updated two launch templates and their ASG version references. |
| Follow-up plan and second apply | Plan reported no changes (exit 0); second apply: 0 added, 0 changed, 0 destroyed. |
| Registry provisioning | One ECR Public repository created with Terraform; a subsequent registry plan made no changes. |

The pinned image digest is `sha256:bb72fe04472b22fb7e4f8026aded48d9e5a80b4e73e488626032b3fec0181a4b`. See the [container update plan](container-plan.txt).

## Live container rollout

The container configuration was applied in `us-east-1`, workspace `budget-constraint`. Each existing native-NGINX VM was then terminated through the EC2 API, one at a time, with ASG desired capacity kept at one. A was serving from its container and its startup log was checked before B was terminated.

| Test | Successful responses | First response from replacement | Slowest response |
| --- | ---: | ---: | ---: |
| Replace A | 1,859/1,859 | 745.89 seconds | 2.38 seconds |
| Replace B | 1,336/1,336 | 563.02 seconds | 2.63 seconds |

All **3,195 requests during the replacement tests** returned HTTP 200, the expected welcome page and a CloudFront cache miss, with no curl errors. Including the healthy baselines, all **3,714 sampled requests** succeeded between 05:35:41 and 06:04:41 UTC on 9 September 2026. The final baseline served 58 requests from replacement A and 62 from replacement B.

| Slot | Terminated instance | Container replacement |
| --- | --- | --- |
| A | `i-07fc304e1b3d69f16` | `i-05b5fb0f44c83629e` |
| B | `i-0ff7a217a3fbc300d` | `i-0f569a6d5a931f1ae` |

AWS scaling activity confirms both replacements were automatic. Each replacement used launch-template version 2 and user-data matching the applied plan. Both console logs show the pinned image download, `CONTAINER_READY` from Docker inspect with `running=true`, `network=host` and `restart=unless-stopped`, followed by NGINX 1.30.4 and successful cloud-init completion. This verifies the actual image pull and automatic container startup on the IPv6-connected VMs.

Both retained their original ENI, IPv6 address and public DNS name. The final inventory has two healthy `t4g.nano` VMs in separate availability zones, standard CPU credits, two encrypted 8 GiB gp3 root disks and no public IPv4 addresses. Both old VMs are terminated and their root disks have been deleted. The default workspace's state files were unchanged.

Docker installation is slow on these CPU-limited instances; the observed recovery times were about 12.5 and 9.4 minutes. The other VM served throughout each replacement, with failover adding latency. These results cover the sampled GET workload. Forced container restart was tested locally; the live checks verified the restart policy and startup on new VMs.

Raw probes, applied plans, console logs, scaling activity and final inventory are stored locally in `artifacts/container-live-test-20260909T053425Z` (ignored by Git).

Docker restarts an exited container and starts it after a host reboot. Its health check reports an unhealthy container but does not itself restart a hung process; ASG replacement continues to use EC2 health checks.
