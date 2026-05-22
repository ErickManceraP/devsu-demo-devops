# Devsu Demo DevOps — Node.js

> **DevOps Technical Test** — Erick Mancera  
> Stack: Node.js 18.15.0 · Express 4.18.2 · SQLite · Docker · Kubernetes · GitHub Actions

## Table of Contents

- [Overview](#overview)
- [Architecture Diagrams](#architecture-diagrams)
- [CI/CD Pipeline](#cicd-pipeline)
- [Kubernetes Setup](#kubernetes-setup)
- [Running Locally](#running-locally)
- [Running with Docker](#running-with-docker)
- [Deploying to Kubernetes](#deploying-to-kubernetes)
- [API Reference](#api-reference)
- [Design Decisions](#design-decisions)

---

## Overview

REST API for user management with three endpoints: list users, get user by ID, and create user. The app uses SQLite as the database (file-based), Sequelize as the ORM, and Express as the HTTP framework.

---

## Architecture Diagrams

### Application Architecture

```mermaid
graph TD
    Client([Client / curl / Postman])
    Ingress[Nginx Ingress\ndevsu-demo.local]
    SVC[Service\nClusterIP :80]
    POD1[Pod 1\nNode.js :8000]
    POD2[Pod 2\nNode.js :8000]
    HPA[HorizontalPodAutoscaler\nmin:2 max:5]
    DB1[(SQLite\n/app/data/dev.sqlite)]
    DB2[(SQLite\n/app/data/dev.sqlite)]
    CM[ConfigMap\nNODE_ENV, PORT, DB_NAME]
    SEC[Secret\nDB_USER, DB_PASSWORD]

    Client -->|HTTP| Ingress
    Ingress -->|routes traffic| SVC
    SVC -->|load balances| POD1
    SVC -->|load balances| POD2
    HPA -.->|scales| POD1
    HPA -.->|scales| POD2
    POD1 --- DB1
    POD2 --- DB2
    CM -.->|env vars| POD1
    CM -.->|env vars| POD2
    SEC -.->|secrets| POD1
    SEC -.->|secrets| POD2
```

### Kubernetes Resource Map

```mermaid
graph LR
    subgraph Namespace: devsu-demo
        NS[Namespace]
        CM[ConfigMap\ndevsu-demo-config]
        SEC[Secret\ndevsu-demo-secret]
        DEP[Deployment\n2 replicas]
        SVC[Service\nClusterIP]
        ING[Ingress\nnginx]
        HPA[HPA\nmin2/max5]
        POD1[Pod 1]
        POD2[Pod 2]
        VOL1[emptyDir\n/app/data]
        VOL2[emptyDir\n/app/data]
    end

    NS --> CM
    NS --> SEC
    NS --> DEP
    NS --> SVC
    NS --> ING
    NS --> HPA
    DEP --> POD1
    DEP --> POD2
    CM --> POD1
    CM --> POD2
    SEC --> POD1
    SEC --> POD2
    POD1 --> VOL1
    POD2 --> VOL2
    SVC --> POD1
    SVC --> POD2
    ING --> SVC
    HPA --> DEP
```

---

## CI/CD Pipeline

### Pipeline Flow

```mermaid
flowchart LR
    A([Push to main\nor PR]) --> B

    subgraph JOBS
        B[Code Build\nnpm ci]
        B --> C[Static Analysis\nESLint]
        B --> D[Unit Tests\n+ Coverage]
        C --> E{All checks\npassed?}
        D --> E
        E -->|Yes| F[Docker Build\nand Push GHCR]
        F --> G[Deploy to\nKubernetes]
        G --> H[Wait rollout\nkubectl rollout status]
    end

    H --> I([Done])
    E -->|No| J([Pipeline fails])
```

### Pipeline Steps Detail

| Step | Tool | Trigger |
|------|------|---------|
| Code Build | `npm ci` | All branches |
| Static Code Analysis | ESLint | All branches |
| Unit Tests | Jest | All branches |
| Code Coverage | Jest `--coverage` (>=70% lines) | All branches |
| Docker Build & Push | Docker Buildx -> GHCR | `push` to `main` only |
| Deploy to Kubernetes | `kubectl apply -f k8s/` | `push` to `main` only |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `GITHUB_TOKEN` | Auto-provided by GitHub — used for GHCR push |
| `KUBECONFIG` | Base64-encoded kubeconfig for the target cluster |

---

## Kubernetes Setup

### Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured against your cluster
- [minikube](https://minikube.sigs.k8s.io/docs/start/) or Docker Desktop with K8s enabled (for local)
- Nginx Ingress Controller installed

```bash
# Install nginx ingress on minikube
minikube addons enable ingress

# Or on a generic cluster
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### Resource Files

```
k8s/
├── namespace.yaml    # Namespace: devsu-demo
├── configmap.yaml    # Non-sensitive env vars
├── secret.yaml       # DATABASE_USER, DATABASE_PASSWORD (base64)
├── deployment.yaml   # 2 replicas, probes, resource limits, emptyDir
├── service.yaml      # ClusterIP on port 80 -> 8000
├── ingress.yaml      # Nginx ingress: devsu-demo.local
└── hpa.yaml          # HPA: min 2, max 5, CPU 70%
```

### Manual Deploy

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Replace IMAGE_PLACEHOLDER with real image tag before applying
sed -i "s|IMAGE_PLACEHOLDER|ghcr.io/YOUR_USER/devsu-demo-devops-nodejs:latest|g" k8s/deployment.yaml

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

# Verify
kubectl get all -n devsu-demo
```

### Add local DNS entry (for minikube)

```bash
# Get minikube IP
minikube ip  # e.g. 192.168.49.2

# Add to /etc/hosts
echo "192.168.49.2  devsu-demo.local" | sudo tee -a /etc/hosts

# Test
curl http://devsu-demo.local/api/users
```

---

## Running Locally

### Prerequisites

- Node.js 18.15.0

```bash
# Install dependencies
npm install

# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Lint
npm run lint

# Start server
npm start
```

Open http://localhost:8000/api/users

---

## Running with Docker

```bash
# Build image
docker build -t devsu-demo-nodejs:local .

# Run with docker-compose (recommended)
docker-compose up

# Run standalone
docker run -p 8000:8000 \
  -e DATABASE_USER=user \
  -e DATABASE_PASSWORD=password \
  -e DATABASE_NAME=/app/data/dev.sqlite \
  devsu-demo-nodejs:local
```

---

## API Reference

Base URL: `http://localhost:8000/api`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users` | List all users |
| GET | `/users/:id` | Get user by ID |
| POST | `/users` | Create new user |

### Create User

```bash
curl -X POST http://localhost:8000/api/users \
  -H "Content-Type: application/json" \
  -d '{"dni": "123456789", "name": "Erick Mancera"}'
```

Response `201`:
```json
{ "id": 1, "dni": "123456789", "name": "Erick Mancera" }
```

---

## Design Decisions

### SQLite in Kubernetes

SQLite is a file-based database, which presents limitations in a Kubernetes environment:

- **No shared state between pods** — each pod has its own `emptyDir` volume, so data is not shared across replicas. For a production system this would need to be replaced with PostgreSQL or MySQL using a StatefulSet or an external managed DB.
- **Data is ephemeral** — `emptyDir` volumes are cleared on pod restart. A `PersistentVolumeClaim` would be needed for production data durability.
- **Why kept for this test** — the exercise focuses on DevOps practices (Docker, CI/CD, K8s), not the database architecture. The SQLite limitation is noted as a known trade-off.

### Docker Multi-stage Build

The Dockerfile uses two stages:
1. `deps` — installs only production dependencies
2. `runtime` — copies the app and runs it as a non-root user

This keeps the final image lean and secure.

### HPA Configuration

- `minReplicas: 2` — always maintain high availability
- `maxReplicas: 5` — cap scaling to control costs
- CPU target: 70%, Memory target: 80%
- Scale-down stabilization: 180s to avoid flapping

### Security Practices

- Container runs as non-root user (`appuser`, UID 1001)
- All Linux capabilities dropped at container level
- Secrets stored in K8s Secrets, not hardcoded in ConfigMaps or the image
- `.dockerignore` excludes `.env`, test files, and `node_modules` from the build context

---

## License

Copyright © 2023 Devsu. All rights reserved.

---

## Terraform (IaC — Bonus)

The `terraform/` directory provisions the complete AWS infrastructure using Terraform.

### What it creates

| Resource | Count | Notes |
|----------|-------|-------|
| VPC | 1 | CIDR 10.0.0.0/16 |
| Public Subnets | 2 | One per AZ — for load balancers |
| Private Subnets | 2 | One per AZ — for worker nodes |
| NAT Gateways | 2 | One per AZ for HA egress |
| Internet Gateway | 1 | Public internet access |
| EKS Cluster | 1 | Kubernetes 1.28 |
| EKS Node Group | 1 | t3.small, min 2 / max 5 |
| IAM Roles | 2 | Control plane + node group |
| OIDC Provider | 1 | Enables IRSA |
| Nginx Ingress (Helm) | 1 | Via helm_release |
| K8s Namespace | 1 | devsu-demo |
| K8s ConfigMap | 1 | App config |
| K8s Secret | 1 | DB credentials |
| K8s Deployment | 1 | 2 replicas |
| K8s Service | 1 | ClusterIP |
| K8s Ingress | 1 | Nginx |
| K8s HPA | 1 | min 2, max 5 |

**Total: 33 resources**

### Infrastructure Diagram

```mermaid
graph TD
    subgraph AWS Region us-east-1
        subgraph VPC 10.0.0.0/16
            IGW[Internet Gateway]

            subgraph AZ-1 us-east-1a
                PUB1[Public Subnet\n10.0.101.0/24]
                PRI1[Private Subnet\n10.0.1.0/24]
                NAT1[NAT Gateway]
            end

            subgraph AZ-2 us-east-1b
                PUB2[Public Subnet\n10.0.102.0/24]
                PRI2[Private Subnet\n10.0.2.0/24]
                NAT2[NAT Gateway]
            end

            subgraph EKS Cluster
                CP[Control Plane]
                subgraph Node Group t3.small
                    N1[Node 1\nAZ-1]
                    N2[Node 2\nAZ-2]
                end
            end

            LB[AWS Load Balancer\nNginx Ingress]
        end
    end

    Internet([Internet]) --> IGW
    IGW --> LB
    LB --> N1
    LB --> N2
    PUB1 --> NAT1
    PUB2 --> NAT2
    NAT1 --> PRI1
    NAT2 --> PRI2
    PRI1 --> N1
    PRI2 --> N2
    N1 --> CP
    N2 --> CP
```

### Quick Start

```bash
cd terraform

# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit app_image, aws_region, db_password, etc.

# 2. Initialize providers
terraform init

# 3. Review what will be created
terraform plan \
  -var="db_user=user" \
  -var="db_password=your-secure-password"

# 4. Apply (creates ~33 resources, takes ~12 min)
terraform apply \
  -var="db_user=user" \
  -var="db_password=your-secure-password"

# 5. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name devsu-demo-cluster

# 6. Verify
kubectl get all -n devsu-demo

# Destroy when done (avoids AWS costs)
terraform destroy \
  -var="db_user=user" \
  -var="db_password=your-secure-password"
```

### Required GitHub Secrets (for Terraform workflow)

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `DB_USER` | SQLite DB user (passed as TF var) |
| `DB_PASSWORD` | SQLite DB password (passed as TF var) |

See `docs/terraform-apply-output.txt` for a sample execution output.
