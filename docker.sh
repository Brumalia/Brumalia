#!/bin/bash

env_url=https://raw.githubusercontent.com/Brumalia/Brumalia/master/.env.sample
docker_compose_cms=https://raw.githubusercontent.com/Brumalia/Brumalia/master/yaml/docker-compose.yml
docker_compose_mariadb=https://raw.githubusercontent.com/Brumalia/Brumalia/master/yaml/docker-compose.mysql.yml
webname=
dbname=

ingroup() {
  [[ " "`id -nG $2`" " == *" $1 "* ]]
}

downloadDockerCompose() {
  if [[ -f "docker-compose.yml" ]]; then
    echo -n "backing up existing docker-compose.yml... "
    mv docker-compose.yml docker-compose.yml.bak-`date +"%Y-%m-%d-%H%M"`
  fi
  curl -fsSL -H 'Cache-Control: no-cache' $1 -o docker-compose.yml
}

yesnoask() {
  local prompt default reply

  while true; do
    if [[ "${2:-}" == "Y" ]]; then
      prompt="Y/n"
      default="Y"
    elif [[ "${2:-}" == "N" ]]; then
      prompt="y/N"
      default="N"
    else
      prompt="y/n"
      default=""
    fi

    echo -n "$1 [$prompt] "
    read reply
    
    # No reply? Set default
    if [[ -z "$reply" ]]; then
      reply=${default}
    fi

    case "$reply" in
    Y* | y*) return 0 ;;
    N* | n*) return 1 ;;
    esac
  done
}

askinstalloption() {
  while true; do
    echo "Available container options:"
    echo "   1) Install just WinterCMS"
    echo "   2) Install WinterCMS with MariaDB"
    echo ""
    echo -n "Select install option: [1] "
    read reply

    if [[ -z "$reply" ]]; then
      reply="1"
    fi

    case "$reply" in
    1) return 1 ;;
    2) return 2 ;;
    3) return 3 ;;
    esac
  done
}

askwebname() {
  local wname

  while true; do
    echo -n "Name for web container? [winter_web] "
    read wname

    if [[ -z "$wname" ]]; then
      wname="winter_web"
    fi

    if [[ "$wname" =~ [^a-z0-9_\-] ]]; then
      echo "Invalid name specified, accepted characters (a-z 0-9 _-)."
    else
      webname=$wname
      return 0
    fi
  done
}

askdbname() {
  local wname

  while true; do
    echo -n "Name for database container? [winter_db] "
    read wname

    if [[ -z "$wname" ]]; then
      wname="winter_db"
    fi

    if [[ "$wname" =~ [^a-z0-9_\-] ]]; then
      echo "Invalid name specified, accepted characters (a-z 0-9 _-)."
    else
      dbname=$wname
      return 0
    fi
  done
}

intro() {
  echo -e ".======================================================================."
  echo -e "|                                                                      |"
  echo -e "| d8888b. d8888b. db    db .88b  d88.  .d8b.  db      d888888b  .d8b.  |"
  echo -e "| 88  \`8D 88  \`8D 88    88 88'YbdP\`88 d8' \`8b 88        \`88'   d8' \`8b |"
  echo -e "| 88oooY' 88oobYP 88    88 88  88  88 88ooo88 88         88    88ooo88 |"
  echo -e "| 88~~~b. 88\`8b   88    88 88  88  88 88~~~88 88         88    88~~~88 |"
  echo -e "| 88   8D 88 \`88. 88b  d88 88  88  88 88   88 88booo.   .88.   88   88 |"
  echo -e "| Y8888P' 88   YD ~Y8888P' YP  YP  YP YP   YP Y88888P Y888888P YP   \`Y |"
  echo -e "|                                                                      |"                                                                   
  echo -e "\`============================ Container Setup ========================='"
  echo -e ""
}

outro() {
  # sourced from https://www.asciiart.eu/holiday-and-events/christmas/snowmen && https://github.com/wintercms/winter/blob/develop/modules/system/console/WinterInstall.php#L358
  echo -e ".===========================================================."
  echo -e "| *    *           *.   *   .                      *     .  |"
  echo -e "|         .   .               __   *    .     * .     *     |"
  echo -e "|      *         *   . .    _|__|_        *    __   .       |"
  echo -e "|\033[1;32m  /\\ \033[0m      \033[1;32m/\\ \033[0m              ('')    *       _|__|_     .   |"
  echo -e "|\033[1;32m /  \\ \033[0m  * \033[1;32m/  \\ \033[0m  *     .  <( . )> *  .       ('')   *   *  |"
  echo -e "|\033[1;32m /  \\ \033[0m    \033[1;32m/  \\ \033[0m   .      _(__.__)_  _   ,--<(  . )>  .    .|"
  echo -e "|\033[1;32m/    \\ \033[0m  \033[1;32m/    \\ \033[0m     *   |       |  )),\`   (   .  )     *  |"
  echo -e "| \`\033[1;33m||\033[0m\` ..  \`\033[1;33m||\033[0m\`   . *... ==========='\`   ... '--\`-\` ... * jb|"
  echo -e "\`==========================================================='"
}

