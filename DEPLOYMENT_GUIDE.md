# Deployment Guide (prod/dev switching with Terraform)

This guide matches the current repository layout and Terraform/GitHub Actions behavior.

## Pre-deployment checklist

- **AWS CLI configured**

```bash
aws sts get-caller-identity
```

- **Terraform installed** \(1.6+\)

```bash
terraform version
```

- **S3 bucket exists for Terraform state** (required for GitHub Actions / recommended for local too)

```bash
aws s3 mb s3://your-unique-bucket-name --region us-east-1
aws s3api put-bucket-versioning --bucket your-unique-bucket-name --versioning-configuration Status=Enabled
```

- **GitHub repo is cloneable from EC2**

Your launch templates run `git clone` from GitHub during boot. If the repo is **private**, instances cannot clone and will never become healthy unless you add authentication.

## Local deployment (manual)

### 1) Initialize Terraform with the S3 backend

```bash
cd terraform
terraform init \
  -backend-config="bucket=your-unique-bucket-name" \
  -backend-config="key=prod-dev/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

### 2) Deploy prod (or dev)

```bash
terraform apply -auto-approve -var="active_target=prod"
```

Switch later:

```bash
terraform apply -auto-approve -var="active_target=dev"
```

### 3) Verify the app

```bash
APP_URL="$(terraform output -raw app_url)"
curl -sS "$APP_URL/"
curl -sS "$APP_URL/v2/health"
curl -sS "$APP_URL/v2/hello"
```

## GitHub Actions deployment (CI/CD)

Workflow: `.github/workflows/deploy.yaml`

### Required repository secrets

| Secret | Required | Notes |
|---|---:|---|
| `AWS_ACCESS_KEY_ID` | yes | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | yes | IAM user secret key |
| `AWS_REGION` | yes | required by `configure-aws-credentials` |
| `TF_STATE_BUCKET` | yes | Terraform S3 backend bucket |
| `TF_STATE_KEY` | no | defaults to `prod-dev/terraform.tfstate` |

### Run the workflow

1. GitHub → **Actions** → **prod-dev Deployment**
2. **Run workflow**
3. Select **prod** or **dev**

This runs Terraform with `-var="active_target=prod|dev"`.

## Updating the application

### Important note (how code reaches instances)

Instances download code at boot via `terraform/launch-templates.tf`:
- `prod` instances clone branch **`main`**
- `dev` instances clone branch **`dev`**
- the app must exist under the repo’s `app/` folder (so it can run `node app.js` from there)

### Deploy a new version to dev

```bash
git checkout dev
git add app/
git commit -m "Update app"
git push -u origin dev
```

Then switch traffic to dev (or keep dev active) and **replace the dev instance** so it pulls the new code (terminate the instance in the `dev-asg`, it will recreate).

### Promote dev → prod

```bash
git checkout main
git merge dev
git push origin main
```

Then switch back to prod:

```bash
cd terraform
terraform apply -auto-approve -var="active_target=prod"
```

## Troubleshooting

### Terraform init fails: “S3 bucket does not exist”

Create the bucket first, then re-run init:

```bash
aws s3 mb s3://your-unique-bucket-name --region us-east-1
```

### Target group unhealthy / ALB returns 502

Most common causes:
- user-data `git clone` failed (repo is private or branch doesn’t exist)
- app path mismatch (repo doesn’t contain `app/app.js` + `app/package.json`)
- service not running

On the instance (via EC2 Instance Connect):

```bash
sudo cat /var/log/user-data.log
sudo systemctl status nodeapp --no-pager
curl -sS http://127.0.0.1:3000/
```

### Rollback

Rollback is just switching `active_target` back:

```bash
cd terraform
terraform apply -auto-approve -var="active_target=prod"
```
