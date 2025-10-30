// =============================================================================
// VaaS - Gestão de Clientes (Versão Moderna)
// =============================================================================

const API_BASE = '/api';

// =============================================================================
// UTILS
// =============================================================================

function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = `toast ${type}`;
  toast.classList.remove('hidden');

  setTimeout(() => {
    toast.classList.add('hidden');
  }, 3000);
}

function getInitials(nome) {
  return nome
    .split(' ')
    .map(word => word[0])
    .join('')
    .toUpperCase()
    .substring(0, 2);
}

// =============================================================================
// API CALLS
// =============================================================================

async function fetchClientes() {
  const response = await fetch(`${API_BASE}/clients`);
  if (!response.ok) throw new Error('Falha ao carregar clientes');
  return response.json();
}

async function fetchCamerasPorCliente(clienteId) {
  const response = await fetch(`${API_BASE}/cameras`);
  if (!response.ok) throw new Error('Falha ao carregar câmeras');
  const cameras = await response.json();
  return cameras.filter(cam => cam.cliente_id === clienteId);
}

async function salvarCliente(data) {
  const method = data.id ? 'PUT' : 'POST';
  const url = data.id ? `${API_BASE}/clients/${data.id}` : `${API_BASE}/clients`;

  const payload = {
    nome: data.nome,
    documento: data.documento,
    email: data.email || null,
    telefone: data.telefone || null
  };

  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.detail || 'Erro ao salvar cliente');
  }

  return response.json();
}

async function deletarCliente(id) {
  const response = await fetch(`${API_BASE}/clients/${id}`, {
    method: 'DELETE'
  });

  if (!response.ok) {
    throw new Error('Erro ao deletar cliente');
  }
}

// =============================================================================
// RENDER FUNCTIONS
// =============================================================================

function renderClientCard(cliente, camerasCount) {
  const initials = getInitials(cliente.nome);
  const statusClass = cliente.status === 'ativo' ? 'success' : 'danger';

  return `
    <div class="client-card" data-client-id="${cliente.id}">
      <div class="client-card-header">
        <div class="client-card-avatar">${initials}</div>
        <div class="client-card-actions">
          <button class="btn btn-sm btn-ghost btn-edit" data-client-id="${cliente.id}" title="Editar">
            ✏️
          </button>
          <button class="btn btn-sm btn-danger btn-delete" data-client-id="${cliente.id}" title="Excluir">
            🗑️
          </button>
        </div>
      </div>

      <div class="client-card-body">
        <h3 class="client-card-name">${cliente.nome}</h3>
        <div class="client-card-info">
          <div class="client-card-info-item">
            <span>📄</span>
            <span>${cliente.documento}</span>
          </div>
          ${cliente.email ? `
            <div class="client-card-info-item">
              <span>✉️</span>
              <span>${cliente.email}</span>
            </div>
          ` : ''}
          ${cliente.telefone ? `
            <div class="client-card-info-item">
              <span>📞</span>
              <span>${cliente.telefone}</span>
            </div>
          ` : ''}
        </div>
      </div>

      <div class="client-card-footer">
        <span class="badge badge-${statusClass}">
          ${cliente.status === 'ativo' ? '✓ Ativo' : '✗ Inativo'}
        </span>
        <span class="badge badge-info">
          📹 ${camerasCount} câmera${camerasCount !== 1 ? 's' : ''}
        </span>
      </div>
    </div>
  `;
}

