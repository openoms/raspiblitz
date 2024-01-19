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
