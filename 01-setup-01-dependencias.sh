#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 0.3: Instalação de Dependências Essenciais (v1.1)
#
# Adiciona a instalação do 'jq' para processamento de JSON.
# =================================================================

echo "--------------------------------------------------"
echo "Iniciando verificação e instalação de dependências..."
echo "--------------------------------------------------"

# Atualiza a lista de pacotes
echo "Atualizando lista de pacotes (apt-get update)..."
sudo apt-get update -y
echo

# Instala utilitários básicos
install_package "curl"
install_package "apt-transport-https"
install_package "ca-certificates"
install_package "gnupg"
install_package "lsb-release"
install_package "jq" # <-- ADICIONADO

echo

# Verifica e instala o Docker
if command -v docker &> /dev/null; then
    echo "-> Docker já está instalado."
else
    echo "-> Instalando Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture  ) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs  ) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "-> Docker instalado com sucesso. É recomendado sair e logar novamente para usar docker sem 'sudo'."
fi
echo

# Verifica e instala o Docker Compose (standalone)
COMPOSE_VERSION="v2.27.0"
if [ -f /usr/local/bin/docker-compose ]; then
    echo "-> Docker Compose (standalone) já está instalado."
else
    echo "-> Instalando Docker Compose (standalone) versão ${COMPOSE_VERSION}..."
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s  )-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "-> Docker Compose (standalone) instalado com sucesso."
fi

echo
echo "--------------------------------------------------"
echo "Verificação de dependências concluída."
echo "--------------------------------------------------"
