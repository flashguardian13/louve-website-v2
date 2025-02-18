#!/bin/bash

# One argument required: an email address to use with CertBot for SSL certs.
if [ $# -lt 1 ]; then
  echo "An email argument is required."
  echo "Usage: $0 <email>"
  exit 1
fi

# Abort if we are given the placeholder email in the EC2 user data.
if [ "$1" = "your@email.here" ]; then
  echo "$0: Please replace the placeholder email in the user data with your own email."
  exit 1
fi

# Install Packages
# augeas-libs: for CertBot
# httpd: Apache, for serving files to the web
# python3: for CertBot via pip
echo "Installing packages ..."
dnf update -y
dnf install -y \
    augeas-libs \
    httpd \
    python3

# Run Apache and always run Apache
echo "Starting Apache ..."
systemctl start httpd
systemctl enable httpd

# Go to repository (checked out via user data script)
echo "Updating webserver repository ..."
cd ~/louve-website-v2
git remote update
git checkout main
git pull --ff-only

# Install webserver files
echo "Installing webserver files ..."
rsync -aq var/www/ /var/www

# Give apache group access to the webserver files
echo "Updating webserver file permissions ..."
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;

# Add ec2-user to apache group
echo "Adding ec2-user to apache group ..."
usermod -a -G apache ec2-user

# Install Certbot via pip for HTTPS
echo "Installing CertBot via pip ..."
dnf remove certbot
python3 -m venv /opt/certbot/
source /opt/certbot/bin/activate
pip install --upgrade pip
pip install \
    certbot \
    certbot-apache

# Install CertBot shim
echo "Installing CertBot shim ..."
cp scripts/certbot /usr/bin/

# Install SSL Certs and enable HTTPS for Apache using Certbot
echo "Enabling SSL via CertBot ..."
certbot run \
    --non-interactive \
    --keep \
    --email '$1' \
    --domains "rhiannonlouve.com,www.rhiannonlouve.com" \
    --agree-tos \
    --apache

# Set up automatic cert renewal
# https://unix.stackexchange.com/a/744641/245955
echo "Setting up automatic SSL cert renewal ..."
cp systemd/system/certbot.service /lib/systemd/system/
cp systemd/system/certbot.timer /lib/systemd/system/
chmod 644 /lib/systemd/system/certbot.*
systemctl enable --now certbot.timer

echo "Setup complete!"

