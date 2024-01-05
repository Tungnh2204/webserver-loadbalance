#!/bin/bash
# Usage: bash create-high-availability-vm-with-sets.sh <Resource Group Name>
# By Nguyen Hoang Tung

RgName=$1

date
# Create a Virtual Network for the VMs
echo '------------------------------------------'
echo 'Creating a Virtual Network for the VMs'
az network vnet create \
    --resource-group $RgName \
    --name bePortalVnet \
    --subnet-name bePortalSubnet 

# Create a Network Security Group
echo '------------------------------------------'
echo 'Creating a Network Security Group'
az network nsg create \
    --resource-group $RgName \
    --name bePortalNSG 

# Add inbound rule on port 80
echo '------------------------------------------'
echo 'Allowing access on port 80'
az network nsg rule create \
    --resource-group $RgName \
    --nsg-name bePortalNSG \
    --name Allow-80-Inbound \
    --priority 110 \
    --source-address-prefixes '*' \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --description "Allow inbound on port 80."

# Create the NIC
for i in 1 2; do
  echo '------------------------------------------'
  echo 'Creating webNic'$i
  az network nic create \
    --resource-group $RgName \
    --name NHTwebNic$i \
    --vnet-name bePortalVnet \
    --subnet bePortalSubnet \
    --network-security-group bePortalNSG
done 

# Create an availability set
echo '------------------------------------------'
echo 'Creating an availability set'
az vm availability-set create -n portalAvailabilitySet -g $RgName

# Create 2 VM's from a template
for i in 1 2 ; do
    echo '------------------------------------------'
    echo 'Creating webVM'$i
    az vm create \
        --admin-username azureuser \
        --resource-group $RgName \
        --name NHT-Web-VM$i \
        --nics NHTNic$i \
        --image Ubuntu2204 \
        --availability-set portalAvailabilitySet \
        --generate-ssh-keys \
        --custom-data cloud-init.txt
done
#Create a new public IP address
echo '------------------------------------------'
echo 'Creating a new public IP address'
az network public-ip create \
  --resource-group $RgName \
  --allocation-method Static \
  --name NHTPublicIP

# Create the load balancer
echo '------------------------------------------'
echo 'Creating a the load balancer'
az network lb create \
  --resource-group $RgName \
  --name NHT-LB \
  --public-ip-address NHTPublicIP \
  --frontend-ip-name NHT-PIP \
  --backend-pool-name NHT-bePool

#Create a health probe
echo '------------------------------------------'
echo 'Creating a health probe'
az network lb probe create \
  --resource-group $RgName \
  --lb-name NHT-LB \
  --name NHT-HealthProbe \
  --protocol tcp \
  --port 80

# Create LB rule
echo '------------------------------------------'
echo 'Creating LB rule'
az network lb rule create \
  --resource-group $RgName \
  --lb-name NHT-LB \
  --name NHT-lbRule \
  --protocol tcp \
  --frontend-port 80 \
  --backend-port 80 \
  --frontend-ip-name NHT-PIP \
  --backend-pool-name NHT-bePool \
  --probe-name NHT-HealthProbe
# Connect VMs to the back-end pool
echo '------------------------------------------'
echo 'Connect VMs to the back-end pool'
for i in 1 2; do
az network nic ip-config update \
  --resource-group $RgName \
  --nic-name NHTwebNic$i \
  --name ipconfig1 \
  --lb-name NHT-LB \
  --lb-address-pools NHT-bePool

az network nic ip-config update \
  --resource-group $RgName \
  --nic-name NHTwebNic$i \
  --name ipconfig1 \
  --lb-name NHT-LB \
  --lb-address-pools NHT-bePool

az network nic ip-config update \
  --resource-group $RgName \
  --nic-name NHTwebNic$i \
  --name ipconfig1 \
  --lb-name NHT-LB \
  --lb-address-pools NHT-bePool
done

echo http://$(az network public-ip show \
    --resource-group $RgName \
    --name NHTPublicIP \
    --query ipAddress \
    --output tsv)
# Done
echo '--------------------------------------------------------'
echo '             VM Setup Script Completed'
echo '--------------------------------------------------------'
