#!/bin/bash

# init message
echo \
$'            ,,,,,,
        o#\'9MMHb\':\'-,o,
     .oH":HH$\' "\' \' -*R&o,
    dMMM*""\'`\'      .oM"HM?.
  ,MMM\'          "HLbd< ?&H\\
 .:MH ."\\          ` MM  MM&b
. \"*H    -        &MMMMMMMMMH:
.    dboo        MMMMMMMMMMMM.
.   dMMMMMMb      *MMMMMMMMMP.
.    MMMMMMMP        *MMMMMP .
     `#MMMMM           MM6P ,
 \'    `MMMP\"           HM*`,
  \'    :MM             .- ,
   \'.   `#?..  .       ..\'
      -.   .         .-
        \'\'-.oo,oo.-\'\'
        PROJECT GLOBE
'

read -p "This script will check for dependencies, install them if needed, and automatically configure ALL frontends. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "No worries. You can always configure these manually or run this script again later. Goodbye!"
    exit 0
fi

# color vars
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# dep check vars
debian=true
ubuntu=false
skippedPKG=false
aptUpdated=false
dockerChange=false

# extra vars
scriptDir=$(dirname "$(readlink -f "$0")")
cd $scriptDir # ensures directory specific commands work
ip=$(curl -m 5 ipv4.icanhazip.com)

# cert + nginx func
# TODO: support wildcard certs
# TODO: support setting multiple domains at once, to prevent having to test and restart multiple times per frontend
# TODO: possibly skip this segment for self hosters?
configure_nginx() {
    local domain="$1"
    local conf="$2"
    local output="${3:-$conf}"
    local port="$4"

    echo "Add the following to your DNS settings:"
    echo "[A] $domain -> $ip"
    read -p "Press enter when you have done so." -n 1 -r

    sudo certbot certonly --nginx -d $domain
    if [ $? -eq 0 ]; then
        sudo cp "../nginx/${conf}" /etc/nginx/sites-enabled/${output}
        sudo sed -i "s/domain/$domain/g" "/etc/nginx/sites-enabled/${output}"
        if [ ! -z "$port" ]; then
            sudo sed -i "s/port/$port/g" "/etc/nginx/sites-enabled/${output}" 
        fi
        sudo nginx -t
        if [ $? -eq 0 ]; then
            sudo systemctl restart nginx
        else
            echo -e "${RED}ERROR:${NC} Nginx configuration could not be loaded properly! Please see above for details."
            sudo rm /etc/nginx/sites-enabled/$conf
        fi
    else
        echo -e "${RED}ERROR:${NC} Could not get certificate! (DNS likely has not been updated yet.) Please get the certificate and add the nginx configuration later by running the following:"
        echo "sudo certbot certonly --nginx -d $domain"
        echo "sudo cp ${GREEN}globe${NC}/nginx/${conf} /etc/nginx/sites-enabled/${output}"
        echo "sudo sed -i 's/domain/$domain/g' /etc/nginx/sites-enabled/${output}"
        echo "sudo nginx -t"
        echo "sudo systemctl restart nginx"
    fi
}

# ----------------
# dependency check
# ----------------
echo "Checking dependencies..."

# check distro, if it's not debian based then notify user
if [ -f /etc/os-release ]; then
    . /etc/os-release

    if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"ubuntu"* ]]; then
        ubuntu=true
    elif [[ "$ID" != "debian" && "$ID_LIKE" != *"debian"* ]]; then
        echo -e "${YELLOW}WARN:${NC} You're not on a Debian-based distro. Please note that this script will not be able to automatically install most dependencies for you, and you will need to install them manually."
        debian=false
    fi
else
    echo -e "${YELLOW}WARN:${NC} You're not on a Debian-based distro. Please note that this script will not be able to automatically install most dependencies for you, and you will need to install them manually."
    debian=false
fi


