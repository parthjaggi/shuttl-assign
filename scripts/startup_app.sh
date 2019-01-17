#!/bin/bash
sudo http-echo -listen=:80 -text="hello world, my deployment_group is: ${deployment_group}" &