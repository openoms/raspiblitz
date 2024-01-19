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
