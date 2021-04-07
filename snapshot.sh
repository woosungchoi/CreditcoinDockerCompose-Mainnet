#!/bin/bash

/bin/echo "도커를 정지합니다..."
# Server shutdown
/usr/local/bin/docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Client/docker-compose.yaml down
sleep 1
/usr/local/bin/docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml down
sleep 1
/bin/echo "스냅샷 찍기 시작..."
# Take snapshot
DATEX=$(/bin/date +%y%m%d_%H%M%S)
TargetFile="/home/ftpuser/CTC_Snapshot_$DATEX.tar.gz"
/bin/tar -I pigz -Scf $TargetFile -P /var/lib/docker/volumes/server_validator-block-volume/_data/ 
/bin/echo "스냅샷 저장 완료..."
sleep 1

# Server Up
/bin/echo "도커를 시작합니다..."
/usr/local/bin/docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml up -d
sleep 1
/usr/local/bin/docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Client/docker-compose.yaml up -d
sleep 1