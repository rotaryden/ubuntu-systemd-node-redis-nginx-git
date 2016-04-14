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

##LICENSE

MIT
