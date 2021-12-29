provider "azurerm" {
	features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
    name                = "${var.prefix}-network"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    tags = {
        "infra" = "virtual_network"
    }
}

resource "azurerm_subnet" "internal" {
    name                 = "${var.prefix}-subnet"
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
    name                = "${var.prefix}-nic"
    resource_group_name = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location

    ip_configuration {
        name                          = "${var.prefix}-nic-ip"
        subnet_id                     = azurerm_subnet.internal.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        "infra" = "nic"
    }
}

resource "azurerm_public_ip" "main" {
    name                = "${var.prefix}-public-ip"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    allocation_method   = "Dynamic"

    tags = {
        "infra" = "public-ip"
    }
}

resource "azurerm_lb" "main" {
    name                = "${var.prefix}-lb"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    frontend_ip_configuration {
        name                 = "${var.prefix}-fe-ip"
        public_ip_address_id = azurerm_public_ip.main.id
    }

    tags = {
        "infra" = "load-balancer"
    }
}

resource "azurerm_linux_virtual_machine" "main" {
    name                            = "${var.prefix}-vm"
    resource_group_name             = azurerm_resource_group.main.name
    location                        = azurerm_resource_group.main.location
    size                            = "Standard_B1ls"
    count                           = "${var.vm_count}"

    admin_username                  = "${var.username}"
    admin_password                  = "${var.password}"
    disable_password_authentication = false
    network_interface_ids = [
        azurerm_network_interface.main.id,
    ]

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_disk {
        storage_account_type = "Standard_LRS"
        caching              = "ReadWrite"
    }

    tags = {
        "infra" = "virtual_machine"
    }
}