# check for docker
if [ ! command -v docker &> /dev/null ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} Docker not found. Installing..."
        sudo apt update
        aptUpdated=true
        sudo apt install ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        if [ "$ubuntu" = true ]; then
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        else
            sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        fi
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        if [ "$ubuntu" = true ]; then
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        else
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi
        sudo apt update
        sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker $USER
        newgrp docker
        dockerChange=true
        echo -e "${GREEN}Installed Docker!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} Docker not found."
    fi
fi

# check for docker compose
if [ ! docker compose version &> /dev/null ]; then
    echo -e "${YELLOW}WARN:${NC} Docker Compose (v2) not found. Installing..."
    mkdir -p ~/.docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    echo -e "${GREEN}Installed Docker Compose!${NC}"
fi

# nginx
if [ ! command -v nginx &> /dev/null && "$debian" = true ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} Nginx not found. Installing..."
        if [ "$aptUpdated" = false ]; then
            sudo apt update
            aptUpdated=true
        fi
        sudo apt install -y nginx
        echo -e "${GREEN}Installed Nginx!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} Docker not found."
    fi
fi

# python, requests and pyroute2 (for IPv6 rotation)
if [ ! command -v python3 &> /dev/null ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} Python not found. Installing..."
        if [ "$aptUpdated" = false ]; then
            sudo apt update
            aptUpdated=true
        fi
        sudo apt install -y python3 python-is-python3 python3-pip
        echo -e "${GREEN}Installed Python!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} Python not found."
    fi
fi
if [ ! command -v pip &> /dev/null ]; then
    :
else
    pip show "requests" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ "$debian" = true ]; then
            echo -e "${YELLOW}WARN:${NC} Python Requests not found. Installing..."
            if [ "$aptUpdated" = false ]; then
                sudo apt update
                aptUpdated=true
            fi
            sudo apt install -y python3-requests
        else
            skippedPKG=true
            echo -e "${RED}ERROR:${NC} Python Requests not found."
        fi
    fi
    pip show "pyroute2" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        if [ "$debian" = true ]; then
            echo -e "${YELLOW}WARN:${NC} Python PyRoute2 not found. Installing..."
            if [ "$aptUpdated" = false ]; then
                sudo apt update
                aptUpdated=true
            fi
            sudo apt install -y python3-pyroute2
        else
            skippedPKG=true
            echo -e "${RED}ERROR:${NC} Python PyRoute2 not found."
        fi
    fi
fi

# certbot
if [ ! command -v certbot &> /dev/null ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} Certbot not found. Installing..."
        if [ "$aptUpdated" = false ]; then
            sudo apt update
            aptUpdated=true
        fi
        sudo apt install -y certbot python3-certbot-nginx
        echo -e "${GREEN}Installed Certbot!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} Certbot not found."
    fi
fi

# node v18 (for poke)
if ! command -v node &> /dev/null || [[ $(node -v | cut -d. -f1) != "v18" ]]; then
    echo -e "${YELLOW}WARN:${NC} Node.JS v18 not found. Installing..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 18
    echo -e "${GREEN}Installed Node.JS!${NC}"
fi

# jq (used in some scripts, like setting up docker's daemon.json)
if [ ! command -v jq &> /dev/null ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} jq not found. Installing..."
        if [ "$aptUpdated" = false ]; then
            sudo apt update
            aptUpdated=true
        fi
        sudo apt install -y jq
        echo -e "${GREEN}Installed jq!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} jq not found."
    fi
fi

# sponge (used in some scripts, like setting up docker's daemon.json)
if [ ! command -v sponge &> /dev/null ]; then
    if [ "$debian" = true ]; then
        echo -e "${YELLOW}WARN:${NC} jq not found. Installing..."
        if [ "$aptUpdated" = false ]; then
            sudo apt update
            aptUpdated=true
        fi
        sudo apt install -y moreutils
        echo -e "${GREEN}Installed jq!${NC}"
    else
        skippedPKG=true
        echo -e "${RED}ERROR:${NC} jq not found."
    fi
fi

# if they're not debian and missed a pkg, exit
if [ "$skippedPKG" = true ]; then
    echo "Please install the above dependencies first, then re-run this script."
    exit 1
fi

