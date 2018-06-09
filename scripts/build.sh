#!/bin/sh -e

# This file is part of docker-debian-systemd.
#
# Copyright (c)
#   2018 Alexander Haase <ahaase@alexhaase.de>
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

# Docker image build script.
#
# This script should help to create the systemd enabled Debian images. It builds
# a new image for a specific tag (the current stable release by default) and
# pushes the new image to Docker hub. Later, all images may be bundled as multi
# arch image with the manifest script.
#
# NOTE: At the time of writing this script, the Docker daemon needs experimental
#       features enabled to gain support of squash image building.

# Get the OS type. As Debian runs at Linux only, the OS type should match linux
# or an error message will be printed and the script exits.
DOCKER_OS=$(docker info --format '{{.OSType}}')
if [ "$DOCKER_OS" != 'linux' ]
then
    echo 'OS type not supported: requires Linux.' >&2
    exit 1
fi

# Get the OS architecture.
case $(docker info --format '{{.Architecture}}') in
    'x86')     DOCKER_ARCH='i386'  ;;
    'x86_64')  DOCKER_ARCH='amd64' ;;
    'armhf')   DOCKER_ARCH='arm'   ;;
    'aarch64') DOCKER_ARCH='arm64' ;;

    # If the architectures above didn't match, the OS arch is unknown and/or not
    # supported, so an error message will be printed and the script exits.
    *)
        echo 'OS architecture is not supported.' >&2
        exit 1
esac




# Read command line options.
#
# A set of default values is set, so calling this script without any options
# will build the current Debian release by default. However, the user has the
# ability to change some options depending on his needs.
#
# NOTE: Especially the image name should be changed, when this script is NOT run
#       by the writer of this script.
IMAGE_NAME='alehaa/debian-systemd'
IMAGE_TAG='stretch'
IMAGE_PUSH=1

while getopts hln:t: OPT
do
    case $OPT in
        l) IMAGE_PUSH=0       ;;
        n) IMAGE_NAME=$OPTARG ;;
        t) IMAGE_TAG=$OPTARG  ;;

        h)
            echo "Usage: $0 [-h] [-l] [-n NAME] [-t TAG]"
            echo ""
            echo "  -h        Give this help list"
            echo "  -l        Just build the image, don't push to the registry"
            echo "  -n NAME   The image name to be built"
            echo "  -t TAG    The image tag to be built"
            echo ""

            exit 0
        ;;

        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
        ;;
    esac
done




# Build the image.
#
# NOTE: The architecture will be added to the tag, so these may be used for
#       generating the manifest in a later step. Otherwise the different
#       architectures would overwrite itself, as they'd share a common tag.
IMAGE="$IMAGE_NAME:$IMAGE_TAG-$DOCKER_ARCH"

docker build                       \
    -t $IMAGE                      \
    --squash                       \
    --build-arg RELEASE=$IMAGE_TAG \
    .


# If not disabled, upload the image to the docker registry.
#
# NOTE: Uploading the image is required for creating the manifest. Otherwise the
#       image can be used local only.
if [ $IMAGE_PUSH == 1 ]
then
    docker push $IMAGE
fi
