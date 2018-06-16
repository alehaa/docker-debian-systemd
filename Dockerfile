# This file is part of docker-debian-systemd.
#
# Copyright (c)
#   2018 Alexander Haase <ahaase@mksec.de>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This image bases on the regular Debian image. By default the 'latest' tag
# (pointing to the current stable release) of the parent image will be used.
# However, an alternate parent tag may be set by defining the 'TAG' build
# argument to a specific Debian release, e.g. 'stretch' or 'buster'.
ARG  TAG=latest
FROM debian:${TAG}


# Configure the debconf frontend.
#
# This image doesn't include whiptail, dialog, nor the readline perl module.
# Therefore, the debconf frontend will be set to 'teletype' to avoid error
# messages about no dialog frontend could be found.
RUN echo 'debconf debconf/frontend select teletype' | debconf-set-selections


# Install the neccessary packages.
#
# In addition to the regular Debian base image, a BASIC set of packages from the
# Debian minimal configuration will be installed. After all packages have been
# installed, the apt caches and some log files will be removed to minimize the
# image.
#
# NOTE: An upgrade will be performed to include updates and security fixes of
#       installed packages that received updates in the Debian repository after
#       the upstream image has been created.
#
# NOTE: Instead of exim4, sSMTP will be used to deliver system mails to a local
#       mail relay instead of running an MTA in each container. Please file an
#       issue if you think this should be changed.
#
# NOTE: No syslog daemon will be installed, as systemd's journald should fit
#       most needs. Please file an issue if you think this should be changed.
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
        systemd        \
        systemd-sysv   \
        cron           \
        anacron        \
        ssmtp          \
        rsyslog-

RUN apt-get clean
RUN rm -rf                        \
    /var/lib/apt/lists/*          \
    /var/log/alternatives.log     \
    /var/log/apt/history.log      \
    /var/log/apt/term.log         \
    /var/log/dpkg.log


# Configure systemd.
#
# For running systemd inside a Docker container, some additional tweaks are
# required. For a detailed list see:
#
# https://developers.redhat.com/blog/2016/09/13/ \
#   running-systemd-in-a-non-privileged-container/
#
# The 'container' environment variable tells systemd that it's running iside a
# Docker container environment.
ENV container docker

# A different stop signal is required, so systemd will initate a shutdown when
# running 'docker stop <container>'.
STOPSIGNAL SIGRTMIN+3

# The host's cgroup filesystem need's to be mounted (read-only) in the
# container. '/run', '/run/lock' and '/tmp' need to be tmpfs filesystems when
# running the container without 'CAP_SYS_ADMIN'.
#
# NOTE: For running Debian stretch, 'CAP_SYS_ADMIN' still needs to be added, as
#       stretch's version of systemd is not recent enough. Buster will run just
#       fine without 'CAP_SYS_ADMIN'.
VOLUME [ "/sys/fs/cgroup", "/run", "/run/lock", "/tmp" ]

# To avoid ugly warnings when running this image on a host running systemd, the
# following units will be masked.
#
# NOTE: This will not remove ALL warnings in all Debian releases, but seems to
#       work for stretch.
RUN systemctl mask --   \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount

# The machine-id should be generated when creating the container. This will be
# done automatically if the file is not present, so let's delete it.
RUN rm -f           \
    /etc/machine-id \
    /var/lib/dbus/machine-id

# As this image should run systemd, the default command will be changed to start
# the init system. CMD will be preferred in favour of ENTRYPOINT, so one may
# override it when creating the container to e.g. run a bash console instead.
CMD [ "/sbin/init" ]


# Configure sSMTP.
#
# After installing sSMTP, the hostname of the current container (the one used to
# build the image) will be written into multiple configuration files. However,
# by removing the hosname from the configuration, sSMTP is forced to dynamically
# lookup the hostname when a new container is run from this image.
RUN rm -f /etc/mailname
RUN sed '/hostname/d' -i /etc/ssmtp/ssmtp.conf
