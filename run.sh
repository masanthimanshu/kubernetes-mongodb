#!/usr/bin/env bash
set -e

# 1. Create cluster only if it doesn't already exist
if ! kind get clusters | grep -q "mongo-cluster"; then
    kind create cluster --name mongo-cluster --config k8s/k8s-cluster.yaml
else
    echo "Cluster 'mongo-cluster' already exists."
fi

# 2. Apply all Kubernetes YAML files
kubectl apply -f k8s/k8s-secrets.yaml -f k8s/volume/ -f k8s/database/ -f k8s/app/

# 3. Wait for all pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=60s

# 4. Show success message
echo "All done! Access Mongo Express at: http://localhost:30081"
