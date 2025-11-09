#!/bin/bash
set -e

echo "Deploying Meteoride to Kubernetes..."

# Apply ConfigMap and Secrets
echo "Creating ConfigMap and Secrets..."
kubectl apply -f backend/k8s/configmap.yaml
kubectl apply -f backend/k8s/secret.yaml

# Deploy Redis
echo "Deploying Redis..."
kubectl apply -f backend/k8s/redis.yaml

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=meteoride-redis --timeout=120s

# Deploy Backend
echo "Deploying Backend..."
kubectl apply -f backend/k8s/deployment.yaml

# Wait for Backend to be ready
echo "Waiting for Backend to be ready..."
kubectl wait --for=condition=ready pod -l app=meteoride-backend --timeout=120s

# Apply HPA
echo "Applying HorizontalPodAutoscaler..."
kubectl apply -f backend/k8s/hpa.yaml

echo "Deployment complete!"
echo ""
echo "To check the status:"
echo "  kubectl get pods"
echo "  kubectl get services"
echo ""
echo "To access the backend:"
echo "  kubectl port-forward svc/meteoride-backend 8080:80"
