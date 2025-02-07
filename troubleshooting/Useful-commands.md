# Useful Troubleshoting Commands

## Kubernetes

```sh
kubectl logs $(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep endpoints)
USER=$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.user}')
kubectl auth can-i get pods --as=$USER
kubectl config view --minify
gcloud auth print-access-token | kubectl auth can-i get pods --all-namespaces --token=$(cat)
kubectl auth can-i get orchestras --as=system:serviceaccount:default:default
kubectl patch orch orch01 --type=json -p '[{"op": "remove", "path": "/metadata/finalizers"}]'
```

## Google Cloud CLI

```sh
gcloud auth list
```