echo -e "${GREEN}All dependencies installed!${NC}"
if [ "$dockerChange" = true ]; then
    echo -e "${YELLOW}WARN:${NC} Please note that since you needed to install Docker, this script automatically added you to the Docker group. That change will only take effect in this session and after relogging - any existing sessions will require you to use sudo to run Docker commands, or you can run \`newgrp docker\`."
fi

# ----
# ipv6
# ----
askedipv6=false

setup_ipv6() {
    askedipv6=true
    read -p "Do you already have IPv6 set up? (y/N) " -n 1 -r ipv6
    echo
    if [[ $ipv6 =~ ^[Yy]$ ]]; then
        echo "Got it. Skipping IPv6 setup."
    else
        read -p "Do you want to set up IPv6? (y/N) " -n 1 -r ipv6
        echo

        disable_ipv6() {
            if [ $1 == "invidious" ]; then
                sed -i "s/force-resolve: ipv6/#force-resolve: ipv6/g" ../services/invidious/docker-compose.yml
                sed -i "s/host_binding: ::0/#host_binding: ::0/g" ../services/invidious/docker-compose.yml
                sed -i "/networks:/,/^$/ s/^/# /" ../services/invidious/docker-compose.yml
            elif [ $1 == "piped" ]; then
                sed -i "/networks:/,/^$/ s/^/# /" ../services/piped/docker-compose.yml
            fi
        }

        if [[ $ipv6 =~ ^[Yy]$ ]]; then
            # test to see if IPv6 connectivity works
            if curl -m 5 ipv6.icanhazip.com > /dev/null 2>&1; then
                # test to see if IPv6 rotation works
                while [ -z $ipv6_range ]; do
                    read -p "What is your IPv6 range? " ipv6_range
                done
                cd ..
                sudo python smart-ipv6-rotator/smart-ipv6-rotator.py run --ipv6range=$ipv6_range
                cd $scriptDir
                if [ $? -eq 0 ]; then
                    # configure docker to use ipv6
                    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
                    [ -s /etc/docker/daemon.json.bak ] || echo {} | sudo tee -a /etc/docker/daemon.json.bak
                    sudo jq '. += {"experimental": true, "ip6tables": true}' /etc/docker/daemon.json.bak | sudo sponge /etc/docker/daemon.json
                    sudo systemctl restart docker
                    # change range in rotate.sh
                    echo $ipv6_range > range.txt
                    # add to crontab
                    sudo crontab -l | { cat; echo "@reboot sleep 30s && ${scriptDir}/rotate.sh"; echo "0 */12 0 0 0 ${scriptDir}/rotate.sh"; } | sudo crontab -
                    echo -e "${GREEN}IPv6 successfully set up!${NC}"
                else
                    echo -e "${RED}ERROR:${NC} Smart IPv6 rotator failed! Please run it manually and resolve any errors."
                    disable_ipv6
                fi
            else
                echo -e "${RED}ERROR:${NC} Your server can not be reached over IPv6! Please check and see if it supports it or if it's configured."
                disable_ipv6
            fi
        else
            echo "No worries, you can always set it up later with this guide: https://docs.invidious.io/ipv6-rotator/"
            disable_ipv6
        fi
    fi
}

