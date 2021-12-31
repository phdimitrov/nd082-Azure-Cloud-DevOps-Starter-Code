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
    count               = var.vm_count
    name                = "${var.prefix}-nic-${count.index}"
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

resource "azurerm_lb_backend_address_pool" "main" {
    name            = "${var.prefix}-lb-be-addr-pool"
    loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
    count                   = var.vm_count
    network_interface_id    = azurerm_network_interface.main[count.index].id
    ip_configuration_name   = "${var.prefix}-nic-ip"
    backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}


resource "azurerm_network_security_group" "webserver" {
    name                = "${var.prefix}-nsg"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name
    
    security_rule {
        access                     = "Allow"
        direction                  = "Inbound"
        name                       = "tls"
        priority                   = 100
        protocol                   = "Tcp"
        source_port_range          = "*"
        source_address_prefix      = "*"
        destination_port_range     = "443"
        destination_address_prefix = azurerm_subnet.internal.address_prefixes[0]
    }

    tags = {
        "infra" = "nsg"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "main" {
    count                     = var.vm_count
    network_interface_id      = azurerm_network_interface.main[count.index].id
    network_security_group_id = azurerm_network_security_group.webserver.id
}

data "azurerm_image" "main" {
    name                = "${var.image_name}"
    resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_availability_set" "main" {
    name                = "${var.prefix}-availability-set"
    location            = azurerm_resource_group.main.location
    resource_group_name = azurerm_resource_group.main.name

    tags = {
        "infra" = "availability-set"
    }
}

resource "azurerm_linux_virtual_machine" "main" {
    count                           = var.vm_count
    name                            = "${var.prefix}-vm-${count.index}"
    resource_group_name             = azurerm_resource_group.main.name
    location                        = azurerm_resource_group.main.location
    size                            = "Standard_B1ls"
    availability_set_id             = azurerm_availability_set.main.id
    
    admin_username                  = "${var.username}"
    admin_password                  = "${var.password}"
    disable_password_authentication = false
    source_image_id                 = data.azurerm_image.main.id
    network_interface_ids = [
        azurerm_network_interface.main[count.index].id,
    ]
    
    os_disk {
        storage_account_type = "Standard_LRS"
        caching              = "ReadWrite"
    }

    tags = {
        "infra" = "virtual_machine"
    }

    depends_on = [
        azurerm_network_interface.main,
        azurerm_availability_set.main,
        azurerm_lb.main,
    ]
}