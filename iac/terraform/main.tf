# Configuración general
resource "azurerm_resource_group" "proyecto" {
  name     = "proyecto"
  location = "eastus"
}

######################
# Virtual Network and subnet
######################

resource "azurerm_virtual_network" "proyecto_network" {
  name                = "proyecto_network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name
}

resource "azurerm_subnet" "proyecto_subnet" {
  name                 = "proyecto_subnet"
  resource_group_name  = azurerm_resource_group.proyecto.name
  virtual_network_name = azurerm_virtual_network.proyecto_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "proyecto_nsg" {
  name                = "proyecto_nsg"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  security_rule {
    name                       = "allowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowWireguard"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowPublicWeb"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowNPMPanel"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "81"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowHTTPS"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

######################
# Admin VM
######################

resource "azurerm_public_ip" "admin_public_ip" {
  name                = "admin_ip"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "admin_nic" {
  name                = "admin_nic"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  ip_configuration {
    name                          = "ipconfig_admin_nic"
    subnet_id                     = azurerm_subnet.proyecto_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.admin_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_admin" {
  network_interface_id      = azurerm_network_interface.admin_nic.id
  network_security_group_id = azurerm_network_security_group.proyecto_nsg.id
}

resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_sensitive_file" "admin_private_key" {
  content         = tls_private_key.admin.private_key_openssh
  filename        = "../secrets/admin"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "admin" {
  name                  = "admin"
  location              = azurerm_resource_group.proyecto.location
  resource_group_name   = azurerm_resource_group.proyecto.name
  network_interface_ids = [azurerm_network_interface.admin_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "admin_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  computer_name                   = var.admin_hostname
  admin_username                  = var.username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.admin.public_key_openssh
  }

  admin_ssh_key {
    username   = var.username
    public_key = file("../secrets/github.pub")
  }

  provisioner "local-exec" {
    # command = "./post-apply-script.sh ${var.username} ${var.vpn_hostname} ${azurerm_public_ip.vpn_public_ip.ip_address} ${local_sensitive_file.vpn.filename} ${var.todo_hostname} ${azurerm_public_ip.todo_public_ip.ip_address} ${local_sensitive_file.todo.filename} ${var.todo2_hostname} ${azurerm_public_ip.todo2_public_ip.ip_address} ${local_sensitive_file.todo2.filename} ${var.dns_hostname} ${azurerm_public_ip.dns_public_ip.ip_address} ${local_sensitive_file.dns.filename}"
    # command = "./post-apply-script.sh ${var.username} ${var.vpn_hostname} ${azurerm_public_ip.vpn_public_ip.ip_address} ${local_sensitive_file.vpn.filename} ${var.todo_hostname} ${azurerm_public_ip.todo_public_ip.ip_address} ${local_sensitive_file.todo.filename} todo2 0.0.0.0 ../secrets/todo2 ${var.dns_hostname} ${azurerm_public_ip.dns_public_ip.ip_address} ${local_sensitive_file.dns.filename}"
    command = "./post-apply-script.sh ${var.username} ${var.vpn_hostname} ${azurerm_public_ip.vpn_public_ip.ip_address} ${local_sensitive_file.vpn.filename} ${var.admin_hostname} ${azurerm_public_ip.admin_public_ip.ip_address} ${local_sensitive_file.admin_private_key.filename} ${var.todo_hostname} ${azurerm_network_interface.todo_nic.private_ip_address} ${var.todo2_hostname} ${azurerm_network_interface.todo2_nic.private_ip_address}"
  }
}

######################
# VPN VM
######################

resource "azurerm_public_ip" "vpn_public_ip" {
  name                = "vpn_ip"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vpn_nic" {
  name                = "vpn_nic"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  ip_configuration {
    name                          = "ipconfig_vpn_nic"
    subnet_id                     = azurerm_subnet.proyecto_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.5"
    public_ip_address_id          = azurerm_public_ip.vpn_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_vpn" {
  network_interface_id      = azurerm_network_interface.vpn_nic.id
  network_security_group_id = azurerm_network_security_group.proyecto_nsg.id
}

resource "tls_private_key" "vpn" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_sensitive_file" "vpn" {
  content         = tls_private_key.vpn.private_key_openssh
  filename        = "../secrets/vpn"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "vpn" {
  name                  = "vpn"
  location              = azurerm_resource_group.proyecto.location
  resource_group_name   = azurerm_resource_group.proyecto.name
  network_interface_ids = [azurerm_network_interface.vpn_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "vpn_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  computer_name                   = var.vpn_hostname
  admin_username                  = var.username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.vpn.public_key_openssh
  }
}

######################
# TODO VM
######################
resource "azurerm_network_interface" "todo_nic" {
  name                = "todo_nic"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  ip_configuration {
    name                          = "ipconfig_todo_nic"
    subnet_id                     = azurerm_subnet.proyecto_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.6"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_todo" {
  network_interface_id      = azurerm_network_interface.todo_nic.id
  network_security_group_id = azurerm_network_security_group.proyecto_nsg.id
}

resource "tls_private_key" "todo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_sensitive_file" "todo" {
  content         = tls_private_key.todo.private_key_openssh
  filename        = "../secrets/todo"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "todo" {
  name                  = "todo"
  location              = azurerm_resource_group.proyecto.location
  resource_group_name   = azurerm_resource_group.proyecto.name
  network_interface_ids = [azurerm_network_interface.todo_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "todo_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  computer_name                   = var.todo_hostname
  admin_username                  = var.username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.todo.public_key_openssh
  }
}

######################
# TODO VM COPY
######################
resource "azurerm_network_interface" "todo2_nic" {
  name                = "todo2_nic"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  ip_configuration {
    name                          = "ipconfig_todo2_nic"
    subnet_id                     = azurerm_subnet.proyecto_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.7"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_todo2" {
  network_interface_id      = azurerm_network_interface.todo2_nic.id
  network_security_group_id = azurerm_network_security_group.proyecto_nsg.id
}

resource "tls_private_key" "todo2" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_sensitive_file" "todo2" {
  content         = tls_private_key.todo2.private_key_openssh
  filename        = "../secrets/todo2"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "todo2" {
  name                  = "todo2"
  location              = azurerm_resource_group.proyecto.location
  resource_group_name   = azurerm_resource_group.proyecto.name
  network_interface_ids = [azurerm_network_interface.todo2_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "todo2_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12"
    version   = "latest"
  }

  computer_name                   = var.todo2_hostname
  admin_username                  = var.username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.username
    public_key = tls_private_key.todo2.public_key_openssh
  }
}

##################
# Load Balancer
##################

resource "azurerm_lb" "lb" {
  name                = "loadBalancer"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name
  sku = "Standard"

  frontend_ip_configuration {
    name                 = "publicIPAddress"
    subnet_id            = azurerm_subnet.proyecto_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
  }
}


resource "azurerm_lb_backend_address_pool" "lb_backend" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
  # virtual_network_id = azurerm_virtual_network.proyecto_network.id
}

resource "azurerm_lb_backend_address_pool_address" "todo" {
  name                    = "todo"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
  virtual_network_id      = azurerm_virtual_network.proyecto_network.id
  ip_address              = azurerm_network_interface.todo_nic.private_ip_address
}

resource "azurerm_lb_backend_address_pool_address" "todo2" {
  name                    = "todo2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
  virtual_network_id      = azurerm_virtual_network.proyecto_network.id
  ip_address              = azurerm_network_interface.todo2_nic.private_ip_address
}

resource "azurerm_lb_probe" "probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "probe"
  port            = 80
}

resource "azurerm_lb_rule" "rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "Rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "publicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.probe.id
}

##################
# Database
##################

resource "azurerm_postgresql_server" "db-server" {
  name                = "proyecto-ti-db-server"
  location            = azurerm_resource_group.proyecto.location
  resource_group_name = azurerm_resource_group.proyecto.name

  sku_name = "GP_Gen5_64"

  storage_mb                    = 5120
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  auto_grow_enabled             = true
  public_network_access_enabled = false

  administrator_login          = var.db_admin
  administrator_login_password = var.db_password
  version                      = "9.5"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "db" {
  name                = "appdb"
  resource_group_name = azurerm_resource_group.proyecto.name
  server_name         = azurerm_postgresql_server.db-server.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# resource "azurerm_postgresql_virtual_network_rule" "db_vnr" {
#   name                                 = "postgresql-vnet-rule"
#   resource_group_name                  = azurerm_resource_group.proyecto.name
#   server_name                          = azurerm_postgresql_server.db-server.name
#   subnet_id                            = azurerm_subnet.proyecto_subnet.id
#   ignore_missing_vnet_service_endpoint = true
# }
