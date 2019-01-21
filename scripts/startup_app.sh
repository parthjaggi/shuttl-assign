#!/bin/bash
sudo -u ubuntu bash << EOF
pip install awscli --user
mkdir -p /home/ubuntu/http-echo-logs
touch /home/ubuntu/http-echo-logs/requests.log
http-echo -listen=:3000 -text="hello world, my deployment_group is: ${deployment_group}" &>> /home/ubuntu/http-echo-logs/requests.log &
EOF