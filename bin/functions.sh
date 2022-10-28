#!/bin/bash

## bash strict mode
set -euo pipefail
IFS=$'\n\t'

COLOR_RED=$(echo -en '\033[00;31m')
COLOR_GREEN=$(echo -en '\033[00;32m')
COLOR_ORANGE=$(echo -en '\033[00;33m')
COLOR_NONE=$(echo -en '\033[0m')

#######################################
# Arguments:
#   $1 - UPDATER_PROFILES_DIR
#######################################
function create_or_load_profile(){
  HOSTNAME=$(hostnamectl hostname)
  INSTALLER_PROFILE_PATH="${1}/${HOSTNAME}/.env"
  if [[ -f ${INSTALLER_PROFILE_PATH} ]]; then
    # shellcheck disable=SC1090
    source "${INSTALLER_PROFILE_PATH}"
    return
  fi
  if [[ -d "${1}" ]]; then
    while true; do
      echo 'Available profiles:'
      ls "${1}"
      echo
      echo -n 'Install from profile (empty string for new profile): '
      read -r requested_profile
      echo
      if [[ -z "${requested_profile}" ]]; then
        break
      fi
      INSTALLER_PROFILE_PATH="${1}/${requested_profile}/.env"
      if [[ -f ${INSTALLER_PROFILE_PATH} ]]; then
        # shellcheck disable=SC1090
        source "${INSTALLER_PROFILE_PATH}"
        sudo hostnamectl set-hostname "${requested_profile}"
        HOSTNAME=$(hostnamectl hostname)
        break
      fi
    done
  fi

  echo -n 'Create a new profile: '
  read -r requested_profile
  echo
  sudo hostnamectl set-hostname "${requested_profile}"
  HOSTNAME=$(hostnamectl hostname)
  mkdir -p "${1}/${HOSTNAME}"
  INSTALLER_PROFILE_PATH="${1}/${HOSTNAME}/.env"
  touch "${INSTALLER_PROFILE_PATH}"
}

function stop_asking_for_sudo_password(){
  WHOAMI=$(whoami)
  if ! sudo grep -q "${WHOAMI}" /etc/sudoers; then
    echo "" | sudo tee -a /etc/sudoers > /dev/null
    echo "${WHOAMI} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
  fi
}

function reconfigure_zypper_repositories(){
  echo_current_step "Removing all repositories"
  sudo zypper rr --all

  echo_current_step "Adding fresh repositories"
  sudo zypper --gpg-auto-import-keys --quiet addrepo \
    --check --refresh --priority 90 \
    "http://download.opensuse.org/tumbleweed/repo/oss/" \
    "oss" > /dev/null
  sudo zypper --gpg-auto-import-keys --quiet addrepo \
    --check --refresh --priority 90 \
    "http://download.opensuse.org/tumbleweed/repo/non-oss/" \
    "non-oss" > /dev/null
  sudo zypper --gpg-auto-import-keys --quiet addrepo \
    --check --refresh --priority 90 \
    "http://download.opensuse.org/update/tumbleweed/" \
    "updates" > /dev/null
  sudo zypper --gpg-auto-import-keys --quiet addrepo \
    --check --refresh --priority 50 \
    "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/" \
    "packman" > /dev/null

  if [[ "${SUBLIME_TEXT}" == true || "${SUBLIME_MERGE}" == true ]]; then
    sudo rpm -v --import \
    https://download.sublimetext.com/sublimehq-rpm-pub.gpg
    sudo zypper --quiet addrepo -g \
    https://download.sublimetext.com/rpm/stable/x86_64/ \
    "sublimetext.com" > /dev/null
  fi

  if [[ "${SIGNAL}" == true ]]; then
    sudo zypper --quiet addrepo https://download.opensuse.org/repositories/network:/im:/signal/openSUSE_Tumbleweed/ \
    "obs_signal" > /dev/null
  fi

  sudo zypper --quiet addrepo https://cli.github.com/packages/rpm/gh-cli.repo \
      > /dev/null

  if [[ "${NVIDIA_OPTIMUS}" = true ]]; then
    sudo zypper --quiet addrepo https://download.nvidia.com/opensuse/tumbleweed \
        "nvidia.com" > /dev/null
  fi

  if [[ "${CHROME}" = true ]]; then
    sudo rpm -v --import \
    https://dl.google.com/linux/linux_signing_key.pub
    sudo zypper --quiet addrepo -g \
    http://dl.google.com/linux/chrome/rpm/stable/x86_64 \
    "google.com/chrome" > /dev/null
  fi
}

