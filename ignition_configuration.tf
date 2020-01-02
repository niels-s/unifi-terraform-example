data "ignition_config" "unifi_controller" {
  files = [
    data.ignition_file.profile_variables.rendered,
    data.ignition_file.sshd_config.rendered
  ]

  filesystems = [
    data.ignition_filesystem.unifi_controller_data_mount.rendered
  ]

  systemd = [
    data.ignition_systemd_unit.sshd_port.rendered,
    data.ignition_systemd_unit.unifi_controller_data_unit.rendered
  ]
}

data "ignition_file" "profile_variables" {
  filesystem = "root"
  path       = "/etc/profile.d/variables.sh"
  mode       = 420 # 644

  content {
    content = <<-EOT
      export TERM=xterm
    EOT
  }
}

# Configure SSH Service
data "ignition_file" "sshd_config" {
  filesystem = "root"
  path       = "/etc/ssh/sshd_config"
  mode       = 384 # 600

  content {
    content = <<-CONFIG
      # Use most defaults for sshd configuration.
      UsePrivilegeSeparation sandbox
      Subsystem sftp internal-sftp
      ClientAliveInterval 180
      UseDNS no
      UsePAM yes
      PrintLastLog no # handled by PAM
      PrintMotd no # handled by PAM

      PermitRootLogin no
      AllowUsers core
      AuthenticationMethods publickey
    CONFIG
  }
}

data "ignition_systemd_unit" "sshd_port" {
  name = "sshd.socket"

  dropin {
    name    = "10-sshd-port.conf"
    content = <<-CONFIG
      [Socket]
      ListenStream=
      ListenStream=2222
    CONFIG
  }
}

// Configure Block Storage Mount
data "ignition_filesystem" "unifi_controller_data_mount" {
  name = "unifi_controller_data_mount"

  mount {
    device          = "/dev/disk/by-id/scsi-0DO_Volume_sdb"
    wipe_filesystem = false
    format          = "ext4"
  }
}

data "ignition_systemd_unit" "unifi_controller_data_unit" {
  name    = "mnt-unifi_controller_data.mount"
  enabled = true
  content = <<-CONFIG
    [Unit]
    Description = Unifi Controller Data Mount

    [Mount]
    What=/dev/disk/by-id/scsi-0DO_Volume_sdb
    Where=/mnt/unifi_controller_data
    Options=defaults,discard,noatime
    Type=ext4

    [Install]
    WantedBy = multi-user.target
  CONFIG
}
