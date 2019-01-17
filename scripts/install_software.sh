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

# start server
http-echo -listen=:80 -text="hello world" &