#######################################
# Arguments:
#   $1 - Question
#   $2 - Default answer (optional)
#######################################
function confirm_action(){
  echo
  while true; do
    if [[ "$#" -ge 2 ]]; then
      if [[ "$2" == 'Y' || "$2" == 'y' ]]; then
        question="$1 [Y/n]: "
      elif [[ "$2" == 'N' || "$2" == 'n' ]]; then
        question="$1 [y/N]: "
      else
        question="$1 [y/n]: "
      fi
    else
      question="$1 [y/n]: "
    fi
    echo -n "${question}"
    read -r answer
    if [[ "$#" -ge 2 && -n "$2" ]]; then
      answer=${answer:-"$2"}
    fi
    if [[ ${answer} = "Y" || ${answer} = "y" ]]; then
      return 0
      break
    elif [[ ${answer} = "n" ]]; then
      return 1
      break
    else
      echo "Invalid answer. Please, try again."
    fi
  done
}

function offer_reboot_if_required(){
  if ! sudo zypper --quiet needs-rebooting; then
    echo "It is highly recommended to reboot your PC and run this updater again."
    # shellcheck disable=SC2310
    if confirm_action "Reboot now?"; then
      sudo reboot
    fi
  fi
}

#######################################
# Arguments:
#   $1 - owner/repository on GitHub
#######################################
function github_latest_release_api_endpoint() {
  echo "https://api.github.com/repos/${1}/releases/latest"
}

#######################################
# Arguments:
#   $1 - UPDATER_CACHE_DIR
#   $2 - owner/repository on GitHub
#   $3 - json path to correct release file
#   $4 - stop_if_not_new = skip install if remote file is not newer
#######################################
function get_latest_release_from_github() {
  endpoint=$(set -e; github_latest_release_api_endpoint "${2}")
  if ! wget --quiet -O /tmp/latest_release_info "${endpoint}"; then
    echo ''
    return
  fi

  json=$(jq "${3}" --raw-output < /tmp/latest_release_info)

  dl_url=$(echo "${json}" | jq ".browser_download_url" --raw-output)
  file_name=$(echo "${json}" | jq ".name" --raw-output)
  version=$(echo "${dl_url}" | grep -Eo '(download/v).*(/)' | awk -F "/" '{ print $2 }')
  if [[ -z "${version}" ]]; then
    version=$(echo "${json}" | jq ".updated_at" --raw-output)
  fi
  local_file="${1}/${version}_${file_name}"

  if [[ ! -f "${local_file}" ]]; then
    wget --quiet --show-progress -O "${local_file}" "${dl_url}"
    echo "${local_file}"
  else
    if [[ "$#" -ge 4 ]] && [[ "${4}" != "stop_if_not_new" ]]; then
      echo "${local_file}"
    else
      echo "${local_file}"
    fi
  fi
}

#######################################
# Arguments:
#   $1 - UPDATER_CACHE_DIR
#######################################
function wget_or_get_from_cache() {
  local_file="${1}/$(basename "${1}")"
  if [[ ! -f "${local_file}" ]]; then
    wget --quiet --show-progress -O "${local_file}" "${1}"
  fi
  echo "${local_file}"
}

#######################################
# Arguments:
#   $1 - message to print out
#######################################
function echo_current_step(){
  echo "${COLOR_GREEN}########## ${1} ##########${COLOR_NONE}"
}

#######################################
# Arguments:
#   $1 - message to print out
#######################################
function echo_warning(){
  echo "${COLOR_ORANGE}########## ${1} ##########${COLOR_NONE}"
}

#######################################
# Arguments:
#   $1 - message to print out
#######################################
function echo_error(){
  echo "${COLOR_RED}### ${1} ###${COLOR_NONE}"
}

#######################################
# clone this clean installation first, so an autoinst.xml file
#  becomes available for this machine
#
# this file can be kept in VCS and later used for automatic install
#  of this machine
#
# Arguments:
#   $1 - UPDATER_LOG_DIR
#######################################
function clone_system(){
    whoami=$(whoami)
    datetime=$(date '+%Y-%m-%d_%H:%M:%S')
    local autoinstfile="${1}/${datetime}-clean.install.xml" 
    sudo zypper install --no-confirm autoyast2
    sudo yast2 clone_system
    sudo mv /root/autoinst.xml "${autoinstfile}" 
    sudo chown "${whoami}:${whoami}" "${autoinstfile}"
    sudo chmod 644 "${autoinstfile}"
}