install() {
  echo ""
  echo "Checking pre-reqs:"
  echo -n "Checking for curl... "
  if [[ ! $(command -v curl) ]]; then
    echo "Not installed."
    echo "Please install curl through your package manager and then rerun this script."
    exit 1
  else
    echo "Installed."
  fi

  echo -n "Checking for docker... "
  if [[ $(command -v docker) && $(docker --version) ]]; then
    echo "Installed."
  else
    echo "Not installed."
    if yesnoask "Do you want to install Docker now?" Y; then
      curl -fsSL get.docker.com -o get-docker
      chmod +x get-docker.sh
      ./get-docker.sh
      rm get-docker.sh

      # Check if root, if not, add to docker 
      if [ "$(whoami)" != "root" ] && ! ingroup "docker" $(whoami); then
        echo "You are not the root user and you are not in a group with permission to use docker."
        echo "Should we add you to the docker group, so you can use docker commands? This is typically not recommended."
        echo "More information can be found at: https://docs.docker.com/engine/install/linux-postinstall/"
        if yesnoask "Add to docker group?" Y; then
          sudo usermod -aG docker "$(whoami)"
          echo "Added to docker group. Please restart your shell to apply the new group assignments,"
          echo "then restart the script."
          exit
        else
          echo "Please restart the script as root or a user in the docker group."
          exit 1
        fi
      fi
    else
      echo "Please install docker and then restart the script to continue."
      exit 1
    fi
    echo "Docker installation completed."
  fi

  echo -n "Checking for docker-compose... "
  if [[ $(command -v docker-compose) && $(docker-compose --version) ]]; then
    echo "Installed."
  else
    echo "Not installed."
    if yesnoask "Do you want to install docker-compose now?" Y; then
      local COMPOSE_VERSION=1.28.5

      if [ "$(whoami)" != "root" ]; then
        if [[ ! $(command -v sudo) ]]; then
          echo "Sudo does not appear to be installed. Please install and rerun this script."
          exit 1
        fi
      fi

      sudo sh -c "curl -fsSL https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compsoe-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose"
      sudo chmod +x /usr/local/bin/docker-compose

      if yesnoask "Do you want to install the docker-compose shell completion for bash shells?" N; then
        sudo sh -c "curl -fsSL https://raw.githubusercontent.com/docker/compose/${COMPOSE_VERSION}/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compse"
      fi

      echo "Installation of docker-compose completed."
    fi
  fi
  echo ""

  if [[ ! -f .env ]]; then
    echo -n "Getting default .env..."
    curl -fsSL $env_url -o .env
    echo "Done"
    if yesnoask "Do you want to edit the .env file? (RECOMMENDED)" Y; then
      echo "We will resume the installer when you exit the editor. Press enter to open .env in vi now."
      echo "If you'd like to use a different editor, CTRL+C, edit, then rerun the installer."
      read
      vi .env
    fi
  fi

  echo "Sourcing .env"
  source .env

  askinstalloption
  installoption=$?

  if [[ -z "$SERVICE_WEB" ]]; then
    echo ""
    askwebname
    echo 'SERVICE_WEB="$webname"' >> .env
  else
    echo "Setting web service name to: $SERVICE_DB"
    webname="$SERVICE_WEB"
  fi

  if [[ "$installoption" == "2" ]]; then
    if [[ -z "$SERVICE_DB" ]]; then
      echo ""
      askdbname
      echo 'SERVICE_DB="$dbname"' >> .env
    else
      echo "Setting db service name to: $SERVICE_DB"
      dbname="$SERVICE_DB"
    fi
  fi

  echo ""

  echo -n "Downloading docker-compose.yml..."
  if [[ "$installoption" == "1" ]]; then
    downloadDockerCompose $docker_compose_cms
  elif [[ "$installoption" == "2" ]]; then
    downloadDockerCompose $docker_compose_mariadb
  fi
  echo "Done"

  echo "Running docker-compose pull"
  docker-compose pull

  echo "Running docker-compose up..."
  docker-compose up -d

  echo "Starting winter:install..."
  docker exec -ti -u www-data ${SERVICE_WEB} bash -c "cd /var/www/html && php artisan winter:install && touch .installed"
  docker exec -ti -u www-data ${SERVICE_WEB} bash -c "cd /var/www/html && php artisan winter:env && php artisan key:generate"

  echo "Installation is complete! You should be able to open a web browser and access http://localhost:${HTTP_PORT}"

  echo ""

  if yesnoask "Do you want to disable debug mode?" Y; then
    docker exec -ti -u www-data ${SERVICE_WEB} bash -c "sed -i 's/APP_DEBUG=true/APP_DEBUG=false/g' /var/www/html/.env"
    docker exec -ti -u www-data ${SERVICE_WEB} bash -c "grep APP_DEBUG /var/www/html/.env"
    echo "Done"
  fi
}

uninstall() {
  if yesnoask "This action is destructive and will wipe the containers and data. Continue?" N; then
    docker-compose down -v
    docker-compose rm -f
    docker volume prune -f
    docker image prune -af
    echo "Containers and volumes have been removed."
  fi
}

intro
"$@"
outro