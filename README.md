# Brumalia

Brumalia was an ancient Roman winter solstice festival honoring Saturn/Cronus and Ceres/Demeter. During the Byzantine era, Brumalia celebrations would commence on November 24 and last for about a month, until the start of Saturnalia. [Wiki](https://en.wikipedia.org/wiki/Brumalia)

Today, Brumalia is a container package and installer for [WinterCMS](https://wintercms.com), designed to make installation/deployment of a WinterCMS website quick and easy.

## Requirements
* Docker and Docker Compose (installer will attempt to install these if missing)
* Curl (installer will attempt to install this if missing)
* Bourne Against Shell (bash)
* A load balancer or reverse proxy to funnel connections (Recommended)

## Usage

### Installation

To install a new environment, it's recommended you create a new subdirectory specifically for the environment as a .env file will be created with the configuration used to uninstall if needed.

* Download the shell script
```
curl https://raw.githubusercontent.com/Brumalia/Brumalia/master/docker.sh -o docker.sh
```
* Run it with the install argument
```
./docker.sh install
```

Additional Notes:
* You will be asked to edit the .env file during running
* References to URL should be localhost if you are using for dev, otherwise it should be the address serviced by your reverse proxy

### Uninstall

To uninstall, change to the directory used in the Installation step and run:
```
./docker.sh uninstall
```

## Dot Env Configuration

```
# These should not be changed once installation has occurred.

#################################
# Service Names
#################################
# MariaDB service name, this will be the hostname used by WinterCMS
# Default: winter_db
SERVICE_DB=winter_db
# Web service name
# Default: winter_web
SERVICE_WEB=winter_web

#################################
# Version Configuration
#################################
# Tag of the container to use for the database container, see https://hub.docker.com/r/brumalia/db for available tags
# Default: latest
DB_VERSION=latest
# Tag of the container to use for the web container, see https://hub.docker.com/r/brumalia/web for available tags
# Default: dev-develop
WEB_VERSION=dev-develop

#################################
# Database Server Configuration
#################################
# The port to connect to. Leave this as the default value unless you're connecting
#   to an external database server.
# Default: 3306
MYSQL_PORT=3306

# The non-root user WinterCMS will use to connect to the database.
# Default: brumalia
MYSQL_USER=brumalia

# The password WinterCMS will use to connect to the database.
# By default, the database is not exposed to the Internet at all and this is only
#   an internal password used by the service itself.
# Default: secret12345
MYSQL_PASSWORD=secret12345

# The name of the WinterCMS database.
# Default: brumalia
MYSQL_DATABASE=brumalia

# Automatically generate a random root password upon the first database spin-up.
#   This password will be visible in the mariadb container's logs.
# Default: yes
MYSQL_RANDOM_ROOT_PASSWORD=yes

# Log slower queries for the purpose of diagnosing issues. Only turn this on when
#   you need to, by uncommenting this and switching it to 1.
# To read the slow query log once enabled, run:
#   docker-compose exec mariadb slow_queries
# Default: 0
MYSQL_SLOW_QUERY_LOG=0

# Set the amount of allowed connections to the database. This value should be increased
# if you are seeing the `Too many connections` error in the logs.
# Default: 100
MYSQL_MAX_CONNECTIONS=100

#################################
# Web Server Configuration
#################################
# Set this to a path, or leave as "www" to create an internal, persistent Docker volume
# If doing dev work and you want direct access to files, change this to an absolute path to mount
# Default: www
WEB_VOLUME=www

# Port to have the web container be exposed on on the host
# Default: 80
HTTP_PORT=80
```