function get_base_packages_list(){
  local -a install
  install=(
    7zip \
    ImageMagick \
    MozillaFirefox \
    NetworkManager-openvpn \
    ShellCheck \
    arandr \
    bat \
    bc \
    breeze \
    bzip2 \
    calc \
    compsize \
    deadbeef \
    dex \
    diff-so-fancy \
    ecryptfs-utils \
    fd \
    feh \
    firewalld \
    fontawesome-fonts \
    fzf \
    fzf-zsh-completion \
    gcolor3 \
    gimp \
    git \
    git-delta \
    gnome-keyring \
    google-opensans-fonts \
    gparted \
    i3-gaps \
    i3blocks \
    i3lock \
    i3status \
    ifuse \
    iosevka-ss11-fonts \
    jpegoptim \
    jq \
    keychain \
    kitty \
    libQt5QuickControls2-5 \
    libnotify-tools \
    libqt5-qtquickcontrols2 \
    lnav \
    lua54 \
    meld \
    mpd \
    mpv \
    ncmpcpp \
    neovim \
    nmap \
    nodejs-default \
    npm \
    openscad \
    optipng \
    pavucontrol \
    perl-AnyEvent-I3 \
    picom \
    pinentry-gnome3 \
    playerctl \
    polybar \
    pulseaudio \
    pv \
    python3-pip \
    qutebrowser \
    redshift \
    ripgrep \
    rofi \
    scout-command-not-found \
    sshfs \
    stress-ng \
    tigervnc \
    ubuntu-fonts \
    unzip \
    x11vnc \
    xdotool \
    xev \
    xfce4-screenshooter \
    xinit \
    xinput \
    xkill \
    xorg-x11-server \
    xprop \
    zsh \
  )
  echo "${install[@]}"
}

function get_preset_packages_list(){
  local -a install

  install=$(set -e; get_base_packages_list)

  if [[ "${LIBREOFFICE}" == true ]]; then
    install+=(libreoffice-calc libreoffice-writer)
  fi

  if [[ "${NVIDIA_OPTIMUS}" == true ]]; then
    install+=(x11-video-nvidiaG06 nvidia-glG06 suse-prime)
  fi

  if [[ "${SOLAAR}" == true ]]; then
    install+=(solaar)
  fi

  if [[ "${LOCALWEBDEV}" == true ]]; then
    install+=(apache2 php8 php8-cli mariadb apache2-mod_php8 php8-mysql \
      php8-calendar php8-mbstring php8-xdebug php8-gd php8-pcntl \
      php-composer2)
  fi

  if [[ "${TLP}" == true ]]; then
    install+=(tlp)
  fi

  if [[ "${CHROME}" == true ]]; then
    install+=(google-chrome-stable)
  fi

  if [[ "${KERNEL_DEVEL}" == true ]]; then
    install+=(kernel-devel)
  fi

  if [[ "${DOCKER}" == true ]]; then
    install+=(docker)
  fi

  if [[ "${LIBRESPOT}" == true ]]; then
    install+=(rustup alsa-devel)
  fi

  if [[ "${SUBLIME_TEXT}" == true ]]; then
    install+=(sublime-text)
  fi

  if [[ "${SUBLIME_MERGE}" == true ]]; then
    install+=(sublime-merge)
  fi

  if [[ "${SIGNAL}" == true ]]; then
    install+=(signal-desktop)
  fi

  if [[ "${INSTALL_VIRTUALBOX}" == true ]]; then
    install+=(virtualbox virtualbox-host-source kernel-devel kernel-default-devel)
  fi

  install+=(gh)

  if [[ "${AIRPODS_PRO}" == true ]]; then
    install+=(pulseaudio-module-bluetooth bluez bluez-utils)
  fi

  # install dolphin?
  install+=(dolphin qt5ct adwaita-qt5)
  # TODO add this line to /etc/environment:
  # QT_QPA_PLATFORMTHEME=qt5ct

  echo "${install[@]}"
}

function get_stubborn_git_files(){
  local -a files
  files=( \
    ~/.config/deadbeef/config \
    ~/.config/OpenSCAD/OpenSCAD.conf \
    ~/.config/gtk-2.0/gtkfilechooser.ini \
    ~/.config/mc/ini \
    ~/.config/digikamrc \
    ~/.config/htop/htoprc \
    ~/.config/qt5ct/qt5ct.conf \
  )
  echo "${files[@]}"
}

#######################################
# Arguments:
#   $1 - UPDATER_CACHE_DIR
#######################################
function install_jetbrains_fonts(){
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'JetBrains/JetBrainsMono' '.assets[0]')
  if [[ -z "${local_file}" ]]; then
    echo_error 'cannot get latest release info from github'
  else
    rm -rf ~/.local/share/fonts/JetBrains/
    mkdir -p ~/.local/share/fonts/JetBrains/
    cd ~/.local/share/fonts/JetBrains/
    unzip -q "${local_file}"
  fi
}

