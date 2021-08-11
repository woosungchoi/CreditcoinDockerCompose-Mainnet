sudo apt update
sudo apt install build-essential libboost-all-dev libcrypto++-dev -y

/usr/bin/g++-9 -O2 -Wall ./*.cpp -o ./hashServer -lboost_system -lpthread -lcryptopp
