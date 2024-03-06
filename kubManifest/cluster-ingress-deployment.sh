#!/bin/bash

start_containers() {
  echo "Starting cluster..."

  echo "Creating cluster..."
  kind create cluster --config kind-ingress.yaml

  echo "Creating ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
 
  echo "Creating namespaces..."
  kubectl create ns sqldb
  kubectl create ns webapp
  
  echo "Creating backend deployment..."
  kubectl apply -f backend-deployment.yaml -n sqldb
  echo "Creating backend clusterIP service..."
  kubectl apply -f backend-service.yaml -n sqldb
  
  
  echo "Creating frontend deployment..."
  # For each app color version
  sed 's/{{APP_COLOR}}/blue/g' frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/lime/g' frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend clusterIP services..."
  sed 's/{{APP_COLOR}}/blue/g' frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/lime/g' frontend-service.yaml | kubectl apply -f - -n webapp

  echo "Creating frontend ingress service..."
  kubectl apply -f frontend-ingress.yaml -n webapp
}

stop_and_cleanup() {
  echo "Removing cluster..."
  kind delete cluster
}

echo "Select an action:"
echo "1. Start cluster"
echo "2. Delete cluster"
read -p "Enter your choice (1/2): " choice

case "$choice" in
  "1")
    start_containers
    ;;
  "2")
    stop_and_cleanup
    ;;
  *)
    echo "Invalid choice. Please select 1 or 2."
    exit 1
    ;;
esac

exit 0
