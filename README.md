# Production Deployment Guide

This repository contains the Terraform and Kubernetes configurations for deploying the production environment. Follow the steps carefully to set up and deploy.

---

## Prerequisites

- AWS CLI installed and configured
- Terraform installed (v1.0+ recommended)
- kubectl installed
- Sufficient AWS IAM permissions to deploy infrastructure and manage EKS

---

## Step 1. Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```
Replace `<repository-url>` with your GitHub repository link and `<repository-directory>` with the cloned directory name.

---

## Step 2. Configure AWS CLI

```bash
aws configure --profile <your-profile-name>
```
You will be prompted to enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region name
- Default output format

Example:
```bash
aws configure --profile sigmastream
```

---

## Step 3. Terraform Deployment

### 3.1. Navigate to the Terraform directory
```bash
cd terraform
```

### 3.2. Update the profile name in Terraform code
**Note:** Update your AWS profile name in the Terraform provider block in `main.tf` as shown in the screenshot below:

![Update AWS profile in main.tf](<aws-profile-screenshot.png>)

### 3.3. Initialize Terraform
```bash
terraform init
```

### 3.4. Apply Terraform
```bash
terraform apply --auto-approve
```
This will provision all required AWS resources for the project.

---

## Step 4. Kubernetes Deployment

### 4.1. Navigate to the Kubernetes directory
```bash
cd ../kubernetes
```

### 4.2. Update kubeconfig for EKS cluster
```bash
aws eks update-kubeconfig --region us-east-1 --name idempiere-prod-cluster --profile <your-profile-name>
```

### 4.3. Apply Kubernetes manifests in order

#### 4.3.1. Namespace
```bash
kubectl apply -f namespace.yaml
```

#### 4.3.2. StorageClass
```bash
kubectl apply -f storageclass.yaml
```

#### 4.3.3. Secrets
```bash
kubectl apply -f secrets.yaml
```

#### 4.3.4. Service
```bash
kubectl apply -f service.yaml
```

#### 4.3.5. Headless Service
```bash
kubectl apply -f headless-service.yaml
```

#### 4.3.6. AWS EBS CSI Driver
```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.28"
```

#### 4.3.7. Patch CoreDNS for toleration
```bash
kubectl -n kube-system patch deployment coredns --type='json' -p '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"app","operator":"Equal","value":"true","effect":"NoSchedule"}]}]'
```

#### 4.3.8. Patch EBS CSI Controller for toleration
```bash
kubectl -n kube-system patch deployment ebs-csi-controller --type='json' -p '[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"mongodb","operator":"Equal","value":"true","effect":"NoSchedule"}]}]'
```

#### 4.3.9. Aurora bootstrap job
```bash
kubectl apply -f aurora-bootstrap-job.yaml
```

#### 4.3.10. StatefulSet MongoDB
```bash
kubectl apply -f mongodb-statefulset.yaml
kubectl get pods -n app-prod -w
```

#### 4.3.12. Wait for aurora bootstrap job to complete
Check the job status:
```bash
kubectl get pods -n app-prod -w
```
Once the aurora bootstrap job is completed, press Ctrl+C to exit watch mode.

#### 4.3.13. Deployment (apply only if aurora bootstrap completed successfully)
```bash
kubectl apply -f deployment.yaml
```

#### 4.3.14. Server Metrics
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

kubectl -n kube-system patch deployment metrics-server --type='json' -p='[{"op":"add","path":"/spec/template/spec/tolerations","value":[{"key":"app","operator":"Equal","value":"true","effect":"NoSchedule"}]}]'

kubectl -n kube-system patch deployment metrics-server --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

#### 4.3.15. Cluster Role
```bash
kubectl apply -f clusterrole.yaml
```

#### 4.3.16. Cluster Autoscaler
```bash
kubectl apply -f clusterautoscaler.yaml
```

#### 4.3.17. Horizontal Pod Autoscaler (HPA)
```bash
kubectl apply -f hpa.yaml
```

#### 4.3.18. Network Policy
```bash
kubectl apply -f networkpolicy.yaml
```

#### 4.3.19. Final checks - ensure no pods are in Pending state
```bash
kubectl get pods -n kube-system
kubectl get pods -n app-prod
```

---

## Step 5. Access the Application

Fetch the Load Balancer URL:
```bash
kubectl get svc -n app-prod
```
Open the URL in your browser in the following format:
```
https://<load-balancer-url>/WITSMLStore/services/Store
```
Replace `<load-balancer-url>` with the URL obtained from the service output.

---

Note:
- Replace `<your-profile-name>` with your configured AWS CLI profile name.
- Replace `<load-balancer-url>` with the URL obtained from the service output.
- Follow the steps and order strictly to avoid dependency errors.

---

## Scaling Configuration

- **Horizontal Pod Autoscaler (HPA):**  
  You can change the scaling values (such as minimum and maximum replicas, and CPU utilization thresholds) in `kubernetes/hpa.yaml`.

- **Node Count:**  
  The number of nodes in your cluster can be adjusted in the Terraform configuration files (e.g., `terraform/main.tf`).

- **Pod Replicas:**  
  The number of application pod replicas can be set in your deployment file (e.g., `kubernetes/deployment.yaml`).

## Support

For any issues or clarifications, please reach out to the SigmaStream or raise an issue in this repository.