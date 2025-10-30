// =============================================================================
// VaaS - Gestão de Câmeras (Versão Moderna)
// =============================================================================

const API_BASE = '/api';
const HLS_BASE = 'http://localhost:8888';

let currentClientId = null;
let currentClient = null;
let statusRefreshInterval = null;

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

function getStatusBadgeClass(status) {
  const map = {
    'online': 'status-online',
    'ready': 'status-ready',
    'off': 'status-off'
  };
  return map[status] || 'status-off';
}

function getStatusLabel(status) {
  const map = {
    'online': 'ONLINE',
    'ready': 'PRONTA',
    'off': 'OFFLINE'
  };
  return map[status] || 'OFF';
}

// =============================================================================
// URL PARAMS
// =============================================================================

function getClientIdFromUrl() {
  const params = new URLSearchParams(window.location.search);
  return params.get('cliente');
}

// =============================================================================
// API CALLS
// =============================================================================

async function fetchCliente(id) {
  const response = await fetch(`${API_BASE}/clients/${id}`);
  if (!response.ok) throw new Error('Cliente não encontrado');
  return response.json();
}

async function fetchCameras(clienteId) {
  const response = await fetch(`${API_BASE}/cameras`);
  if (!response.ok) throw new Error('Falha ao carregar câmeras');
  const allCameras = await response.json();
  return allCameras.filter(cam => cam.cliente_id === clienteId);
}

async function fetchCamerasStatus() {
  const response = await fetch(`${API_BASE}/status/cameras`);
  if (!response.ok) throw new Error('Falha ao carregar status');
  return response.json();
}

async function salvarCamera(data) {
  const method = data.id ? 'PUT' : 'POST';
  const url = data.id ? `${API_BASE}/cameras/${data.id}` : `${API_BASE}/cameras`;

  const payload = {
    cliente_id: data.cliente_id,
    nome: data.nome,
    protocolo: data.protocolo,
    endpoint: data.endpoint,
    ativo: data.ativo,
    transcode_to_h265: data.transcode_to_h265
  };

  const response = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.detail || 'Erro ao salvar câmera');
  }

  return response.json();
}

async function deletarCamera(id) {
  const response = await fetch(`${API_BASE}/cameras/${id}`, {
    method: 'DELETE'
  });

  if (!response.ok) {
    throw new Error('Erro ao deletar câmera');
  }
}

