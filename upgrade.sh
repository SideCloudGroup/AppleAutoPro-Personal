#!/bin/bash
# AppleAutoPro 一键升级脚本
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
UPGRADE_FILE="./data/upgrade.json"
repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"
LATEST_TAG=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

export COMPOSER_ALLOW_SUPERUSER=1
if [ ! -e "think" ]; then
    echo -e "${RED}请在网站根目录执行该脚本！${NC}"
    exit;
fi

if ! command -v unzip &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v jq &> /dev/null || ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}缺少必要的工具，正在安装……${NC}"
    if [ -f /etc/debian_version ]; then
        apt update && apt -y install unzip curl wget jq rsync
    elif [ -f /etc/redhat-release ]; then
        yum -y install unzip curl wget jq rsync
    else
       echo -e "${RED}无法检测到当前系统，已退出${NC}"
       exit;
    fi
fi

echo -e "${BLUE}如文件存在改动，一键更新后将会被替换至最新版本，改动将会消失，请注意备份${NC}"
echo -e "${BLUE}If there are changes in the file, it will be replaced with the latest version after one-click update, and the changes will disappear. Please backup.${NC}"
echo -e "${YELLOW}请按回车继续执行更新 | Press enter to continue...${NC}"
read
echo -e "${GREEN}正在升级到最新版本：$LATEST_TAG${NC}"
if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
    wget -T 20 -q "https://kkgithub.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
else
    wget -T 20 -q "https://github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
fi
if [ $? -ne 0 ]; then
    echo -e "${RED}wget失败或超时，退出程序${NC}"
    exit 1
fi
rm -rf "$filename"
unzip -q -o "$filename.zip"
if [ ! -d "$filename" ]; then
    echo -e "${RED}$filename 目录不存在，退出更新……${NC}"
    exit 1
fi
rm -rf ./app
rm -rf ./resources
cp ./public/favicon.ico "$filename/public"
rsync -aq --remove-source-files "$filename/" ./
rm -rf "$filename"
rm -rf "$filename.zip"
UPGRADE_DB=$(jq -r '.upgrade_db' "$UPGRADE_FILE")
php think migrate:run
php composer.phar upgrade --no-interaction
chmod -R 755 ./*
chown -R www:www ./*
UPGRADE_ENV=$(jq -r '.upgrade_env' "$UPGRADE_FILE")
if [ "$UPGRADE_ENV" == "true" ]; then
    echo -e "${GREEN}本次有环境变量更新，以下是更新信息：${NC}"
    echo "----------------------------------"
    jq -r '.env_updates' "$UPGRADE_FILE"
    echo "----------------------------------"
else
    echo -e "${GREEN}本次无环境变量更新${NC}"
fi
echo -e "${GREEN}升级完成！${NC}"