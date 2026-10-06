# MongoDB & Mongo Express on Kubernetes (Kind)

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.28+-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Kind](https://img.shields.io/badge/Kind-Cluster-blue?logo=docker&logoColor=white)](https://kind.sigs.k8s.io/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Latest-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)
[![Mongo Express](https://img.shields.io/badge/Mongo--Express-Web_UI-000000?logo=express&logoColor=white)](https://github.com/mongo-express/mongo-express)

A reproducible local Kubernetes environment deploying a persistent **MongoDB** instance paired with the **Mongo Express** web-based management UI using **Kind** (Kubernetes in Docker).

---

## Table of Contents

- [What the Project Does](#what-the-project-does)
- [Why the Project Is Useful](#why-the-project-is-useful)
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Quickstart (Automated)](#quickstart-automated)
  - [Manual Step-by-Step Deployment](#manual-step-by-step-deployment)
- [Access & Credentials](#access--credentials)
- [Verification & Useful Commands](#verification--useful-commands)
- [Tearing Down](#tearing-down)
- [Where to Get Help](#where-to-get-help)
- [Contributing](#contributing)

---

## What the Project Does

This project provides a clean, modular Kubernetes setup to run a local database stack on a [Kind](https://kind.sigs.k8s.io/) cluster. It automates:

1. **Kind Cluster Provisioning**: Creates a cluster (`mongo-cluster`) configured with host-to-container port mapping and volume mounts.
2. **Persistent Storage**: Sets up a local `PersistentVolume` and `PersistentVolumeClaim` mapped to host storage (`/tmp/mongo-data`), ensuring database records persist across pod restarts.
3. **MongoDB Deployment**: Runs a single-replica MongoDB container with configured resource limits and credential injection via Kubernetes Secrets.
4. **Mongo Express UI**: Deploys a high-availability, 2-replica Mongo Express web interface connected to the database via internal DNS.
5. **NodePort Expose**: Exposes Mongo Express via NodePort `30081`, accessible directly from the host machine at `http://localhost:30081`.

---

## Why the Project Is Useful

- **Zero-Friction Local Testing**: Quickly spin up or tear down a realistic Kubernetes database setup without managing cloud infrastructure or paying for managed clusters.
- **Production-Like Separation of Concerns**: Manifests are organized into dedicated directories (`app`, `database`, `volume`) following infrastructure-as-code best practices.
- **Persistent Data**: Database state is preserved in host storage (`/tmp/mongo-data`) through Kubernetes Persistent Volumes.
- **Secure Secrets Management**: Database and web administrative passwords are separated into Kubernetes Secret objects rather than hardcoded into deployment specs.
- **Automated Rollout**: Includes a turnkey deployment script (`run.sh`) that provisions the cluster, applies manifests in dependency order, and waits for deployment readiness before completing.

---

## Architecture Overview

```mermaid
flowchart LR
    User([Browser / Host]) -->|http://localhost:30081| NodePort[NodePort Service :30081]
    NodePort -->|Port 8081| ME[Mongo Express Pods (2 Replicas)]
    ME -->|Port 27017| MongoSvc[ClusterIP Service: mongo-service]
    MongoSvc --> MongoPod[MongoDB Pod]
    MongoPod -->|/data/db| PVC[PersistentVolumeClaim: mongo-volume]
    PVC --> PV[PersistentVolume: mongo-pv]
    PV --> HostDir[Host Path: /tmp/mongo-data]
    Secret[K8s Secret: secrets] -.->|Injects Credentials| ME
    Secret -.->|Injects Credentials| MongoPod
```

---

## Repository Structure

```text
.
├── k8s/
│   ├── app/
│   │   ├── mongo-express-app.yaml       # Deployment for Mongo Express (2 replicas)
│   │   └── mongo-express-service.yaml   # NodePort service exposing port 30081
│   ├── database/
│   │   ├── mongo-app.yaml               # Deployment for MongoDB (1 replica)
│   │   └── mongo-service.yaml           # Internal ClusterIP service (port 27017)
│   ├── volume/
│   │   ├── mongo-volume.yaml            # PersistentVolume mapped to /tmp/mongo-data
│   │   └── mongo-volume-claim.yaml      # PersistentVolumeClaim requesting 2Gi storage
│   ├── control-plane.yaml               # Kind cluster config (port mappings & extra mounts)
│   └── secrets.yaml                     # Kubernetes Secret for auth credentials
├── run.sh                               # Automated cluster bootstrap & deploy script
└── README.md                            # Project documentation
```

---

## Getting Started

### Prerequisites

Ensure you have the following installed on your host system:

- [Docker](https://docs.docker.com/get-docker/) (running and accessible)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) (`kind` CLI v0.20+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (Kubernetes CLI)
- **Bash** shell (macOS / Linux / WSL)

### Quickstart (Automated)

Run the bootstrap script from the project root:

```bash
chmod +x run.sh
./run.sh
```

The script will:
1. Verify if `mongo-cluster` exists; if not, create it using `k8s/control-plane.yaml`.
2. Apply the secrets, volumes, database manifests, and app manifests.
3. Wait for pod rollouts to complete.
4. Output the web access URL.

Once the script completes, open `http://localhost:30081` in your browser.

---

### Manual Step-by-Step Deployment

If you prefer applying manifests individually:

#### 1. Create the Kind Cluster
```bash
kind create cluster --name mongo-cluster --config k8s/control-plane.yaml
```

#### 2. Apply Kubernetes Secrets
```bash
kubectl apply -f k8s/secrets.yaml
```

#### 3. Provision Storage (PV & PVC)
```bash
kubectl apply -f k8s/volume/
```

#### 4. Deploy MongoDB & ClusterIP Service
```bash
kubectl apply -f k8s/database/
```

#### 5. Deploy Mongo Express & NodePort Service
```bash
kubectl apply -f k8s/app/
```

#### 6. Wait for Deployments to Roll Out
```bash
kubectl rollout status deployment/mongo-deployment --timeout=180s
kubectl rollout status deployment/mongo-express-deployment --timeout=180s
```

---

## Access & Credentials

When navigating to `http://localhost:30081`, you will be prompted for HTTP Basic Authentication.

| Component | Username | Password | Defined In |
| :--- | :--- | :--- | :--- |
| **Mongo Express UI (Web Auth)** | `user` | `pass` | `k8s/secrets.yaml` (`web-*`) |
| **MongoDB Root Database** | `mongo-user` | `mongo-pass` | `k8s/secrets.yaml` (`mongo-root-*`) |

> **Warning**: The default credentials in `k8s/secrets.yaml` are intended for local development only. Do not use these default values in shared or production environments.

---

## Verification & Useful Commands

Check the running pods, services, and volume status:

```bash
# View all pods and their status
kubectl get pods

# View services and exposed ports
kubectl get svc

# Inspect PersistentVolume and PVC bindings
kubectl get pv,pvc

# Stream logs from Mongo Express
kubectl logs -l app=mongo-express --tail=50 -f

# Stream logs from MongoDB
kubectl logs -l app=mongo --tail=50 -f
```

---

## Tearing Down

To delete the resources or completely remove the Kind cluster:

### Option 1: Delete Kubernetes Workloads (Keep Cluster)
```bash
kubectl delete -f k8s/app/ -f k8s/database/ -f k8s/volume/ -f k8s/secrets.yaml
```

### Option 2: Delete Entire Kind Cluster
```bash
kind delete cluster --name mongo-cluster
```

To clean up persistent host data as well:
```bash
rm -rf /tmp/mongo-data
```

---

## Where to Get Help

- **Kubernetes Documentation**: [kubernetes.io/docs](https://kubernetes.io/docs/)
- **Kind (Kubernetes in Docker)**: [kind.sigs.k8s.io](https://kind.sigs.k8s.io/)
- **Mongo Express Official Repo**: [github.com/mongo-express/mongo-express](https://github.com/mongo-express/mongo-express)
- **MongoDB Docker Hub**: [hub.docker.com/_/mongo](https://hub.docker.com/_/mongo)
- **Issues**: Open an issue in this repository for any bugs or questions.

---

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/my-feature`).
3. Validate your changes against a clean Kind cluster using `./run.sh`.
4. Commit your changes (`git commit -m "Add new feature"`).
5. Push to your branch (`git push origin feature/my-feature`).
6. Open a Pull Request describing your changes.
