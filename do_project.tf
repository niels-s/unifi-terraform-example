resource "digitalocean_project" "unifi" {
  name        = "unifi"
  description = "all resources for Unifi Ubquiti controller"
  purpose     = "Unifi Controller"
  environment = "Production"
  resources = [
    "do:droplet:${digitalocean_droplet.unifi_controller.id}",
    "do:volume:${digitalocean_volume.unifi_controller_data.id}"
  ]
}

resource "digitalocean_ssh_key" "ssh_key" {
  name       = var.ssh_public_key_name
  public_key = var.ssh_public_key
}