#######################################
# TODO TEST THIS
#
# Arguments:
#   $1 - UPDATER_CACHE_DIR
#######################################
function install_phpstorm(){
  if [[ ! -d ~/data/software/PhpStorm/ ]]; then
    echo "${HOME}/data/software/PhpStorm/ already exists"
    echo "remove it, or specify another install location"
    exit 1
  fi
  php_storm_url='https://download.jetbrains.com/webide/PhpStorm-2022.1.2.tar.gz'
  mkdir -p ~/data/software/PhpStorm
  cd ~/data/software/PhpStorm
  local_file=$(set -e; wget_or_get_from_cache "${1}" "${php_storm_url}")
  tar -xzf "${local_file}" -C ~/data/software/PhpStorm
  {
    echo 'fs.inotify.max_user_watches = 524288'
    echo
  } | sudo tee /usr/lib/sysctl.d/60-jetbrains.conf > /dev/null 2>&1
}

function install_spotify(){
  spotify_file_location=~/.local/bin/spotify-easyrpm
  github_url_base='https://raw.githubusercontent.com'
  if [[ ! -f "${spotify_file_location}" ]]; then
    wget --quiet --show-progress -O "${spotify_file_location}" \
      "${github_url_base}/megamaced/spotify-easyrpm/master/spotify-easyrpm"
    chmod +x "${spotify_file_location}"
  fi
  if ! command -v spotify > /dev/null; then
    "${spotify_file_location}"
  fi
}

function install_lazygit(){
  whoami=$(whoami)
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github \
    "${1}" \
    'jesseduffield/lazygit' \
    '.assets[] | select(.name | contains("Linux_x86_64"))' \
    'stop_if_not_new')
  if [[ -n "${local_file}" ]]; then
    rm -rf /tmp/lazygit/
    mkdir -p /tmp/lazygit/
    tar xzf "${local_file}" -C /tmp/lazygit/
    source_file=/tmp/lazygit/lazygit
    target_file="/home/${whoami}/.local/bin/lazygit"
    if ! cmp --silent "${source_file}" "${target_file}"; then
      if cp "${source_file}" "${target_file}"; then
        chmod +x "${target_file}"
      else
        echo_error 'lazygit is in use. cannot update now.'
      fi
    fi
    rm -rf /tmp/lazygit/
  fi
}

function install_phpstan(){
  whoami=$(whoami)
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'phpstan/phpstan' \
    '.assets[] | select (.name == "phpstan.phar")' \
    'stop_if_not_new')
  if [[ -n "${local_file}" ]]; then
    target_file="/home/${whoami}/.local/bin/phpstan"
    if ! cmp --silent "${local_file}" "${target_file}"; then
      if cp "${local_file}" "${target_file}"; then
        chmod +x "${target_file}"
      else
        echo_error 'phpstan is in use. cannot update now.'
      fi
    fi
  fi
}

function install_php_cs_fixer(){
  whoami=$(whoami)
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'FriendsOfPHP/PHP-CS-Fixer' \
    '.assets[] | select (.name == "php-cs-fixer.phar")' \
    'stop_if_not_new')
  if [[ -n "${local_file}" ]]; then
    target_file="/home/${whoami}/.local/bin/php-cs-fixer"
    if ! cmp --silent "${local_file}" "${target_file}"; then
      if cp "${local_file}" "${target_file}"; then
        chmod +x "${target_file}"
      else
        echo_error 'php-cs-fixer is in use. cannot update now.'
      fi
    fi
  fi
}

function install_dart_sass(){
  whoami=$(whoami)
  sass_target="/home/${whoami}/.local/bin/sass"
  if [[ -f "${sass_target}" ]]; then
    update_rule='stop_if_not_new'
  else
    update_rule='force_install'
  fi
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'sass/dart-sass' \
    '.assets[] | select(.name | contains("linux-x64.tar.gz"))' \
    "${update_rule}")
  if [[ -n "${local_file}" ]]; then
    rm -rf /tmp/sass/
    mkdir -p /tmp/sass/
    tar xzf "${local_file}" -C /tmp/sass/
    cp /tmp/sass/dart-sass/sass "${sass_target}"
    chmod +x "${sass_target}"
    rm -rf /tmp/sass/
  fi
}