async function atualizarCliente(id, data) {
  const response = await fetch(`${API_BASE}/clients/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.detail || 'Erro ao atualizar cliente');
  }

  return response.json();
}

// =============================================================================
// RENDER FUNCTIONS
// =============================================================================

async function renderClientInfo() {
  try {
    currentClient = await fetchCliente(currentClientId);

    document.getElementById('client-name').textContent = currentClient.nome;

    const details = [];
    if (currentClient.documento) details.push(`📄 ${currentClient.documento}`);
    if (currentClient.email) details.push(`✉️ ${currentClient.email}`);
    if (currentClient.telefone) details.push(`📞 ${currentClient.telefone}`);

    document.getElementById('client-details').textContent = details.join(' • ');

  } catch (error) {
    console.error('Erro ao carregar cliente:', error);
    showToast('Cliente não encontrado', 'error');
    setTimeout(() => {
      window.location.href = '/index.html';
    }, 2000);
  }
}

function renderCameraCard(camera, statusInfo) {
  const statusClass = getStatusBadgeClass(statusInfo?.status || 'off');
  const statusLabel = getStatusLabel(statusInfo?.status || 'off');
  const isOnline = statusInfo?.online || false;

  const snapshotUrl = `${API_BASE}/cameras/${camera.id}/snapshot?t=${Date.now()}`;

  return `
    <div class="camera-list-item" style="
      background: linear-gradient(135deg, var(--card-bg) 0%, rgba(30, 41, 59, 0.8) 100%);
      border: 1px solid var(--border-color);
      border-radius: 0.75rem;
      overflow: hidden;
      display: flex;
      align-items: stretch;
      min-height: 150px;
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1), 0 0 20px rgba(59, 130, 246, 0.05);
      transition: all 0.3s ease;
      position: relative;
    " onmouseover="this.style.transform='translateY(-2px)'; this.style.boxShadow='0 8px 16px rgba(0, 0, 0, 0.2), 0 0 30px rgba(59, 130, 246, 0.1)';" onmouseout="this.style.transform='translateY(0)'; this.style.boxShadow='0 4px 6px rgba(0, 0, 0, 0.1), 0 0 20px rgba(59, 130, 246, 0.05)';">

      <!-- Brilho sutil de fundo -->
      <div style="position: absolute; top: 0; left: 0; right: 0; height: 2px; background: linear-gradient(90deg, transparent, rgba(59, 130, 246, 0.5), transparent);"></div>

      <!-- Foto da Câmera (Esquerda) -->
      <div style="
        position: relative;
        width: 260px;
        flex-shrink: 0;
        background: linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 100%);
        box-shadow: inset 0 0 20px rgba(0, 0, 0, 0.5);
      ">
        ${isOnline ? `
          <img
            src="${snapshotUrl}"
            data-camera-id="${camera.id}"
            class="camera-snapshot"
            alt="${camera.nome}"
            style="width: 100%; height: 100%; object-fit: cover; filter: brightness(0.95);"
            onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"
          />
          <div class="camera-offline-placeholder" style="display: none; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary); flex-direction: column; position: absolute; top: 0; left: 0; right: 0; bottom: 0;">
            <div style="font-size: 2.5rem; margin-bottom: 0.5rem; opacity: 0.5;">📹</div>
            <div style="font-size: 0.875rem; opacity: 0.7;">Sem sinal</div>
          </div>
        ` : `
          <div style="display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary); flex-direction: column;">
            <div style="font-size: 2.5rem; margin-bottom: 0.5rem; opacity: 0.5;">📹</div>
            <div style="font-size: 0.875rem; opacity: 0.7;">Sem sinal</div>
          </div>
        `}
        <div style="position: absolute; top: 0.75rem; left: 0.75rem;">
          <span class="badge badge-${statusClass}" style="
            font-size: 0.7rem;
            padding: 0.375rem 0.625rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
          ">
            ${statusLabel}
          </span>
        </div>
      </div>

      <!-- Informações (Centro) -->
      <div style="flex: 1; padding: 1.25rem; display: flex; flex-direction: column; justify-content: center; min-width: 0;">
        <div style="display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem;">
          <h3 style="
            font-size: 1.375rem;
            font-weight: 600;
            margin: 0;
            color: var(--text-primary);
            text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
          ">
            ${camera.nome}
          </h3>
          <span class="badge ${camera.protocolo === 'RTMP' ? 'badge-warning' : camera.protocolo === 'RTSP' ? 'badge-info' : 'badge-primary'}" style="font-size: 0.7rem; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);">
            ${camera.protocolo}
          </span>
          ${camera.transcode_to_h265
            ? '<span class="badge badge-warning" style="font-size: 0.7rem; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);">H.264 → H.265</span>'
            : '<span class="badge badge-success" style="font-size: 0.7rem; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);">H.264</span>'}
          ${camera.ativo
            ? '<span class="badge badge-success" style="font-size: 0.7rem; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);">✓ Ativa</span>'
            : '<span class="badge badge-danger" style="font-size: 0.7rem; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);">✗ Inativa</span>'}
        </div>

        <div style="
          font-size: 0.875rem;
          color: var(--text-secondary);
          word-break: break-all;
          line-height: 1.6;
          padding: 0.5rem 0;
          border-bottom: 1px solid rgba(59, 130, 246, 0.2);
          margin-bottom: 0.75rem;
        ">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <strong style="color: var(--text-primary);">Endpoint:</strong>
            <span style="flex: 1; font-family: monospace; font-size: 0.8rem; color: var(--text-secondary);">
              ${camera.endpoint.length > 70 ? camera.endpoint.substring(0, 70) + '...' : camera.endpoint}
            </span>
          </div>
        </div>

        <!-- Botões Horizontais -->
        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
          <button class="btn-action btn-view" data-camera-id="${camera.id}" ${!isOnline ? 'disabled' : ''} title="Ver câmera" style="
            background: var(--primary);
            border: 1px solid var(--primary);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 0.375rem;
            cursor: pointer;
            font-size: 0.875rem;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 0.375rem;
            box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
          "
          onmouseover="if(!this.disabled) { this.style.background='var(--primary-hover)'; this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 8px rgba(59, 130, 246, 0.3)'; }"
          onmouseout="if(!this.disabled) { this.style.background='var(--primary)'; this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 4px rgba(59, 130, 246, 0.2)'; }">
            <span style="filter: grayscale(1);">👁</span>
            <span>Ver</span>
          </button>

          <button class="btn-action btn-edit" data-camera-id="${camera.id}" title="Editar câmera" style="
            background: var(--primary);
            border: 1px solid var(--primary);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 0.375rem;
            cursor: pointer;
            font-size: 0.875rem;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 0.375rem;
            box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
          "
          onmouseover="this.style.background='var(--primary-hover)'; this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 8px rgba(59, 130, 246, 0.3)';"
          onmouseout="this.style.background='var(--primary)'; this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 4px rgba(59, 130, 246, 0.2)';">
            <span style="filter: grayscale(1);">✏</span>
            <span>Editar</span>
          </button>

          <button class="btn-action btn-delete" data-camera-id="${camera.id}" title="Excluir câmera" style="
            background: var(--primary);
            border: 1px solid var(--primary);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 0.375rem;
            cursor: pointer;
            font-size: 0.875rem;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 0.375rem;
            box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
          "
          onmouseover="this.style.background='var(--primary-hover)'; this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 8px rgba(59, 130, 246, 0.3)';"
          onmouseout="this.style.background='var(--primary)'; this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 4px rgba(59, 130, 246, 0.2)';">
            <span style="filter: grayscale(1);">🗑</span>
            <span>Excluir</span>
          </button>

          <button
            class="btn-action btn-copy-endpoint"
            data-endpoint="${camera.endpoint.replace(/"/g, '&quot;')}"
            title="Copiar endpoint"
            style="
              background: var(--primary);
              border: 1px solid var(--primary);
              color: white;
              padding: 0.5rem 1rem;
              border-radius: 0.375rem;
              cursor: pointer;
              font-size: 0.875rem;
              transition: all 0.2s;
              display: flex;
              align-items: center;
              gap: 0.375rem;
              box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
            "
            onmouseover="this.style.background='var(--primary-hover)'; this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 8px rgba(59, 130, 246, 0.3)';"
            onmouseout="this.style.background='var(--primary)'; this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 4px rgba(59, 130, 246, 0.2)';"
          >
            <span style="filter: grayscale(1);">📋</span>
            <span>Copiar</span>
          </button>

          <button
            class="btn-action btn-toggle-gpu"
            data-camera-id="${camera.id}"
            data-h265-enabled="${camera.transcode_to_h265}"
            title="${camera.transcode_to_h265 ? 'Desativar H.265 (GPU)' : 'Ativar H.265 (GPU)'}"
            style="
              background: ${camera.transcode_to_h265 ? 'var(--warning)' : 'var(--primary)'};
              border: 1px solid ${camera.transcode_to_h265 ? 'var(--warning)' : 'var(--primary)'};
              color: white;
              padding: 0.5rem 1rem;
              border-radius: 0.375rem;
              cursor: pointer;
              font-size: 0.875rem;
              transition: all 0.2s;
              display: flex;
              align-items: center;
              gap: 0.375rem;
              box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
            "
            onmouseover="this.style.transform='translateY(-1px)'; this.style.boxShadow='0 4px 8px rgba(59, 130, 246, 0.3)';"
            onmouseout="this.style.transform='translateY(0)'; this.style.boxShadow='0 2px 4px rgba(59, 130, 246, 0.2)';"
          >
            <span style="filter: grayscale(1);">🎮</span>
            <span>${camera.transcode_to_h265 ? 'H.265' : 'H.264 → H.265'}</span>
          </button>
        </div>
      </div>
    </div>
  `;
}

async function renderCameras() {
  try {
    const [cameras, statusData] = await Promise.all([
      fetchCameras(currentClientId),
      fetchCamerasStatus()
    ]);

    const container = document.getElementById('cameras-list');

    if (cameras.length === 0) {
      container.innerHTML = `
        <div style="padding: 3rem; text-align: center;">
          <p style="color: var(--text-secondary); font-size: 1.125rem; margin-bottom: 1rem;">
            Nenhuma câmera cadastrada ainda
          </p>
          <button class="btn btn-primary" id="btn-add-first-camera">
            + Adicionar Primeira Câmera
          </button>
        </div>
      `;

      document.getElementById('btn-add-first-camera')?.addEventListener('click', abrirModalNovaCamera);
      updateCameraStats(0, 0, 0, 0);
      return;
    }

    // Criar mapa de status
    const statusMap = {};
    statusData.cameras.forEach(cam => {
      statusMap[cam.id] = cam;
    });

    // Renderizar câmeras em lista vertical
    const cardsHTML = cameras.map(camera => {
      const statusInfo = statusMap[camera.id];
      return renderCameraCard(camera, statusInfo);
    }).join('');

    container.innerHTML = cardsHTML;

    // Event listeners

    // Botão copiar endpoint
    document.querySelectorAll('.btn-copy-endpoint').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const endpoint = btn.dataset.endpoint;

        // Copiar para clipboard
        navigator.clipboard.writeText(endpoint).then(() => {
          // Feedback visual
          const originalHTML = btn.innerHTML;
          btn.innerHTML = '<span style="filter: grayscale(1);">✓</span><span>Copiado!</span>';
          btn.style.background = 'var(--success)';
          btn.style.borderColor = 'var(--success)';

          setTimeout(() => {
            btn.innerHTML = originalHTML;
            btn.style.background = 'var(--primary)';
            btn.style.borderColor = 'var(--primary)';
          }, 2000);

          showToast('Endpoint copiado!', 'success');
        }).catch(err => {
          console.error('Erro ao copiar:', err);
          showToast('Erro ao copiar endpoint', 'error');
        });
      });
    });

    document.querySelectorAll('.btn-view').forEach(btn => {
      btn.addEventListener('click', () => {
        const cameraId = btn.dataset.cameraId;
        const camera = cameras.find(c => c.id === cameraId);
        if (camera) {
          openFullscreenPlayer(camera, statusMap[camera.id]);
        }
      });
    });

    document.querySelectorAll('.btn-edit').forEach(btn => {
      btn.addEventListener('click', () => {
        const cameraId = btn.dataset.cameraId;
        const camera = cameras.find(c => c.id === cameraId);
        if (camera) {
          abrirModalEditarCamera(camera);
        }
      });
    });

    document.querySelectorAll('.btn-delete').forEach(btn => {
      btn.addEventListener('click', async () => {
        const cameraId = btn.dataset.cameraId;
        const camera = cameras.find(c => c.id === cameraId);

        if (confirm(`Deseja realmente excluir a câmera "${camera.nome}"?`)) {
          try {
            await deletarCamera(cameraId);
            showToast('Câmera excluída com sucesso!', 'success');
            await renderCameras();
          } catch (error) {
            showToast(error.message, 'error');
          }
        }
      });
    });

    document.querySelectorAll('.btn-toggle-gpu').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        e.stopPropagation();
        const cameraId = btn.dataset.cameraId;
        const camera = cameras.find(c => c.id === cameraId);
        const currentH265 = btn.dataset.h265Enabled === 'true';
        const newH265 = !currentH265;

        try {
          // Atualizar câmera mantendo todos os campos
          await salvarCamera({
            id: camera.id,
            cliente_id: camera.cliente_id,
            nome: camera.nome,
            protocolo: camera.protocolo,
            endpoint: camera.endpoint,
            ativo: camera.ativo,
            transcode_to_h265: newH265
          });

          showToast(`H.265 (GPU) ${newH265 ? 'ativado' : 'desativado'}!`, 'success');
          await renderCameras();
        } catch (error) {
          showToast(error.message, 'error');
        }
      });
    });

    // Atualizar stats
    const online = statusData.cameras.filter(c => c.status === 'online').length;
    const ready = statusData.cameras.filter(c => c.status === 'ready').length;
    const off = statusData.cameras.filter(c => c.status === 'off').length;
    updateCameraStats(cameras.length, online, ready, off);

  } catch (error) {
    console.error('Erro ao carregar câmeras:', error);
    showToast('Erro ao carregar câmeras', 'error');
  }
}

function updateCameraStats(total, online, ready, off) {
  document.getElementById('stat-total-cameras').textContent = total;
  document.getElementById('stat-online').textContent = online;
  document.getElementById('stat-ready').textContent = ready;
  document.getElementById('stat-off').textContent = off;
}

// =============================================================================
// SNAPSHOT (Sem Auto-Refresh - Atualiza só ao carregar página)
// =============================================================================

// Removido auto-refresh conforme solicitado
// Snapshots são carregados apenas quando a página é carregada/atualizada

// =============================================================================
// HLS PLAYER
// =============================================================================

function initializeHLSPlayers() {
  const videos = document.querySelectorAll('.camera-video');

  videos.forEach(video => {
    const hlsUrl = video.dataset.hlsUrl;

    if (Hls.isSupported()) {
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90
      });

      hls.loadSource(hlsUrl);
      hls.attachMedia(video);

      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        video.play().catch(e => console.log('Autoplay prevented:', e));
      });

      hls.on(Hls.Events.ERROR, (event, data) => {
        if (data.fatal) {
          console.error('HLS error:', data);
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = hlsUrl;
      video.addEventListener('loadedmetadata', () => {
        video.play().catch(e => console.log('Autoplay prevented:', e));
      });
    }
  });
}

function openFullscreenPlayer(camera, statusInfo) {
  // TODO: Implementar player fullscreen
  showToast('Player fullscreen em desenvolvimento', 'info');
}

// =============================================================================
// MODALS
// =============================================================================

async function abrirModalNovaCamera() {
  const modal = document.getElementById('modal-camera');
  const title = document.getElementById('modal-camera-title');
  const form = document.getElementById('form-camera');

  title.textContent = 'Nova Câmera';
  form.reset();
  document.getElementById('camera-id').value = '';
  document.getElementById('camera-cliente-id').value = currentClientId;
  document.getElementById('camera-ativo').checked = true;

  // Buscar próximo nome disponível
  const cameras = await fetchCameras(currentClientId);
  const proximoNome = getProximoNomeCameraDisponivel(cameras);
  document.getElementById('camera-nome').value = proximoNome;

  // Configurar listener para gerar endpoint RTMP automaticamente
  setupEndpointAutoGeneration();

  modal.classList.remove('hidden');
}

// Encontra o próximo nome de câmera disponível (cam1, cam2, etc.)
// Preenche gaps se houver (ex: se deletar cam2, reutiliza cam2)
function getProximoNomeCameraDisponivel(cameras) {
  // Extrair números das câmeras existentes (cam1 -> 1, cam2 -> 2)
  const numerosUsados = cameras
    .map(cam => {
      const match = cam.nome.match(/^cam(\d+)$/);
      return match ? parseInt(match[1]) : null;
    })
    .filter(num => num !== null)
    .sort((a, b) => a - b);

  // Se não há câmeras, retorna cam1
  if (numerosUsados.length === 0) {
    return 'cam1';
  }

  // Procurar primeiro gap (número faltando)
  for (let i = 1; i <= numerosUsados.length; i++) {
    if (!numerosUsados.includes(i)) {
      return `cam${i}`;
    }
  }

  // Se não há gaps, retorna próximo número
  const ultimoNumero = numerosUsados[numerosUsados.length - 1];
  return `cam${ultimoNumero + 1}`;
}

// Configura geração automática do endpoint RTMP
function setupEndpointAutoGeneration() {
  // Função para gerar endpoint RTMP
  const gerarEndpointRTMP = () => {
    // Sempre pegar elementos atuais do DOM
    const protocoloSelect = document.getElementById('camera-protocolo');
    const nomeInput = document.getElementById('camera-nome');
    const endpointInput = document.getElementById('camera-endpoint');

    const protocolo = protocoloSelect.value;
    const nome = nomeInput.value.trim();

    if (protocolo === 'RTMP' && nome && currentClient) {
      const endpoint = `rtmp://mediamtx:1935/live/${currentClient.slug}/${nome}`;
      endpointInput.value = endpoint;
      endpointInput.readOnly = true;
      endpointInput.style.background = 'rgba(59, 130, 246, 0.1)';
      endpointInput.style.color = 'var(--primary)';
    } else {
      endpointInput.readOnly = false;
      endpointInput.style.background = '';
      endpointInput.style.color = '';
    }
  };

  // Remover listeners anteriores se existirem e adicionar novos
  const protocoloSelect = document.getElementById('camera-protocolo');
  const nomeInput = document.getElementById('camera-nome');

  const newProtocoloSelect = protocoloSelect.cloneNode(true);
  protocoloSelect.parentNode.replaceChild(newProtocoloSelect, protocoloSelect);
  const newNomeInput = nomeInput.cloneNode(true);
  nomeInput.parentNode.replaceChild(newNomeInput, nomeInput);

  // Adicionar novos listeners aos elementos atuais
  document.getElementById('camera-protocolo').addEventListener('change', gerarEndpointRTMP);
  document.getElementById('camera-nome').addEventListener('input', gerarEndpointRTMP);

  // Gerar endpoint inicialmente se RTMP já estiver selecionado
  gerarEndpointRTMP();
}

