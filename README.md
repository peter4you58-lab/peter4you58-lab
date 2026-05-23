# 🚀 AWS Production-Ready Platform

> A full production-grade DevOps platform built with Terraform, EKS, GitHub Actions, and Prometheus — designed to mirror real-world enterprise deployments.

![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue?logo=githubactions)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-blue?logo=kubernetes)
![AWS](https://img.shields.io/badge/Cloud-AWS-orange?logo=amazonaws)
![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus%20%2B%20Grafana-red?logo=grafana)

---

## 📐 Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                        AWS Cloud                        │
│                                                         │
│   ┌──────────────────────────────────────────────────┐  │
│   │                    VPC                           │  │
│   │                                                  │  │
│   │  ┌─────────────┐      ┌─────────────────────┐   │  │
│   │  │ Public Subnet│      │   Private Subnet    │   │  │
│   │  │             │      │                     │   │  │
│   │  │  ALB/NLB    │─────▶│  EKS Worker Nodes   │   │  │
│   │  │  NAT Gateway│      │  RDS PostgreSQL      │   │  │
│   │  └─────────────┘      └─────────────────────┘   │  │
│   └──────────────────────────────────────────────────┘  │
│                                                         │
│   S3 + CloudFront │ ECR │ Route53 │ ACM │ Secrets Mgr  │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Cloud | AWS (EKS, RDS, S3, ECR, Route53, ACM) |
| IaC | Terraform |
| Containers | Docker + Kubernetes (EKS) |
| Package Manager | Helm |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana + Loki |
| Security | Trivy + Kyverno + AWS Secrets Manager |
| App | Python Flask API + PostgreSQL (SQLAlchemy) |

---

## ✨ Features

- ✅ One-command infrastructure provisioning with Terraform
- ✅ Auto-scaling EKS cluster with Horizontal Pod Autoscaler
- ✅ Fully automated CI/CD — test → lint → security scan → build → deploy
- ✅ Container image vulnerability scanning with Trivy
- ✅ Full observability: metrics, logs, and alerts
- ✅ Secrets never hardcoded — Grafana, AlertManager, and DB passwords all via Kubernetes Secrets
- ✅ Network policies enforcing zero-trust between pods
- ✅ Multi-environment support (dev and prod) with separate Terraform state
- ✅ PostgreSQL-backed API — no in-memory state, consistent across all replicas
- ✅ Zero-downtime rolling deployments with `--atomic` Helm flag

---

## 📋 Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform >= 1.5
- kubectl >= 1.28
- Helm >= 3.12
- Docker
- Python 3.11+

---

## ⚡ Quick Start

### Step 1 — Bootstrap Terraform remote state (once)

```bash
# Create the S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Now uncomment the backend block in terraform/environments/dev/main.tf
```

### Step 2 — Provision infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### Step 3 — Configure kubectl

```bash
aws eks update-kubeconfig --name dev-devops-portfolio-cluster --region us-east-1
```

### Step 4 — Create Kubernetes Secrets (before deploying the app)

```bash
# RDS credentials (build the DATABASE_URL from Terraform outputs)
DB_ENDPOINT=$(terraform -chdir=terraform/environments/dev output -raw eks_cluster_endpoint)
DB_URL="postgresql://dbadmin:<password>@${DB_ENDPOINT}:5432/appdb"

kubectl create secret generic rds-credentials \
  --from-literal=database_url="$DB_URL" \
  --namespace production \
  --create-namespace

# Grafana admin password
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='<your-strong-password>' \
  --namespace monitoring \
  --create-namespace

# AlertManager Slack webhook
kubectl create secret generic alertmanager-slack-secret \
  --from-literal=slack_api_url='https://hooks.slack.com/services/...' \
  --namespace monitoring
```

### Step 5 — Deploy the app

```bash
helm upgrade --install myapp ./helm/myapp \
  --namespace production \
  --create-namespace \
  --set image.repository=<YOUR_ECR_REGISTRY>/devops-portfolio-app \
  --set image.tag=<IMAGE_SHA> \
  --values helm/myapp/values.yaml \
  --atomic
```

### Step 6 — Deploy monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/prometheus/values.yaml
```

---

## 🔄 CI/CD Pipeline

```
Push to any branch  →  Test + Lint + Terraform validate
Open Pull Request   →  Trivy security scan
Merge to main       →  Build image (SHA tag) → Push to ECR → Deploy to EKS → Slack
```

**Image tagging:** every image is tagged with the exact git commit SHA (e.g. `abc1234`). The `latest` tag is never pushed to ECR. The CD pipeline downloads the tag written by CI as an artifact, ensuring it deploys the exact image that was built and scanned.

---

## 📊 Monitoring

- **Grafana** available after port-forward: `kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring`
- Tracks: request rate, error rate, CPU/memory, pod health, crash-looping pods
- **AlertManager** sends Slack alerts for high error rates, pod crashes, and high memory usage
- Alert credentials are stored in Kubernetes Secrets — never committed to git

---

## 🔒 Security Measures

| Measure | Implementation |
|---|---|
| Image scanning | Trivy in CI — blocks on CRITICAL/HIGH |
| No privileged containers | Kyverno ClusterPolicy (Enforce) |
| Non-root containers | Kyverno ClusterPolicy (Enforce) |
| No `latest` tag in prod | Kyverno ClusterPolicy (Audit → Enforce) |
| Resource limits required | Kyverno ClusterPolicy (Enforce) |
| All capabilities dropped | Kyverno ClusterPolicy (Enforce) |
| Read-only root filesystem | Deployment securityContext |
| Zero-trust networking | Kubernetes NetworkPolicy |
| Secrets management | AWS Secrets Manager + Kubernetes Secrets |
| IAM least privilege | EKS node roles scoped to ECR read + EKS CNI |
| EKS API access control | `public_access_cidrs` variable |

---

## 💰 Estimated AWS Cost

| Environment | Resource | Monthly |
|---|---|---|
| Dev | EKS Cluster | ~$72 |
| Dev | EC2 (2× t3.medium) | ~$60 |
| Dev | RDS t3.micro | ~$15 |
| Dev | NAT Gateway | ~$32 |
| **Dev Total** | | **~$179/month** |
| Prod | EKS + EC2 (3× t3.large) | ~$280 |
| Prod | RDS t3.small | ~$28 |
| Prod | NAT + misc | ~$40 |
| **Prod Total** | | **~$348/month** |

> 💡 Destroy dev when not in use: `terraform destroy -chdir=terraform/environments/dev`

---

## 👤 Author

**peter4you58** — DevOps Engineer
- GitHub: [github.com/peter4you58-lab](https://github.com/peter4you58-lab)