function install_docker_compose(){
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'docker/compose' \
    '.assets[] | select(.name | contains("sha256") | not) | select(.name | contains("docker-compose-linux-x86_64"))' \
    'stop_if_not_new'
  )
  if [[ -n "${local_file}" ]]; then
    target_file="/home/${WHOAMI}/.local/bin/docker-compose"
    if ! cmp --silent "${local_file}" "${target_file}"; then
      if cp "${local_file}" "${target_file}"; then
        chmod +x "${target_file}"
      else
        echo_error 'docker-compose is in use. Cannot update.'
      fi
    fi
  fi
}

function install_lazydocker(){
  whoami=$(whoami)
  # shellcheck disable=SC2311
  local_file=$(get_latest_release_from_github "${1}" \
    'jesseduffield/lazydocker' \
    '.assets[] | select(.name | contains("Linux_x86_64"))' \
    'stop_if_not_new'
  )
  if [[ -n "${local_file}" ]]; then
    rm -rf /tmp/lazydocker/
    mkdir -p /tmp/lazydocker/
    tar xzf "${local_file}" -C /tmp/lazydocker/
    source_file=/tmp/lazydocker/lazydocker
    target_file="/home/${whoami}/.local/bin/lazydocker"
    if ! cmp --silent "${source_file}" "${target_file}"; then
      if cp "${source_file}" "${target_file}"; then
        chmod +x "${target_file}"
      else
        echo_error 'lazydocker is in use. cannot update now.'
      fi
    fi
    rm -rf /tmp/lazydocker/
  fi
}

function install_librespot(){
  if [[ ! -d ~/data/repos/librespot/ ]]; then
    mkdir -p ~/data/repos/
    cd ~/data/repos/
    git clone https://github.com/librespot-org/librespot
  fi
  if [[ "${1}" == 'full' ]]; then
    rustup --quiet install stable > /dev/null
    rustup --quiet default stable > /dev/null
  fi
  rustup --quiet update > /dev/null
  cd ~/data/repos/librespot/
  git pull --quiet
  availableRam=$(awk '/MemAvailable/ { printf "%d", $2/1024; } ' /proc/meminfo)
  if [[ "${availableRam}" -ge 4096 ]]; then
    jobs=4
  else
    jobs=1
  fi
  cargo build \
    --no-default-features \
    --features 'alsa-backend' \
    --release \
    -j "${jobs}"
  cp \
    ~/data/repos/librespot/target/release/librespot \
    ~/.local/bin/librespot
  chmod +x ~/.local/bin/librespot
}

function list_installed_packages(){
  zypper search --installed-only
}

function set_default_values(){
  set +u
  if [[ -z "${INSTALL_SASS}" ]]; then INSTALL_SASS=false; fi
  if [[ -z "${DOCKER}" ]]; then DOCKER=false; fi
  if [[ -z "${LIBRESPOT}" ]]; then LIBRESPOT=false; fi
  if [[ -z "${TIMEZONE}" ]]; then TIMEZONE='UTC'; fi
  if [[ -z "${STOP_ASKING_FOR_SUDO_PASSWORD}" ]]; then
    STOP_ASKING_FOR_SUDO_PASSWORD=false
  fi
  if [[ -z "${LIBREOFFICE}" ]]; then LIBREOFFICE=false; fi
  if [[ -z "${NVIDIA_OPTIMUS}" ]]; then NVIDIA_OPTIMUS=false; fi
  if [[ -z "${SOLAAR}" ]]; then SOLAAR=false; fi
  if [[ -z "${LOCALWEBDEV}" ]]; then LOCALWEBDEV=false; fi
  if [[ -z "${TLP}" ]]; then TLP=false; fi
  if [[ -z "${CHROME}" ]]; then CHROME=false; fi
  if [[ -z "${SUBLIME_TEXT}" ]]; then SUBLIME_TEXT=false; fi
  if [[ -z "${SUBLIME_MERGE}" ]]; then SUBLIME_MERGE=false; fi
  if [[ -z "${SIGNAL}" ]]; then SIGNAL=false; fi
  if [[ -z "${INSTALL_VIRTUALBOX}" ]]; then INSTALL_VIRTUALBOX=false; fi
  if [[ -z "${AIRPODS_PRO}" ]]; then AIRPODS_PRO=false; fi
  if [[ -z "${VAR_LOG_IN_TMPFS}" ]]; then VAR_LOG_IN_TMPFS=false; fi
  if [[ -z "${PHP_STORM}" ]]; then PHP_STORM=false; fi
  if [[ -z "${SPOTIFY}" ]]; then SPOTIFY=false; fi
  if [[ -z "${KERNEL_DEVEL}" ]]; then KERNEL_DEVEL=false; fi
  if [[ -z "${TMP_SIZE}" ]]; then TMP_SIZE='4G'; fi
  set -u
}

