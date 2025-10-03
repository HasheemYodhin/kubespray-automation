# Kubespray Kubernetes Cluster Deployment

This project provides an automated way to generate Kubespray inventory files and deploy a production-ready Kubernetes cluster.

## Prerequisites

### System Requirements
- **Control Plane Node**: Minimum 2 vCPUs, 4GB RAM, 20GB disk
- **Worker Nodes**: Minimum 1 vCPU, 2GB RAM, 20GB disk per node
- **Operating System**: Ubuntu 20.04/22.04 LTS (recommended)
- **Network**: All nodes must be able to communicate with each other

### Required Software
- Bash shell
- SSH access to all target nodes
- Python 3.6+
- Git

## Quick Start

### Step 1: Generate Inventory

1. **Run the inventory generator**:
   ```bash
   chmod +x inventory-generator.sh
   ./inventory-generator.sh
2. Follow the prompts:
#    - Enter control plane IP addresses
#    - Enter number of worker nodes
#    - Enter worker node IP addresses  
#    - Enter SSH user and key path

# 4. The script will generate:
#    - inventory/mycluster/hosts.yaml
#    - deploy-cluster.sh

# 5. Deploy the cluster:
./deploy-cluster.sh

