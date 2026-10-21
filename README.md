# Private OKE + Object Storage + MySQL HeatWave on OCI

Production-oriented, self-managed Terraform modules (no third-party registry modules).

```
.
├── main.tf variables.tf outputs.tf providers.tf versions.tf moved.tf
├── envs/                     # one tfvars + backend file per environment (no secrets)
│   ├── uat.tfvars  uat.backend.hcl
│   └── prod.tfvars prod.backend.hcl
├── modules/
│   ├── network/        VCN (no IGW), NAT + Service Gateway, route tables, private subnets
│   ├── security/       NSGs + least-privilege rules (cp, workers, pods, lb, db); has a mocked-provider test
│   ├── vault/          OCI Vault, auto-rotating AES key, KMS service policy, generated DB password secret
│   ├── oke/            private OKE cluster, node pools, optional OCI Bastion
│   ├── jumphost/       optional public jump host VM (own public subnet + Internet Gateway)
│   ├── storage/        private versioned buckets, optional workload-identity policy
│   ├── mysql/          MySQL DB system (private, PITR, delete protection) + HeatWave cluster
│   └── observability/  VCN flow logs, notification topic, MySQL CPU/memory/disk alarms
├── Makefile  .tflint.hcl  .pre-commit-config.yaml  .github/workflows/terraform.yml
```

## Usage
```
# 1. one-off per environment: create the state bucket and a Customer Secret Key (see "Remote state")
# 2. edit envs/<env>.tfvars and envs/<env>.backend.hcl
export TF_VAR_mysql_admin_password='Str0ng#Passw0rd'       # optional: generated when unset (terraform output -raw mysql_admin_password)
make plan  ENV=uat
make apply ENV=uat
```

## What makes it production grade
- **Isolation:** one state, tfvars and backend per environment; resource names carry the `name_prefix`.
- **Private by default:** no Internet Gateway, private API endpoint, private subnets, NSGs only (empty security lists).
- **Encryption:** `create_vault = true` creates a Vault + auto-rotating HSM key used for OKE secrets, node volumes, buckets.
  **Enable it on the first deployment.** Adding a key to an existing cluster forces replacement.
- **Secrets:** with Vault enabled, the MySQL admin password is generated and stored as a Vault secret
  (`mysql_admin_secret_id` output). It still exists in Terraform state, so keep the state bucket private.
- **Data protection:** MySQL backups, point-in-time recovery, optional HA, delete protection with final backup,
  versioned buckets, versioned state bucket.
- **Observability:** VCN flow logs on every subnet; email alarms on MySQL CPU, memory and disk (set `alert_email`).
- **Quality gates:** `terraform fmt`, `validate`, `tflint`, `trivy` config scan and a mocked-provider `terraform test`
  run in CI; the plan job runs on pull requests.
- **Module versioning:** modules are local. To release them independently, move `modules/` into your own Git repo,
  tag per module, and change `source` to `git::https://.../terraform-oci-platform.git//modules/<name>?ref=<tag>`.

## Remote state (native OCI backend, Terraform >= 1.12)
State lives in an Object Storage bucket in your tenancy and uses your normal OCI API key from `~/.oci/config`.
```
oci os ns get                                   # namespace for envs/<env>.backend.hcl
oci os bucket create --namespace-name <ns> --compartment-id <ocid> --name tfstate-oke-uat --versioning Enabled
terraform init -reconfigure -backend-config=envs/uat.backend.hcl
```
The user needs permission on the bucket, e.g. `Allow group <g> to manage objects in compartment <name> where target.bucket.name = 'tfstate-oke-uat'`.

## Before the first production apply
- Use a dedicated compartment (not the tenancy root) and create the IAM policies OKE needs
  (`Allow any-user to manage instances/use private-ips/use network-security-groups ... request.principal.type = 'cluster'`).
- Check the MySQL shape and HeatWave support: `oci mysql shape list --compartment-id <ocid> --availability-domain <AD>`.
- Pin `node_image_id` and `kubernetes_version`; review the plan; `bastion_client_cidrs` must be PUBLIC IPs.
- To destroy MySQL: set `mysql_deletion_protection = false`, apply, then destroy.

## Access the private Kubernetes API
```
oci bastion session create-port-forwarding --bastion-id <bastion_id> \
  --ssh-public-key-file ~/.ssh/id_rsa.pub --target-private-ip <private endpoint IP> \
  --target-port 6443 --session-ttl 10800
```
Then run the `kubeconfig_command` output and point the server at the forwarded port.

## Public jump host (`create_jumphost = true`)

A small Oracle Linux 9 VM with a public IP in its own subnet (`jumphost_subnet_cidr`), with
`kubectl`, the OCI CLI and the MySQL client installed. SSH is allowed only from `jumphost_allowed_cidrs`.
Its subnet is allowed to reach the API endpoint (6443) and MySQL (3306/33060).

```bash
ssh opc@$(terraform output -raw jumphost_public_ip)

# kubectl from your workstation through the jump host (uses your own OCI credentials):
$(terraform output -raw kubeconfig_command)
kubectl config set-cluster "$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')" --proxy-url=socks5://localhost:1080
ssh -N -D 1080 opc@$(terraform output -raw jumphost_public_ip) &
kubectl get nodes
```

## Not included
DRG/VPN or FastConnect, cluster autoscaler, WAF, Vault-backed Kubernetes secrets (External Secrets), cross-region backup copy.
