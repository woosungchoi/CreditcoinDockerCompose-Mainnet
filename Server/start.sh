#!/bin/bash

hashServerPid=$(head -n 1 /root/CreditcoinDockerCompose-Mainnet/Server/hashServer.pid 2> /dev/null)
kill $hashServerPid 2> /dev/null
rm /root/CreditcoinDockerCompose-Mainnet/Server/hashServer.pid 2> /dev/null
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml down 2>/dev/null
sudo docker network prune -f
nohup /root/CreditcoinDockerCompose-Mainnet/Server/hashServer 10000 >> /root/CreditcoinDockerCompose-Mainnet/Server/hashServer.log &
hashServerPid=$!
echo $hashServerPid > /root/CreditcoinDockerCompose-Mainnet/Server/hashServer.pid
renice -n 10 -p $hashServerPid
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml up -d