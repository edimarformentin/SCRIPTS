#!/bin/bash
# Nome do arquivo: 4.9_criar_backend_patch_detector.sh
# Função: Aplica um patch no gerenciar_frigate.py para adicionar a lógica de detecção de GPU.

set -Eeuo pipefail

echo "==== SCRIPT 4.9: APLICANDO PATCH DE DETECÇÃO DE GPU ===="

# Navega para o diretório onde o script a ser modificado está localizado.
cd /home/edimar/SISTEMA/GESTAO_WEB

# Verifica se o arquivo alvo existe antes de tentar modificá-lo.
if [ ! -f "gerenciar_frigate.py" ]; then
    echo "ERRO: O arquivo gerenciar_frigate.py não foi encontrado. Execute os scripts anteriores primeiro."
    exit 1
fi

echo "--> Modificando a função 'selecionar_detector' em gerenciar_frigate.py..."

# Bloco de código Python que será executado para fazer a substituição.
# Ele lê o arquivo, substitui a função inteira e salva o arquivo de volta.
python3 - <<'PYTHON_PATCH'
import re
import sys

# Caminho do arquivo a ser modificado
file_path = "gerenciar_frigate.py"

# Nova implementação da função, com a lógica de detecção de GPU.
# Esta função será inserida no lugar da original.
new_function_code = """
def selecionar_detector():
    # Tenta detectar uma GPU NVIDIA usando o comando 'nvidia-smi'.
    try:
        # Executa o comando e verifica se a saída contém "NVIDIA-SMI".
        # O timeout evita que o script fique preso.
        subprocess.check_output("nvidia-smi", shell=True, text=True, timeout=5)
        print("[INFO] GPU NVIDIA detectada. Configurando detector para CUDA.")
        # Se o comando for bem-sucedido, retorna a configuração para usar a GPU.
        return {
            'tensorrt': {
                'type': 'tensorrt',
                'device': '0' # Usa a primeira GPU detectada
            }
        }
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        # Se o comando falhar (não instalado, não encontrado, erro), assume CPU.
        print("[INFO] Nenhuma GPU NVIDIA encontrada ou 'nvidia-smi' falhou. Usando CPU como detector.")
        return {
            'cpu': {
                'type': 'cpu'
            }
        }
"""

try:
    # Lê o conteúdo original do arquivo.
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Usa expressão regular para encontrar e substituir a função 'selecionar_detector' inteira.
    # O padrão (re.DOTALL) permite que '.' corresponda a quebras de linha.
    pattern = re.compile(r"def selecionar_detector\(\):.*?return \{.*?'type'.*?\}\s*\}", re.DOTALL)

    # Verifica se o padrão foi encontrado antes de substituir.
    if not pattern.search(content):
        print(f"AVISO: A função 'selecionar_detector' padrão não foi encontrada em {file_path}. O patch não será aplicado.")
        sys.exit(0)

    # Substitui o código antigo pelo novo.
    new_content = pattern.sub(new_function_code.strip(), content, count=1)

    # Escreve o conteúdo modificado de volta no arquivo.
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print("--> Patch aplicado com sucesso.")

except FileNotFoundError:
    print(f"ERRO: O arquivo {file_path} não foi encontrado.")
    sys.exit(1)
except Exception as e:
    print(f"Ocorreu um erro inesperado ao aplicar o patch: {e}")
    sys.exit(1)
PYTHON_PATCH

echo "==== SCRIPT 4.9 CONCLUÍDO ===="
