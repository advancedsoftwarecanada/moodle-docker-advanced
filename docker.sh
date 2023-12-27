#!/bin/bash

# Function to setup Moodle Docker
moodle_configure() {

    if [ -f local_config.txt ]; then
        rm local_config.txt
    fi

    #SETUP URL (It may be necessary to set the DEVICE you want to listen on, default is 127.0.0.1:8080)

    read -p "Enter System User (e.g., root, www, apache): " SYSTEM_USER
    read -p "Enter System Group (e.g., root, www, apache): " SYSTEM_GROUP

    read -p "Enter full https://example.com or https://www.example.com to access: " MOODLE_DOCKER_WEB_HOST
    read -p "Enter Docker Web Port (80->8080)(80->8081)(80->8082) That you will forward traffic to access this Moodle. For reverse proxy you can specify the network device (192.168.2.50:8081)" MOODLE_DOCKER_WEB_PORT
    read -p "Enter Proxy SSL? (Cloudflare? true): " MOODLE_CFG_SSLPROXY
    read -p "Enter Reverse Proxy Mode? (Typically false): " MOODLE_CFG_REVERSEPROXY

    read -p "Enter Moodle Docker DB User: " MOODLE_DB_USER
    read -sp "Enter Moodle Docker DB Password: " MOODLE_DB_PASS
    echo "" # Newline after password

    # Additional environment variables and settings
    read -p "Enter Moodle Docker DB (e.g., pgsql): " MOODLE_DOCKER_DB
    read -p "Enter Compose Project Name (e.g., moodle-mysite-com): " COMPOSE_PROJECT_NAME
    read -p "Enter Moodle Docker PHP Version (e.g., 8.1): " MOODLE_DOCKER_PHP_VERSION

    read -p "Enter Moodle Docker WWWROOT path: " MOODLE_DOCKER_WWWROOT
    read -p "Enter Moodle Docker MOODLEDATA path: " MOODLE_DOCKER_MOODLEDATA
    read -p "Enter Moodle Docker DB Volume path: " MOODLE_DOCKER_DB_VOLUME

    # Save settings to local_config.txt
    cat <<EOL > local_config.txt
SYSTEM_USER=${SYSTEM_USER}
SYSTEM_GROUP=${SYSTEM_GROUP}
MOODLE_DOCKER_WEB_HOST=${MOODLE_DOCKER_WEB_HOST}
MOODLE_DOCKER_WEB_PORT=${MOODLE_DOCKER_WEB_PORT}
MOODLE_CFG_SSLPROXY=${MOODLE_CFG_SSLPROXY}
MOODLE_CFG_REVERSEPROXY=${MOODLE_CFG_REVERSEPROXY}
MOODLE_DOCKER_DB=${MOODLE_DOCKER_DB}
COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME}
MOODLE_DOCKER_PHP_VERSION=${MOODLE_DOCKER_PHP_VERSION}
MOODLE_DOCKER_WWWROOT=${MOODLE_DOCKER_WWWROOT}
MOODLE_DOCKER_MOODLEDATA=${MOODLE_DOCKER_MOODLEDATA}
MOODLE_DOCKER_DB_VOLUME=${MOODLE_DOCKER_DB_VOLUME}
MOODLE_DB_USER=${MOODLE_DB_USER}
MOODLE_DB_PASS=${MOODLE_DB_PASS}
EOL

    echo "Configuration saved to local_config.txt"

    # Save settings to local.yaml
    cat <<EOL > local.yaml
version: "2"
services:
  webserver:
    image: moodlehq/moodle-php-apache:${MOODLE_DOCKER_PHP_VERSION}
    environment:
      MOODLE_DOCKER_DB: "${MOODLE_DOCKER_DB}"
      MOODLE_DOCKER_DB_TYPE: "${MOODLE_DOCKER_DB}"
      MOODLE_DOCKER_DB_HOST: "db"
      MOODLE_DOCKER_DB_NAME: "moodle"
      MOODLE_DOCKER_DB_USER: "${MOODLE_DB_USER}"
      MOODLE_DOCKER_DB_PASS: "${MOODLE_DB_PASS}"
      MOODLE_DOCKER_WWWROOT: "/var/www/html/moodle"
    volumes:
      - "${MOODLE_DOCKER_WWWROOT}:/var/www/html/moodle"
      - "${MOODLE_DOCKER_MOODLEDATA}:/var/www/moodledata"
    ports:
      - "0:80"  # Dynamic port assignment

  db:
    image: "postgres:13"
    environment:
      POSTGRES_DB: "moodle"
      POSTGRES_USER: "${MOODLE_DB_USER}"
      POSTGRES_PASSWORD: "${MOODLE_DB_PASS}"
    volumes:
      - "${MOODLE_DOCKER_DB_VOLUME}:/var/lib/postgresql/data"

  # Add other services as needed...
EOL

    load_settings
    cp config.docker-template.php $MOODLE_DOCKER_WWWROOT/config.php

    echo "Configuration saved to local.yaml"
    echo "You may now run './docker.sh --install' to install Moodle."
}


