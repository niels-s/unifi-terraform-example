data "ignition_config" "unifi_controller" {
  files = [
    data.ignition_file.profile_variables.rendered,
    data.ignition_file.sshd_config.rendered
  ]
  systemd = [
    data.ignition_systemd_unit.sshd_port.rendered
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

