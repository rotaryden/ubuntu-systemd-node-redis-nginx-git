### basic setup

USERNAME=$1

adduser $USERNAME

### to make super user or just add to another group
gpasswd -a $USERNAME sudo

### make ownership of directories

mkdir /www
chown -R $USERNAME:$USERNAME /www

### allow systemctl under the non-root 
visudo

```sh

# this line is need for autodeploy scripts, allow only [re]start systemctl commands to run with no password
USERNAME ALL = NOPASSWD: /bin/systemctl status webapp-*-*-*.service, NOPASSWD: /bin/systemctl *start webapp-*-*-*.service

# [optional] Restrict members of group sudo to execute only restricted set of commands
%sudo   ALL = /bin/systemctl * webapp-*-*-*, /bin/ls *  
# OR, alternatively and less strict,
%sudo ALL=!/bin/su, !/usr/bin/sudo -s, !/usr/bin/passwd root

# User privilege specification - only root has full access
root    ALL=(ALL:ALL) ALL

# And not adin group - comment it out
# %admin ALL=(ALL) ALL

```

### root login remote shell
```sh
cat << EOF >> /etc/ssh/sshd_config
PermitRootLogin no
EOF
```

service ssh restart

### locales

```sh
locale-gen --purge en_US en_US.UTF-8
dpkg-reconfigure locales 
cat << EOF >> /etc/environment
LC_ALL="en_US.UTF-8"
EOF
```

### software

```sh
su - web

sudo apt-get update
sudo apt-get upgrade

sudo apt-get install git nginx fail2ban software-properties-common build-essential python-software-properties gcc-4.8 g++-4.8

sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8

curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash

. ~/.bashrc
```

### Node.js

```sh
nvm install node
npm install -g gulp
```

## git

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

### hooks
#### Only one hook shown here, second one is similar

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

### the same for another hook


```sh
chmod +x post-receive
```

### locally: 
```
git remote add dev ssh://web@web.dev.foobar.com/www/webapp/foobar/ui-dev.git
```

nginx
------------------------------

```sh
systemctl enable nginx


nano /etc/nginx/sites-available/default 

server {
    listen 80;
    listen [::]:80;

    server_name foobar.com;

    location ~ ^/(robots.txt|humans.txt) {
        root /www/webapp/foobar/ui-dev/public;
    }

    location /public/ {
      rewrite ^/public/(.*)$ /dist/$1 break;
      root /www/webapp/foobar/ui-dev;
      access_log off;
      expires -1;
    }

    location /assets/ {
      root /www/webapp/foobar/ui-dev;
      access_log off;
      expires -1;
    }

    location /dev/ {
        root /www/webapp/foobar/api-dev;
        expires -1;
        proxy_pass http://127.0.0.1:3000/dev/;
    }


    location /swagger/ {
        root /www/webapp/foobar/api-dev;
        expires -1;
        proxy_connect_timeout 159s;
        proxy_send_timeout   600;
        proxy_read_timeout   600; 
        proxy_pass http://127.0.0.1:3000/swagger/;
    }

    location /api/ {
        root /www/webapp/foobar/api-dev;
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
        root /www/webapp/foobar/ui-dev;
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

server {
    listen 3000;

    server_name foobar.me;


    location / {
        root /www/webapp/foobar/mongoclient;
        expires -1;
        proxy_pass http://127.0.0.1:8001/;
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

### correct permissions for systemctl services

chmod 664 /etc/systemd/system/webapp*.service
 
### enabling 

systemctl enable foobar-ui-dev.service
systemctl enable foobar-api-dev.service
systemctl enable foobar-queue-dev.service

### starting 
systemctl restart foobar-ui-dev.service

### changing

systemctl daemon-reload

MongoDB
-------------------

```sh
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list
sudo apt-get update
sudo apt-get install -y --allow-unauthenticated mongodb-org

sudo nano /etc/systemd/system/mongodb.service
```
[Unit]
Description=High-performance, schema-free document-oriented database
After=network.target

[Service]
User=mongodb
ExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf

[Install]
WantedBy=multi-user.target
```
sudo chmod 664 /etc/systemd/system/mongodb.service
sudo systemctl start mongodb
```

### in case UFW is used
sudo ufw allow from your_other_server_ip/32 to any port 27017  
sudo ufw status

### superuser

mongo

use admin

```javascript
db.createUser(
  {
    user: "grandis",
    pwd: "dddd",
    roles: [
              { role: "userAdminAnyDatabase", db: "admin" },
              { role: "readWriteAnyDatabase", db: "admin" },
              { role: "dbAdminAnyDatabase", db: "admin" },
              { role: "clusterAdmin", db: "admin" }
           ]
  }
)
```


### activate authmodels

nano /etc/mongod.conf
```
security:
  authorization: enabled
```

### create regular DB user
mongo -u superuser -p --authenticationDatabase admin

use admin

```javascript
db.createUser(
  {
    user: "web",
    pwd: "ooo",
    roles: [
              { role: "readWrite", db: "onsite" },
           ]
  }
)
```

### use this user
mongo -u web -p --authenticationDatabase admin


## MongoClient setup

```sh
curl https://install.meteor.com/ | sh
cd /www/webapp/foobar
git clone https://github.com/rsercano/mongoclient.git mongoclient
cd mongoclient

cat << EOF > run-prod
#!/usr/bin/env bash

export MONGOCLIENT_AUTH=true
export MONGOCLIENT_USERNAME=yourlogin
export MONGOCLIENT_PASSWORD=yourpass
```

meteor run -p 8001

sudo nano /etc/systemd/system/webapp-foobar-mongoclient-prod.service
```sh
[Service]
ExecStart=/www/webapp/foobar/mongoclient/run-prod
SyslogIdentifier=webapp-foobar-mongoclient-prod
WorkingDirectory=/www/webapp/foobar/mongoclient
Restart=always
StandardOutput=syslog
StandardError=syslog
User=versi
Group=versi
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```


redis 
---------------------------

```sh
add-apt-repository ppa:chris-lea/redis-server
apt-get update
apt-get install redis-server
```

redis-cli ping
#>> PONG

ifconfig

eth0      Link encap:Ethernet  HWaddr 04:01:9a:55:fd:01  
          inet addr:159.203.64.119  Bcast:159.203.79.255  Mask:255.255.240.0
          ...

eth1      Link encap:Ethernet  HWaddr 04:01:9a:55:fd:02  

          inet addr: >>>>>> 10.132.1.187 <<<<<<<<  Bcast:10.132.255.255  Mask:255.255.0.0

          ...


vim /etc/redis/redis.conf

```sh
bind localhost 10.132.1.187  -- to restrict only to withing-vps calls
#bind -- to allow calls from external net

requirepass pass
```


```sh
systemctl restart redis-server
```

Tools
-----------------

### display port
netstat -tulpn

