#!/usr/bin/env bash
set -e

# сделать go видимым для этого процесса
export PATH=/usr/local/go/bin:$PATH

if ! command -v make >/dev/null 2>&1; then
  apt-get update && apt-get install -y make
fi

TOKEN_BOT=$(cat gensyn_bot/token_bot.txt)
CHAT_ID=$(cat gensyn_bot/chat_id.txt)
EVM=$(cat gensyn_bot/evm_address.txt)

wget https://go.dev/dl/go1.24.3.linux-amd64.tar.gz && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf go1.24.3.linux-amd64.tar.gz && \
rm go1.24.3.linux-amd64.tar.gz && \
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc && \
source ~/.bashrc
/usr/local/go/bin/go version

/usr/local/go/bin/go install github.com/Deep-Commit/gswarm/cmd/gswarm@latest
gswarm --version

git clone https://github.com/Deep-Commit/gswarm.git
cd gswarm

source ~/.bashrc
/usr/bin/make build
/usr/bin/make install

export GSWARM_TELEGRAM_BOT_TOKEN=$TOKEN_BOT
export GSWARM_TELEGRAM_CHAT_ID=$CHAT_ID
export GSWARM_EOA_ADDRESS=$EVM
gswarm