load_settings() {
    # Load settings from local_config.txt
    if [ -f local_config.txt ]; then
        source local_config.txt
    else
        echo "Error: local_config.txt not found. Please run './docker.sh --configure' first."
        exit 1
    fi

    # Export necessary environment variables
    export SYSTEM_USER
    export SYSTEM_GROUP
    export MOODLE_DOCKER_WEB_HOST
    export MOODLE_DOCKER_WEB_PORT
    export MOODLE_CFG_SSLPROXY
    export MOODLE_CFG_REVERSEPROXY
    export MOODLE_DOCKER_DB
    export COMPOSE_PROJECT_NAME
    export MOODLE_DOCKER_PHP_VERSION
    export MOODLE_DOCKER_WWWROOT
    export MOODLE_DOCKER_MOODLEDATA
    export MOODLE_DOCKER_DB_VOLUME
    export MOODLE_DB_USER
    export MOODLE_DB_PASS

    # Debug: Print loaded settings
    echo "Loaded Web Host: ${MOODLE_DOCKER_WEB_HOST}"
    echo "Loaded Web Port: ${MOODLE_DOCKER_WEB_PORT}"
    echo "Loaded SSL Proxy: ${MOODLE_CFG_SSLPROXY}"
    echo "Loaded Reverse Proxy: ${MOODLE_CFG_REVERSEPROXY}"
    echo "Loaded DB: ${MOODLE_DOCKER_DB}"
    echo "Loaded Compose Project Name: ${COMPOSE_PROJECT_NAME}"
    echo "Loaded PHP Version: ${MOODLE_DOCKER_PHP_VERSION}"
    echo "Loaded WWWROOT: ${MOODLE_DOCKER_WWWROOT}"
    echo "Loaded MOODLEDATA: ${MOODLE_DOCKER_MOODLEDATA}"
    echo "Loaded DB Volume: ${MOODLE_DOCKER_DB_VOLUME}"
    echo "Loaded DB User: ${MOODLE_DB_USER}"
    echo "Loaded DB Pass: ${MOODLE_DB_PASS}"

}

permissions(){

    # Load admin credentials
    load_settings

    # Tell user that this command should be run as root
    if [ "$EUID" -ne 0 ]; then
        echo "Please run this script as root."
        exit 1
    fi

    # Create folders if they don't exist
    mkdir -p ${MOODLE_DOCKER_MOODLEDATA}
    mkdir -p ${MOODLE_DOCKER_DB_VOLUME}

    # permissions
    chown -R andy:andy ${MOODLE_DOCKER_WWWROOT}
    chown -R andy:andy ${MOODLE_DOCKER_MOODLEDATA}
    chown -R andy:andy ${MOODLE_DOCKER_DB_VOLUME}

    chmod -R 777 ${MOODLE_DOCKER_WWWROOT}
    chmod -R 777 ${MOODLE_DOCKER_MOODLEDATA}
    chmod -R 777 ${MOODLE_DOCKER_DB_VOLUME}
}

start_docker() {
    echo "Starting Moodle Docker..."
    load_settings
    permissions

    bin/moodle-docker-compose up -d
}

install_moodle() {
    echo "Installing Moodle..."

    # Load admin credentials
    load_settings
    permissions

    # Debug: Print loaded admin credentials
    echo "Loaded Admin User: ${MOODLE_DB_USER}"
    echo "Loaded Admin Password: ${MOODLE_DB_PASS}"

    # Log in to the webserver container
    WEB_CONTAINER=$(docker ps --filter "name=${COMPOSE_PROJECT_NAME}-webserver" --format "{{.Names}}")

    # Run Moodle installation command with admin credentials
    docker exec -it "${WEB_CONTAINER}" bash -c "php admin/cli/install_database.php --agree-license --adminuser=${MOODLE_DB_USER} --adminpass=${MOODLE_DB_PASS}"

}

connect() {
    echo "Connecting to Docker Terminal..."

    # Load admin credentials
    load_settings

    # Log in to the webserver container
    WEB_CONTAINER=$(docker ps --filter "name=${COMPOSE_PROJECT_NAME}-webserver" --format "{{.Names}}")

    # Run Moodle installation command with admin credentials
    docker exec -it "${WEB_CONTAINER}" bash

}

stop_docker() {
    echo "Stopping Moodle Docker..."
    load_settings
    bin/moodle-docker-compose stop
}

destroy_docker() {
    echo "Destroying Moodle Docker..."
    load_settings
    bin/moodle-docker-compose down

    # Prompt to destroy or keep Moodle data
    read -p "Destroy Moodle database and cache folders? (y/n): " DESTROY_MOODLE_DATA

    if [ "${DESTROY_MOODLE_DATA}" == "y" ]; then
        echo "Destroying Moodle data..."

        rm -rf ../moodledata
        rm -rf ../moodledb
    else
        echo "Keeping Moodle data..."
    fi

}

if [ "$1" == "--configure" ]; then
    moodle_configure
elif [ "$1" == "--install" ]; then
    install_moodle
elif [ "$1" == "--connect" ]; then
    connect
elif [ "$1" == "--permissions" ]; then
    permissions
elif [ "$1" == "--start" ]; then
    start_docker
elif [ "$1" == "--stop" ]; then
    stop_docker
elif [ "$1" == "--destroy" ]; then
    destroy_docker
else
    echo "Usage:"
    echo "  ./docker.sh --configure  : Configure Moodle paths, database, and other settings"
    echo "  ./docker.sh --permissions: Set permissions for Moodle Docker *MUST BE RUN AS ROOT*"
    echo "  ./docker.sh --install    : Install Moodle in the Docker container"
    echo "  ./docker.sh --connect    : Connect to the Docker container terminal"
    echo "  ./docker.sh --start      : Start Moodle (includes Moodle installation)"
    echo "  ./docker.sh --stop       : Stop Moodle"
    echo "  ./docker.sh --destroy    : Destroy Moodle (DATABASE AND FILES WILL BE DESTROYED)"
fi

