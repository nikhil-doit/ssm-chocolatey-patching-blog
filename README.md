# Patching Beyond Microsoft: Third-Party App Management with SSM and Chocolatey

Terraform code to automate third-party application installs and upgrades on Windows Server using AWS Systems Manager and Chocolatey.

## Architecture

```
GitHub → Terraform Cloud → AWS (SSM Parameter + Document + Association) → EC2 Windows Instances (Chocolatey)
```

## What This Deploys

- VPC with public/private subnets across 2 AZs
- VPC Endpoints for SSM (private subnet connectivity)
- Windows Server 2022 EC2 instance with SSM role
- SSM Parameter Store (`/chocolatey/packages`) with package config
- SSM Command Document (`SSM-Chocolatey-ManagePackages`)
- SSM State Manager Association (daily schedule, tag-based targeting)

## Prerequisites

- AWS account with appropriate permissions
- Terraform Cloud workspace connected to this repo
- AWS credentials configured in Terraform Cloud (environment variables)

## Usage

1. Fork/clone this repo
2. Connect to a Terraform Cloud workspace (update `organization` and `workspace` in `provider.tf`)
3. Set environment variables in Terraform Cloud:
   - `AWS_ACCESS_KEY_ID` (sensitive)
   - `AWS_SECRET_ACCESS_KEY` (sensitive)
4. Push to trigger a run

## Modifying Packages

Edit the `packages` list in `terraform/main.tf`:

```hcl
packages = [
  { Name = "7zip", Version = "latest", Upgrade = "yes", Switches = "" },
  { Name = "notepadplusplus", Version = "latest", Upgrade = "yes", Switches = "" },
  { Name = "googlechrome", Version = "latest", Upgrade = "yes", Switches = "--ignore-checksums" },
  { Name = "firefox", Version = "latest", Upgrade = "yes", Switches = "" },
  { Name = "vim", Version = "latest", Upgrade = "no", Switches = "" },
]
```

Push to GitHub → Terraform applies → re-trigger association → packages updated.

## Blog Post

Full writeup: [Patching Beyond Microsoft: How I Automated Third-Party App Updates on Windows Server Using SSM and Chocolatey](#)

## References

- [AWS Blog: Manage third-party applications using SSM and Chocolatey](https://aws.amazon.com/blogs/mt/manage-third-party-application-installation-versioning-and-updates-in-windows-server-nodes-using-aws-system-manager-and-chocolatey/)
- [AWS Docs: Patching applications released by Microsoft on Windows Server](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-patching-windows-applications.html)
- [Chocolatey Package Repository](https://community.chocolatey.org/packages)

## Cleanup

```bash
terraform destroy
```
