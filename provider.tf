provider "digitalocean" {
  token   = var.digitalocean_token
  version = "~> 1.9"
}

provider "ignition" {
  version = "~> 1.2"
}
