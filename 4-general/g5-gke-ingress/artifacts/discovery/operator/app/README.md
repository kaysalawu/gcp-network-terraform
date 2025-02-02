# Discovery Operator

## Main

The ingress cluster hosts the operator deployment running this code. The deployment is configured with a k8s service account that has workload
identity linked to a GCE service account in the local project. The GCE service account has project roles/container.admin role for access to target external workload clusters.

The operator knows which external clusters to scan for pods by reading custom resources (CRs) of kind 'orchestras.example.com'. The CRs contain the context information needed to switch to the target external cluster.

The operator switches context to each cluster, extracts pod information and updates the CR status with the pod information.

## _PodManager

