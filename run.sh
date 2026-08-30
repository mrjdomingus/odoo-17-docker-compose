#!/bin/bash
DESTINATION=$1
PORT=$2
CHAT=$3

# Clone Odoo directory
git clone --branch odoo19 --depth=1 https://github.com/mrjdomingus/odoo-17-docker-compose $DESTINATION
rm -rf $DESTINATION/.git

# Create PostgreSQL directory
mkdir -p $DESTINATION/postgresql

# Create Odoo data directory
mkdir -p $DESTINATION/odoo_data

# Check if the 7zip file with enterprise addons exists before extracting. If so, unzip it in folder enterprise_addons
if [ -f ../addons_enterprise_odoo_19.7z ]; then
    # Extract to a temp directory
    7z x ../addons_enterprise_odoo_19.7z -o./temp
    
    # Move contents to addons folder
    mkdir -p enterprise_addons
    mv temp/addons_enterprise_odoo_19/* enterprise_addons/

    # Change ownership of enterprise_addons to match the enclosing folder
    sudo chown --reference=. enterprise_addons
    
    # Clean up
    rm -rf temp
else
    echo "Warning: ../addons_enterprise_odoo_19.7z not found"
fi

# Change ownership to current user and set restrictive permissions for security
sudo chown -R $USER:$USER $DESTINATION
sudo chmod -R 700 $DESTINATION  # Only the user has access

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Running on macOS. Skipping inotify configuration."
else
  # System configuration
  if grep -qF "fs.inotify.max_user_watches" /etc/sysctl.conf; then
    echo $(grep -F "fs.inotify.max_user_watches" /etc/sysctl.conf)
  else
    echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
  fi
  sudo sysctl -p
fi

# Set ports in docker-compose.yml
# Update docker-compose configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS sed syntax
  sed -i '' 's/10017/'$PORT'/g' $DESTINATION/docker-compose.yml
  sed -i '' 's/20017/'$CHAT'/g' $DESTINATION/docker-compose.yml
else
  # Linux sed syntax
  sed -i 's/10017/'$PORT'/g' $DESTINATION/docker-compose.yml
  sed -i 's/20017/'$CHAT'/g' $DESTINATION/docker-compose.yml
fi

# Set file and directory permissions after installation
find $DESTINATION -type f -exec chmod 644 {} \;
find $DESTINATION -type d -exec chmod 755 {} \;

chmod +x $DESTINATION/entrypoint.sh

# Run Odoo
if ! is_present="$(type -p "docker-compose")" || [[ -z $is_present ]]; then
  docker compose -f $DESTINATION/docker-compose.yml up -d
else
  docker-compose -f $DESTINATION/docker-compose.yml up -d
fi

echo "Odoo started at http://localhost:$PORT | Master Password: mag1ster | Live chat port: $CHAT"
