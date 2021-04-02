#!/usr/bin/env bash

if [ "$1" == "setup" ]; then
  echo 'extracting snapshot...' \
  && sudo rm -f /var/lib/docker/volumes/server_validator-block-volume/_data/* \
  && sudo tar -I pigz -xvf /home/ftpuser/snapshot.tar.gz -P /var/lib/docker/volumes/server_validator-block-volume/ \
  && sudo chmod +x restart_node.sh && chmod +x snapshot.sh && chmod +x cc.sh \
  && sudo docker-compose -f ./Server/docker-compose.yaml up -d \
  && sudo docker-compose -f ./Client/docker-compose.yaml up -d \
  && sudo docker exec -it creditcoin-client ./ccclient sighash \
  && echo 'Above text is your sighash' \
  && echo 'Configuring cron...' \
  && echo "*/30 * * * * /root/CreditcoinDocs-Mainnet/restart_node.sh >> /root/CreditcoinDocs-Mainnet/restart_node.log 2>&1" >> mycron \
  && sudo crontab mycron; rm mycron \
  && read -p "Do you want change sighash? : " CHANGE_WALLET \
  && if [ "$CHANGE_WALLET" == "y" ]; then
            read -p "Input your CTC PRIVATE KEY : " CTC_PRIVKEY2 \
            && read -p "Input your CTC PUBLIC KEY : " CTC_PUBKEY \
            && sudo docker exec sawtooth-validator-default bash echo $CTC_PRIVKEY2 > /etc/sawtooth/keys/validator.priv \
            && sudo docker exec sawtooth-validator-default bash echo $CTC_PUBKEY > /etc/sawtooth/keys/validator.pub \
            && echo 'Restarting CTC Server...' \
            && sudo docker-compose -f ./Server/docker-compose.yaml down \
            && sudo docker-compose -f ./Server/docker-compose.yaml up -d
     fi
  echo 'Done! 🎉' \
  && echo 'by Woosung Choi' \
  && echo 'Below is a list of containers.'\
  && sudo docker ps
fi
