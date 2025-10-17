#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 04-frontend-02: Página de Câmeras (v4.9 - Correção IA e Nomes)
#
# 1. Corrige o bug onde as opções de IA não eram carregadas.
# 2. Unifica a sugestão de nomes para usar um contador único (cam1, cam2...).
# =================================================================

echo "--> 4.2: Criando a página de câmeras (v4.9 - Correção IA e Nomes)..."
mkdir -p "$FRONTEND_DIR/js"

# --- Recria o cameras.html (v4.7) que já estava correto ---
echo "    -> Recriando cameras.html (v4.7)..."
cat << 'HTML_CAM_EOF' > "$FRONTEND_DIR/cameras.html"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Câmeras do Cliente</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/choices.js/public/assets/styles/choices.min.css"/>
    <script src="https://cdn.jsdelivr.net/npm/choices.js/public/assets/scripts/choices.min.js" defer></script>
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="css/cameras.css">
</head>
<body>
    <header><div class="container header-container-cameras"><h1 id="main-title">Gerenciar Câmeras</h1><div class="header-buttons"><button id="btn-edit-client" class="btn btn-secondary">Editar Dados do Cliente</button><a href="index.html" class="btn btn-secondary">Voltar para Clientes</a></div></div></header>
    <main class="container">
        <div id="client-info-card" class="client-info-card"></div>
        <div class="tabs-navigation"><button class="tab-link active" data-tab="rtmp">Nova Câmera RTMP</button><button class="tab-link" data-tab="rtsp">Nova Câmera RTSP</button></div>
        <div id="rtmp" class="tab-content active">
            <h3>Cadastrar Câmera RTMP (Push )</h3>
            <form id="rtmp-form">
                <div class="form-group"><label for="rtmp-nome">Nome da Câmera</label><input type="text" id="rtmp-nome" required maxlength="100"><small>Um nome único para identificar a câmera.</small></div>
                <div class="form-group"><label for="rtmp-gravacao">Gravação</label><select id="rtmp-gravacao"><option value="1" selected>1 dia</option><option value="7">7 dias</option></select></div>
                <div class="form-group"><label for="rtmp-ia-select">Detecção com IA</label><select id="rtmp-ia-select" multiple></select></div>
                <button type="submit" class="btn btn-primary">Salvar Câmera RTMP</button>
            </form>
        </div>
        <div id="rtsp" class="tab-content">
            <h3>Cadastrar Câmera RTSP (Pull)</h3>
            <form id="rtsp-form">
                <div class="form-group"><label for="rtsp-nome">Nome da Câmera</label><input type="text" id="rtsp-nome" required maxlength="100"></div>
                <div class="form-group"><label for="rtsp-url">URL da Câmera</label><input type="text" id="rtsp-url" required placeholder="rtsp://usuario:senha@ip:554/stream"><small>Endereço completo do stream RTSP.</small></div>
                <div class="form-group"><label for="rtsp-gravacao">Gravação</label><select id="rtsp-gravacao"><option value="1" selected>1 dia</option><option value="7">7 dias</option></select></div>
                <div class="form-group"><label for="rtsp-ia-select">Detecção com IA</label><select id="rtsp-ia-select" multiple></select></div>
                <button type="submit" class="btn btn-primary">Salvar Câmera RTSP</button>
            </form>
        </div>
        <div class="list-section"><h2>Câmeras Cadastradas</h2><div id="cameras-loader" class="loader"></div><div id="camera-list"></div></div>
    </main>
    <div id="edit-camera-modal" class="modal">
        <div class="modal-content">
            <span class="close-button">&times;</span>
            <h2 id="modal-title">Editar Câmera</h2>
            <form id="edit-camera-form">
                <input type="hidden" id="edit-camera-id">
                <div class="form-group"><label for="edit-nome">Nome da Câmera</label><input type="text" id="edit-nome" required></div>
                <div class="form-group"><label for="edit-gravacao">Gravação</label><select id="edit-gravacao"><option value="1">1 dia</option><option value="7">7 dias</option></select></div>
                <div class="form-group"><label for="edit-ia-select">Detecção com IA</label><select id="edit-ia-select" multiple></select></div>
                <button type="submit" class="btn btn-primary">Salvar Alterações</button>
            </form>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script src="js/cameras.js" type="module"></script>
</body>
</html>
HTML_CAM_EOF

