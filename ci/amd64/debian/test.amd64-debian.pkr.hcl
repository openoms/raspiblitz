variable "iso_name" { default = "debian-12.4.0-amd64-netinst.iso" }
variable "iso_checksum" { default = "64d727dd5785ae5fcfd3ae8ffbede5f40cca96f1580aaa2820e8b99dae989d94" }

variable "pack" { default = "lean" }
variable "github_user" { default = "raspiblitz" }
variable "branch" { default = "dev" }
variable "desktop" { default = "none" }

variable "boot" { default = "uefi" }
variable "preseed_file" { default = "preseed.cfg" }
variable "hostname" { default = "raspiblitz-amd64" }

variable "image_link" { default = "https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso" }
variable "image_checksum" { default = "23ab444503069d9ef681e3028016250289a33cc7bab079259b73100daee0af66" }

variable "disk_size" { default = "30000" }
variable "memory" { default = "4096" }
variable "cpus" { default = "4" }

packer {
  required_version = ">= 1.7.0, < 2.0.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0, < 2.0.0"
    }
  }
}

locals {
  name_template = "${var.hostname}-debian-${var.pack}"
}

source "qemu" "debian" {

  disk_image = true

  image_path = "../../../raspiblitz-amd64-debian-lean.qcow2"

  cpus             = var.cpus
  disk_size        = var.disk_size

  iso_checksum     = var.image_checksum
  iso_url          = var.image_link
  memory           = var.memory

  ssh_password     = "raspiblitz"
  ssh_port         = 22
  ssh_timeout      = "10000s"
  ssh_username     = "admin"

  format           = "qcow2"
  vm_name          = "${local.name_template}.qcow2"
  headless         = false

  vnc_bind_address = "127.0.0.1"
  vnc_port_max     = 5900
  vnc_port_min     = 5900
  qemuargs = [
    ["-m", var.memory],
    ["-display", "none"]
  ]
}

build {
  description = "Can't use variables here yet!"
  sources     = ["source.qemu.debian"]

  provisioner "shell" {
    environment_vars = [
      "HOME_DIR=/home/admin",
      "github_user=${var.github_user}",
      "branch=${var.branch}",
    ]

    execute_command   = "echo 'raspiblitz' | {{.Vars}} sudo -S -E sh -eux '{{.Path}}'"
    expect_disconnect = true
    scripts = [
      "./../_common/env.sh",
      "./scripts/test.raspiblitz.sh",
    ]
  }
}
