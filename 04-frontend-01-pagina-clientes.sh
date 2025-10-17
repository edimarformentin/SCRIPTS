#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 1.3.1: Frontend - Página de Clientes (v4.3 - Corrigido)
#
# Corrige o erro [object Object] no cadastro de novos clientes.
# =================================================================

echo "--> 1.3.1: Criando a página de clientes (v4.3 - Corrigido)..."

mkdir -p "$FRONTEND_DIR/css"
mkdir -p "$FRONTEND_DIR/js"

# --- Cria o arquivo index.html ---
echo "    -> Criando index.html..."
cat << 'HTML_EOF' > "$FRONTEND_DIR/index.html"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Painel VaaS - Clientes</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link rel="stylesheet" href="css/style.css">
    <link rel="stylesheet" href="css/cameras.css">
</head>
<body>
    <header>
        <div class="container">
            <h1>Painel de Gestão VaaS</h1>
            <button id="btn-add-client" class="btn btn-primary">Cadastrar Cliente</button>
        </div>
    </header>
    <main class="container">
        <h2>Clientes Cadastrados</h2>
        <p class="instructions">Clique em um cliente para gerenciar suas câmeras.</p>
        <div id="loader" class="loader"></div>
        <table id="clients-table">
            <thead>
                <tr>
                    <th>Nome</th>
                    <th>ID Legível</th>
                    <th>Email</th>
                    <th>CPF</th>
                    <th>Endereço</th>
                    <th>Ações</th>
                </tr>
            </thead>
            <tbody></tbody>
        </table>
    </main>
    <div id="client-modal" class="modal">
        <div class="modal-content">
            <span class="close-button">&times;</span>
            <h2 id="modal-title">Cadastrar Novo Cliente</h2>
            <form id="client-form">
                <input type="hidden" id="client-id">
                <div class="form-group"><label for="nome">Nome Completo</label><input type="text" id="nome" required></div>
                <div class="form-group"><label for="email">E-mail</label><input type="email" id="email" required></div>
                <div class="form-group"><label for="cpf">CPF</label><input type="text" id="cpf" required></div>
                <div class="form-group"><label for="endereco">Endereço</label><textarea id="endereco"></textarea></div>
                <button type="submit" id="save-button" class="btn btn-primary">Salvar Cliente</button>
            </form>
            <div id="form-message" class="message"></div>
        </div>
    </div>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script src="js/app.js" type="module"></script>
</body>
</html>
HTML_EOF