async function renderClientes() {
  try {
    const clientes = await fetchClientes();
    const grid = document.getElementById('clients-grid');

    if (clientes.length === 0) {
      grid.innerHTML = `
        <div class="text-center" style="grid-column: 1 / -1; padding: 3rem;">
          <p style="color: var(--text-secondary); font-size: 1.125rem;">
            Nenhum cliente cadastrado ainda
          </p>
          <button class="btn btn-primary mt-2" id="btn-add-first">
            + Adicionar Primeiro Cliente
          </button>
        </div>
      `;

      document.getElementById('btn-add-first')?.addEventListener('click', abrirModalNovoCliente);
      updateStats(0, 0, 0);
      return;
    }

    // Buscar contagem de câmeras para cada cliente
    const camerasPromises = clientes.map(c => fetchCamerasPorCliente(c.id));
    const camerasResults = await Promise.all(camerasPromises);

    const cardsHTML = clientes.map((cliente, index) => {
      const camerasCount = camerasResults[index].length;
      return renderClientCard(cliente, camerasCount);
    }).join('');

    grid.innerHTML = cardsHTML;

    // Event listeners para os cards
    document.querySelectorAll('.client-card').forEach(card => {
      const clientId = card.dataset.clientId;

      // Clicar no card abre página de câmeras
      card.addEventListener('click', (e) => {
        // Não abrir se clicou em botão
        if (e.target.closest('.btn-edit') || e.target.closest('.btn-delete')) {
          return;
        }
        window.location.href = `/cameras.html?cliente=${clientId}`;
      });
    });

    // Botões de editar
    document.querySelectorAll('.btn-edit').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const clientId = btn.dataset.clientId;
        const cliente = clientes.find(c => c.id === clientId);
        if (cliente) {
          abrirModalEditarCliente(cliente);
        }
      });
    });

    // Botões de deletar
    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const clientId = btn.dataset.clientId;
        const cliente = clientes.find(c => c.id === clientId);

        if (confirm(`Deseja realmente excluir o cliente "${cliente.nome}"?\n\nTodas as câmeras associadas serão excluídas também.`)) {
          try {
            await deletarCliente(clientId);
            showToast('Cliente excluído com sucesso!', 'success');
            await renderClientes();
          } catch (error) {
            showToast(error.message, 'error');
          }
        }
      });
    });

    // Atualizar stats
    const totalCameras = camerasResults.reduce((acc, cams) => acc + cams.length, 0);
    const clientesAtivos = clientes.filter(c => c.status === 'ativo').length;
    updateStats(clientes.length, clientesAtivos, totalCameras);

  } catch (error) {
    console.error('Erro ao carregar clientes:', error);
    showToast('Erro ao carregar clientes', 'error');

    const grid = document.getElementById('clients-grid');
    grid.innerHTML = `
      <div class="text-center" style="grid-column: 1 / -1; padding: 3rem;">
        <p style="color: var(--danger); font-size: 1.125rem;">
          Erro ao carregar clientes
        </p>
        <button class="btn btn-primary mt-2" onclick="location.reload()">
          🔄 Tentar Novamente
        </button>
      </div>
    `;
  }
}

function updateStats(total, ativos, cameras) {
  document.getElementById('stat-total').textContent = total;
  document.getElementById('stat-ativos').textContent = ativos;
  document.getElementById('stat-cameras').textContent = cameras;
}

// =============================================================================
// MODAL
// =============================================================================

function abrirModalNovoCliente() {
  const modal = document.getElementById('modal-cliente');
  const title = document.getElementById('modal-title');
  const form = document.getElementById('form-cliente');

  title.textContent = 'Novo Cliente';
  form.reset();
  document.getElementById('cliente-id').value = '';

  modal.classList.remove('hidden');
}

function abrirModalEditarCliente(cliente) {
  const modal = document.getElementById('modal-cliente');
  const title = document.getElementById('modal-title');

  title.textContent = 'Editar Cliente';

  document.getElementById('cliente-id').value = cliente.id;
  document.getElementById('nome').value = cliente.nome;
  document.getElementById('documento').value = cliente.documento;
  document.getElementById('email').value = cliente.email || '';
  document.getElementById('telefone').value = cliente.telefone || '';

  modal.classList.remove('hidden');
}

function fecharModal() {
  const modal = document.getElementById('modal-cliente');
  modal.classList.add('hidden');
}

async function salvarClienteModal() {
  const id = document.getElementById('cliente-id').value;
  const nome = document.getElementById('nome').value.trim();
  const documento = document.getElementById('documento').value.trim();
  const email = document.getElementById('email').value.trim();
  const telefone = document.getElementById('telefone').value.trim();

  if (!nome || !documento) {
    showToast('Preencha os campos obrigatórios', 'error');
    return;
  }

  try {
    await salvarCliente({ id, nome, documento, email, telefone });
    showToast(id ? 'Cliente atualizado!' : 'Cliente criado!', 'success');
    fecharModal();
    await renderClientes();
  } catch (error) {
    showToast(error.message, 'error');
  }
}

// =============================================================================
// INIT
// =============================================================================

document.addEventListener('DOMContentLoaded', () => {
  // Carregar clientes
  renderClientes();

  // Event listeners
  document.getElementById('btn-novo-cliente')?.addEventListener('click', abrirModalNovoCliente);
  document.getElementById('modal-close')?.addEventListener('click', fecharModal);
  document.getElementById('modal-cancel')?.addEventListener('click', fecharModal);
  document.getElementById('modal-salvar')?.addEventListener('click', salvarClienteModal);

  // Fechar modal ao clicar fora
  document.getElementById('modal-cliente')?.addEventListener('click', (e) => {
    if (e.target.id === 'modal-cliente') {
      fecharModal();
    }
  });

  // Submit do form
  document.getElementById('form-cliente')?.addEventListener('submit', (e) => {
    e.preventDefault();
    salvarClienteModal();
  });
});
