#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
# Preseed debconf to avoid kernel prompts
echo "linux-base linux-base/do-bootloader boolean false" | debconf-set-selections
echo "* libraries/restart-without-asking boolean true" | debconf-set-selections

set -euo pipefail

############################################
#               USER SETTINGS
############################################

# Твои прежние «стартовые» флаги — оставляю.
CONNECT_TO_TESTNET=${CONNECT_TO_TESTNET:-true}   # Сохранил твой флаг и интерактивный вопрос ниже
USE_BIG_SWARM=${USE_BIG_SWARM:-false}            # Больше не используется новой версией — оставил как заглушку
PARAM_B=${PARAM_B:-7}                            # Больше не используется — оставил как заглушку
PUSH_TO_HF=${PUSH_TO_HF:-false}                  # Устарело — логика ниже теперь спрашивает про push отдельно
CPU_ONLY=${CPU_ONLY:-true}                       # Можно оставить, но новая логика не ветвится по GPU

# Версия GenRL (из нового апдейта)
GENRL_TAG=${GENRL_TAG:-"0.1.6"}

# Контракты из новой версии
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PRG_CONTRACT="0x51D4db531ae706a6eC732458825465058fA23a35"

# PRG игра (AI Prediction Market) — по умолчанию true, ниже будет вопрос
export PRG_GAME=${PRG_GAME:-true}

# Хагингфейс токен — используем твой прежний HF_TOKEN, если задан
# HF_TOKEN=${HF_TOKEN:-""}
export HUGGINGFACE_ACCESS_TOKEN=${HUGGINGFACE_ACCESS_TOKEN:-"None"}

# Общие пути/папки
ROOT=$PWD
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Необязательные параметры окружения (как в новом скрипте)
export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes
export CONNECT_TO_TESTNET

# peer/public/host maddr — в новой версии не используются, но оставим переменные,
# чтобы не ломать твои возможные внешние сценарии
export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS

DEFAULT_PUB_MULTI_ADDRS=""
DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"

PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

# Ключ для PeerID — как у тебя
DEFAULT_IDENTITY_PATH="$ROOT/swarm.pem"
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

# Цветные эхо — как у тебя
GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() { echo -e "$GREEN_TEXT$1$RESET_TEXT"; }
echo_blue()  { echo -e "$BLUE_TEXT$1$RESET_TEXT"; }
echo_red()   { echo -e "$RED_TEXT$1$RESET_TEXT"; }

############################################
#                CLEANUP (твоя логика)
############################################
cleanup() {
    echo_green ">> Shutting down trainer..."
    # твои диагностические строки оставил
    (command -v node >/dev/null 2>&1 && node -v) || true
    (command -v nvm  >/dev/null 2>&1 && nvm ls) || true
    (command -v yarn >/dev/null 2>&1 && yarn -v) || true

    # Удалять json из modal-login (ты раньше комментировал rm) — в новой версии удаление безопасно:
    # rm -r "$ROOT_DIR/modal-login/temp-data/"*.json 2>/dev/null || true

    # Гасим всю группу процессов
    kill -- -$$ 2>/dev/null || true
    exit 0
}
errnotify() {
    echo_red ">> An error was detected while running rl-swarm. See $ROOT/logs for full logs."
}
trap cleanup EXIT
trap errnotify ERR

############################################
#                 BANNER
############################################
echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    From Gensyn
EOF
echo -en "$RESET_TEXT"

############################################
#      Твои интерактивные вопросы (сохранены)
############################################

# CONNECT_TO_TESTNET — действительно используется (запуск modal-login)
if [ -z "${CONNECT_TO_TESTNET+x}" ]; then
    while true; do
        read -p ">> Would you like to connect to the Testnet? [Y/n] " yn
        yn=${yn:-Y}
        case $yn in
            [Yy]*) CONNECT_TO_TESTNET=true;  break ;;
            [Nn]*) CONNECT_TO_TESTNET=false; break ;;
        esac
    done
fi

# USE_BIG_SWARM — больше не влияет на конфиг новой версии. Сохраняю вопрос, но помечаю как ignored.
if [ -z "${USE_BIG_SWARM+x}" ]; then
    while true; do
        read -p ">> Which swarm …? [A/b] (ignored by new version) " ab
        ab=${ab:-A}
        case $ab in
            [Aa]*|[Bb]*) break ;;
        esac
    done
    echo_blue ">> Note: 'USE_BIG_SWARM' is ignored by the new version."
fi

# PARAM_B — тоже больше не используется. Оставляю вопрос-заглушку.
if [ -z "${PARAM_B+x}" ]; then
    while true; do
        read -p ">> How many parameters (in billions)? [0.5, 1.5, 7, 32, 72] (ignored by new version) " pc
        pc=${pc:-0.5}
        case $pc in
            0.5|1.5|7|32|72) PARAM_B=$pc; break ;;
        esac
    done
    echo_blue ">> Note: 'PARAM_B' is ignored by the new version."
fi

############################################
#                 LOGS DIR
############################################
mkdir -p "$ROOT/logs"

