resource "digitalocean_droplet" "unifi_controller" {
  image       = "coreos-stable"
  name        = var.hostname
  region      = "ams3"
  size        = "s-1vcpu-1gb" # TODO: change size eventually
  ipv6        = true
  resize_disk = false
  ssh_keys    = [digitalocean_ssh_key.ssh_key.fingerprint]
  user_data   = data.ignition_config.unifi_controller.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_volume" "unifi_controller_data" {
  region                  = digitalocean_droplet.unifi_controller.region
  name                    = "unifi_controller_data"
  size                    = 20
  initial_filesystem_type = "xfs"
  description             = "Store the MongoDB data of the Unifi Controller"
}

resource "digitalocean_volume_attachment" "unifi_controller" {
  droplet_id = digitalocean_droplet.unifi_controller.id
  volume_id  = digitalocean_volume.unifi_controller_data.id
}

resource "digitalocean_floating_ip" "unifi_controller" {
  region = digitalocean_droplet.unifi_controller.region
}

resource "digitalocean_floating_ip_assignment" "unifi_controller" {
  ip_address = digitalocean_floating_ip.unifi_controller.ip_address
  droplet_id = digitalocean_droplet.unifi_controller.id

  lifecycle {
    create_before_destroy = true
  }
}