# ---------
# invidious
# ---------
setup_invidious() {
    echo "Setting up Invidious..."
    cp ../services/invidious-template/docker-compose.template.yml ../services/invidious/docker-compose.yml
    cp ../services/invidious-template/nginx.conf ../services/invidious/nginx.conf
    cp ../services/invidious-template/docker/* ../services/invidious/docker/

    # generate hmac key
    hmac=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    sed -i "s/hmac_key: .*/hmac_key: $hmac/g" ../services/invidious/docker-compose.yml

    # generate potoken + visitor_data
    potvis=$(docker run quay.io/invidious/youtube-trusted-session-generator)
    pot=$(echo "$potvis" | grep -oP '(?<=visitor_data: )[^ ]+')
    vis=$(echo "$potvis" | grep -oP '(?<=po_token: )[^ ]+')

    if [ -z "$pot" ] || [ -z "$vis" ]; then
        # comment out values if it can't generate it
        echo -e "${RED}ERROR:${NC} Could not generate a trusted session and get po_token / visitor_data values! If you are planning on running a public instance, please add these later on."
        sed -i "s/po_token: .*/#po_token: changeme/g" ../services/invidious/docker-compose.yml
        sed -i "s/visitor_data: .*/#visitor_data: changeme/g" ../services/invidious/docker-compose.yml
    else
        sed -i "s/po_token: .*/po_token: $pot/g" ../services/invidious/docker-compose.yml
        sed -i "s/visitor_data: .*/visitor_data: $vis/g" ../services/invidious/docker-compose.yml
    fi

    # admin, domain, banner
    read -i admin -p "What user do you want to set as admin? (Default 'admin') " invuser
    invuser=${invuser:-admin}
    sed -i "/admins:/!b;n;s/- .*/- $invuser/" ../services/invidious/docker-compose.yml

    while [ -z $invdomain ]; do
        read -p "What domain do you want to use? " invdomain
    done
    sed -i "s/domain: .*/domain: $invdomain/g" ../services/invidious/docker-compose.yml

    read -p "What do you want to set as the banner? (Default: none) " invbanner
    if [ -z "$invbanner" ]; then sed -i "s/banner: .*/#banner: changeme/g" ../services/invidious/docker-compose.yml;
    else sed -i "s/banner: .*/banner: $banner/g" ../services/invidious/docker-compose.yml; fi

    # IPv6
    if [ "$askedipv6" = false ]; then
        setup_ipv6 invidious
    fi

    # add to crontab
    crontab -l | { cat; echo "0 * * * * ${scriptDir}/inv-restart.sh"; } | crontab -

    # get cert + add nginx
    configure_nginx $invdomain "invidious.conf"

    # start up
    cd ../services/invidious
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Invidious successfully set up!${NC}"
}

# -----
# piped
# -----
setup_piped() {
    echo "Setting up Piped..."
    cp ../services/piped/docker-compose.template.yml ../services/piped/docker-compose.yml

    # mostly copied from https://github.com/TeamPiped/Piped-Docker/blob/main/configure-instance.sh
    while [ -z $pifront ]; do read -p "What domain do you want to use for the frontend? (e.g. pi.ggtyler.dev) " -r pifront; done
    while [ -z $piapi ]; do read -p "What domain do you want to use for the backend? (e.g. piapi.ggtyler.dev) " -r piapi; done
    while [ -z $piproxy ]; do read -p "What domain do you want to use for the proxy? (e.g. piproxy.ggtyler.dev) " -r piproxy; done

    piconf=$(find ../services/piped/config/ -type f ! -name '*.yml')
    sed -i "s/FRONTEND_HOSTNAME/${pifront}/g" $piconf
    sed -i "s/BACKEND_HOSTNAME_PLACEHOLDER/${piapi}/g" $piconf
    sed -i "s/BACKEND_HOSTNAME/${piapi}/g" $piconf
    sed -i "s/PROXY_HOSTNAME/${piproxy}/g" ../services/piped/docker-compose.yml

    # IPv6
    if [ "$askedipv6" = false ]; then
        setup_ipv6 piped
    fi

    configure_nginx $pifront "standard.conf" "piped_front.conf" 54302
    configure_nginx $piapi "standard.conf" "piped_api.conf" 54302
    configure_nginx $piproxy "standard.conf" "piped_proxy.conf" 54302

    cd ../services/piped
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Piped successfully set up!${NC}"
}

