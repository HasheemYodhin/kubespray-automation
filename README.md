Kubespray Kubernetes Cluster Deployment

This project provides an automated way to generate Kubespray inventory files and deploy a production-ready Kubernetes cluster.

Prerequisites:

System Requirements:
Control Plane Node: Minimum 2 vCPUs, 4GB RAM, 20GB disk
Worker Nodes: Minimum 1 vCPU, 2GB RAM, 20GB disk per node
Operating System: Ubuntu 20.04/22.04 LTS (recommended)
Network: All nodes must be able to communicate with each other

Required Software
Bash shell
SSH access to all target nodes
Python 3.6+
Git

Setup Instructions
1. Clone the repository
   
git clone https://github.com/HasheemYodhin/kubespray-automation.git

cd kubespray

3. Make the script executable
   
chmod +x kubespray.sh

5. Run the script
./kubespray.sh

Example Run
==================================================
Kubespray Inventory Generator
==================================================

[INFO] Enter Control Plane Node Details:
Control Plane Public IP (ansible_host): 54.196.170.222   #public ip
Control Plane Private IP (ip/access_ip): 172.31.22.116   #private ip

How many worker nodes do you want? (0-10): 1  #Enter the no of nodes

[INFO] Enter Worker Node 1 Details:
Worker 1 Public IP (ansible_host): 13.218.169.173  #public ip
Worker 1 Private IP (ip/access_ip): 172.31.20.38   #private ip

Enter SSH user [ubuntu]: ubuntu
Enter SSH private key path: /home/ubuntu/.ssh/lens.pem    #give the path

[INFO] Generating hosts.yaml...
[INFO] Inventory file created: inventory/mycluster/hosts.yaml

[INFO] Cluster Inventory Summary:
Control Plane:
  Public IP: 54.196.170.222
  Private IP: 172.31.22.116

Worker Nodes: 1
Worker 1:
  Public IP: 13.218.169.173
  Private IP: 172.31.20.38

SSH User: ubuntu 
SSH Key: /home/ubuntu/.ssh/lens.pem 

[INFO] Creating deployment script...
[INFO] Deployment script created: deploy-cluster.sh
[INFO] To deploy the cluster, run: ./deploy-cluster.sh

#Deploy the Cluster

./deploy-cluster.sh

#Verify the cluster

kubectl get nodes

kubectl get pods -A

#Delete the Cluster
cd kubespray
source venv/bin/activate

ansible-playbook -i inventory/mycluster/hosts.yaml reset.yml -b -v
