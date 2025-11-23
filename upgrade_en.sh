#!/bin/sh
# AppleAutoPro-Personal Upgrade Script
IFS=$'\n\t'
if [ -t 0 ]; then stty erase ^H; fi
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"

check_docker_permission() {
  current_user=$(whoami)
  if [ "$current_user" != "root" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo -e "${BLUE}Detected system: ${YELLOW}macOS${NC}"
      if ! docker info &>/dev/null; then
        echo -e "${RED}Unable to connect to Docker daemon${NC}"
        echo -e "${YELLOW}Please check if Docker Desktop is installed and if Docker Desktop service is running!${NC}"
        echo -e "${RED}If you are sure Docker Desktop is running, please try running this script with root(sudo)!${NC}"
        exit 1
      fi
    else
      echo -e "${BLUE}Detected system: ${YELLOW}Linux${NC}"
      if ! id -nG "$current_user" | grep -qw docker; then
        echo -e "${RED}Current user is not root and not in docker group, no permission to use docker${NC}"
        echo -e "${YELLOW}Solutions:${NC}"
        echo -e "1.${BLUE}Add current user to docker group and re-enter terminal${YELLOW}(sudo gpasswd -a username docker)${NC}"
        echo -e "2.${BLUE}Run this script directly with root(sudo)!${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${BLUE}Detected current user: ${YELLOW}root${NC}"
  fi
}
check_docker_permission
check_docker_compose() {
  if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}docker-compose.yml file not found${NC}"
    echo -e "${YELLOW}Please run this script from the program root directory!${NC}"
    exit 1
  fi
}
check_docker_compose
if ! command -v unzip &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}Missing necessary tools, installing...${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt -y install unzip curl wget jq rsync
    elif [ -f /etc/redhat-release ]; then
        yum -y install unzip curl wget jq rsync
    else
       echo -e "${RED}Unable to detect current system, exiting${NC}"
       exit;
    fi
fi
geo_check() {
    api_list=(
        "https://cloudflare.com/cdn-cgi/trace"
        "https://blog.cloudflare.com/cdn-cgi/trace"
        "https://dash.cloudflare.com/cdn-cgi/trace"
        "https://developers.cloudflare.com/cdn-cgi/trace"
    )
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    isCN="false"
    for url in "${api_list[@]}"; do
        text="$(curl -A "$ua" -m 10 -sSL "$url" 2>/dev/null)" || continue
        [ -z "$text" ] && continue
        location="$(echo "$text" | grep '^loc=' | cut -d'=' -f2)"
        if [ -n "$location" ]; then
            if [ "$location" = "CN" ]; then
                isCN="true"
            else
                isCN="false"
            fi
            break
        else
            if echo "$text" | grep -q 'loc=CN'; then
                isCN="true"
                break
            fi
        fi
    done
}
geo_check
LATEST_TAG=$(curl -m 10 -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$isCN" = "true" ]; then
    echo -e "${RED}Failed to get version number or timeout, please manually enter version number (e.g.: 4.0.0):${NC}"
    read manual_tag
    if [[ "$manual_tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        LATEST_TAG="$manual_tag"
    else
        echo -e "${RED}Version number format is incorrect, exiting script${NC}"
        exit 1
    fi
fi
echo -e "${BLUE}If there are changes in the file, it will be replaced with the latest version after one-click update, and the changes will disappear. Please backup.${NC}"
echo -e "${GREEN}Current latest version: $LATEST_TAG${NC}"
echo -e "${YELLOW}Press enter to continue...${NC}"
read
echo -e "${GREEN}Upgrading to latest version: $LATEST_TAG${NC}"
if [ "$isCN" = "true" ]; then
    wget -T 20 -q "https://ghfast.top/github.com/$repo/archive/refs/heads/v4.zip" -O "v4.zip"
    wget -T 20 -q "https://ghfast.top/github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
else
    wget -T 20 -q "https://github.com/$repo/archive/refs/heads/v4.zip" -O "v4.zip"
    wget -T 20 -q "https://github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
fi
if [ $? -ne 0 ]; then
    echo -e "${RED}wget failed or timeout, exiting program${NC}"
    exit 1
fi
unzip -q -o "v4.zip"
rsync -av --remove-source-files --exclude 'docker-compose.yml' --exclude 'Caddyfile' "$filename-4"/ ./
rm -rf "$filename-4"
rm -rf "v4.zip"
unzip -q -o "$filename.zip"
if [ ! -d "$filename" ]; then
    echo -e "${RED}$filename directory does not exist, exiting update...${NC}"
    exit 1
fi
rm -rf ./web/app
rsync -aq --remove-source-files "$filename/" ./web/
rm -rf "$filename"
rm -rf "$filename.zip"
docker compose pull
chmod +x ./data/entrypoint.sh
echo -e "${GREEN}Update completed, please check the update log, check if frontend configuration file needs changes.${NC}"
docker compose down
docker compose up -d
echo -e "${YELLOW}Do you want to clean old images? (y/n)${NC}"
read prune_choice
if [ "$prune_choice" = "y" ]; then
    docker image prune -f
    echo -e "${GREEN}Old images cleaned${NC}"
else
    echo -e "${YELLOW}Skipping old image cleanup${NC}"
fi
echo -e "${GREEN}Upgrade completed!${NC}"
exit 0

