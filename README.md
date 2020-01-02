# Ubiquiti Unifi Controller

This project manages the setup of the Unifi Controller of Ubiquiti at Digital
Ocean with Terraform. We use a CoreOS Droplet and configure services using
Docker images.

We use an [nginx proxy with certbot](https://github.com/staticfloat/docker-nginx-certbot)
encapsulated in the image which makes it easy to setup valid Let's Encrypt
certificates.

For the Unifi Controller we use [jacobalberty/unifi](https://github.com/jacobalberty/unifi-docker)
image which comes packaged with MongoDB itself so we don't need to run a
separate service for it. We could if we want to but this is the most
straightforward and easiest approach.

We also use a separate mount where we store some information like the
certificates and the MongoDB data so you don't loose data when the Droplet needs
and update/upgrade for example.

# Access Core OS host

you can access the Core OS host using SSH, for obscurity we chosen to use port
2222 instead of the default 22 port.

```shell script
ssh core@host_ip_or_domain -p 2222
```

This project uses the [script to rule them all](https://github.com/github/scripts-to-rule-them-all)
approach from Github so you will find a `setup`, `test` and `deploy` script
which you can use.

# Deploy

We are using Terraform to setup the complete project (Host, docker containers,
mounts, static ip). We only don't manage the DNS records in here since we use
Cloudflare to manage our DNS. Make sure to setup the domain record otherwise
Let's Encrypt won't be able to generate a certificate.

You can setup you local machine by running `script/setup`.

There is a `script/deploy` script which you can run to provision everything. You
only need to provide the variables `digitalocean_token` and `ssh_public_key`.

I suggest using an `.auto.tfvars` file which is the most convient option however
there are several other options check the Terraform documentation for more
information.

### TODO

- Fix mount to take full size of block storage. When we started using the block
  storage we didn't use it full capacity so I resized it manually instead using
  this [guideline](https://www.digitalocean.com/docs/volumes/how-to/increase-size/)
  But it should be part of the provisioning instead.

