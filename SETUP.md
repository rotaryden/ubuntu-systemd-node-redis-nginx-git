Description
=======================
Here is Ubuntu 15.04 server setup from scratch. Hope it woud be useful.

Tested on DigitalOcean, 1 Gb instance.

In the box:
- Secured user, disabled root ssh login
- API Node.js back-end (foobar-api-dev)
- Redis for API back-end
- UI supplying Node.js back-end
- Nginx setup as proxy for both Node.js servers and for
static content loading
- git deployments with hook scripts
- systemd service files to run Node.js continuosly 
(like forever or pm2 do, but with native OS means)

##What to change:

- Replace "foobar" with your domain
- Replace user name "web" to what you like,
or better to some hardly figuring name

##Management:
to ssh: 
```sh
ssh web@$foobar.com
```

to view logs: 
```sh
ssh web@$foobar.com "journalctl -f"
```

add to your Git kind of: 
```sh
git remote add vps ssh://web@foobar.com/www/foobar-api-dev.git
git remote add vps ssh://web@foobar.com/www/foobar-ui-dev.git
```

and just push to master:

```sh
git push vps master
```

it will update server instance automatically in post-receive hook



##Details

###basic setup

```sh
adduser web
```

###to make super user or just add to another group
```sh
gpasswd -a web sudo
```

###make ownership of directories

```sh
mkdir /www
chown -R web:web /www
```

###change password
```sh
passwd 
```

###allow systemctl under the non-root 
```sh
visudo

web ALL = NOPASSWD: /bin/systemctl status webapp-*-*-*.service, NOPASSWD: /bin/systemctl *start webapp-*-*-*.service
```

###root login remote shell
```sh
nano /etc/ssh/sshd_config

PermitRootLogin no

service ssh restart
```

###locales

```sh
locale-gen en_US en_US.UTF-8
dpkg-reconfigure locales 
```

###software
```sh
su - web

sudo apt-get update
sudo apt-get upgrade

sudo apt-get install git nginx software-properties-common build-essential python-software-properties gcc-4.8 g++-4.8
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash

. ~/.bashrc

#install latest node, or change to specific version in your package.json
nvm install node

npm install -g gulp
```

##git

```sh
cd /www
mkdir webapp
cd webapp
mkdir foobar
cd foobar
mkdir ui-dev
mkdir ui-dev.git
cd ui-dev.git
git init --bare

cd hooks
cat > post-receive
```

###hooks
####Only one hook shown here, second one is similar

```sh
#!/bin/sh
APP=ui
APPENV=dev
PROJECT=foobar
DEPLOY_ALLOWED_BRANCH="master"

APPSTRING="webapp/${PROJECT}/${APP}-${APPENV}"
SVCSTRING="webapp-${PROJECT}-${APP}-${APPENV}"
SERVICE="${SVCSTRING}.service"
SERVICE2="${PROJECT}-queue-${APPENV}.service"
DEPLOY_ROOT="/www/${APPSTRING}"
GIT_DIR="${DEPLOY_ROOT}.git"   

IP="$(ip addr show eth0 | grep 'inet ' | cut -f2 | awk '{ print $2}')"

echo
echo "$(date): Welcome to '$(hostname -f)' (${IP})"
echo

mkdir -p "${DEPLOY_ROOT}"

read oldrev newrev refname

export DEPLOY_BRANCH=$(git rev-parse --symbolic --abbrev-ref $refname)
export DEPLOY_OLDREV="$oldrev"
export DEPLOY_NEWREV="$newrev"
export DEPLOY_REFNAME="$refname"

echo "DEPLOY_BRANCH=$(DEPLOY_BRANCH)"
echo "DEPLOY_OLDREV=$(DEPLOY_OLDREV)"
echo "DEPLOY_NEWREV=$(DEPLOY_NEWREV)"
echo "DEPLOY_REFNAME=$(DEPLOY_REFNAME)"

if [ ! -z "${DEPLOY_ALLOWED_BRANCH}" ]; then
    if [ "${DEPLOY_ALLOWED_BRANCH}" != "$DEPLOY_BRANCH" ]; then
        echo "Branch '${DEPLOY_BRANCH}' of '${DEPLOY_APP_NAME}' application will not be deployed. Exiting."
        exit 1
    fi
fi

echo
echo "Copying source tree to ${DEPLOY_ROOT}..."
git --work-tree=$DEPLOY_ROOT --git-dir=$GIT_DIR checkout -f || exit 1
echo DONE

cd $DEPLOY_ROOT
echo "Enter $(pwd)"

echo "Resetting to ${DEPLOY_NEWREV}..."
git --work-tree=$DEPLOY_ROOT --git-dir=$GIT_DIR reset --hard "$DEPLOY_NEWREV" || exit 1
echo DONE
echo

echo "CHANGED FILES:"
git diff-tree --no-commit-id --name-only -r ${DEPLOY_NEWREV}

NEED_INSTALL=`git diff-tree --no-commit-id --name-only -r ${DEPLOY_NEWREV} | perl -ne 'if (/package\.json/) {print "true";} else {print "false";}'`

export NVM_DIR="/home/$USER/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

VERSION=`cat ${DEPLOY_ROOT}/package.json | perl -ne 'print $1 if /\"node\"\:\s*\"\^([\d\.]+)\"/'`

#installs if needed and make using of the $VERSION
nvm install $VERSION

if [ ! -d "node_modules" -o "${NEED_INSTALL}" = "true" ]; then
    echo "--------------- NEED REINSTALLING MODULES (package.json changed)-------------------------
    npm install --production
else
    echo "Just running build script..."
    npm run-script build
fi

echo "Restarting service ${SERVICE}..."
sudo /bin/systemctl restart $SERVICE
echo DONE
echo
sleep 3
echo "Status of ${SERVICE}:"
sudo /bin/systemctl status $SERVICE

#echo "Restarting service ${SERVICE2}..."
#sudo /bin/systemctl restart $SERVICE2
#echo DONE
#echo
#sleep 3
#echo "Status of ${SERVICE2}:"
#sudo /bin/systemctl status $SERVICE2

echo DONE.
echo
```

