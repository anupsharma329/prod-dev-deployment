# prod-dev Deployment with AWS ALB + Terraform

Production-ready prod-dev deployment for a Node.js application using **AWS Application Load Balancer**, **Auto Scaling Groups**, **Terraform**, and **GitHub Actions**.

---

## Overview

| Feature | Description |
|---------|-------------|
| **prod-dev** | Two identical environments (prod & dev); only one receives traffic at a time |
| **Zero-downtime** | Switch traffic instantly by changing a single variable |
| **Rollback** | Revert to previous environment in seconds |
| **Infrastructure as Code** | All AWS resources managed via Terraform |
| **CI/CD** | Deploy and switch via GitHub Actions workflow |

---

## Architecture

```
                            ┌─────────────────────────────────────────────────────────────┐
                            │                         AWS VPC                             │
                            │                      10.0.0.0/16                            │
                            │                                                             │
    ┌──────────┐            │   ┌─────────────────────────────────────────────────────┐   │
    │  Users   │────HTTP────│───│            Application Load Balancer                │   │
    │ Internet │    :80     │   │                  (main-alb)                         │   │
    └──────────┘            │   │              Security Group: alb-sg                 │   │
                            │   └─────────────────────┬───────────────────────────────┘   │
                            │                         │                                   │
                            │              ┌──────────┴──────────┐                        │
                            │              │      Listener       │                        │
                            │              │    Port 80 HTTP     │                        │
                            │              │                     │                        │
                            │              │  active_target =    │                        │
                            │              │   "prod" │ "dev"  │                        │
                            │              └──────────┬──────────┘                        │
                            │                         │                                   │
                            │         ┌───────────────┴───────────────┐                   │
                            │         ▼                               ▼                   │
                            │  ┌─────────────┐                 ┌─────────────┐            │
                            │  │  prod-tg    │                 │  dev-tg   │            │
                            │  │  Port 3000  │                 │  Port 3000  │            │
                            │  └──────┬──────┘                 └──────┬──────┘            │
                            │         │                               │                   │
                            │         ▼                               ▼                   │
                            │  ┌─────────────┐                 ┌─────────────┐            │
                            │  │  prod-asg   │                 │  dev-asg  │            │
                            │  │ desired=1/0 │                 │ desired=0/1 │            │
                            │  └──────┬──────┘                 └──────┬──────┘            │
                            │         │                               │                   │
                            │         ▼                               ▼                   │
                            │  ┌─────────────┐                 ┌─────────────┐            │
                            │  │    EC2      │                 │    EC2      │            │
                            │  │ Node.js App │                 │ Node.js App │            │
                            │  │   :3000     │                 │   :3000     │            │
                            │  │  (prod)     │                 │  (dev)    │            │
                            │  └─────────────┘                 └─────────────┘            │
                            │                                                             │
                            │  ┌─────────────┐     ┌─────────────┐                        │
                            │  │ Subnet AZ-a │     │ Subnet AZ-b │                        │
                            │  │ 10.0.1.0/24 │     │ 10.0.2.0/24 │                        │
                            │  └─────────────┘     └─────────────┘                        │
                            │                                                             │
                            └─────────────────────────────────────────────────────────────┘
```

### How It Works

1. **One apply creates both** prod and dev environments (target groups, ASGs, launch templates)
2. **`active_target`** variable controls which environment is live:
   - Listener forwards to the chosen target group
   - Active ASG has `desired_capacity = 1`, inactive has `0`
3. **Switch** by changing `active_target` and re-applying — traffic moves instantly

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **AWS Account** | With permissions for VPC, EC2, ALB, ASG, IAM |
| **Terraform** | v1.6+ installed locally |
| **AWS CLI** | Configured with credentials (`aws configure`) |
| **S3 Bucket** | For Terraform state (required for GitHub Actions) |
| **GitHub Secrets** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `TF_STATE_BUCKET` |

---

## Project Structure

```
├── .github/workflows/
│   └── deploy.yaml              # GitHub Actions workflow (prod/dev choice)
├── app/
│   ├── prod/
│   │   ├── app.js               # prod Node.js app (port 3000)
│   │   └── package.json
│   └── dev/
│       ├── app.js               # dev Node.js app (port 3000)
│       └── package.json
├── terraform/
│   ├── main.tf                  # VPC, IGW, subnets, security groups
│   ├── alb.tf                   # Application Load Balancer
│   ├── listener.tf              # Listener (forwards to prod or dev)
│   ├── target-groups.tf         # prod-tg, dev-tg (port 3000)
│   ├── autoscaling.tf           # prod-asg, dev-asg
│   ├── launch-templates.tf      # EC2 config, user_data (Node.js setup)
│   ├── variable.tf              # region, vpc_cidr, active_target
│   ├── outputs.tf               # ALB DNS, app URL
│   ├── provider.tf              # AWS provider
│   └── backend.hcl.example      # S3 backend config template
└── README.md                    # This file
```

---

## Deployment

### Step 1: Set Up S3 Backend (One-Time)

