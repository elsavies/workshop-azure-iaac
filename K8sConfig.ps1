kubectl apply -f .\namespace.yaml

$IngressNamespace = "dev-yovoydelivery"

kubectl config set-context $(kubectl config current-context) --namespace $IngressNamespace

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update 

helm uninstall dev-nginx-ingress

helm install dev-nginx-ingress ingress-nginx/ingress-nginx --namespace $IngressNamespace --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

# Label the ingress-basic namespace to disable resource validation
kubectl label namespace $IngressNamespace cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm uninstall cert-manager

helm install cert-manager --namespace $IngressNamespace --version v1.5.4 --set installCRDs=true --set nodeSelector."beta\.kubernetes\.io/os"=linux jetstack/cert-manager

kubectl delete -f .\cluster-issuer.yaml
kubectl apply -f .\cluster-issuer.yaml
