sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Client/docker-compose.yaml down
sleep 5
sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Server/docker-compose.yaml down
sleep 5
sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Client/docker-compose.yaml pull
sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Server/docker-compose.yaml pull
sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Server/docker-compose.yaml up -d
sleep 5
sudo docker-compose -f /root/CreditcoinDocs-Mainnet/Client/docker-compose.yaml up -d