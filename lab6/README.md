# Lab 6 -- Ansible configuration management and a Packer golden AMI

Azeez Kehinde Bolaji, student ID 157691239 -- ACS730

## Required sentences

- **Runner-to-instance mechanism:** I used AWS Systems Manager Session Manager, because it needs no inbound port and no stored key: the instance's SSM agent dials out over 443 using the LabInstanceProfile, and the runner authenticates with the same temporary session credentials, so there is no private key in repository secrets and no port 22 open to a runner whose address changes. (Packer's own build uses an ephemeral per-run key pair and a temporary port-22 security group that it deletes at the end of the build; nothing of that is kept.)
- **What changed=0 on a second run proves:** it proves every task checked the real state of each host and found it already matched what the role asks for, not that the playbook did nothing, which is what makes the same command safe on a brand-new instance, on an already converged one, and from a pipeline on every merge.
- **Why deregistering an AMI is not enough:** the AMI is only a pointer, and the EBS snapshot behind it is the stored data and the thing that bills, so deregistering leaves the snapshot behind, and once the AMI is gone describe-images can no longer say which snapshot belonged to it; I read the snapshot id first and delete both.

## Design notes

- Terraform tags each instance `Lab=lab6` and `Role=web` and attaches the existing `LabInstanceProfile`; there is no key pair and no port 22 rule. The `amazon.aws.aws_ec2` inventory filters on those tags and groups by `Role`, so no instance id or IP is written anywhere in the repository.
- Ansible reaches the `role_web` group over the `aws_ssm` connection. The SSM transfer bucket and `ansible_aws_ssm_region` must both be us-east-1; if they disagree, the first task fails with PermanentRedirect.
- The playbook is a four-line play that calls the `webserver` role. It uses fully-qualified module names, YAML-dict arguments, quoted modes, `state: present`, `state: started` and a handler for the restart, so the second run reports changed=0.
- The workflow `lab6-configure.yml` installs Ansible, boto3 and the SSM plugin before provisioning, and runs the playbook in the step immediately after `terraform apply`, behind a retry loop because apply returns before the SSM agent has registered.

## Comparison

| Path | Seconds (launch to HTTP 200) | What it includes |
|---|---|---|
| Converge on boot (Terraform replace + Ansible over SSM) | 104 | destroying the old instance (about 30 s), launching the new one, SSM agent registration, running the role, service start |
| Golden AMI (Packer) | 20 | instance launch and boot only; the role was applied once at build time |

The 104 s figure includes about 30 s of Terraform destroying the instance being replaced, which the golden-AMI run did not have, so the true gap is somewhat smaller than 104 vs 20. The packages (`python3`, `rsync`) were already in the AL2023 image, so `dnf` downloaded nothing in this run; the time went to the replace, waiting for the SSM agent to register, and the role's tasks over Session Manager. The Packer build itself took 3 min 40 s, paid once.

The golden AMI moves the work rather than removing it: the work happens once at build time instead of on every launch. So the AMI wins once you launch more than a couple of instances and loses when you launch one, because you paid a full Packer build to save about 80 seconds.

- **What breaks with golden AMIs:** an image is a frozen moment, so updates released after the bake are not in it and you need a rebuild cadence; and you cannot see inside it without reading the build log, whereas a playbook is the documentation.
- **What breaks with converge-on-boot:** every launch depends on the package mirrors and the SSM service being reachable right then, so a mirror outage means instances that boot and never become ready, at exactly the moment (autoscaling at night) you do not want a network dependency in the boot path.

**Recommendation:** golden AMI, because we launch in groups and want instances ready in seconds with no network dependency at boot; I would switch to converge-on-boot for a single long-lived server that changes often, where a rebuild per change is not worth it.

## Experiments

### Experiment 1: break idempotency with a shell task
Prediction: Without creates:: changed=1 on both runs, on both hosts. A shell task can’t look at the host to see whether its work is already done, so it reports changed every time. 
Expected, with creates:: changed=0. Ansible checks whether /opt/acs730-web/logs exists and skips the task if it does.
Result: with `ansible.builtin.shell: mkdir -p /opt/acs730-web/logs` the recap showed changed=1 on both hosts on the first run and changed=1 again on the second run. After adding `creates: /opt/acs730-web/logs` the run showed changed=0 on both hosts.
Explanation: Ansible cannot work this out for itself because a shell command is opaque, so it cannot inspect the host to see whether the command's effect already exists and reports changed every time; `creates:` gives it a path to check. (The directory already existed from the earlier runs, so this run was skipped.) Afterwards I restored the original tasks and re-confirmed changed=0.

### Experiment 2: `state: latest` versus `state: present`
Prediction:It depends. present means “installed”, latest means “the newest version available”, so it reports changed only if a newer python3 or rsync has been published. If none had, I’d expect changed=0 both times.
Result: with `state: latest` on the dnf task both runs showed changed=0 on both hosts, because no newer packages were available at that moment.
Explanation: the answer does depend on the day: on any day upstream ships an update to `python3` or `rsync`, `latest` would report changed and silently upgrade packages I did not ask for. In a pipeline that runs on every merge I want `present`, because a merge should only change what the code says; "always up to date" is not obviously right since it makes runs non-reproducible and lets an upstream release break a deploy, so updates should be a deliberate change, such as a rebuilt golden AMI. I restored `state: present` and re-confirmed changed=0.
