#!/bin/bash

CurBlkNum=0
PreBlkNum=0
while true
    do
        CurBlkNum=$(docker exec -it creditcoin-client ./ccclient tip | awk '/^[0-9]/{print int($0)}')

        if [ "$PreBlkNum" -eq 0 ]
            then
                echo "$(date "+%Y-%m-%d %H:%M:%S") | 현재 블록높이는 $CurBlkNum입니다."
        elif [ "$PreBlkNum" -eq "$CurBlkNum" ]
            then
                echo "$(date "+%Y-%m-%d %H:%M:%S") | 현재 블록높이가 30분 전과 같아 서버를 재기동합니다..."
                docker-compose -f ./Client/docker-compose.yaml down
                sleep 1
                docker-compose -f ./Server/docker-compose.yaml down
                sleep 1
                docker-compose -f ./Client/docker-compose.yaml pull
                docker-compose -f ./Server/docker-compose.yaml pull
                docker-compose -f ./Server/docker-compose.yaml up -d
                sleep 1
                docker-compose -f ./Client/docker-compose.yaml up -d
                sleep 1
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S") | 30분 전 블록높이는 $PreBlkNum이고 현재 블록높이는 $CurBlkNum입니다."
        fi
        
        PreBlkNum=$CurBlkNum
        sleep 1800

    done
;;