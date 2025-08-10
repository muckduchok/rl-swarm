#!/bin/sh
set -e

PATH="/usr/local/go/bin:/usr/local/bin:/usr/bin:$HOME/go/bin:$PATH"; export PATH

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
/usr/local/go/bin/go version

cd gswarm

env PATH="/usr/local/go/bin:$PATH" make build
env PATH="/usr/local/go/bin:$PATH" make install

export GSWARM_TELEGRAM_BOT_TOKEN=$TOKEN_BOT
export GSWARM_TELEGRAM_CHAT_ID=$CHAT_ID
export GSWARM_EOA_ADDRESS=$EVM
screen -dmS gswarm-bot gswarm