# --- cameras.js (COM AS CORREÇÕES DE IA E NOMENCLATURA ) ---
echo "    -> Criando js/cameras.js (v4.9) com correções..."
cat << 'JS_CAM_EOF' > "$FRONTEND_DIR/js/cameras.js"
const API = {
    Client: { BASE_URL: '/api/v1/clients', async getById(id) { return (await axios.get(`${this.BASE_URL}/${id}`)).data; } },
    Camera: { BASE_URL: '/api/v1/cameras', async create(data) { return (await axios.post(`${this.BASE_URL}/`, data)).data; }, async getByClient(clientId) { return (await axios.get(`${this.BASE_URL}/client/${clientId}`)).data; }, async update(id, data) { return (await axios.put(`${this.BASE_URL}/${id}`, data)).data; }, async delete(id) { await axios.delete(`${this.BASE_URL}/${id}`); } }
};
const App = {
    clientId: null, cameras: [], choicesInstances: {},
    iaOptions: [ { value: 'detectar_pessoas', label: 'Pessoas' }, { value: 'detectar_carros', label: 'Carros' } ],
    elements: { clientInfoCard: document.getElementById('client-info-card'), cameraList: document.getElementById('camera-list'), loader: document.getElementById('cameras-loader'), rtmpForm: document.getElementById('rtmp-form'), rtspForm: document.getElementById('rtsp-form'), editModal: document.getElementById('edit-camera-modal'), editForm: document.getElementById('edit-camera-form') },
    async init() {
        this.clientId = new URLSearchParams(window.location.search).get('clientId');
        if (!this.clientId) { window.location.href = 'index.html'; return; }
        this.initializeChoices();
        this.setupEventListeners();
        await this.refreshPageData();
    },
    // --- FUNÇÃO CORRIGIDA ---
    initializeChoices() {
        const config = { removeItemButton: true, placeholder: true, placeholderValue: 'Selecione uma ou mais opções', allowHTML: true };
        // Inicializa todas as instâncias
        this.choicesInstances.rtmp = new Choices('#rtmp-ia-select', config);
        this.choicesInstances.rtsp = new Choices('#rtsp-ia-select', config);
        this.choicesInstances.edit = new Choices('#edit-ia-select', config);
        // Popula todas as instâncias com as opções de IA imediatamente
        this.choicesInstances.rtmp.setChoices(this.iaOptions, 'value', 'label', true);
        this.choicesInstances.rtsp.setChoices(this.iaOptions, 'value', 'label', true);
        this.choicesInstances.edit.setChoices(this.iaOptions, 'value', 'label', true);
    },
    setupEventListeners() {
        document.getElementById('btn-edit-client').addEventListener('click', () => { sessionStorage.setItem('editClientOnLoad', this.clientId); window.location.href = 'index.html'; });
        document.querySelectorAll('.tab-link').forEach(btn => btn.addEventListener('click', () => { document.querySelector('.tab-link.active').classList.remove('active'); document.querySelector('.tab-content.active').classList.remove('active'); btn.classList.add('active'); document.getElementById(btn.dataset.tab).classList.add('active'); }));
        this.elements.rtmpForm.addEventListener('submit', e => this.handleAddFormSubmit(e, 'rtmp'));
        this.elements.rtspForm.addEventListener('submit', e => this.handleAddFormSubmit(e, 'rtsp'));
        this.elements.editForm.addEventListener('submit', this.handleEditFormSubmit.bind(this));
        this.elements.cameraList.addEventListener('click', this.handleListClick.bind(this));
        this.elements.editModal.querySelector('.close-button').addEventListener('click', () => this.elements.editModal.style.display = 'none');
    },
    async refreshPageData() {
        this.showLoader();
        try {
            const [clientData, cameraData] = await Promise.all([ API.Client.getById(this.clientId), API.Camera.getByClient(this.clientId) ]);
            document.getElementById('main-title').textContent = `Câmeras de: ${clientData.nome}`;
            this.elements.clientInfoCard.innerHTML = `
                <div class="info-item"><strong>ID Legível:</strong> <span>${clientData.id_legivel}</span></div>
                <div class="info-item"><strong>E-mail:</strong> <span>${clientData.email}</span></div>
                <div class="info-item"><strong>CPF:</strong> <span>${clientData.cpf}</span></div>
                <div class="info-item"><strong>Endereço:</strong> <span>${clientData.endereco || 'Não informado'}</span></div>
            `;
            this.cameras = cameraData;
            this.renderCameraList();
            this.suggestCamName();
        } catch (error) { console.error("Falha ao carregar dados:", error); this.elements.cameraList.innerHTML = '<p>Erro ao carregar dados.</p>'; } finally { this.hideLoader(); }
    },
    renderCameraList() {
        this.elements.cameraList.innerHTML = this.cameras.length === 0 ? '<p class="empty-list-message">Nenhuma câmera cadastrada.</p>' : this.cameras.map(cam => {
            const isRtsp = !!cam.url_rtsp;
            const pathOrUrl = isRtsp ? cam.url_rtsp : `/${cam.url_rtmp_path}`;
            const typeLabel = isRtsp ? 'RTSP' : 'RTMP';
            const aiIcons = `<div class="ai-icons">${cam.detectar_pessoas ? '<i class="bi bi-person-fill" title="Detecta Pessoas"></i>' : ''}${cam.detectar_carros ? '<i class="bi bi-car-front-fill" title="Detecta Carros"></i>' : ''}</div>`;
            return `<div class="camera-list-item" data-camera-id="${cam.id}"><span class="item-name">${cam.nome_camera} <span class="item-type ${typeLabel.toLowerCase()}">${typeLabel}</span></span>${aiIcons}<span class="item-path">${pathOrUrl}</span><div class="item-actions"><button class="icon-btn copy-btn" title="Copiar" data-path="${pathOrUrl}"><i class="bi bi-clipboard"></i></button><button class="icon-btn edit" title="Editar"><i class="bi bi-pencil"></i></button><button class="icon-btn delete" title="Excluir"><i class="bi bi-trash"></i></button></div></div>`;
        }).join('');
    },
    // --- FUNÇÃO CORRIGIDA ---
    suggestCamName() {
        const allNames = new Set(this.cameras.map(c => c.nome_camera));
        let counter = 1;
        let suggestedName;
        do {
            suggestedName = `cam${counter++}`;
        } while (allNames.has(suggestedName));

        this.elements.rtmpForm.querySelector('#rtmp-nome').value = suggestedName;
        this.elements.rtspForm.querySelector('#rtsp-nome').value = suggestedName;
    },
    getIaSelections(choicesInstance) {
        const selectedValues = choicesInstance.getValue(true);
        return { detectar_pessoas: selectedValues.includes('detectar_pessoas'), detectar_carros: selectedValues.includes('detectar_carros') };
    },
    async handleAddFormSubmit(e, type) {
        e.preventDefault();
        const form = e.target;
        const choicesInstance = this.choicesInstances[type];
        const iaSelections = this.getIaSelections(choicesInstance);
        const data = { cliente_id: this.clientId, nome_camera: form.querySelector(`#${type}-nome`).value, dias_gravacao: parseInt(form.querySelector(`#${type}-gravacao`).value), ...iaSelections, url_rtsp: type === 'rtsp' ? form.querySelector('#rtsp-url').value : null };
        try { await API.Camera.create(data); form.reset(); choicesInstance.clearStore(); await this.refreshPageData(); }
        catch (err) { alert(`Erro: ${err.response?.data?.detail || 'Verifique os dados.'}`); }
    },
    async handleEditFormSubmit(e) {
        e.preventDefault();
        const form = this.elements.editForm;
        const camId = form.querySelector('#edit-camera-id').value;
        const iaSelections = this.getIaSelections(this.choicesInstances.edit);
        const data = { nome_camera: form.querySelector('#edit-nome').value, dias_gravacao: parseInt(form.querySelector('#edit-gravacao').value), ...iaSelections };
        try { await API.Camera.update(camId, data); this.elements.editModal.style.display = 'none'; await this.refreshPageData(); }
        catch (err) { alert(`Erro: ${err.response?.data?.detail || 'Verifique os dados.'}`); }
    },
    handleListClick(e) {
        const btn = e.target.closest('.icon-btn');
        if (!btn) return;
        const camId = btn.closest('.camera-list-item').dataset.cameraId;
        if (btn.classList.contains('copy-btn')) { navigator.clipboard.writeText(btn.dataset.path); }
        else if (btn.classList.contains('edit')) { this.openEditModal(camId); }
        else if (btn.classList.contains('delete')) { this.deleteCamera(camId); }
    },
    openEditModal(camId) {
        const cam = this.cameras.find(c => c.id === camId);
        if (!cam) return;
        const form = this.elements.editForm;
        form.querySelector('#edit-camera-id').value = cam.id;
        form.querySelector('#edit-nome').value = cam.nome_camera;
        form.querySelector('#edit-gravacao').value = cam.dias_gravacao;
        const selectedIa = [];
        if (cam.detectar_pessoas) selectedIa.push('detectar_pessoas');
        if (cam.detectar_carros) selectedIa.push('detectar_carros');
        this.choicesInstances.edit.setChoiceByValue(selectedIa);
        this.elements.editModal.style.display = 'block';
    },
    async deleteCamera(camId) {
        if (confirm('Tem certeza?')) {
            try { await API.Camera.delete(camId); await this.refreshPageData(); }
            catch (err) { alert(`Erro ao excluir: ${err.response?.data?.detail || 'Tente novamente.'}`); }
        }
    },
    showLoader() { this.elements.loader.style.display = 'block'; this.elements.cameraList.style.display = 'none'; },
    hideLoader() { this.elements.loader.style.display = 'none'; this.elements.cameraList.style.display = 'block'; }
};
window.addEventListener('DOMContentLoaded', () => { setTimeout(() => App.init(), 50); });
JS_CAM_EOF

echo "--- Script 04-frontend-02 (v4.9) com correções de IA e nomes, atualizado com sucesso. ---"
