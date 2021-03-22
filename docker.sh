#!/bin/bash

docker_compose_cms=
docker_compose_mariadb=
docker_compose_postgresql=
webname=

ingroup() {
  [[ " "`id -nG $2`" " == *" $1 "* ]]
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
    echo "   3) Install WinterCMS with PostgreSQL"
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

intro() {
  # source: https://github.com/wintercms/winter/blob/develop/modules/system/console/WinterInstall.php#L342-L351
  echo -e ".==========================================================================."
  echo -e "|                                                                          |"
  echo -e "| db   d8b   db d888888b d8b   db d888888b d88888b d8888b.       \033[1;34m...\033[0m       |"
  echo -e "| 88   I8I   88   \`88'   888o  88 \`~~88~~' 88'     88  \`8D  \033[1;34m... ..... ...\033[0m  |"
  echo -e "| 88   I8I   88    88    88V8o 88    88    88ooooo 88oobY'    \033[1;34m.. ... ..\033[0m    |"
  echo -e "| Y8   I8I   88    88    88 V8o88    88    88~~~~~ 88\`8b      \033[1;34m.. ... ..\033[0m    |"
  echo -e "| \`8b d8'8b d8'   .88.   88  V888    88    88.     88 \`88.  \033[1;34m... ..... ...\033[0m  |"
  echo -e "|  \`8b8' \`8d8'  Y888888P VP   V8P    YP    Y88888P 88   YD       \033[1;34m...\033[0m       |"
  echo -e "|                                                                          |"
  echo -e "\`============================ Container Setup ============================='"
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
  echo -e "\`================== INSTALLATION COMPLETE =================='"
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

  askinstalloption
  installoption=$?

  echo ""

  askwebname

  echo ""

  echo "Downloading docker-compose.yml..."
  # downloadDockerCompose

  echo "Running docker-compose pull"
  docker-compose pull

  echo "Running docker-compose up..."
  WEB_NAME=${webname} docker-compose up -d

  echo "Starting winter:install..."
  docker exec -ti -u www-data ${webname} bash -c "cd /var/www/html && php artisan winter:install && touch .installed"
  docker exec -ti -u www-data ${webname} bash -c "cd /var/www/html && php artisan winter:env && php artisan key:generate"
}

uninstall() {
  if yesnoask "This action is destructive and will wipe the containers and data. Continue?" N; then
    askwebname

    WEB_NAME=${webname} docker-compose down -v
    WEB_NAME=${webname} docker-compose rm -f
    docker volume prune -f
    docker image prune -a
    echo "Containers and volumes have been removed."
  fi
}

intro
"$@"
outro