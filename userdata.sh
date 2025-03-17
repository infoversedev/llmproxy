#!/bin/bash
pip install --upgrade pip
sudo yum install -y git python3-pip
python3 -m venv myenv
source myenv/bin/activate
cp docker-compose.yml /home/hctllmproxydockerimages/litellm/myenv/
cd /home/hctllmproxydockerimages/litellm/myenv/
pip install docker
pip install docker-compose
#sudo systemctl enable --now docker
#git clone https://github.com/BerriAI/litellm
#cd litellm
echo 'LITELLM_MASTER_KEY="sk-1234"' > .env
echo 'LITELLM_SALT_KEY="sk-1234"' >> .env
git clone https://github.com/infoversedev/llmproxy/
docker compose up

