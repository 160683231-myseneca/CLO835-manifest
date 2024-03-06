#!/bin/bash

start_containers() {
  echo "Starting cluster..."

  echo "Creating cluster..."
  kind create cluster --config kind-nodeport.yaml
 
  echo "Creating namespaces..."
  kubectl create ns sqldb
  kubectl create ns webapp
  
  echo "Creating backend deployment..."
  kubectl apply -f backend-deployment.yaml -n sqldb
  kubectl apply -f backend-service.yaml -n sqldb
  
  
  echo "Creating frontend deployment..."
  kubectl apply -f myapp-deployment.yaml -n webapp
  kubectl apply -f myapp-service.yaml -n webapp
  kubectl apply -f myapp-NodePort.yaml -n webapp
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
