# Configure the Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

variable "subscription_id" {
  type    = string
  default = "710e601e-7eb5-47b7-a7db-370d7d6619cb"
  #default = "a8143c26-4989-xxxx-xxxx-672e4ffd9911"

}

variable scfile {
    type = string
    default = "userdata.tpl"
}

#variable "litellm_master_key" {
#  type        = string
#  description = "Master key for LiteLLM"
#}

#variable "litellm_salt_key" {
#  type        = string
#  description = "Salt key for LiteLLM"
#}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "example-resources"
  location = "Canada Central"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "example-network"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet for the VM
resource "azurerm_subnet" "backend" {
  name                 = "backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.7.0/24"]
}


# Create a network interface for the VM
resource "azurerm_network_interface" "nic" {
  name                = "example-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id

  }
}

# Create a public IP address
resource "azurerm_public_ip" "public_ip" {
  name                = "vm-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "example-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  admin_password      = "P@ssw0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]
  #custom_data                     = base64encode("userdata.tpl")

  disable_password_authentication = false

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_virtual_machine_extension" "rundockerscript" {
  name                 = "script"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

protected_settings = <<PROT
  {
    "script": "${base64encode(file(var.scfile))}"
  }
PROT

}
# Provisioner use as a last resort, recommended option is cloud-init
# The provisioner block is commented out because it is generally recommended to use cloud-init for provisioning.
# Uncomment and use the provisioner block below if cloud-init is not an option or if you need to run specific commands after VM creation.
#  provisioner "remote-exec" {
#   inline = [
#    "#!/bin/bash",
#    "sudo yum install -y git python3-pip",
#   "sudo pip3 install docker",
#    "sudo pip3 install docker-compose",
#    "git clone https://github.com/BerriAI/litellm",
#    "cd litellm",
#"echo 'LITELLM_MASTER_KEY="sk-1234"' > .env",
#"echo 'LITELLM_SALT_KEY="sk-1234"' >> .env",
#    "echo 'LITELLM_MASTER_KEY=\"${var.litellm_master_key}\"' > .env",
#    "echo 'LITELLM_SALT_KEY=\"${var.litellm_salt_key}\"' >> .env",
#    "docker-compose up"
#  ]
#  connection {
#    type                 = "ssh"
#    user                 = "root"
#    password             = "P@ssw0rd1234!"
#    port                 = 22
#    host                 = self.private_ip_address
#}

#}

# Output the public IP address
output "public_ip_address" {
  value = azurerm_public_ip.public_ip
}

resource "azurerm_network_security_group" "nsg_allow_inbound" {
  name                = "nsg_allow_inbound"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow_inbound_22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_inbound_4000"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "4000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_inbound_5432"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.nsg_allow_inbound.id
}

