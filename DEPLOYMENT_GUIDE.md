# Deployment Guide

Complete step-by-step guide for deploying the prod-dev infrastructure on AWS.

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Local Deployment (Manual)](#local-deployment-manual)
3. [GitHub Actions Deployment (CI/CD)](#github-actions-deployment-cicd)
4. [Switching Environments](#switching-environments)
5. [Rollback Procedure](#rollback-procedure)
6. [Post-Deployment Validation](#post-deployment-validation)
7. [Common Deployment Scenarios](#common-deployment-scenarios)

---

## Pre-Deployment Checklist

Before deploying, ensure you have completed these items:

### AWS Setup

- [ ] AWS account with appropriate permissions (VPC, EC2, ALB, ASG, IAM, S3)
- [ ] AWS CLI installed and configured
- [ ] IAM user/role with programmatic access

```bash
# Verify AWS CLI configuration
aws sts get-caller-identity
```

### Local Tools

- [ ] Terraform v1.6+ installed
- [ ] Git installed

```bash
# Verify Terraform
terraform version

# Expected output: Terraform v1.6.x or higher
```

### S3 Backend (Required for Team/CI)

- [ ] S3 bucket created for Terraform state

```bash
# Create S3 bucket (one-time)
aws s3 mb s3://your-unique-bucket-name --region us-east-1

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket your-unique-bucket-name \
  --versioning-configuration Status=Enabled
```

### GitHub Secrets (For CI/CD)

- [ ] `AWS_ACCESS_KEY_ID` - IAM access key
- [ ] `AWS_SECRET_ACCESS_KEY` - IAM secret key
- [ ] `TF_STATE_BUCKET` - S3 bucket name
- [ ] `AWS_REGION` - AWS region (optional, defaults to us-east-1)

---

## Local Deployment (Manual)

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/prod-dev-deployment.git
cd prod-dev-deployment
```

### Step 2: Create Backend Configuration

Create `terraform/backend.hcl` (this file is gitignored):

```hcl
bucket = "your-terraform-state-bucket"
key    = "prod-dev/terraform.tfstate"
region = "us-east-1"
```

### Step 3: Initialize Terraform

```bash
cd terraform

# Initialize with S3 backend
terraform init -backend-config=backend.hcl
```

**Expected output:**
```
Initializing the backend...
Successfully configured the backend "s3"!
Terraform has been successfully initialized!
```

### Step 4: Review the Plan

```bash
terraform plan -var="active_target=prod"
```

**What you'll see:**
- VPC and networking resources
- Security groups (alb-sg, app-sg)
- Application Load Balancer
- Target groups (prod-tg, dev-tg)
- Launch templates (prod-template, dev-template)
- Auto Scaling Groups (prod-asg, dev-asg)

**Expected:** `Plan: 18 to add, 0 to change, 0 to destroy`

### Step 5: Apply (Deploy prod Environment)

```bash
terraform apply -var="active_target=prod"
```

Type `yes` when prompted.

**Deployment takes approximately 3-5 minutes.**

### Step 6: Get the Application URL

```bash
terraform output app_url
```

**Example output:**
```
app_url = "http://main-alb-123456789.us-east-1.elb.amazonaws.com"
```

### Step 7: Verify Deployment

```bash
# Wait 2-3 minutes for instance to become healthy
# Then test the URL
curl $(terraform output -raw app_url)
```

**Expected:** HTML response with "prod Environment"

---

## GitHub Actions Deployment (CI/CD)

### Step 1: Configure GitHub Secrets

Navigate to: **Repository → Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your IAM access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret access key |
| `TF_STATE_BUCKET` | Your S3 bucket name |
| `AWS_REGION` | `us-east-1` (or your preferred region) |

### Step 2: Push Code to Repository

```bash
git add .
git commit -m "Initial prod-dev deployment setup"
git push origin main
```

### Step 3: Run the Workflow

1. Go to **Actions** tab in GitHub
2. Select **prod-dev Deployment** workflow
3. Click **Run workflow**
4. Select target environment:
   - **prod** - Deploy to prod environment
   - **dev** - Deploy to dev environment
5. Click **Run workflow**

### Step 4: Monitor the Workflow

The workflow executes these steps:
1. **Checkout** - Gets the latest code
2. **Setup Terraform** - Installs Terraform
3. **Configure AWS** - Sets up AWS credentials
4. **Terraform Init** - Initializes with S3 backend
5. **Terraform Format** - Validates code formatting
6. **Terraform Plan** - Shows what will change
7. **Terraform Apply** - Applies the changes

### Step 5: View Outputs

After successful completion, check the workflow logs for:
- ALB DNS name
- Application URL
- Active target confirmation

---

## Switching Environments

### Understanding the Switch

When you switch from prod to dev (or vice versa):

| What Changes | prod Active | dev Active |
|--------------|-------------|--------------|
| Listener forwards to | prod-tg | dev-tg |
| prod-asg desired_capacity | 1 | 0 |
| dev-asg desired_capacity | 0 | 1 |
| Traffic goes to | prod instances | dev instances |

### Switch via CLI (Local)

```bash
cd terraform

# Current: prod is active
# Switch to dev
terraform apply -var="active_target=dev"
```

**What happens:**
1. Listener rule changes to forward to `dev-tg`
2. `dev-asg` scales from 0 → 1 (launches instance)
3. `prod-asg` scales from 1 → 0 (terminates instance)
4. New instance takes ~3-5 minutes to become healthy
5. Traffic automatically routes to dev

### Switch via GitHub Actions

1. Go to **Actions** → **prod-dev Deployment**
2. Click **Run workflow**
3. Select **dev**
4. Click **Run workflow**

### Verify the Switch

```bash
# Check which environment is active
curl $(terraform output -raw app_url)

# Or check the /health endpoint
curl $(terraform output -raw app_url)/health
```

**Expected response after switching to dev:**
```json
{"status":"ok","environment":"dev","version":"1.0","timestamp":"..."}
```

---

## Rollback Procedure

### Instant Rollback

If something goes wrong with the dev deployment, rollback instantly:

```bash
# Rollback to prod
terraform apply -var="active_target=prod"
```

Or via GitHub Actions:
1. Run workflow with **prod** selected

### Rollback Timeline

| Time | Action |
|------|--------|
| 0s | Run `terraform apply -var="active_target=prod"` |
| ~10s | Listener switches to prod-tg |
| ~30s | prod ASG begins scaling up |
| ~2-3 min | New prod instance passes health checks |
| ~3-5 min | Full traffic on prod, dev scales down |

### Emergency Rollback (AWS Console)

If Terraform is unavailable, use AWS Console:

1. **EC2 → Load Balancers → main-alb**
2. **Listeners → HTTP:80 → View/edit rules**
3. Change forward action to the other target group
4. Save changes

---

## Post-Deployment Validation

### Checklist After Each Deployment

#### 1. Verify ALB Health

```bash
# Get ALB DNS
terraform output alb_dns_name

# Test connectivity
curl -I http://$(terraform output -raw alb_dns_name)
```

**Expected:** `HTTP/1.1 200 OK`

#### 2. Check Target Group Health

**AWS Console:**
- EC2 → Target Groups → prod-tg (or dev-tg) → Targets tab
- Status should be **healthy**

**CLI:**
```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names prod-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

#### 3. Test Application Endpoints

```bash
APP_URL=$(terraform output -raw app_url)

# Home page
curl $APP_URL

# Health check
curl $APP_URL/health
```

#### 4. Verify Auto Scaling Group

```bash
# Check prod ASG
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names prod-asg \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Running:Instances[*].HealthStatus}'

# Check dev ASG
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names dev-asg \
  --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Running:Instances[*].HealthStatus}'
```

---

## Common Deployment Scenarios

### Scenario 1: First-Time Deployment

```bash
# 1. Initialize
cd terraform
terraform init -backend-config=backend.hcl

# 2. Deploy prod
terraform apply -var="active_target=prod"

# 3. Verify
curl $(terraform output -raw app_url)
```

### Scenario 2: Deploy New Version to dev

```bash
# 1. Update app/dev/app.js with new code
# 2. Commit and push changes
git add app/dev/
git commit -m "Update dev app with new feature"
git push origin main

# 3. Switch to dev (launches new instance with updated code)
terraform apply -var="active_target=dev"

# 4. Verify new version
curl $(terraform output -raw app_url)/health
```

### Scenario 3: Rollback After Failed Deployment

```bash
# dev deployment has issues
# Immediately switch back to prod
terraform apply -var="active_target=prod"

# Verify prod is serving traffic
curl $(terraform output -raw app_url)
```

### Scenario 4: Update Infrastructure (Not App)

```bash
# Made changes to Terraform files (e.g., instance type)
# Plan first
terraform plan -var="active_target=prod"

# Apply if changes look correct
terraform apply -var="active_target=prod"
```

### Scenario 5: Complete Teardown

```bash
# Destroy all resources
terraform destroy -var="active_target=prod"

# Verify (should show no resources)
terraform show
```

---

## Deployment Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEPLOYMENT FLOW                                  │
└─────────────────────────────────────────────────────────────────────────┘

  FIRST DEPLOYMENT                    ENVIRONMENT SWITCH
  ═══════════════                     ══════════════════

  ┌─────────────┐                     ┌─────────────────┐
  │  git clone  │                     │ Update app code │
  └──────┬──────┘                     └────────┬────────┘
         │                                     │
         ▼                                     ▼
  ┌─────────────┐                     ┌─────────────────┐
  │ terraform   │                     │   git commit    │
  │    init     │                     │   git push      │
  └──────┬──────┘                     └────────┬────────┘
         │                                     │
         ▼                                     ▼
  ┌─────────────┐                     ┌─────────────────┐
  │ terraform   │                     │ terraform apply │
  │   plan      │                     │ -var=dev      │
  └──────┬──────┘                     └────────┬────────┘
         │                                     │
         ▼                                     ▼
  ┌─────────────┐                     ┌─────────────────┐
  │ terraform   │                     │ Listener switch │
  │   apply     │                     │ ASG scales      │
  │ -var=prod   │                     └────────┬────────┘
  └──────┬──────┘                              │
         │                                     ▼
         ▼                            ┌─────────────────┐
  ┌─────────────┐                     │ Health checks   │
  │   Wait for  │                     │    pass         │
  │   healthy   │                     └────────┬────────┘
  └──────┬──────┘                              │
         │                                     ▼
         ▼                            ┌─────────────────┐
  ┌─────────────┐                     │ Traffic on new  │
  │  Access     │                     │  environment    │
  │  ALB URL    │                     └─────────────────┘
  └─────────────┘


  ROLLBACK                            CI/CD (GitHub Actions)
  ════════                            ══════════════════════

  ┌─────────────┐                     ┌─────────────────┐
  │ Issue       │                     │ Push to main    │
  │ detected    │                     └────────┬────────┘
  └──────┬──────┘                              │
         │                                     ▼
         ▼                            ┌─────────────────┐
  ┌─────────────┐                     │ Actions trigger │
  │ terraform   │                     │ or manual run   │
  │   apply     │                     └────────┬────────┘
  │ -var=prod   │                              │
  └──────┬──────┘                              ▼
         │                            ┌─────────────────┐
         ▼                            │ Select prod or  │
  ┌─────────────┐                     │    dev        │
  │ Instant     │                     └────────┬────────┘
  │ switch back │                              │
  └──────┬──────┘                              ▼
         │                            ┌─────────────────┐
         ▼                            │ Workflow runs   │
  ┌─────────────┐                     │ init/plan/apply │
  │ Service     │                     └────────┬────────┘
  │ restored    │                              │
  └─────────────┘                              ▼
                                      ┌─────────────────┐
                                      │ Deployment      │
                                      │ complete        │
                                      └─────────────────┘
```

---

## Troubleshooting During Deployment

### Terraform Init Fails

```
Error: Failed to get existing workspaces
```

**Fix:** Check S3 bucket exists and credentials have access:
```bash
aws s3 ls s3://your-bucket-name
```

### Terraform Apply Times Out

**Cause:** Instance never becomes healthy.

**Fix:**
1. Check target group health in AWS Console
2. Connect to instance via EC2 Instance Connect
3. Check logs: `sudo cat /var/log/user-data.log`

### 502 Bad Gateway After Deploy

**Cause:** Instance not ready or app not running.

**Fix:**
1. Wait 3-5 minutes for health checks
2. If still failing, check instance:
   ```bash
   sudo systemctl status nodeapp
   curl http://127.0.0.1:3000/
   ```

### GitHub Actions Fails at AWS Credentials

**Cause:** Missing or incorrect secrets.

**Fix:** Verify all secrets are set correctly in GitHub:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `TF_STATE_BUCKET`

---

## Quick Reference

| Task | Command |
|------|---------|
| Initialize | `terraform init -backend-config=backend.hcl` |
| Plan | `terraform plan -var="active_target=prod"` |
| Deploy prod | `terraform apply -var="active_target=prod"` |
| Switch to dev | `terraform apply -var="active_target=dev"` |
| Rollback to prod | `terraform apply -var="active_target=prod"` |
| Get URL | `terraform output app_url` |
| Check State | `terraform show` |
| Destroy | `terraform destroy -var="active_target=prod"` |

---

## Next Steps

After successful deployment:

1. **Set up monitoring** - CloudWatch alarms for ALB and ASG
2. **Configure HTTPS** - Add ACM certificate and HTTPS listener
3. **Custom domain** - Create Route 53 alias record
4. **Auto scaling policies** - Configure scaling based on CPU/traffic
5. **CI/CD enhancements** - Add testing stages to workflow