# ---------
# hyperpipe
# ---------
setup_hyperpipe() {
    echo "Setting up Hyperpipe..."
    cp ../services/hyperpipe/docker-compose.template.yml ../services/hyperpipe/docker-compose.yml

    while [ -z $hpfront ]; do
        read -p "What domain do you want to use for the frontend? (e.g. hp.ggtyler.dev) " hpfront
    done
    while [ -z $hpapi ]; do
        read -p "What domain do you want to use for the backend? (e.g. hpapi.ggtyler.dev) " hpapi
    done

    sed -i "s/PIPED_PROXY_URL/$piproxy/g" ../services/hyperpipe/docker-compose.yml
    sed -i "s/PIPED_API_URL/$piapi/g" ../services/hyperpipe/docker-compose.yml
    sed -i "s/HYPERPIPE_API_URL/$hpapi/g" ../services/hyperpipe/docker-compose.yml

    configure_nginx $hpfront "standard.conf" "hyperpipe_front.conf" 54303
    configure_nginx $hpapi "standard.conf" "hyperpipe_api.conf" 54304

    cd ../services/hyperpipe
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Hyperpipe successfully set up!${NC}"
}

# ----
# poke
# ----
setup_poke() {
    echo "Setting up Poke..."

    # update config (ashley pls switch to config.json.example alr)
    invdomainhttps="https://$invdomain"
    jq --arg inv "$invdomainhttps" '.invapi = $inv' ../services/poke/config.json | sponge ../services/poke/config.json
    jq --arg inv "$invdomainhttps" '.invchannel = $inv' ../services/poke/config.json | sponge ../services/poke/config.json
    jq --arg inv "$invdomainhttps" '.videourl = $inv' ../services/poke/config.json | sponge ../services/poke/config.json
    jq '.server_port = "54305"' ../services/poke/config.json | sponge ../services/poke/config.json

    while [ -z $pokedomain ]; do
        read -p "What domain do you want to use? " pokedomain
    done
    configure_nginx $pokedomain "standard.conf" "poke.conf" 54305

    cd ../services/poke
    npm install
    npm install -g pm2
    pm2 start server.js --name poke
    cd $scriptDir
    echo -e "${GREEN}Poke successfully set up!${NC}"
}

# ------
# redlib
# ------
setup_redlib() {
    echo "Setting up RedLib..."
    cp ../services/redlib/docker-compose.template.yml ../services/redlib/docker-compose.yml
    cp ../services/redlib/.template.env ../services/redlib/.env

    while [ -z $redlibdomain ]; do
        read -p "What domain do you want to use? " redlibdomain
    done

    configure_nginx $redlibdomain "standard.conf" "redlib.conf" 54306

    cd ../services/redlib
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}RedLib successfully set up!${NC}"
}

# ----------
# safetwitch
# ----------
setup_safetwitch() {
    echo "Setting up SafeTwitch..."
    cp ../services/safetwitch/docker-compose.template.yml ../services/safetwitch/docker-compose.yml

    while [ -z $stfront ]; do
        read -p "What domain do you want to use for the frontend? (e.g. st.ggtyler.dev) " stfront
    done
    while [ -z $stapi ]; do
        read -p "What domain do you want to use for the backend? (e.g. stapi.ggtyler.dev) " stapi
    done

    sed -i "s/frontendCHANGEME/$stfront/g" ../services/safetwitch/docker-compose.yml
    sed -i "s/backendCHANGEME/$stapi/g" ../services/safetwitch/docker-compose.yml

    configure_nginx $stfront "safetwitch.conf" "safetwitch_front.conf" 54307
    configure_nginx $stapi "safetwitch.conf" "safetwitch_api.conf" 54308

    cd ../services/safetwitch
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}SafeTwitch successfully set up!${NC}"
}

# ----
# dumb
# ----
setup_dumb() {
    echo "Setting up Dumb..."
    cp ../services/dumb/docker-compose.template.yml ../services/dumb/docker-compose.yml

    while [ -z $dumbdomain ]; do
        read -p "What domain do you want to use? " dumbdomain
    done
    configure_nginx $dumbdomain "standard.conf" "dumb.conf" 54309

    cd ../services/dumb
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Dumb successfully set up!${NC}"
}

# ----------
# breezewiki
# ----------
setup_breezewiki() {
    echo "Setting up BreezeWiki..."
    cp ../services/breezewiki/docker-compose.template.yml ../services/breezewiki/docker-compose.yml
    cp ../services/breezewiki/config.template.ini ../services/breezewiki/config.ini

    while [ -z $breezedomain ]; do
        read -p "What domain do you want to use? " breezedomain
    done
    sed -i "s/domain/$breezedomain/g" ../services/breezewiki/config.ini
    # TODO: Set up wildcard domain here too (since BreezeWiki uses one to redirect sub -> wiki)
    configure_nginx $breezedomain "standard.conf" "breezewiki.conf" 54310

    cd ../services/breezewiki
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}BreezeWiki successfully set up!${NC}"
}

