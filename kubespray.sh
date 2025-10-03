#!/bin/bash

# Kubespray Inventory Generator
set -e

echo "=================================================="
echo "Kubespray Inventory Generator"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Get control plane details
echo
print_status "Enter Control Plane Node Details:"
read -p "Control Plane Public IP (ansible_host): " CONTROL_PUBLIC_IP
if ! validate_ip "$CONTROL_PUBLIC_IP"; then
    echo -e "${RED}Invalid control plane public IP${NC}"
    exit 1
fi

read -p "Control Plane Private IP (ip/access_ip): " CONTROL_PRIVATE_IP
if ! validate_ip "$CONTROL_PRIVATE_IP"; then
    echo -e "${RED}Invalid control plane private IP${NC}"
    exit 1
fi

# Get number of worker nodes
echo
while true; do
    read -p "How many worker nodes do you want? (0-10): " WORKER_COUNT
    if [[ $WORKER_COUNT =~ ^[0-9]+$ ]] && [ $WORKER_COUNT -ge 0 ] && [ $WORKER_COUNT -le 10 ]; then
        break
    else
        echo -e "${RED}Please enter a number between 0 and 10${NC}"
    fi
done

# Get worker node details
WORKER_PUBLIC_IPS=()
WORKER_PRIVATE_IPS=()

for ((i=1; i<=WORKER_COUNT; i++)); do
    echo
    print_status "Enter Worker Node $i Details:"
    read -p "Worker $i Public IP (ansible_host): " public_ip
    if ! validate_ip "$public_ip"; then
        echo -e "${RED}Invalid worker $i public IP${NC}"
        exit 1
    fi
    
    read -p "Worker $i Private IP (ip/access_ip): " private_ip
    if ! validate_ip "$private_ip"; then
        echo -e "${RED}Invalid worker $i private IP${NC}"
        exit 1
    fi
    
    WORKER_PUBLIC_IPS+=("$public_ip")
    WORKER_PRIVATE_IPS+=("$private_ip")
done

# Get SSH details
echo
read -p "Enter SSH user [ubuntu]: " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}

read -p "Enter SSH private key path: " SSH_KEY_PATH
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo -e "${RED}SSH key file not found: $SSH_KEY_PATH${NC}"
    exit 1
fi

# Create inventory directory
INVENTORY_DIR="inventory/mycluster"
mkdir -p $INVENTORY_DIR

# Generate hosts.yaml
print_status "Generating hosts.yaml..."

cat > $INVENTORY_DIR/hosts.yaml << EOF
all:
  hosts:
    control-plane:
      ansible_host: $CONTROL_PUBLIC_IP
      ip: $CONTROL_PRIVATE_IP
      access_ip: $CONTROL_PRIVATE_IP
EOF

# Add worker nodes to hosts
for ((i=0; i<WORKER_COUNT; i++)); do
    worker_num=$((i+1))
    cat >> $INVENTORY_DIR/hosts.yaml << EOF
    worker$worker_num:
      ansible_host: ${WORKER_PUBLIC_IPS[$i]}
      ip: ${WORKER_PRIVATE_IPS[$i]}
      access_ip: ${WORKER_PRIVATE_IPS[$i]}
EOF
done

# Add children section
cat >> $INVENTORY_DIR/hosts.yaml << EOF
  children:
    kube_control_plane:
      hosts:
        control-plane:
    kube_node:
      hosts:
        control-plane:
EOF

# Add workers to kube_node
for ((i=1; i<=WORKER_COUNT; i++)); do
    cat >> $INVENTORY_DIR/hosts.yaml << EOF
        worker$i:
EOF
done

# Add remaining sections
cat >> $INVENTORY_DIR/hosts.yaml << EOF
    etcd:
      hosts:
        control-plane:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
  vars:
    ansible_user: $SSH_USER
    ansible_ssh_private_key_file: $SSH_KEY_PATH
EOF

print_status "Inventory file created: $INVENTORY_DIR/hosts.yaml"

# Display summary
echo
print_status "Cluster Inventory Summary:"
echo "Control Plane:"
echo "  Public IP: $CONTROL_PUBLIC_IP"
echo "  Private IP: $CONTROL_PRIVATE_IP"
echo
echo "Worker Nodes: $WORKER_COUNT"
for ((i=0; i<WORKER_COUNT; i++)); do
    worker_num=$((i+1))
    echo "Worker $worker_num:"
    echo "  Public IP: ${WORKER_PUBLIC_IPS[$i]}"
    echo "  Private IP: ${WORKER_PRIVATE_IPS[$i]}"
done
echo
echo "SSH User: $SSH_USER"
echo "SSH Key: $SSH_KEY_PATH"

# Create complete deployment script
print_status "Creating deployment script..."

cat > deploy-cluster.sh << EOF
#!/bin/bash

# Auto-generated Kubespray Deployment Script
set -e

echo "Starting Kubernetes cluster deployment..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y python3 python3-pip git python3-venv

# Clone Kubespray
if [ ! -d "kubespray" ]; then
    git clone https://github.com/kubernetes-sigs/kubespray.git
fi

cd kubespray

# Create virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Copy inventory if not exists
if [ ! -d "inventory/mycluster" ]; then
    cp -r ../$INVENTORY_DIR inventory/
fi

# Configure group variables
mkdir -p inventory/mycluster/group_vars/all
cat > inventory/mycluster/group_vars/all/all.yml << ALL_EOF
---
cluster_name: mycluster
ansible_user: $SSH_USER
ansible_ssh_private_key_file: "$SSH_KEY_PATH"
disable_swap: true
container_manager: docker
kube_version: 1.31.0
kube_network_plugin: calico
kube_pods_subnet: 10.233.64.0/18
kube_service_addresses: 10.233.0.0/18
auto_renew_certificates: true
ALL_EOF

mkdir -p inventory/mycluster/group_vars/k8s_cluster
cat > inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml << K8S_EOF
---
kube_version: 1.31.0
kube_network_plugin: calico
kube_pods_subnet: 10.233.64.0/18
kube_service_addresses: 10.233.0.0/18
cluster_name: mycluster
kube_proxy_mode: ipvs
K8S_EOF

cat > inventory/mycluster/group_vars/k8s_cluster/addons.yml << ADDONS_EOF
---
metrics_server_enabled: true
kube_state_metrics_enabled: true
node_exporter_enabled: true
helm_enabled: false
registry_enabled: false
ingress_nginx_enabled: false
metallb_enabled: false
cert_manager_enabled: false
dashboard_enabled: false
ADDONS_EOF

# Deploy cluster
echo "Deploying Kubernetes cluster..."
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b -v

echo "Kubernetes cluster deployed successfully!"
echo "To access the cluster:"
echo "scp -i $SSH_KEY_PATH $SSH_USER@$CONTROL_PUBLIC_IP:/etc/kubernetes/admin.conf ./"
echo "export KUBECONFIG=./admin.conf"
EOF

chmod +x deploy-cluster.sh

print_status "Deployment script created: deploy-cluster.sh"
print_status "To deploy the cluster, run: ./deploy-cluster.sh"
