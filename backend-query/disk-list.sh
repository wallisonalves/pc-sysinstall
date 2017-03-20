#!/bin/sh
#-
# Copyright (c) 2010 iXsystems, Inc.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $FreeBSD: head/usr.sbin/pc-sysinstall/backend-query/disk-list.sh 233186 2012-03-19 16:13:14Z jpaetzel $

ARGS=$1
FLAGS_MD=""
FLAGS_CD=""
FLAGS_VERBOSE=""

shift
while [ -n "$1" ]
do
  case "$1" in
    -m)
      FLAGS_MD=1
      ;;
    -v)
      FLAGS_VERBOSE=1
      ;;
    -c)
      FLAGS_CD=1
      ;;
  esac
  shift
done

# Create our device listing
SYSDISK=$(sysctl -n kern.disks)
if [ -n "${FLAGS_MD}" ]
then
  MDS=`mdconfig -l`
  if [ -n "${MDS}" ]
  then
    SYSDISK="${SYSDISK} ${MDS}"
  fi
fi

# Add any RAID devices
if [ -d "/dev/raid" ] ; then
  cd /dev/raid
  for i in `ls`
  do
      SYSDISK="${SYSDISK} ${i}"
  done
fi

# Sort the disk list to a more sane output
SYSDISK="`echo $SYSDISK | tr ' ' '\n' | sed 's/\([^0-9]*\)/\1 /' | sort +0 -1 +1n | tr -d ' '`"

# Now loop through these devices, and list the disk drives
for i in ${SYSDISK}
do

  # Get the current device
  DEV="${i}"

  # Make sure we don't find any cd devices
  if [ -z "${FLAGS_CD}" ]
  then
    case "${DEV}" in
      acd[0-9]*|cd[0-9]*|scd[0-9]*) continue ;;
    esac
  fi

  # Try and find some identification information with camcontrol
  NEWLINE=$(camcontrol identify $DEV 2>/dev/null | sed -ne 's/^device model *//p')
  if [ -z "$NEWLINE" ]; then
     NEWLINE=" <Unknown Device>"
  fi

  # Check for garbage that we can't sort
  echo $NEWLINE | sort >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     NEWLINE="<Unknown Device>"
  fi

  if [ -n "${FLAGS_MD}" ] && echo "${DEV}" | grep -E '^md[0-9]+' >/dev/null 2>/dev/null
  then
	NEWLINE="Memory Disk"
  fi

  if echo "${DEV}" | grep -E '^nvd[0-9]+' >/dev/null 2>/dev/null
  then
	NEWLINE="NVMe Device"
  fi

  if [ -n "${FLAGS_VERBOSE}" ]
  then
	:
  fi

  # Save the disk list
  echo $DEV | grep -q "^da[0-9]"
  if [ $? -ne 0 ] ; then
    # Device other than USB
    if [ -n "$DLIST" ]; then
      DLIST="\n${DLIST}"
    fi
    DLIST="${DEV}:${NEWLINE}${DLIST}"
  else
    # USB Device, we list those last

    # First, lets make sure that this isn't install media
    glabel status | grep "${DEV}p3" | grep -q "TRUEOS_INSTALL"
    if [ $? -eq 0 ] ; then continue; fi

    if [ -n "$USBLIST" ]; then
      USBLIST="\n${USBLIST}"
    fi
    USBLIST="${DEV}:${NEWLINE}${USBLIST}"
  fi

done

# Echo out the found line
if [ -n "$DLIST" ] ; then
  echo -e "$DLIST" | sort
fi
if [ -n "$USBLIST" ] ; then
  echo -e "$USBLIST" | sort
fi
