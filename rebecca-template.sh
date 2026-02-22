#!/bin/bash

REBECCA_DIR="/opt/rebecca"
ENV_FILE="$REBECCA_DIR/.env"
TEMPLATE_DIR="/var/lib/rebecca/templates/subscription"
GITHUB_API_URL="https://api.github.com/repos/im-JvD/Rebecca-Template/contents/Templates"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run this script as root.${NC}"
  exit 1
fi

show_exit_msg() {
    echo ""
    echo ""
    echo -e "${WHITE}==================================================================${NC}"
    echo -e "${GREEN}Good luck...${NC} To Open this Menu again, just Type : ${MAGENTA}rebecca-template${NC}"
    echo -e "${WHITE}==================================================================${NC}"
    echo ""
}
trap show_exit_msg EXIT


draw_header() {
    clear
    echo ""
    echo -e "    ${CYAN}https://github.com/im-JvD/Rebecca-Template${NC}"
    echo ""
    echo -e "${WHITE}===================================================${NC}"
    echo -e "  Install ${MAGENTA}Subscription Template${NC} for ${GREEN}Rebecca${NC} ${WHITE}Panel${NC}"
    echo -e "${WHITE}===================================================${NC}"
    echo ""
    echo ""
}

apply_settings() {
    sed -i '/^CUSTOM_TEMPLATES_DIRECTORY=/d' "$ENV_FILE"
    sed -i '/^SUBSCRIPTION_PAGE_TEMPLATE=/d' "$ENV_FILE"
    
    echo "CUSTOM_TEMPLATES_DIRECTORY=\"/var/lib/rebecca/templates/\"" >> "$ENV_FILE"
    echo "SUBSCRIPTION_PAGE_TEMPLATE=\"subscription/index.html\"" >> "$ENV_FILE"
    
    echo -e "${GREEN}[+] Template paths configured in .env file.${NC}"
}

remove_settings() {
    sed -i '/^CUSTOM_TEMPLATES_DIRECTORY=/d' "$ENV_FILE"
    sed -i '/^SUBSCRIPTION_PAGE_TEMPLATE=/d' "$ENV_FILE"
    echo -e "${GREEN}[+] Template paths removed from .env file.${NC}"
}

show_menu() {
    clear
	  draw_header
    echo -e "      1.${NC} ${GREEN}Install${NC} new Template"
    echo -e "      2.${NC} ${YELLOW}Change${NC} Template"
    echo -e "      3.${NC} ${RED}Delete${NC} Template"
    echo ""
    echo -e "    4. Exit"
    echo ""
    echo -e "${WHITE}===================================================${NC}"
    echo ""
    read -p "Choose an option [1-4]: " OPTION

    case $OPTION in
        1)
            echo -e "\n${YELLOW}[*] Fetching available templates from GitHub...${NC}"
            
            TEMPLATE_LIST=$(python3 -c "
import urllib.request, json, sys
try:
    req = urllib.request.Request('$GITHUB_API_URL', headers={'User-Agent': 'Mozilla/5.0'})
    data = json.loads(urllib.request.urlopen(req).read())
    for item in data:
        if item['type'] == 'dir':
            print(item['name'])
except Exception as e:
    sys.exit(1)
" 2>/dev/null)

            if [ -z "$TEMPLATE_LIST" ]; then
                TEMPLATE_LIST=$(curl -sH "User-Agent: Mozilla/5.0" "$GITHUB_API_URL" | grep -e '"name"' -e '"type"' | grep -B 1 '"type": "dir"' | grep '"name":' | awk -F '"' '{print $4}')
            fi

            if [ -z "$TEMPLATE_LIST" ]; then
                echo -e "${RED}[!] Failed to fetch templates. Please check your internet connection or GitHub API limits.${NC}"
                exit 1
            fi

            IFS=$'\n' read -rd '' -a TEMPLATE_ARRAY <<<"$TEMPLATE_LIST"
            
            echo -e "\n${GREEN}Available Templates:${NC}"
            echo ""
            COUNT=1
            for t in "${TEMPLATE_ARRAY[@]}"; do
                echo "  $COUNT) $t"
                ((COUNT++))
            done
            
            echo ""
            read -p "Select a template to install [1-$((COUNT-1))]: " TEMPLATE_CHOICE
            
            if ! [[ "$TEMPLATE_CHOICE" =~ ^[0-9]+$ ]] || [ "$TEMPLATE_CHOICE" -lt 1 ] || [ "$TEMPLATE_CHOICE" -ge "$COUNT" ]; then
                echo -e "${RED}[!] Invalid selection. Aborting.${NC}"
                exit 1
            fi
            
            SELECTED_TEMPLATE="${TEMPLATE_ARRAY[$((TEMPLATE_CHOICE-1))]}"
            echo -e "${CYAN}[*] You selected: $SELECTED_TEMPLATE${NC}"
            
            TEMPLATE_RAW_URL="https://raw.githubusercontent.com/im-JvD/Rebecca-Template/main/Templates/${SELECTED_TEMPLATE}/index.html"
            
            echo -e "${YELLOW}[*] Downloading $SELECTED_TEMPLATE to $TEMPLATE_DIR...${NC}"
            
            mkdir -p "$TEMPLATE_DIR"
            wget -q -O "$TEMPLATE_DIR/index.html" "$TEMPLATE_RAW_URL"
            
            if [ $? -eq 0 ]; then
                chmod -R 755 /var/lib/rebecca/templates/
                
                apply_settings
                
                echo -e "${YELLOW}[*] Recreating Rebecca container to apply changes...${NC}"
                cd "$REBECCA_DIR" && docker compose up -d > /dev/null 2>&1
                
                echo -e "${GREEN}[+] Installation successful!${NC}"
                echo -e "${YELLOW}[*] Opening  Rebecca live logs... (Press Ctrl+C to exit)${NC}\n"
                
                sleep 2
                
                if command -v rebecca &> /dev/null; then
                    rebecca logs
                else
                    cd "$REBECCA_DIR" && docker compose logs -f
                fi
                
            else
                echo -e "${RED}[!] Failed to download the template file (index.html) from $SELECTED_TEMPLATE.${NC}"
                echo -e "${RED}URL attempted: $TEMPLATE_RAW_URL${NC}"
            fi
            ;;
            
        2)
            echo -e "\n${YELLOW}[*] Change feature is coming soon!${NC}"
            ;;
            
        3)
            echo -e "\n${YELLOW}--- Starting Template Deletion ---${NC}"
            
            echo -e "${YELLOW}[*] Removing template directory (/var/lib/rebecca/templates/)...${NC}"
            rm -rf /var/lib/rebecca/templates/
            
            remove_settings
            
            echo -e "${YELLOW}[*] Recreating Rebecca container to load default settings...${NC}"
            cd "$REBECCA_DIR" && docker compose up -d > /dev/null 2>&1
            
            echo -e "${GREEN}[+] Template removed and panel reset to default successfully!${NC}"
            ;;
            
        4)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
            
        *)
            echo -e "${RED}[!] Invalid option. Please try again.${NC}"
            sleep 2
            show_menu
            ;;
    esac
}

show_menu
