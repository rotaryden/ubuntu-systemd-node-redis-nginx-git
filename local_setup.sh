#!/usr/bin/env bash

cat << EOF >> ~/.ssh/config
Host *
  ServerAliveInterval 50
EOF

