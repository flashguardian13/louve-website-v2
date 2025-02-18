#!/bin/bash

# Install Packages
# git: fetching the webserver files
dnf update -y
dnf install -y git

# Check out repository
cd ~
git clone https://github.com/flashguardian13/louve-website-v2.git

# Run setup
~/louve-website-v2/scripts/setup.sh 'your@email.here'