function abrirModalEditarCamera(camera) {
  const modal = document.getElementById('modal-camera');
  const title = document.getElementById('modal-camera-title');

  title.textContent = 'Editar Câmera';

  document.getElementById('camera-id').value = camera.id;
  document.getElementById('camera-cliente-id').value = camera.cliente_id;
  document.getElementById('camera-nome').value = camera.nome;
  document.getElementById('camera-protocolo').value = camera.protocolo;
  document.getElementById('camera-endpoint').value = camera.endpoint;
  document.getElementById('camera-h265').checked = camera.transcode_to_h265;
  document.getElementById('camera-ativo').checked = camera.ativo;

  modal.classList.remove('hidden');
}

function fecharModalCamera() {
  const modal = document.getElementById('modal-camera');
  modal.classList.add('hidden');
}

async function salvarCameraModal() {
  const id = document.getElementById('camera-id').value;
  const cliente_id = document.getElementById('camera-cliente-id').value;
  const nome = document.getElementById('camera-nome').value.trim();
  const protocolo = document.getElementById('camera-protocolo').value;
  const endpoint = document.getElementById('camera-endpoint').value.trim();
  const h265 = document.getElementById('camera-h265').checked;
  const ativo = document.getElementById('camera-ativo').checked;

  if (!nome || !protocolo || !endpoint) {
    showToast('Preencha todos os campos obrigatórios', 'error');
    return;
  }

  try {
    await salvarCamera({
      id,
      cliente_id,
      nome,
      protocolo,
      endpoint,
      transcode_to_h265: h265,
      ativo
    });

    showToast(id ? 'Câmera atualizada!' : 'Câmera criada!', 'success');
    fecharModalCamera();
    await renderCameras();
  } catch (error) {
    showToast(error.message, 'error');
  }
}

