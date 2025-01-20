terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.10.0"
    }
  }
}

provider "vsphere" {
  user           = "ip-devops@upshield.local"
  password       = "Dd123!@#"
  vsphere_server = "upshld-vcenter-01.upshield.local"

  allow_unverified_ssl = true
}

variable "datacenter"   { default = "HTZNR-NRBRG-DC-1" }
variable "resourcepool" { default = "DevOps" } 
variable "cluster"      { default = "HTZN-NRBRG-DC-1-CLUS1" }
variable "network"      { default = "UPSHLD-INT-VLAN_1110" }
variable "datastore"    { default = "LocalStore-G9-N1-SSD" }
variable "template"     { default = "UPGM-DevOps-Ubuntu-22-Template-Main" }

# Fetch resources
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_resource_pool" "resourcepool" {
  name          = var.resourcepool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Create a VM
resource "vsphere_virtual_machine" "vm" {
  count = 2
  name             = format("terraform-test-vm-%02d", count.index + 1)
  # name = "terraform-test-vm"
  resource_pool_id = data.vsphere_resource_pool.resourcepool.id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 4
  memory   = 8192
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = false
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    # customize {
    #   linux_options {
    #     host_name = "terraform-test-02"
    #     domain    = "local"
    #   }
    #   network_interface {
    #     # DHCP configuration (no IP address specified)
    #   }
    # }
  }

  # Use provisioner to copy SSH keys
  provisioner "file" {
    source      = "~/.ssh/terraform_key.pub"
    destination = "/root/.ssh/authorized_keys"

    connection {
      type     = "ssh"
      user     = "root"
      password = "Dd123!@#"
      host     = self.default_ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /root/.ssh/authorized_keys"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = "Dd123!@#"
      host     = self.default_ip_address
    }
  }
}

output "vm_ips" {
  value = [for vm in vsphere_virtual_machine.vm : vm.default_ip_address]
  description = "The IP addresses of the created VMs."
}

output "vm_names" {
  value = [for vm in vsphere_virtual_machine.vm : vm.name]
  description = "The names of the created VMs."
}