#!/bin/sh
# AppleAutoPro-Personal installation script
IFS=$'\n\t'
if [ -t 0 ]; then stty erase ^H; fi
# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"

# Install missing tools if necessary
if ! command -v unzip &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}Necessary tools missing, installing...${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt -y install unzip curl wget jq rsync
    elif [ -f /etc/redhat-release ]; then
        yum -y install unzip curl wget jq rsync
    else
        echo -e "${RED}Unable to detect current OS, exiting.${NC}"
        exit 1
    fi
fi

# Fetch latest release tag
LATEST_TAG=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Prompt for installation path
echo -e "${YELLOW}Enter installation path (default /opt/AppleAutoPro-Personal):${NC}"
read install_path
install_path=${install_path:-/opt/AppleAutoPro-Personal}

# Check if path exists
if [ -d "$install_path" ]; then
    echo -e "${RED}Directory $install_path already exists, exiting script.${NC}"
    exit 1
fi

mkdir -p "$install_path"
echo -e "${BLUE}Checking and installing required packages...${NC}"

# Ensure Docker is installed
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker is already installed.${NC}"
else
    echo -e "${YELLOW}Docker not found, installing...${NC}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl restart docker
    echo -e "${GREEN}Docker installation completed.${NC}"
fi

# Verify Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker installation failed, please check the errors.${NC}"
    exit 1
fi

cd "$install_path"

# Download code
wget -T 20 -q "https://github.com/$repo/archive/refs/heads/v4.zip" -O "v4.zip"
wget -T 20 -q "https://github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"

# Check download success
if [ $? -ne 0 ]; then
    echo -e "${RED}Download failed or timed out, exiting.${NC}"
    exit 1
fi

# Unpack and clean up
unzip -q -o "v4.zip"
rsync -av --remove-source-files "$filename-4"/ ./
rm -rf "$filename-4" "v4.zip"
unzip -q -o "$filename.zip"
if [ ! -d "$filename" ]; then
    echo -e "${RED}$filename directory not found, aborting update...${NC}"
    exit 1
fi
mv "$filename" web
rm -rf "$filename.zip"
mv .example.env .env

# Pull Docker images and set permissions
docker compose pull
chmod +x ./data/entrypoint.sh

echo -e "${GREEN}Download complete! Please continue with the next steps in the tutorial.${NC}"
exit 0
