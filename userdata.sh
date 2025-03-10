#!/bin/bash
sudo yum install -y git python3-pip
sudo pip3 install docker
sudo pip3 install docker-compose

git clone https://github.com/BerriAI/litellm
cd litellm
echo 'LITELLM_MASTER_KEY="sk-1234"' > .env
echo 'LITELLM_SALT_KEY="sk-1234"' >> .env
source .env
docker-compose up
