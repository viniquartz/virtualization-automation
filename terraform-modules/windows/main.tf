terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  count         = var.resource_pool != null ? 1 : 0
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  # Merge tags
  all_tags = merge(
    var.tags,
    {
      Terraform = "true"
      Module    = "windows"
      OS        = "Windows Server"
    }
  )

  # Convert tags map to vSphere custom attributes format
  custom_attributes = { for k, v in local.all_tags : k => v }

  # Resource pool ID
  resource_pool_id = var.resource_pool != null ? data.vsphere_resource_pool.pool[0].id : data.vsphere_compute_cluster.cluster.resource_pool_id
}

# ==============================================================================
# VM RESOURCE
# ==============================================================================

resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = var.vm_folder
  annotation       = var.annotation

  num_cpus = var.cpu_count
  memory   = var.memory_mb
  guest_id = data.vsphere_virtual_machine.template.guest_id

  # Timeouts
  wait_for_guest_net_timeout = var.wait_for_guest_net_timeout
  shutdown_wait_timeout      = var.shutdown_wait_timeout

  # Network interface
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  # Primary disk
  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = var.enable_disk_thin_provisioning
  }

  # Additional disks
  dynamic "disk" {
    for_each = var.additional_disks
    content {
      label            = disk.value.label
      size             = disk.value.size_gb
      unit_number      = disk.value.unit_number
      thin_provisioned = var.enable_disk_thin_provisioning
    }
  }

  # Clone from template
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      windows_options {
        computer_name         = var.vm_hostname
        workgroup             = var.workgroup
        admin_password        = var.admin_password
        time_zone             = var.timezone
        auto_logon            = var.auto_logon
        auto_logon_count      = var.auto_logon_count
        run_once_command_list = var.run_once_commands
      }

      network_interface {
        ipv4_address = var.ipv4_address
        ipv4_netmask = var.ipv4_netmask
      }

      ipv4_gateway    = var.ipv4_gateway
      dns_server_list = var.dns_servers
    }
  }

  # Custom attributes (tags)
  custom_attributes = local.custom_attributes

  lifecycle {
    ignore_changes = [
      annotation,
    ]
  }
}