############################################
#        Modal login / Testnet Wallet
############################################
if [ "$CONNECT_TO_TESTNET" = true ]; then
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login
    source ~/.nvm/nvm.sh && nvm install 22 && nvm use 22 && nvm alias default 22

    # Node/NVM
    if ! command -v node >/dev/null 2>&1; then
        echo "Node.js not found. Installing NVM and latest Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        # shellcheck disable=SC1090
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
        nvm use node
        nvm alias default node
    fi

    if ! command -v yarn >/dev/null 2>&1; then
        if grep -qi "ubuntu" /etc/os-release 2>/dev/null || uname -r | grep -qi "microsoft"; then
            echo "Detected Ubuntu/WSL. Installing Yarn via apt..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt update && sudo apt install -y yarn
        else
            echo "Installing Yarn globally with npm…"
            npm install -g --silent yarn
        fi
    fi

    # Проставляем адреса контрактов в .env (строки 3 и 4 — как в новом апдейте)
    ENV_FILE="$ROOT/modal-login/.env"
    touch "$ENV_FILE"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "3s|.*|SWARM_CONTRACT_ADDRESS=$SWARM_CONTRACT|" "$ENV_FILE"
        sed -i '' "4s|.*|PRG_CONTRACT_ADDRESS=$PRG_CONTRACT|"   "$ENV_FILE"
    else
        sed -i "3s|.*|SWARM_CONTRACT_ADDRESS=$SWARM_CONTRACT|" "$ENV_FILE"
        sed -i "4s|.*|PRG_CONTRACT_ADDRESS=$PRG_CONTRACT|"     "$ENV_FILE"
    fi

    # Сборка + запуск (как в новом скрипте)
    yarn install --immutable
    echo "Building server"
    yarn build > "$ROOT/logs/yarn.log" 2>&1
    yarn start >> "$ROOT/logs/yarn.log" 2>&1 &

    SERVER_PID=$!
    echo "Started server process: $SERVER_PID"
    sleep 5

    # Пытаемся открыть браузер
    if open http://localhost:3000 2>/dev/null; then
        echo_green ">> Successfully opened http://localhost:3000 in your default browser."
    else
        echo ">> Failed to open http://localhost:3000. Please open it manually."
    fi

    cd ..

    echo_green ">> Waiting for modal userData.json to be created..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 5
    done
    echo "Found userData.json. Proceeding..."

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    export ORG_ID
    echo "Your ORG_ID is set to: $ORG_ID"

    echo "Waiting for API key to become activated..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "API key is activated! Proceeding..."
            break
        else
            echo "Waiting for API key to be activated..."
            sleep 5
        fi
    done
else
    echo_blue ">> CONNECT_TO_TESTNET=false: modal-login будет пропущен."
fi

############################################
#            Python deps (новые)
############################################
echo_green ">> Getting requirements..."
pip install --upgrade pip

echo_green ">> Installing GenRL..."
pip install "gensyn-genrl==${GENRL_TAG}"
pip install "reasoning-gym>=0.1.20"
pip install "hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd"

############################################
#        Конфиги rg-swarm.yaml (новые)
############################################
mkdir -p "$ROOT/configs"
if [ -f "$ROOT/configs/rg-swarm.yaml" ]; then
    if ! cmp -s "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"; then
        if [ -z "${GENSYN_RESET_CONFIG:-}" ]; then
            echo_green ">> Found differences in rg-swarm.yaml. To reset to default, set GENSYN_RESET_CONFIG=1"
        else
            echo_green ">> Backing up existing rg-swarm.yaml and resetting to default."
            mv "$ROOT/configs/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml.bak"
            cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
        fi
    fi
else
    cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
fi

############################################
#      Hugging Face push (новая логика)
############################################
# Если у тебя уже задан HF_TOKEN — используем его.
# if [ -n "$HF_TOKEN" ]; then
#     export HUGGINGFACE_ACCESS_TOKEN="$HF_TOKEN"
# else
#     echo -en "$GREEN_TEXT"
#     read -p ">> Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
#     echo -en "$RESET_TEXT"
#     yn=${yn:-N}
#     case $yn in
#         [Yy]*)
#             read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN ;;
#         *)
#             HUGGINGFACE_ACCESS_TOKEN="None" ;;
#     esac
#     export HUGGINGFACE_ACCESS_TOKEN
# fi

MODEL_NAME="Qwen/Qwen3-0.6B"

echo -en "$GREEN_TEXT"
read -p ">> Enter the name of the model you want to use in huggingface repo/name format, or press [Enter] to use the default model. " MODEL_NAME
echo -en "$RESET_TEXT"
if [ -n "${MODEL_NAME:-}" ]; then
    export MODEL_NAME
    echo_green ">> Using model: $MODEL_NAME"
else
    echo_green ">> Using default model from config"
fi

echo -en "$GREEN_TEXT"
read -p ">> Would you like your model to participate in the AI Prediction Market? [Y/n] " yn_prg
echo -en "$RESET_TEXT"
if [ "$yn_prg" = "n" ] || [ "$yn_prg" = "N" ]; then
    PRG_GAME=false
else
    PRG_GAME=true
fi
export PRG_GAME
echo_green ">> Playing PRG game: $PRG_GAME"

############################################
#                 GO!
############################################
echo_green ">> Good luck in the swarm!"
echo_blue  ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

# НОВЫЙ вход — вместо старого hivemind_exp.gsm8k.train_single_gpu
python -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/rgym_exp/config" \
    --config-name "rg-swarm.yaml"

wait  # Keep script running until Ctrl+C
