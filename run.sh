#!/usr/bin/env bash
set -e

# 1. Create cluster only if it doesn't already exist
if ! kind get clusters | grep -q "mongo-cluster"; then
    kind create cluster --name mongo-cluster --config k8s/control-plane.yaml
else
    echo "Cluster 'mongo-cluster' already exists."
fi

# 2. Apply all Kubernetes YAML files
kubectl apply -f k8s/secrets.yaml -f k8s/volume/ -f k8s/database/ -f k8s/app/

# 3. Wait for all pods to be ready
echo "Waiting for deployments to roll out..."
kubectl rollout status deployment/mongo-deployment --timeout=180s
kubectl rollout status deployment/mongo-express-deployment --timeout=180s

# 4. Show success message
echo "All done! Access Mongo Express at: http://localhost:30081"
