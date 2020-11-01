terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  version = ">=2.0"
  # The "feature" block is required for AzureRM provider 2.x.
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "Prod" {
  name     = "myresourcegroup01"
  location = "West Europe"
}
resource "azurerm_public_ip" "Prod" {  //Here defined the public IP
  name                         = "VMpublicIP"  
  location                     = "${azurerm_resource_group.Prod.location}"  
  resource_group_name          = "${azurerm_resource_group.Prod.name}"  
  allocation_method            = "Static"  
  idle_timeout_in_minutes      = 30  
  domain_name_label            = "myvm01"
}
# Create a virtual network within the resource group
resource "azurerm_virtual_network" "Prod" {
  name                = "myvnet"
  resource_group_name = "${azurerm_resource_group.Prod.name}"
  location            = "${azurerm_resource_group.Prod.location}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "Prod" {
  name                 = "mysubnet"
  resource_group_name  = "${azurerm_resource_group.Prod.name}"
  virtual_network_name = "${azurerm_virtual_network.Prod.name}"
  address_prefix       = "10.0.2.0/24"
}
resource "azurerm_storage_account" "Prod" {
  name                     = "wedstracc"
  resource_group_name      = "${azurerm_resource_group.Prod.name}"
  location                 = "${azurerm_resource_group.Prod.location}"
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  enable_https_traffic_only= "true"
}
resource "azurerm_storage_account_network_rules" "Prod" {
  resource_group_name  = "${azurerm_resource_group.Prod.name}"
  storage_account_name = "${azurerm_storage_account.Prod.name}"

  default_action             = "Allow"
  ip_rules                   = []
  virtual_network_subnet_ids = []
  bypass                     = ["AzureServices"]
}
resource "azurerm_storage_container" "Prod" {
  name                  = "content"
  storage_account_name  = "${azurerm_storage_account.Prod.name}"
  container_access_type = "private"
}

resource "azurerm_storage_blob" "Prod" {
  name                   = "mysite"
  storage_account_name   = "${azurerm_storage_account.Prod.name}"
  storage_container_name = "${azurerm_storage_container.Prod.name}"
  type                   = "Block"
  source                 = "./SITE.jpg"
}
resource "azurerm_network_security_group" "Prod" {
  name                = "mydemo-nsg"
  location            = "${azurerm_resource_group.Prod.location}"
  resource_group_name = "${azurerm_resource_group.Prod.name}"

security_rule {   //Here opened remote desktop port
    name                       = "RDP"  
    priority                   = 110  
    direction                  = "Inbound"  
    access                     = "Allow" 
    protocol                   = "Tcp"  
    source_port_range          = "*"  
    destination_port_range     = "3389"  
    source_address_prefix      = "*"  
    destination_address_prefix = "*"  
  }
}

resource "azurerm_network_interface" "Prod" {
  name                = "vm1nic"
  location            = "${azurerm_resource_group.Prod.location}"
  resource_group_name = "${azurerm_resource_group.Prod.name}"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = "${azurerm_subnet.Prod.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.Prod.id}"
  }
}

resource "azurerm_network_interface_security_group_association" "Prod" {
  network_interface_id      = "${azurerm_network_interface.Prod.id}"
  network_security_group_id = "${azurerm_network_security_group.Prod.id}"
}
resource "azurerm_windows_virtual_machine" "Prod" {
  name                = "myvm01"
  resource_group_name = "${azurerm_resource_group.Prod.name}"
  location            = "${azurerm_resource_group.Prod.location}"
  size                = "Standard_DS2_v2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.Prod.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}
