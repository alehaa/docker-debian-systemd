# Systemd-enabled Debian image for Docker

[![](https://img.shields.io/github/issues-raw/mksec/docker-debian-systemd.svg?style=flat-square)](https://github.com/mksec/docker-debian-systemd/issues)
[![](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/mksec/debian-systemd.svg?style=flat-square)](https://hub.docker.com/r/mksec/debian-systemd/)


## About

This Docker image enhances the [Debian image](https://hub.docker.com/_/debian)
to be run like a VM or LXC container including systemd as init system and other
utilities.

In addition to systemd cron and anacron will be installed. However, in contrast
to the official Debian CD, rsyslog will *NOT* be installed, as journald should
fit most needs.

The image is provided as multi arch image. At the moment the `amd64` and `arm64`
architectures are enabled.


## Usage

For Debian stretch run:
```
docker run -d -it                       \
    -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
    --cap-add SYS_ADMIN                 \
    mksec/debian-systemd:stretch
```

#### Run at Docker for Mac

As the image mounts the systemd cgroup into the container, the host needs to
have it mounted already. However, boot2docker doesn't have systemd installed and
therefore this cgroup isn't available.

To get the cgroup mounted in the Docker VM, you can login into the VM by running
`docker-machine ssh` and run the following code to apply the patch:

```
sudo -s
cat >> /var/lib/boot2docker/bootsync.sh <<EOF
mkdir /sys/fs/cgroup/systemd
mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
EOF
```


## License

This project is licensed under the [MIT License](LICENSE).

&copy; 2018-2019 Alexander Haase
