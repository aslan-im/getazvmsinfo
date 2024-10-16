#!/bin/sh

# Check if a parameter is passed
if [ -z "$1" ]; then
     echo "Subscription name was not provided. Using the default subscription."
else
     subscription_name="$1"
     az account set --subscription "$subscription_name"
fi

# Get all VMs in the subscription and display them in a table. Include Name, Resource Group, Location, NIC Name, and Power State.
vms=$(az vm list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, NicName:networkProfile.networkInterfaces[0].id}' --output json)

vms_array=""

# Iterate over each VM
for row in $(echo "$vms" | jq -r '.[]  | @base64'); do

     _jq() {
          echo "${row}" | base64 --decode | jq -r "${1}"
     }

     # Extract VM and NIC names
     vm_name=$(_jq '.Name')
     nic_name=$(_jq '.NicName')

     echo "Working on VM Name: $vm_name"

     # Get NIC details (NSG, VNet, Subnet)
     nic=$(az network nic show --ids "$nic_name" --query '{name:name, resourceGroup:resourceGroup, networkSecurityGroup:networkSecurityGroup.id, ipConfigurations:ipConfigurations[0].subnet.id}' --output json | jq '{
          name,
          resourceGroup,
          networkSecurityGroup: (.networkSecurityGroup | if type == "string" then split("/")[-1] else "N/A" end),
          subnet: (.ipConfigurations | if type == "string" then split("/")[-1] else "N/A" end),
          vnet: (.ipConfigurations | if type == "string" then split("/")[8] else "N/A" end)
     }')

     # Extract values from NIC details
     nic_name=$(echo "$nic" | jq -r '.name')
     resource_group=$(echo "$nic" | jq -r '.resourceGroup')
     nsg_name=$(echo "$nic" | jq -r '.networkSecurityGroup')
     vnet_name=$(echo "$nic" | jq -r '.vnet')
     subnet_name=$(echo "$nic" | jq -r '.subnet')

     # Append the information to the array
     vms_array="$vms_array $vm_name,$resource_group,$nic_name,$nsg_name,$vnet_name,$subnet_name"
done

echo "VM,RG,NIC,NIC_NSG,VNet,Subnet" >vms.csv

# Print the final array
for vm in $vms_array; do
     echo "$vm" >>vms.csv
done
