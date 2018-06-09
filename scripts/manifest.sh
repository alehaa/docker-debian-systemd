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

# Docker image manifest script.
#
# After building the images for all architectures, this script may be used to
# generate the related manifest for a multi arch image.
#
# NOTE: At the time of writing this script, the Docker client needs experimental
#       features enabled to gain support of the manifest tool.

# Read command line options.
#
# A set of default values is set, so calling this script without any options
# will create the manifest for the current Debian release by default with a set
# of supported architectures. However, the user has the ability to change some
# options depending on his needs.
#
# NOTE: Especially the image name should be changed, when this script is NOT run
#       by the writer of this script.
IMAGE_NAME='alehaa/debian-systemd'
IMAGE_TAG='stretch'
IMAGE_ARCHITECTURES=''
IMAGE_DUPLICATES=''

while getopts a:d:hn:t: OPT
do
    case $OPT in
        a) IMAGE_ARCHITECTURES="$IMAGE_ARCHITECTURES $OPTARG" ;;
        d) IMAGE_DUPLICATES="$IMAGE_DUPLICATES $OPTARG" ;;
        n) IMAGE_NAME=$OPTARG ;;
        t) IMAGE_TAG=$OPTARG  ;;

        h)
            echo "Usage: $0 [-a ARCH] [-h] [-n NAME] [-t TAG]"
            echo ""
            echo "  -a ARCH  Which architectures to include in the manifest"
            echo "  -d TAG   Duplicate the manifest (e.g. latest is stable)"
            echo "  -h       Give this help list"
            echo "  -n NAME  The image name to be built"
            echo "  -t TAG   The image tag to be built"
            echo ""

            exit 0
        ;;

        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
        ;;
    esac
done

[ -z "$IMAGE_ARCHITECTURES" ] && IMAGE_ARCHITECTURES='amd64 arm64'




# Generate the list of images to be used.
#
# The following variables store the name of the base image to be used for
# creating all manifests. In addition a list of all architecture images included
# in the resulting manifest will be generated.
IMAGE="$IMAGE_NAME:$IMAGE_TAG"

for ARCH in $IMAGE_ARCHITECTURES
do
    ARCH_IMAGES="$ARCH_IMAGES $IMAGE-$ARCH"
done




# Generate the manifests.
#
# For each tag a manifest will be generated, based on the architecture images.
# Multiple manifest tags may use the same image tag, e.g. to map the latest tag
# to the current Debian release.
for TAG in $IMAGE_TAG $IMAGE_DUPLICATES
do
    MANIFEST="$IMAGE_NAME:$TAG"

    # First, the manifest needs to be created. If a manifest with this name does
    # already exist, the amend flag ensures it'll be updated instead.
    eval docker manifest create --amend $MANIFEST $ARCH_IMAGES

    # Annotate the individual architecture images inside the manifest depending
    # on their configuration.
    for ARCH in $IMAGE_ARCHITECTURES
    do
        # NOTE: As there's no reliable way to get the Docker host's arch variant
        #       (for ARM), it'll be guessed and may not be 100% right. However,
        #       for the currently supported architectures these do match.
        ARCH_VARIANT=''
        case $ARCH in
            'arm')   ARCH_VARIANT='v7' ;;
            'arm64') ARCH_VARIANT='v8' ;;
        esac

        eval docker manifest annotate \
            $MANIFEST $IMAGE-$ARCH    \
            --os linux                \
            --arch $ARCH              \
            $([ -n "$ARCH_VARIANT" ] && echo "--variant $ARCH_VARIANT")
    done

    # Push the manifest to the docker hub and delete the local copy.
    docker manifest push --purge $MANIFEST

    echo ""
done
