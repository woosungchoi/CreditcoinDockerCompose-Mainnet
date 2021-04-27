sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Client/docker-compose.yaml down
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml down
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Client/docker-compose.yaml pull
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml pull
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Server/docker-compose.yaml up -d
sleep 5
sudo docker-compose -f /root/CreditcoinDockerCompose-Mainnet/Client/docker-compose.yaml up -d