# --- Cria o arquivo app.js (com a chamada da API corrigida ) ---
echo "    -> Criando js/app.js com correção..."
cat << 'JS_APP_EOF' > "$FRONTEND_DIR/js/app.js"
const API = {
    BASE_URL: '/api/v1/clients',
    async getClients() { return (await axios.get(`${this.BASE_URL}/`)).data; },
    async createClient(data) { return (await axios.post(`${this.BASE_URL}/`, data)).data; },
    async updateClient(id, data) { return (await axios.put(`${this.BASE_URL}/${id}`, data)).data; },
    async deleteClient(id) { await axios.delete(`${this.BASE_URL}/${id}`); }
};
const UI = {
    tableBody: document.querySelector('#clients-table tbody'),
    loader: document.getElementById('loader'),
    modal: document.getElementById('client-modal'),
    modalTitle: document.getElementById('modal-title'),
    clientForm: document.getElementById('client-form'),
    formMessage: document.getElementById('form-message'),
    init() {
        document.getElementById('btn-add-client').addEventListener('click', () => this.openModalForCreate());
        document.querySelector('.close-button').addEventListener('click', () => this.closeModal());
        window.addEventListener('click', (e) => { if (e.target === this.modal) this.closeModal(); });
    },
    showLoader() { this.loader.style.display = 'block'; this.tableBody.parentElement.style.display = 'none'; },
    hideLoader() { this.loader.style.display = 'none'; this.tableBody.parentElement.style.display = 'table'; },
    openModalForCreate() {
        this.clientForm.reset();
        this.clientForm['client-id'].value = '';
        this.modalTitle.textContent = 'Cadastrar Novo Cliente';
        this.modal.style.display = 'block';
    },
    openModalForEdit(client) {
        this.clientForm.reset();
        this.clientForm['client-id'].value = client.id;
        this.clientForm['nome'].value = client.nome;
        this.clientForm['email'].value = client.email;
        this.clientForm['cpf'].value = client.cpf;
        this.clientForm['endereco'].value = client.endereco;
        this.modalTitle.textContent = 'Editar Cliente';
        this.modal.style.display = 'block';
    },
    closeModal() { this.modal.style.display = 'none'; this.displayFormMessage(''); },
    renderClients(clients) {
        this.tableBody.innerHTML = '';
        if (clients.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="6">Nenhum cliente cadastrado.</td></tr>';
            return;
        }
        clients.forEach(client => {
            const row = document.createElement('tr');
            row.className = 'client-row';
            row.dataset.clientId = client.id;
            row.dataset.clientName = client.nome;
            row.innerHTML = `
                <td>${client.nome}</td>
                <td>${client.id_legivel}</td>
                <td>${client.email}</td>
                <td>${client.cpf}</td>
                <td>${client.endereco || 'N/A'}</td>
                <td class="actions-cell">
                    <button class="icon-btn edit" title="Editar Cliente"><i class="bi bi-pencil"></i></button>
                    <button class="icon-btn delete" title="Excluir Cliente"><i class="bi bi-trash"></i></button>
                </td>`;
            this.tableBody.appendChild(row);
        });
    },
    displayFormMessage(msg, isError = false) {
        this.formMessage.textContent = msg;
        this.formMessage.className = `message ${isError ? 'error' : (msg ? 'success' : '')}`;
    }
};
const App = {
    clients: [],
    async init() {
        UI.init();
        UI.clientForm.addEventListener('submit', this.handleFormSubmit.bind(this));
        UI.tableBody.addEventListener('click', this.handleTableClick.bind(this));
        await this.loadClients();

        const clientIdToEdit = sessionStorage.getItem('editClientOnLoad');
        if (clientIdToEdit) {
            sessionStorage.removeItem('editClientOnLoad');
            setTimeout(() => {
                const client = this.clients.find(c => c.id === clientIdToEdit);
                if (client) UI.openModalForEdit(client);
            }, 500);
        }
    },
    async loadClients() {
        UI.showLoader();
        try {
            this.clients = await API.getClients();
            UI.renderClients(this.clients);
        } catch (err) {
            console.error('Falha ao carregar clientes:', err);
            UI.tableBody.innerHTML = '<tr><td colspan="6">Erro ao carregar clientes.</td></tr>';
        } finally {
            UI.hideLoader();
        }
    },
    async handleFormSubmit(e) {
        e.preventDefault();
        const id = UI.clientForm['client-id'].value;
        const data = { nome: UI.clientForm['nome'].value, email: UI.clientForm['email'].value, cpf: UI.clientForm['cpf'].value, endereco: UI.clientForm['endereco'].value };
        try {
            // *** AQUI ESTÁ A CORREÇÃO ***
            await (id ? API.updateClient(id, data) : API.createClient(data));
            UI.displayFormMessage(`Cliente ${id ? 'atualizado' : 'cadastrado'}!`);
            setTimeout(() => { UI.closeModal(); this.loadClients(); }, 1000);
        } catch (err) {
            const detail = err.response?.data?.detail || 'Ocorreu um erro inesperado.';
            UI.displayFormMessage(`Erro: ${detail}`, true);
        }
    },
    handleTableClick(e) {
        const target = e.target;
        const row = target.closest('tr');
        if (!row) return;
        const id = row.dataset.clientId;
        const iconButton = target.closest('.icon-btn');

        if (iconButton && iconButton.classList.contains('edit')) {
            e.stopPropagation();
            const client = this.clients.find(c => c.id === id);
            if (client) UI.openModalForEdit(client);
        } else if (iconButton && iconButton.classList.contains('delete')) {
            e.stopPropagation();
            if (confirm('Tem certeza que deseja excluir este cliente? A ação não pode ser desfeita.')) this.deleteClient(id);
        } else if (target.closest('.client-row')) {
            const name = row.dataset.clientName;
            window.location.href = `cameras.html?clientId=${id}&clientName=${encodeURIComponent(name)}`;
        }
    },
    async deleteClient(id) {
        try { await API.deleteClient(id); this.loadClients(); }
        catch (err) { alert('Não foi possível excluir o cliente.'); }
    }
};
document.addEventListener('DOMContentLoaded', () => App.init());
JS_APP_EOF

echo "--- Página de clientes (v4.3) corrigida e criada com sucesso."
