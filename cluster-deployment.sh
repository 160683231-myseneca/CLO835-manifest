#!/bin/bash
start_pod(){
  echo "Starting kind cluster..."
  kind create cluster --config kind-nodeport.yaml
  
  echo "Starting pods..."
  
  echo "Creating namespaces..."
  kubectl create ns sqldb
  kubectl create ns webapp
  
  sleep 10s
  echo "Creating secrets"
  echo "Enter MySQL root password:"
  read -s MYSQL_ROOT_PASSWORD
  
  kubectl create secret generic mydb-secret --from-literal=password="$MYSQL_ROOT_PASSWORD" --type=kubernetes.io/basic-auth -n sqldb  
  kubectl create secret generic mydb-secret --from-literal=password="$MYSQL_ROOT_PASSWORD" --type=kubernetes.io/basic-auth -n webapp  
  
  sleep 10s
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

initialise_ingress_helm() {
  echo "Cleaning up existing resources..."
  delete_cluster
  
  echo "Initialising cluster with ingress..."

  kind create cluster --config kind-ingress.yaml
  
  echo "Creating ingress controller..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=100s
  
  echo "Creating namespaces..."
  kubectl create ns sqldb
  kubectl create ns webapp
  
  echo "Initialising helm charts & sealed secrets..."
    
  echo "Creating sealed secrets controller..."
  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
  helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller 
  
  sleep 60s
  kubectl create secret generic backend-secret --namespace sqldb --dry-run=client --from-literal=password=mytopsecret -o yaml | kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system --scope cluster-wide --format yaml > backend-secret.yaml
  kubectl create secret generic frontend-secret --namespace webapp --dry-run=client --from-literal=password=mytopsecret -o yaml | kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system --scope cluster-wide --format yaml > frontend-secret.yaml
}

start_ingress_version() {
  
  echo "Creating deployments..."
  helm install web-v1 kubChart/ --values kubChart/values.yaml
  helm install web-v2 kubChart/ --values kubChart/values.yaml -f kubChart/values-v2.yaml
  helm install web-blue kubChart/ --values kubChart/values.yaml -f kubChart/values-blue.yaml
  helm install web-pink kubChart/ --values kubChart/values.yaml -f kubChart/values-pink.yaml
  helm install web-v2-blue kubChart/ --values kubChart/values.yaml -f kubChart/values-v2-blue.yaml
  helm install web-v2-pink kubChart/ --values kubChart/values.yaml -f kubChart/values-v2-pink.yaml
  helm ls --all-namespaces

  echo "Choose paths: "
    echo "<ip>/ < v1|v2 > / < red|blue|pink >"
    echo "<ip>/ < red|blue|pink > / < v1|v2 >"
}

start_ingress_version_color() {
  echo "Starting version and color routing with ingress..."
}

delete_cluster() {
  echo "Deleting cluster..."
  kubectl delete secrets --all -n sqldb
  kubectl delete secrets --all -n webapp
  kubectl delete sealedsecrets --all -n sqldb
  kubectl delete sealedsecrets --all -n webapp
  kubectl delete namespace webapp
  kubectl delete namespace sqldb
  if [ -n "$(helm ls -q)" ]; then
    echo "$(helm ls -q)" | xargs helm delete
  fi
  kind delete cluster
}

echo "Select an action:"
echo "1. Pods"
echo "2. Replica Sets"
echo "3. Deployment"
echo "4. Nodeport - Version deployment"
echo "5. Ingress, helm and sealed secrets"
echo "6. Ingress - Version/color deployment"
echo "7. Delete Cluster"
read -p "Enter your choice: " choice

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
    initialise_ingress_helm
    ;;
  "6")
    start_ingress_version
    ;;
  "7")
    delete_cluster
    ;;
  *)
    echo "Invalid choice. Please select 1 - 7."
    exit 1
    ;;
esac

exit 0
