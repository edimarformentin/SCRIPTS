#!/bin/bash
# =================================================================
# Script: 04-frontend-04-pagina-player.sh
#
# Propósito:
# Cria a nova página de visualização (player.html) e seu script
# associado (player.js). Esta página será o hub para assistir
# tanto ao vivo quanto às gravações de uma câmera específica.
#
# O que ele faz:
# 1. Cria o arquivo 'player.html' com a estrutura básica:
#    - Um título.
#    - Um elemento <video> para o player.
#    - Um contêiner <div> para a futura timeline.
# 2. Cria o arquivo 'player.js' com a lógica inicial:
#    - Lê o ID da câmera da URL.
#    - Faz uma chamada à API para buscar a lista de gravações.
#    - Exibe os dados recebidos no console para depuração.
# =================================================================

source "/home/edimar/SCRIPTS/00-configuracao-central.sh"

echo "--> 4.4: Criando a página do Player de Vídeo..."

# --- Cria o arquivo player.html ---
echo "    -> Criando frontend/player.html..."
cat << 'HTML_EOF' > "$FRONTEND_DIR/player.html"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Player VaaS</title>
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="css/player.css">
</head>
<body>
    <header>
        <div class="container">
            <h1 id="camera-title">Player de Vídeo</h1>
            <a href="index.html" class="btn btn-secondary">Voltar para Clientes</a>
        </div>
    </header>
    <main class="container">
        <div class="player-container">
            <video id="main-video-player" controls autoplay muted></video>
        </div>
        <div class="timeline-container">
            <h2>Linha do Tempo</h2>
            <div id="timeline">
                <!-- A timeline interativa será renderizada aqui pelo JS -->
            </div>
        </div>
    </main>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script src="js/player.js" type="module"></script>
</body>
</html>
HTML_EOF

# --- Cria o arquivo de estilo player.css ---
echo "    -> Criando frontend/css/player.css..."
cat << 'CSS_EOF' > "$FRONTEND_DIR/css/player.css"
.player-container {
    width: 100%;
    background-color: #000;
    margin-bottom: 20px;
}
#main-video-player {
    width: 100%;
    height: auto;
    max-height: 70vh;
}
.timeline-container {
    background-color: var(--surface-color );
    padding: 20px;
    border-radius: 8px;
    box-shadow: var(--shadow);
}
CSS_EOF

# --- Cria o arquivo player.js com a lógica inicial ---
echo "    -> Criando frontend/js/player.js..."
cat << 'JS_EOF' > "$FRONTEND_DIR/js/player.js"
const API = {
    BASE_URL: '/api/v1/cameras',
    async getRecordings(cameraId) {
        try {
            const response = await axios.get(`${this.BASE_URL}/${cameraId}/recordings`);
            return response.data;
        } catch (error) {
            console.error(`Falha ao buscar gravações para a câmera ${cameraId}:`, error);
            alert('Não foi possível carregar os dados das gravações.');
            return [];
        }
    }
};

const App = {
    cameraId: null,

    async init() {
        console.log("Player.js iniciado.");

        // 1. Obter o ID da câmera da URL
        const urlParams = new URLSearchParams(window.location.search);
        this.cameraId = urlParams.get('cameraId');

        if (!this.cameraId) {
            alert('ID da câmera não fornecido na URL.');
            window.location.href = 'index.html';
            return;
        }

        console.log(`ID da Câmera: ${this.cameraId}`);

        // 2. Buscar os dados das gravações
        const recordings = await API.getRecordings(this.cameraId);

        // 3. Exibir os dados no console para validação
        console.log("Dados das gravações recebidos da API:");
        console.table(recordings);

        // Próximos passos:
        // - Renderizar a timeline com base nos dados de 'recordings'.
        // - Implementar a lógica para tocar o vídeo ao clicar na timeline.
    }
};

document.addEventListener('DOMContentLoaded', () => App.init());
JS_EOF

echo "--- Página do Player criada com sucesso."
