data "azurerm_subnet" "anchor" {
  count                = local.deploy_anchor && local.sub_admin_exists ? 1 : 0
  name                 = split("/", local.sub_admin_arm_id)[10]
  resource_group_name  = split("/", local.sub_admin_arm_id)[4]
  virtual_network_name = split("/", local.sub_admin_arm_id)[8]
}

# Create Anchor VM
resource "azurerm_network_interface" "anchor" {
  count                         = local.deploy_anchor ? length(local.zones) : 0
  name                          = format("%s_%s%s", local.prefix, local.anchor_virtualmachine_names[count.index], local.resource_suffixes.nic)
  resource_group_name           = local.rg_exists ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location                      = local.rg_exists ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  enable_accelerated_networking = false

  ip_configuration {
    name                          = "IPConfig1"
    subnet_id                     = data.azurerm_subnet.anchor[0].id
    private_ip_address            = try(local.anchor.nic_ips[count.index], cidrhost(data.azurerm_subnet.anchor[0].address_prefixes[0], (count.index + 5)))
    private_ip_address_allocation = "static"
  }
}

# Create the Linux Application VM(s)
resource "azurerm_linux_virtual_machine" "anchor" {
  count                        = local.deploy_anchor && (local.anchor_ostype == "LINUX") ? length(local.zones) : 0
  name                         = format("%s_%s%s", local.prefix, local.anchor_virtualmachine_names[count.index], local.resource_suffixes.vm)
  computer_name                = local.anchor_computer_names[count.index]
  resource_group_name          = local.rg_exists ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location                     = local.rg_exists ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  proximity_placement_group_id = azurerm_proximity_placement_group.ppg[count.index].id
  zone                         = local.zones[count.index]

  network_interface_ids = [
    azurerm_network_interface.anchor[count.index].id
  ]
  size                            = local.anchor_size
  admin_username                  = local.anchor_authentication.username
  disable_password_authentication = true

  os_disk {
    name                 = format("%s_%s%s", local.prefix, local.anchor_virtualmachine_names[count.index], local.resource_suffixes.osdisk)
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = local.anchor_custom_image ? local.anchor_os.source_image_id : null

  dynamic "source_image_reference" {
    for_each = range(local.anchor_custom_image ? 0 : 1)
    content {
      publisher = local.anchor_os.publisher
      offer     = local.anchor_os.offer
      sku       = local.anchor_os.sku
      version   = local.anchor_os.version
    }
  }

  admin_ssh_key {
    username   = local.anchor_authentication.username
    public_key = file(var.sshkey.path_to_public_key)
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage-bootdiag.primary_blob_endpoint
  }
}

# Create the Windows Application VM(s)
resource "azurerm_windows_virtual_machine" "anchor" {
  count                        = local.deploy_anchor && (local.anchor_ostype == "WINDOWS") ? length(local.zones) : 0
  name                         = format("%s_%s%s", local.prefix, local.anchor_virtualmachine_names[count.index], local.resource_suffixes.vm)
  computer_name                = local.anchor_computer_names[count.index]
  resource_group_name          = local.rg_exists ? data.azurerm_resource_group.resource-group[0].name : azurerm_resource_group.resource-group[0].name
  location                     = local.rg_exists ? data.azurerm_resource_group.resource-group[0].location : azurerm_resource_group.resource-group[0].location
  proximity_placement_group_id = azurerm_proximity_placement_group.ppg[count.index].id
  zone                         = local.zones[count.index]

  network_interface_ids = [
    azurerm_network_interface.anchor[count.index].id
  ]

  size           = local.anchor_size
  admin_username = local.anchor_authentication.username
  admin_password = local.anchor_authentication.password

  os_disk {
    name                 = format("%s_%s%s", local.prefix, local.anchor_virtualmachine_names[count.index], local.resource_suffixes.osdisk)
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = local.anchor_custom_image ? local.anchor_os.source_image_id : null

  dynamic "source_image_reference" {
    for_each = range(local.anchor_custom_image ? 0 : 1)
    content {
      publisher = local.anchor_os.publisher
      offer     = local.anchor_os.offer
      sku       = local.anchor_os.sku
      version   = local.anchor_os.version
    }
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage-bootdiag.primary_blob_endpoint
  }
}