// Modal Editar Cliente
function abrirModalEditarCliente() {
  if (!currentClient) return;

  const modal = document.getElementById('modal-editar-cliente');

  document.getElementById('edit-cliente-id').value = currentClient.id;
  document.getElementById('edit-nome').value = currentClient.nome;
  document.getElementById('edit-documento').value = currentClient.documento;
  document.getElementById('edit-email').value = currentClient.email || '';
  document.getElementById('edit-telefone').value = currentClient.telefone || '';

  modal.classList.remove('hidden');
}

function fecharModalEditarCliente() {
  const modal = document.getElementById('modal-editar-cliente');
  modal.classList.add('hidden');
}

async function salvarClienteModal() {
  const id = document.getElementById('edit-cliente-id').value;
  const nome = document.getElementById('edit-nome').value.trim();
  const documento = document.getElementById('edit-documento').value.trim();
  const email = document.getElementById('edit-email').value.trim();
  const telefone = document.getElementById('edit-telefone').value.trim();

  if (!nome || !documento) {
    showToast('Preencha os campos obrigatórios', 'error');
    return;
  }

  try {
    await atualizarCliente(id, { nome, documento, email, telefone });
    showToast('Cliente atualizado!', 'success');
    fecharModalEditarCliente();
    await renderClientInfo();
  } catch (error) {
    showToast(error.message, 'error');
  }
}

