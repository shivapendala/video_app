variable "hcloud_token" {
  type        = string
  description = "API token if using cloud provider (e.g. Hetzner / Hostinger Cloud)"
  default     = ""
}

variable "vps_ip" {
  type        = string
  description = "Target Hostinger VPS IPv4 Address"
  default     = "127.0.0.1"
}

variable "vps_user" {
  type        = string
  description = "SSH User for Hostinger VPS"
  default     = "root"
}

variable "domain_name" {
  type        = string
  description = "Single domain name for ElevateIQ Platform"
  default     = "elevateiq-softtech.com"
}
