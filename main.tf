# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resource_domain" {
  name     = "domain-resources"
  location = "West Europe"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_resource_group" "dev-vn" {
  name     = "dev-network"
  resource_group_name = azurerm_resource_group.resource_domain.name
  location = azurerm_resource_group.mtc-rg.location
  address_space = ["10.123.0.0/16"]

  tags = {
    environment = 'dev'
  }
}

resource "azurerm_subnet" "dev-subnet" {
  name = "dev-subnet"
  resource_group_name = azurerm_resource_group.dev-vn.name
  virtual_network_name = azurerm_virtual_network.dev-vn.name
  address_prefixes = [""]
}

resource "azurerm_network_security_group" "dev-sg" {
  name = "dev-sg"
  location = azurerm_resource_group.resource_domain.location
  resource_group_name = azurerm_resource_group.resource_domain.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_group" "dev-rule" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev-sg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "81.98.221.51/32"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet_network_security_group_association" "dev-sga" {
  subnet_id                 = azurerm_subnet.dev-subnet.id
  network_security_group_id = azurerm_network_security_group.dev-sg.id
}

resource "azurerm_public_ip" "dev-ip" {
  name                    = "dev-pip"
  location                = azurerm_resource_group.dev-rg.location
  resource_group_name     = azurerm_resource_group.dev-rg.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "dev-ip" {
  name                = "dev-ip"
  location            = azurerm_resource_group.dev-rg.location
  resource_group_name = azurerm_resource_group.dev-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dev-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.dev-ip.id
  }

  tags = {
    environment = 'dev'
  }
}

resource "azurerm_linux_virtual_machine" "dev-vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl",{
      hostname = self.public_ip_address
      user = "adminuser",
      identityfile = "~/.ssh/mtcazurekey"
    } )
    interpreter = ["Powershell", "-Command"] ["bash", "-c"]
  }

  tags = {
    environment = "dev"
  }
}

data "azurerm_public_ip" "mtc-ip-data" {
  name = azurerm_public_ip.name
  resource_group_name = azurerm_resource_group.dev-rg.name
}

output "public_ip_address" {
    value = "${azurerm_linux_virtual_machine.dev-vm.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}