// =============================================================================
// AUTO REFRESH
// =============================================================================

function startStatusRefresh() {
  // Snapshots NÃO atualizam automaticamente (conforme solicitado)
  // Apenas status completo a cada 30 segundos (para manter stats atualizados)
  statusRefreshInterval = setInterval(() => {
    renderCameras();
  }, 30000);
}

function stopStatusRefresh() {
  if (statusRefreshInterval) {
    clearInterval(statusRefreshInterval);
    statusRefreshInterval = null;
  }
}

// =============================================================================
// INIT
// =============================================================================

document.addEventListener('DOMContentLoaded', () => {
  // Pegar ID do cliente da URL
  currentClientId = getClientIdFromUrl();

  if (!currentClientId) {
    showToast('Cliente não especificado', 'error');
    setTimeout(() => {
      window.location.href = '/index.html';
    }, 2000);
    return;
  }

  // Carregar dados
  renderClientInfo();
  renderCameras();

  // Iniciar auto-refresh
  startStatusRefresh();

  // Event listeners
  document.getElementById('btn-voltar')?.addEventListener('click', () => {
    window.location.href = '/index.html';
  });

  document.getElementById('btn-nova-camera')?.addEventListener('click', abrirModalNovaCamera);
  document.getElementById('modal-camera-close')?.addEventListener('click', fecharModalCamera);
  document.getElementById('modal-camera-cancel')?.addEventListener('click', fecharModalCamera);
  document.getElementById('modal-camera-salvar')?.addEventListener('click', salvarCameraModal);

  document.getElementById('btn-editar-cliente')?.addEventListener('click', abrirModalEditarCliente);
  document.getElementById('modal-edit-close')?.addEventListener('click', fecharModalEditarCliente);
  document.getElementById('modal-edit-cancel')?.addEventListener('click', fecharModalEditarCliente);
  document.getElementById('modal-edit-salvar')?.addEventListener('click', salvarClienteModal);

  // Fechar modal ao clicar fora
  document.getElementById('modal-camera')?.addEventListener('click', (e) => {
    if (e.target.id === 'modal-camera') {
      fecharModalCamera();
    }
  });

  document.getElementById('modal-editar-cliente')?.addEventListener('click', (e) => {
    if (e.target.id === 'modal-editar-cliente') {
      fecharModalEditarCliente();
    }
  });

  // Submit dos forms
  document.getElementById('form-camera')?.addEventListener('submit', (e) => {
    e.preventDefault();
    salvarCameraModal();
  });

  document.getElementById('form-editar-cliente')?.addEventListener('submit', (e) => {
    e.preventDefault();
    salvarClienteModal();
  });

  // Parar refresh ao sair da página
  window.addEventListener('beforeunload', stopStatusRefresh);
});

// Carregar HLS.js do CDN
(function loadHLSjs() {
  if (!window.Hls) {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/hls.js@latest';
    document.head.appendChild(script);
  }
})();