###the same for another hook


```
chmod +x post-receive
```

###locally: 
```
git remote add dev ssh://web@web.dev.foobar.com/www/foobar-ui-dev.git
```

nginx
------------------------------
```sh
systemctl enable nginx


nano /etc/nginx/sites-available/default 

server {
    listen 80;
    listen [::]:80;

    server_name yourserver.com;

    location ~ ^/(robots.txt|humans.txt) {
        root /www/foobar-ui-dev/public;
    }

    location /public/ {
      rewrite ^/public/(.*)$ /dist/$1 break;
      root /www/foobar-ui-dev;
      access_log off;
      expires -1;
    }

    location /assets/ {
      root /www/foobar-ui-dev;
      access_log off;
      expires -1;
    }

    location /dev/ {
        root /www/foobar-api-dev;
        expires -1;
        proxy_pass http://127.0.0.1:3000/dev/;
    }


    location /swagger/ {
        root /www/foobar-api-dev;
        expires -1;
        proxy_connect_timeout 159s;
        proxy_send_timeout   600;
        proxy_read_timeout   600; 
        proxy_pass http://127.0.0.1:3000/swagger/;
    }

    location /api/ {
        root /www/foobar-api-dev;
        expires -1;
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_connect_timeout 159s;
        proxy_send_timeout   600;
        proxy_read_timeout   600;        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
    }

   location / {
        root /www/foobar-ui-dev;
        expires -1;
        proxy_pass http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_connect_timeout 159s;
        proxy_send_timeout   600;
        proxy_read_timeout   600;        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_cache_bypass $http_upgrade;
        proxy_redirect off;
    }

}
```

```sh
systemctl restart nginx
```

running via pure systemd
-------------------------

```sh
cat > /etc/systemd/system/foobar-ui-dev.service

[Service]
ExecStart=/www/foobar-ui-dev/scripts/hosted_dev_ui
SyslogIdentifier=foobar-ui-dev
WorkingDirectory=/www/foobar-ui-dev
Restart=always
StandardOutput=syslog
StandardError=syslog
User=web
Group=web
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target




cat > /etc/systemd/system/foobar-api-dev.service

[Service]
ExecStart=/www/foobar-api-dev/bin/hosted_dev_server
SyslogIdentifier=foobar-api-dev
WorkingDirectory=/www/foobar-api-dev
Restart=always
StandardOutput=syslog
StandardError=syslog
User=web
Group=web
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target



/etc/systemd/system/foobar-queue-dev.service:

[Service]
ExecStart=/www/foobar-api-dev/bin/hosted_dev_queue
SyslogIdentifier=foobar-queue-dev
WorkingDirectory=/www/foobar-api-dev
Restart=always
StandardOutput=syslog
StandardError=syslog
User=web
Group=web
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

###enabling 

systemctl enable foobar-ui-dev.service
systemctl enable foobar-api-dev.service
systemctl enable foobar-queue-dev.service

###starting 
systemctl restart foobar-ui-dev.service

###changing

systemctl daemon-reload


redis 
---------------------------
```sh
add-apt-repository ppa:chris-lea/redis-server
apt-get update
apt-get install redis-server

redis-cli ping
#>> PONG

ifconfig

eth0      Link encap:Ethernet  HWaddr 04:01:9a:55:fd:01  
          inet addr:159.203.64.119  Bcast:159.203.79.255  Mask:255.255.240.0
          inet6 addr: fe80::601:9aff:fe55:fd01/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:74014 errors:0 dropped:0 overruns:0 frame:0
          TX packets:17143 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:94890732 (94.8 MB)  TX bytes:2444153 (2.4 MB)

eth1      Link encap:Ethernet  HWaddr 04:01:9a:55:fd:02  

          inet addr: >>>>>> 10.132.1.187 <<<<<<<<  Bcast:10.132.255.255  Mask:255.255.0.0

          inet6 addr: fe80::601:9aff:fe55:fd02/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:8 errors:0 dropped:0 overruns:0 frame:0
          TX packets:7 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:648 (648.0 B)  TX bytes:578 (578.0 B)


vim /etc/redis/redis.conf

bind localhost 10.132.1.187  -- to restrict only to withing-vps calls
#bind -- to allow calls from external net

requirepass pass


systemctl restart redis-server
```
Tools
-----------------

###display port
netstat -tulpn

