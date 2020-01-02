data "ignition_config" "unifi_controller" {
  files = [
    data.ignition_file.profile_variables.rendered,
    data.ignition_file.sshd_config.rendered,
    data.ignition_file.nginx_conf_file.rendered,
    data.ignition_file.unifi_nginx_stream_conf_file.rendered,
    data.ignition_file.unifi_nginx_http_conf_file.rendered
  ]

  filesystems = [
    data.ignition_filesystem.unifi_controller_data_mount.rendered
  ]

  systemd = [
    data.ignition_systemd_unit.sshd_port.rendered,
    data.ignition_systemd_unit.unifi_controller_data_unit.rendered,
    data.ignition_systemd_unit.install_docker_network_unit.rendered,
    data.ignition_systemd_unit.nginx_proxy_unit.rendered,
    data.ignition_systemd_unit.unifi_unit.rendered
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

// Configure Nginx Proxy
data "ignition_file" "nginx_conf_file" {
  filesystem = data.ignition_filesystem.unifi_controller_data_mount.name
  path       = "/nginx/nginx.conf"
  mode       = 0644

  content {
    content = <<-CONFIG
      user  nginx;
      worker_processes  1;

      error_log  /var/log/nginx/error.log warn;
      pid        /var/run/nginx.pid;

      events {
          worker_connections  1024;
      }

      http {
          include       /etc/nginx/mime.types;
          default_type  application/octet-stream;

          log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                            '$status $body_bytes_sent "$http_referer" '
                            '"$http_user_agent" "$http_x_forwarded_for"';

          access_log  /var/log/nginx/access.log  main;

          sendfile        on;
          #tcp_nopush     on;

          keepalive_timeout  65;

          #gzip  on;

          include /etc/nginx/conf.d/*.conf;
      }

      stream {
          include /etc/nginx/streams.d/*.conf;
      }
    CONFIG
  }
}

data "ignition_file" "unifi_nginx_stream_conf_file" {
  filesystem = data.ignition_filesystem.unifi_controller_data_mount.name
  path       = "/nginx/streams.d/unifi.conf"
  mode       = 0644

  content {
    content = <<-CONFIG
      upstream unifi_stun_servers {
        server unifi:3478;
      }

      server {
        listen 3478 udp;

        proxy_protocol on;
        proxy_pass unifi_stun_servers;

        error_log /var/log/nginx/stun_errors.log warn;
      }

      server {
        listen 6789 udp;

        proxy_protocol on;
        proxy_pass unifi:6789;
      }
    CONFIG
  }
}

data "ignition_file" "unifi_nginx_http_conf_file" {
  filesystem = data.ignition_filesystem.unifi_controller_data_mount.name
  path       = "/nginx/conf.d/unifi.conf"
  mode       = 0644

  content {
    content = <<-CONFIG
      map $http_upgrade $connection_upgrade {
          default upgrade;
          ''      close;
      }

      server {
        listen 80;

        server_name ${var.hostname};

        return 301 https://$host$request_uri;
      }

      server {
        listen 443 ssl http2;

        server_name           ${var.hostname};
        client_max_body_size  2G;

        ssl_certificate     /etc/letsencrypt/live/${var.hostname}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${var.hostname}/privkey.pem;

        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM';

        location / {
          proxy_pass https://unifi:8443;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $http_host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_buffering off;
        }
      }

      server {
        listen 8080;

        server_name ${var.hostname};

        location / {
          proxy_pass http://unifi:8080;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $http_host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header Upgrade $http_upgrade;
          proxy_buffering off;
        }
      }
    CONFIG
  }
}

data "ignition_systemd_unit" "install_docker_network_unit" {
  name    = "install_docker_network.service"
  enabled = true

  content = <<-CONFIG
    [Unit]
    Description=Install user defined docker network
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/bin/docker network create unifi-network
  CONFIG
}

data "ignition_systemd_unit" "nginx_proxy_unit" {
  name    = "nginx_proxy.service"
  enabled = true

  content = <<-CONFIG
    [Unit]
    Description= Nginx Proxy with Certbot
    After=docker.service
    After=unifi.service
    Requires=docker.service
    Requires=install_docker_network.service

    [Service]
    Restart=always
    TimeoutStartSec=0
    ExecStartPre=/usr/bin/docker pull staticfloat/nginx-certbot
    ExecStartPre=-/usr/bin/docker stop nginxproxy
    ExecStartPre=-/usr/bin/docker rm nginxproxy
    ExecStart=/usr/bin/docker run \
        --name nginxproxy \
        --network unifi-network \
        --restart=no \
        -e CERTBOT_EMAIL=${var.certbot_email} \
        -p 80:80 \
        -p 443:443 \
        -p 3478:3478/udp \
        -p 6789:6789 \
        -p 8080:8080 \
        -v /var/log/nginx:/var/log/nginx \
        -v /var/log/letsencrypt:/var/log/letsencrypt \
        -v /mnt/unifi_controller_data/letsencrypt:/etc/letsencrypt:rw \
        -v /mnt/unifi_controller_data/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
        -v /mnt/unifi_controller_data/nginx/conf.d:/etc/nginx/user.conf.d:ro \
        -v /mnt/unifi_controller_data/nginx/streams.d:/etc/nginx/streams.d:ro \
        staticfloat/nginx-certbot

    [Install]
    WantedBy=multi-user.target
  CONFIG
}

// Setup Unifi controller
data "ignition_systemd_unit" "unifi_unit" {
  name    = "unifi.service"
  enabled = true

  content = <<-CONFIG
    [Unit]
    Description=Unifi Controller
    After=docker.service
    Requires=docker.service
    Requires=install_docker_network.service

    [Service]
    Restart=always
    TimeoutStartSec=0
    ExecStartPre=/usr/bin/docker pull jacobalberty/unifi:5.12
    ExecStartPre=-/usr/bin/docker stop unifi
    ExecStartPre=-/usr/bin/docker rm unifi
    ExecStart=/usr/bin/docker run \
      --name unifi \
      --network unifi-network \
      --restart=no \
      -e TZ='${var.timezone}' \
      --init \
      -v /mnt/unifi_controller_data/unifi:/unifi:rw \
      jacobalberty/unifi:5.12

    [Install]
    WantedBy=multi-user.target
  CONFIG
}