Create an S3 bucket for Terraform state:

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
```

Create `terraform/backend.hcl` (do not commit):

```hcl
bucket = "your-terraform-state-bucket"
key    = "prod-dev/terraform.tfstate"
region = "us-east-1"
```

### Step 2: Initialize Terraform

```bash
cd terraform
terraform init -backend-config=backend.hcl
```

### Step 3: Deploy prod Environment (First Time)

```bash
terraform plan -var="active_target=prod"
terraform apply -var="active_target=prod"
```

**What gets created:**
- VPC with 2 public subnets (2 AZs)
- Internet Gateway and route tables
- Application Load Balancer
- prod and dev target groups
- prod and dev Auto Scaling Groups
- prod ASG launches 1 instance, dev ASG has 0

### Step 4: Access the Application

```bash
terraform output app_url
# Output: http://main-alb-123456789.us-east-1.elb.amazonaws.com
```

Open the URL in your browser — you should see the **prod Environment** page.

---

## Switching Environments

### Switch to dev

```bash
terraform apply -var="active_target=dev"
```

**What happens:**
- Listener forwards traffic to **dev-tg**
- dev ASG scales to 1 instance
- prod ASG scales to 0 instances
- Open ALB URL → **dev Environment** page

### Switch Back to prod (Rollback)

```bash
terraform apply -var="active_target=prod"
```

Traffic instantly moves back to prod.

---

## GitHub Actions Deployment

### Set Up Secrets

In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `TF_STATE_BUCKET` | Your S3 bucket name |
| `AWS_REGION` | `us-east-1` (optional, defaults to us-east-1) |

### Run Deployment

1. Go to **Actions** → **prod-dev Deployment**
2. Click **Run workflow**
3. Select **prod** or **dev**
4. Click **Run workflow**

The workflow will:
- Checkout code
- Configure AWS credentials
- Initialize Terraform with S3 backend
- Plan and apply with selected `active_target`

---

## Health Checks

| Endpoint | Response |
|----------|----------|
| `/` | HTML page (prod or dev themed) |
| `/health` | JSON: `{"status":"ok","environment":"prod\|dev","version":"1.0","timestamp":"..."}` |

**Target group health check:** Path `/`, Port `3000`, HTTP, Success codes `200-299`

---

## Outputs

After `terraform apply`:

```bash
terraform output
```

| Output | Description |
|--------|-------------|
| `alb_dns_name` | ALB DNS name |
| `app_url` | Full URL to access the app |
| `active_target` | Currently active environment (prod/dev) |

---

## Troubleshooting

### 502 Bad Gateway

**Cause:** No healthy instances in the target group.

**Fix:**
1. Check target group health: **EC2 → Target Groups → prod-tg → Targets**
2. If unhealthy, connect to instance and check:
   ```bash
   sudo systemctl status nodeapp
   sudo cat /var/log/user-data.log
   curl http://127.0.0.1:3000/
   ```
3. If user_data failed, terminate the instance — ASG will launch a new one

### Instance Unhealthy in Target Group

**Check:**
1. App running: `sudo systemctl status nodeapp`
2. Port listening: `sudo ss -tlnp | grep 3000`
3. Local test: `curl http://127.0.0.1:3000/`

**Common causes:**
- App not listening on `0.0.0.0` (fixed in user_data with `sed`)
- File permissions (fixed with `chown`)
- user_data failed (check `/var/log/user-data.log`)

### Can't SSH to Instance

Use **EC2 Instance Connect** (no PEM key needed):
1. **EC2 → Instances** → Select instance
2. **Connect** → **EC2 Instance Connect** → **Connect**

Security group `app-sg` already allows port 22 from `0.0.0.0/0`.

### Terraform State Issues

Ensure you're using the same S3 backend:
- Locally: `terraform init -backend-config=backend.hcl`
- GitHub Actions: Uses `TF_STATE_BUCKET` secret

---

## Clean Up

To destroy all resources:

```bash
cd terraform
terraform destroy -var="active_target=prod"
```

---

## Configuration Reference

### Variables (`terraform/variable.tf`)

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidrs` | `["10.0.1.0/24", "10.0.2.0/24"]` | Subnet CIDRs |
| `active_target` | `prod` | Active environment (`prod` or `dev`) |

### Security Groups

| Name | Inbound | Purpose |
|------|---------|---------|
| `alb-sg` | 80 from 0.0.0.0/0 | ALB access from internet |
| `app-sg` | 3000 from alb-sg, 22 from 0.0.0.0/0 | App + SSH access |

---

## Summary

| Action | Command |
|--------|---------|
| **Initialize** | `terraform init -backend-config=backend.hcl` |
| **Deploy prod** | `terraform apply -var="active_target=prod"` |
| **Switch to dev** | `terraform apply -var="active_target=dev"` |
| **Rollback to prod** | `terraform apply -var="active_target=prod"` |
| **Destroy** | `terraform destroy -var="active_target=prod"` |

---

## License

MIT
