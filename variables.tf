variable "digitalocean_token" {
  type        = string
  description = "Token used to query the DigitalOcean API"
}

variable "ssh_public_key_name" {
  type        = string
  description = "Name of the Public key resource in Digital Ocean"
}

variable "ssh_public_key" {
  type        = string
  description = "Public key used to allow SSH access to the VM"
}

variable "hostname" {
  type        = string
  description = "Fully Qualified host name of the server, this will be used to request certificat with Let's Encrypt"
}
