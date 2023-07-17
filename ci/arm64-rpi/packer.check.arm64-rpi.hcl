variable "pack" { default = "lean" }
variable "github_user" { default = "raspiblitz" }
variable "branch" { default = "dev" }
variable "image_link" { default = "https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64.img.xz" }
variable "image_checksum" { default = "e7c0c89db32d457298fbe93195e9d11e3e6b4eb9e0683a7beb1598ea39a0a7aa" }

source "arm" "raspiblitz-arm64-rpi" {
  file_checksum_type    = "sha256"
  file_checksum         = var.image_checksum
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "--decompress", "$ARCHIVE_PATH"]
  file_urls             = [var.image_link]
  image_build_method    = "resize"
  image_chroot_env      = ["PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"]
  image_partitions {
    filesystem   = "vfat"
    mountpoint   = "/boot"
    name         = "boot"
    size         = "256M"
    start_sector = "8192"
    type         = "c"
  }
  image_partitions {
    filesystem   = "ext4"
    mountpoint   = "/"
    name         = "root"
    size         = "0"
    start_sector = "532480"
    type         = "83"
  }
  image_path                   = "raspiblitz-arm64-rpi-${var.pack}.img"
  image_size                   = "28G"
  image_type                   = "dos"
  qemu_binary_destination_path = "/usr/bin/qemu-arm-static"
  qemu_binary_source_path      = "/usr/bin/qemu-arm-static"
  qemuargs = [
    [ "-m", "1024M" ],
    [ "-drive", "file=dynamic_disk.qcow2,if=virtio,size=1024,format=qcow2"]
  ]
}

build {
  sources = ["source.arm.raspiblitz-arm64-rpi"]

  provisioner "shell" {
    inline = [
      "echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
      "parted /dev/vdb mklabel gpt",
      "parted /dev/vdb mkpart primary ext4 0% 100%",
      "mkfs.ext4 /dev/vdb1",
      "mkdir -p /mnt/hdd",
      "echo '/dev/vdb1 /mnt/hdd ext4 defaults 0 0' >> /etc/fstab",
      "mount -a"
    ]
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "github_user=${var.github_user}",
      "branch=${var.branch}",
      "pack=${var.pack}"
    ]
    script = "./check.raspiblitz.sh"
  }

  provisioner "shell" {
    inline = [
      "echo '# delete the SSH keys (will be recreated on the first boot)'",
      "rm -f /etc/ssh/ssh_host_*",
      "echo 'OK'",
    ]
  }
}