# ------
# cobalt
# ------
setup_cobalt() {
    echo "Setting up Cobalt..."
    cp ../services/cobalt-template/docker-compose.template.yml ../services/cobalt/docker-compose.yml
    cp ../services/cobalt-template/cookies.template.json ../services/cobalt/cookies.json
    cp ../services/cobalt-template/Dockerfile ../services/cobalt/Dockerfile-web

    while [ -z $cofront ]; do
        read -p "What domain do you want to use for the frontend? (e.g. co.ggtyler.dev) " cofront
    done
    while [ -z $coapi ]; do
        read -p "What domain do you want to use for the backend? (e.g. coapi.ggtyler.dev) " coapi
    done
    while [ -z $coname ]; do
        read -p "What name do you want to use? (e.g. ggt-nyc1)" coname
    done

    sed -i "s/frontendCHANGEME/$cofront/g" ../services/cobalt/docker-compose.yml
    sed -i "s/backendCHANGEME/$coapi/g" ../services/cobalt/docker-compose.yml
    sed -i "s/nameCHANGEME/$coname/g" ../services/cobalt/docker-compose.yml

    cd ../services/cobalt
    docker compose up -d

    # ask for token
    docker compose exec cobalt-api npm run token:youtube
    # due to limitations with bash, we're gonna have to ask the user to paste the token in manually
    while [ -z $cotoken ]; do
        read -p "Paste the token from above: " -r cotoken
    done
    sed -i "s/changeme/$cotoken/g" ../services/cobalt/cookies.json
    docker compose down && docker compose up -d

    configure_nginx $cofront "standard.conf" "cobalt_front.conf" 54311
    configure_nginx $coapi "standard.conf" "cobalt_api.conf" 54312

    cd $scriptDir
    echo -e "${GREEN}Cobalt successfully set up!${NC}"
}

# -------
# searxng
# -------
setup_searxng() {
    echo "Setting up SearXNG..."
    cp ../services/searxng/docker-compose.template.yml ../services/searxng/docker-compose.yml
    cp ../services/searxng/.template.env ../services/searxng/.template.env
    cp ../services/searxng/config/settings.template.yml ../services/searxng/config/settings.yml
    cp ../services/searxng/config/limiter.template.toml ../services/searxng/config/limiter.toml
    cp ../services/searxng/config/uwsgi.template.ini ../services/searxng/config/uwsgi.ini

    # generate secret key
    sxsecret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    sed -i "s/changeme/$sxsecret/g" ../services/searxng/config/settings.yml

    while [ -z $sxdomain ]; do
        read -p "What domain do you want to use? " sxdomain
    done
    sed -i "s/changeme/$sxdomain/g" ../services/searxng/.env
    configure_nginx $sxdomain "searxng.conf"

    cd ../services/searxng
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}SearXNG successfully set up!${NC}"
}

# ------
# librey
# ------
setup_librey() {
    echo "Setting up LibreY..."
    cp ../services/librey/docker-compose.template.yml ../services/librey/docker-compose.yml
    sed -i "s/invCHANGEME/$invdomain/g" ../services/librey/docker-compose.yml
    sed -i "s/redCHANGEME/$redlibdomain/g" ../services/librey/docker-compose.yml
    sed -i "s/breCHANGEME/$breezedomain/g" ../services/librey/docker-compose.yml

    while [ -z $lydomain ]; do
        read -p "What domain do you want to use? " lydomain
    done
    configure_nginx $lydomain "standard.conf" "librey.conf" 54314

    cd ../services/librey
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}LibreY successfully set up!${NC}"
}

