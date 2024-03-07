#!/bin/bash
create_ns_secrets(){
  echo "Creating namespaces..."
  kubectl create ns sqldb
  kubectl create ns webapp
  
  echo "Creating secrets"
  echo "Enter MySQL root password:"
  read -s MYSQL_ROOT_PASSWORD
  
  kubectl create secret generic mydb-secret --from-literal=password="$MYSQL_ROOT_PASSWORD" -n sqldb  
  kubectl create secret generic mydb-secret --from-literal=password="$MYSQL_ROOT_PASSWORD" -n webapp  
}

start_pod(){
  echo "Starting pods..."
}

start_replicaset(){
  echo "Starting replica sets..."
}

start_deployment() {
  echo "Starting deployment..."

  echo "Creating cluster..."
  kind create cluster --config kind-nodeport.yaml
  
  create_ns_secrets 

  echo "Creating backend deployment..."
  kubectl apply -f kubManifest/backend-deployment.yaml -n sqldb
  echo "Creating backend clusterIP service..."
  kubectl apply -f kubManifest/backend-service.yaml -n sqldb
  
  
  echo "Creating frontend deployment..."
  # For each app color version
  sed 's/{{APP_COLOR}}/blue/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend clusterIP services..."
  sed 's/{{APP_COLOR}}/blue/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend NodePort services..."
  
  sed 's/{{APP_COLOR}}/blue/g; s/{{APP_CONTAINER}}/30010/g' kubManifest/frontend-NodePort.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g; s/{{APP_CONTAINER}}/30100/g' kubManifest/frontend-NodePort.yaml | kubectl apply -f - -n webapp
  echo "Blue app avalaible at <ip>:30010"
  echo "Pink app avalaible at <ip>:30100"
}

start_ingress() {
  echo "Starting ingress..."

  echo "Creating cluster..."
  kind create cluster --config kind-ingress.yaml
 
  create_ns_secrets 
  
  echo "Creating backend deployment..."
  kubectl apply -f kubManifest/backend-deployment.yaml -n sqldb
  echo "Creating backend clusterIP service..."
  kubectl apply -f kubManifest/backend-service.yaml -n sqldb
  
  echo "Creating frontend deployment..."
  # For each app color version
  sed 's/{{APP_COLOR}}/blue/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/red/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend clusterIP services..."
  sed 's/{{APP_COLOR}}/blue/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/pink/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_COLOR}}/red/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp

  echo "Creating ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s

  echo "Creating frontend ingress service..."
  kubectl apply -f kubManifest/frontend-ingress.yaml -n webapp
  echo "Blue app avalaible at <ip>/blue"
  echo "Pink app avalaible at <ip>/pink"
  echo "Red app defaults at <ip>"
}

start_versioning_ingress() {
  echo "Starting versioning with ingress..."
}

delete_resources() {
  echo "Deleting Resources..."
  kubectl delete all --all -n webapp
  kubectl delete all --all -n sqldb
  kubectl delete namespace webapp
  kubectl delete namespace sqldb
  kubectl delete all --all
}

stop_and_cleanup() {
  echo "Deleting cluster..."
  kind delete cluster
}

echo "Select an action:"
echo "1. Pods"
echo "2. Replica Sets"
echo "3. Deployments"
echo "4. Ingress"
echo "5. Versioning using Ingress"
echo "6. Delete Resources"
echo "7. Delete Cluster"
read -p "Enter your choice (1/2): " choice

case "$choice" in
  "1")
    start_pod
    ;;
  "2")
    start_replicaset
    ;;
  "3")
    start_deployment
    ;;
  "4")
    start_ingress
    ;;
  "5")
    start_versioning_ingress
    ;;
  "6")
    stop_and_cleanup
    ;;
  *)
    echo "Invalid choice. Please select 1 - 6."
    exit 1
    ;;
esac

exit 0
