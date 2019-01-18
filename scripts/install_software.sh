#!/bin/bash
apt update

# install golang
curl -O https://storage.googleapis.com/golang/go1.11.2.linux-amd64.tar.gz
tar -xf go1.11.2.linux-amd64.tar.gz
mv go /usr/local 2>/dev/null
ln -s /usr/local/go/bin/go /usr/bin/go

# configure go
mkdir -p $HOME/go
# comment below 3 lines, check if still works.
echo "export GOROOT=/usr/local/go" >> ~/.profile
echo "export GOPATH=\$HOME/go" >> ~/.profile
echo "export PATH=\$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.profile

# download go server
go get github.com/hashicorp/http-echo
ln -s ~/go/bin/http-echo /usr/bin/http-echo

# move logrotate config file
mv /home/ubuntu/go-logrotate /etc/logrotate.d/go-logrotate

# install aws-cli or s3cmd and configure it. create bucket
apt install python-setuptools -y
cd /tmp
curl -LO https://github.com/s3tools/s3cmd/releases/download/v2.0.1/s3cmd-2.0.1.tar.gz
tar -xf s3cmd-*.tar.gz
cd s3cmd-*
python setup.py install