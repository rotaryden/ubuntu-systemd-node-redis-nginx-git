#Ubuntu Server complex setup for Node.js back-ends

Example detailed configuration for Ubuntu Server from scratch, using
- Secured user, disabled root ssh login
- API Node.js back-end (foobar-api-dev)
- Redis for API back-end
- UI supplying Node.js back-end
- Nginx setup as proxy for both Node.js servers and for
static content loading
- git deployments with hook scripts
- systemd service files to run Node.js continuosly 
(like forever or pm2 do, but with native OS means)

Hope it would be useful

Details
=======================
Here is Ubuntu 15.04 server setup from scratch. Hope it woud be useful.

Tested on DigitalOcean, 1 Gb instance.

In the box:
- Secured user, disabled root ssh login
- API Node.js back-end (foobar/api-dev)
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
git remote add vps ssh://web@foobar.com/www/webapp/foobar/api-dev.git
git remote add vps ssh://web@foobar.com/www/webapp/foobar/ui-dev.git
```

and just push to master:

```sh
git push vps master
```

it will update server instance automatically in post-receive hook




##LICENSE

MIT