# ---------------
# simplytranslate
# ---------------
setup_simplytranslate() {
    echo "Setting up SimplyTranslate..."
    # simplytranslate PLEASE PUBLISH A DOCKER IMAGE :sob:
    sed -i "s/5000:/54315:/g" ../services/simplytranslate/docker-compose.yml

    while [ -z $stldomain ]; do
        read -p "What domain do you want to use? " stldomain
    done
    configure_nginx $stldomain "standard.conf" "simplytranslate.conf" 54315

    cd ../services/simplytranslate
    docker compose build
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}SimplyTranslate successfully set up!${NC}"
}

# --------------
# libretranslate
# --------------
setup_libretranslate() {
    echo "Setting up LibreTranslate..."
    cp ../services/libretranslate/docker-compose.template.yml ../services/libretranslate/docker-compose.yml

    while [ -z $ltldomain ]; do
        read -p "What domain do you want to use? " ltldomain
    done
    configure_nginx $ltldomain "standard.conf" "libretranslate.conf" 54316

    cd ../services/libretranslate
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}LibreTranslate successfully set up!${NC}"
}

# ------
# lingva
# ------
setup_lingva() {
    echo "Setting up Lingva..."
    cp ../services/lingva/docker-compose.template.yml ../services/lingva/docker-compose.yml

    while [ -z $lvdomain ]; do
        read -p "What domain do you want to use? " lvdomain
    done
    sed -i "s/changeme/$lvdomain/g" ../services/lingva/docker-compose.yml
    configure_nginx $lvdomain "standard.conf" "lingva.conf" 54317

    cd ../services/lingva
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Lingva successfully set up!${NC}"
}

# -----
# mozhi
# -----
setup_mozhi() {
    echo "Setting up Mozhi..."
    cp ../services/mozhi/docker-compose.template.yml ../services/mozhi/docker-compose.yml

    while [ -z $mzdomain ]; do
        read -p "What domain do you want to use? " mzdomain
    done
    sed -i "s/changeme/$mzdomain/g" ../services/mozhi/docker-compose.yml
    configure_nginx $mzdomain "standard.conf" "mozhi.conf" 54318

    cd ../services/mozhi
    docker compose up -d
    cd $scriptDir
    echo -e "${GREEN}Mozhi successfully set up!${NC}"
}

# -----
# flags
# -----

# Note: this currently uses getopts for flags, but this WILL be changed in the future. Do not expect these flags to stay the same.
while getopts ":iphkrsdbcxytlvm" opt; do
    case $opt in
        i)
            setup_invidious
            ;;
        p)
            setup_piped
            ;;
        h)
            setup_hyperpipe
            ;;
        k)
            setup_poke
            ;;
        r)
            setup_redlib
            ;;
        s)
            setup_safetwitch
            ;;
        d)
            setup_dumb
            ;;
        b)
            setup_breezewiki
            ;;
        c)
            setup_cobalt
            ;;
        x)
            setup_searxng
            ;;
        y)
            setup_librey
            ;;
        t)
            setup_simplytranslate
            ;;
        l)
            setup_libretranslate
            ;;
        v)
            setup_lingva
            ;;
        m)
            setup_mozhi
            ;;
        *)
            setup_invidious
            setup_piped
            setup_hyperpipe
            setup_poke
            setup_redlib
            setup_safetwitch
            setup_dumb
            setup_breezewiki
            setup_cobalt
            setup_searxng
            setup_librey
            setup_simplytranslate
            setup_libretranslate
            setup_lingva
            setup_mozhi
            # add healthcheck.sh to crontab
            ntfy=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
            echo $ntfy > ntfy.txt
            crontab -l | { cat; echo "*/15 * * * * ${scriptDir}/healthcheck.sh"; } | crontab -
            # print post-config steps
            echo -e "${GREEN}All frontends set up, congratulations!${NC}"
            echo "Here's some post-config steps:"
            echo " - Make sure all your instances are reachable online"
            echo " - Tweak any settings needed"
            echo " - Subscribe to ntfy.sh/$ntfy for health check updates"
            echo " - Do occasional updates"
            echo " - Have fun and use responsibly!"
            echo
            ;;
    esac
done