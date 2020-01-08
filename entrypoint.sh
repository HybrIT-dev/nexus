#!/bin/bash
set -m

# start nexus
./opt/sonatype/nexus/bin/nexus run &

# run init script(s)
./opt/sonatype/nexus/setup/postStart.sh

fg %1