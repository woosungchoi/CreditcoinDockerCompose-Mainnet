#!/bin/bash
# creditcoin command selection

until [ "$opt" = "0" ] 
do
	CurBlkNum=0
	PreBlkNum=0

	echo "=================================================="
	echo "1. 서버 및 클라이언트 실행" 
	echo "2. docker container 상태 확인"
	echo "3. 내 서버원장의 블록높이 확인" 
	echo "4. 블록높이 감시 (1시간 동일 시 재기동)"
	echo "5. 내가 캔 블록확인 (종료시 Ctrl+C)" 
	echo "6. validator 디버그 메시지 확인 (종료시 Ctrl+C)"
	echo "7. peer 확인 (종료시 Ctrl+C)"
	echo "8. 서버 및 클라이언트 종료" 
	echo "0. 스크립트 종료"
	echo "--------------------------------------------------"
	printf "원하는 기능의 번호를 선택 후 엔터를 입력하세요 : "

	read opt

	echo "=================================================="

	case $opt in 
		1)
			echo "서버 및 클라이언트 도커 컨테이너를 실행합니다..."
			sudo docker-compose -f ./Server/docker-compose.yaml up -d
			sleep 1
			sudo docker-compose -f ./Client/docker-compose.yaml up -d
			sleep 1
			;;
		2)
			echo "docker container 상태는 아래와 같습니다..."
			sudo docker container ls 
			;;
		3)
			echo "현재 서버 원장의 블록높이는 아래와 같습니다..."
			sudo docker exec -it creditcoin-client ./ccclient tip
			;;
		4)
			while true
			do
				CurBlkNum=$(sudo docker exec -it creditcoin-client ./ccclient tip | awk '/^[0-9]/{print int($0)}')

				if [ "$PreBlkNum" -eq 0 ]
				then 
					echo "$(date "+%Y-%m-%d %H:%M:%S") | 현재 블록높이는 $CurBlkNum입니다."
				elif [ "$PreBlkNum" -eq "$CurBlkNum" ]
				then
					echo "$(date "+%Y-%m-%d %H:%M:%S") | 현재 블록높이가 1시간 전과 같아 서버를 재기동합니다..."
					sudo docker-compose -f ./Client/docker-compose.yaml down 			
					sleep 1
					sudo docker-compose -f ./Server/docker-compose.yaml down
					sleep 1
					sudo docker-compose -f ./Server/docker-compose.yaml up -d
					sleep 1
					sudo docker-compose -f ./Client/docker-compose.yaml up -d
					sleep 1
				else 
					echo "$(date "+%Y-%m-%d %H:%M:%S") | 1시간 전 블록높이는 $PreBlkNum이고 현재 블록높이는 $CurBlkNum입니다."
				fi

				PreBlkNum=$CurBlkNum
				sleep 3600
			done
			;;
		5)
			echo "현재까지 채굴한 블록번호와 공개키는 아래와 같습니다..."
			pub=$(sudo docker exec -it sawtooth-validator-default sh -c "cat /etc/sawtooth/keys/validator.pub")
			sudo docker exec -it sawtooth-validator-default bash -c "sawtooth block list --url http://rest-api:8008 -F csv" | grep $pub | awk -F, 'BEGIN{printf("BLKNUM	SIGNER\n")} {printf("%s\t%s\n", $1, $5)}'
			;;
		6)
			sudo docker exec sawtooth-validator-default tail -f /var/log/sawtooth/validator-debug.log
			;;
		7) 
			while true
			do
				timestamp() {
				  ts=`date +"%Y-%m-%d %H:%M:%S"`
				  echo -n $ts
				}
				REST_API_ENDPOINT=localhost:8008
				peers=`curl http://$REST_API_ENDPOINT/peers 2>/dev/null | grep tcp:// | cut -d \" -f2 | sed 's/^.*\///'`
				# For dynamic peering, need to log  nc  probe results to view history of connected peers over time.
				for p in $peers; do
				  ipv4_address=`echo $p | cut -d: -f1`
				  port=`echo $p | cut -d: -f2`
				  timestamp
				  preamble=" Peer $ipv4_address:$port is"
				  if nc -z $ipv4_address $port
				  then
				    echo "$preamble open"
				  else
				    echo "$preamble closed"
				  fi
				done
			sleep 60
			done | tee -a ctcpeer.result
			;;
		8)
			echo "서버 및 클라이언트 도커 컨테이너를 종료합니다..."
			sudo docker-compose -f ./Client/docker-compose.yaml down 			
			sleep 1
			sudo docker-compose -f ./Server/docker-compose.yaml down
			sleep 1
			;;
		0)
			break
			;;
		*)
			echo "실행할 수 없는 옵션입니다"
			;;
	esac
	echo ""
done
