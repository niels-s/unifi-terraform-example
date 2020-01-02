resource "digitalocean_droplet" "unifi_controller" {
  image       = "coreos-stable"
  name        = var.hostname
  region      = "ams3"
  size        = "s-1vcpu-1gb"
  ipv6        = true
  resize_disk = false
  ssh_keys    = [digitalocean_ssh_key.ssh_key.fingerprint]
  user_data   = data.ignition_config.unifi_controller.rendered

  lifecycle {
    create_before_destroy = true
  }
}
