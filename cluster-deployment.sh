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
  echo "Starting kind cluster..."
  kind create cluster --config kind-nodeport.yaml
  
  echo "Starting pods..."
  
  create_ns_secrets
  
  echo "Creating backend pod..."
  kubectl apply -f kubManifest/backend-pod.yaml -n sqldb
  
  echo "Getting pod IP"
  kubectl wait --for=condition=ready pod/mysql-pod -n sqldb --timeout=90s
  pod_ip=$(kubectl get pod/mysql-pod -n sqldb -o jsonpath='{.status.podIP}')

  echo "Creating frontend pod..."
  sed "s/{{POD_IP}}/${pod_ip}/g" kubManifest/frontend-pod.yaml | kubectl apply -f - -n webapp

  echo "Port forwarding..."
  kubectl wait --for=condition=ready pod/myapp-v1-pod -n webapp --timeout=90s
  kubectl port-forward --address 0.0.0.0 pod/myapp-v1-pod 30010:8080 -n webapp
  echo "App avalaible at <ip>:30010"
}

start_replicaset(){
  echo "Starting replica sets..."
  
  echo "Creating backend pod..."
  kubectl apply -f kubManifest/backend-replicaset.yaml -n sqldb
  
  echo "Creating backend clusterIP service..."
  kubectl apply -f kubManifest/backend-service.yaml -n sqldb
  
  echo "Creating frontend deployment..."
  kubectl apply -f kubManifest/frontend-replicaset.yaml -n webapp
  
  echo "Creating frontend clusterIP service..."
  kubectl apply -f kubManifest/frontend-service.yaml -n webapp
  
  echo "Port forwarding..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=myapp-v1 -n webapp --timeout=90s
  kubectl port-forward --address 0.0.0.0 service/myapp-v1-svc 30010:80 -n webapp
  echo "App avalaible at <ip>:30010"
}

start_nodeport_deployment() {
  echo "Starting deployment using Nodeport service..."
  
  echo "Creating backend deployment..."
  kubectl apply -f kubManifest/backend-deployment.yaml -n sqldb
  
  echo "Creating frontend deployment..."
  sed "s/{{APP_VERSION}}/v1/g" kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend NodePort services..."
  sed "s/{{APP_VERSION}}/v1/g; s/{{APP_CONTAINER}}/30000/g" kubManifest/frontend-NodePort.yaml | kubectl apply -f - -n webapp
  echo "App avalaible at <ip>:30000"
}

start_nodeport_version() {
  echo "Starting versioning using Nodeport service..."
  
  echo "Creating frontend deployment for v2..."
  sed 's/{{APP_VERSION}}/v2/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend NodePort services for v2..."
  sed 's/{{APP_VERSION}}/v2/g; s/{{APP_CONTAINER}}/30001/g' kubManifest/frontend-NodePort.yaml | kubectl apply -f - -n webapp
  echo "Version2 app avalaible at <ip>:30001"
}

start_ingress_version() {
  delete_resources
  delete_cluster
  
  echo "Starting versions using Ingress..."

  echo "Starting Ingress cluster..."
  kind create cluster --config kind-ingress.yaml
 
  create_ns_secrets 
  
  echo "Creating backend deployment..."
  kubectl apply -f kubManifest/backend-deployment.yaml -n sqldb
  echo "Creating backend clusterIP service..."
  kubectl apply -f kubManifest/backend-service.yaml -n sqldb
  
  echo "Creating frontend deployment..."
  sed 's/{{APP_VERSION}}/v1/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_VERSION}}/v2/g' kubManifest/frontend-deployment.yaml | kubectl apply -f - -n webapp
  
  echo "Creating frontend clusterIP services..."
  sed 's/{{APP_VERSION}}/v1/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp
  sed 's/{{APP_VERSION}}/v2/g' kubManifest/frontend-service.yaml | kubectl apply -f - -n webapp

  echo "Creating ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=100s

  echo "Creating frontend ingress service..."
  kubectl apply -f kubManifest/frontend-ingress.yaml -n webapp
  echo "Version1 avalaible at <ip>/v1"
  echo "Version2 avalaible at <ip>/v2"
}

start_ingress_version_color() {
  echo "Starting version and color routing with ingress..."
}

delete_resources() {
  echo "Deleting Resources..."
  kubectl delete all --all -n webapp
  kubectl delete all --all -n sqldb
  kubectl delete namespace webapp
  kubectl delete namespace sqldb
}

delete_cluster() {
  echo "Deleting cluster..."
  kind delete cluster
  docker stop $(docker ps -a -q)
  docker rm $(docker ps -a -q)
  docker rmi $(docker images -q)
  docker volume rm $(docker volume ls -q)
  docker network rm $(docker network ls -q)
}

echo "Select an action:"
echo "1. Pods"
echo "2. Replica Sets"
echo "3. Deployment"
echo "4. Nodeport - Version"
echo "5. Ingress - Version"
echo "6. Ingress - Version & Color"
echo "7. Delete Resources"
echo "8. Delete Cluster"
read -p "Enter your choice (1/2): " choice

case "$choice" in
  "1")
    start_pod
    ;;
  "2")
    start_replicaset
    ;;
  "3")
    start_nodeport_deployment
    ;;
  "4")
    start_nodeport_version
    ;;
  "5")
    start_ingress_version
    ;;
  "6")
    start_ingress_version_color
    ;;
  "7")
    delete_resources
    ;;
  "8")
    delete_cluster
    ;;
  *)
    echo "Invalid choice. Please select 1 - 6."
    exit 1
    ;;
esac

exit 0
