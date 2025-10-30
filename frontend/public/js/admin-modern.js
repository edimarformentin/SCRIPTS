// =============================================================================
// VaaS - Admin Panel (Modern)
// =============================================================================

const API_BASE = '/api';

// State
let gpuRefreshInterval = null;
let gpuRefreshRate = 3000; // 3 seconds default
let gpuRefreshActive = false;
let logsRefreshInterval = null;

// Chart instances
let gpuUtilizationChart = null;
let gpuMemoryChart = null;
let camerasActiveChart = null;

// GPU history data (keep last 20 data points)
const GPU_HISTORY_LENGTH = 20;
let gpuUtilizationHistory = [];
let gpuMemoryHistory = [];
let cameraGpuHistory = {}; // { "cam1": [100, 110, ...], "cam2": [50, 60, ...] }
let gpuLabels = [];

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

function showLoading(show) {
  const overlay = document.getElementById('loading-overlay');
  overlay.style.display = show ? 'flex' : 'none';
}

function formatUptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (days > 0) {
    return `${days}d ${hours}h`;
  }
  return `${hours}h ${minutes}m`;
}

// =============================================================================
// GPU MONITORING
// =============================================================================

async function loadHardwareStatus() {
  try {
    const [hardwareData, gpuPerCameraData] = await Promise.all([
      fetch(`${API_BASE}/hardware`).then(r => r.json()),
      fetch(`${API_BASE}/hardware/gpu-per-camera`).then(r => r.json())
    ]);

    // Update system stats
    updateSystemStats(hardwareData.system);

    // Always show GPU section
    document.getElementById('gpu-section').style.display = 'block';

    // Update GPU if available
    if (hardwareData.gpu && hardwareData.gpu.available) {
      updateGPUStats(hardwareData.gpu, hardwareData.gpu_processes);
    }

    // Update GPU per camera chart (always)
    updateCamerasGPUChart(gpuPerCameraData.cameras);

  } catch (error) {
    console.error('[Admin] Error loading hardware status:', error);
  }
}

function updateSystemStats(system) {
  // CPU
  document.getElementById('stat-cpu').textContent = Math.round(system.cpu.percent);

  // Memory
  document.getElementById('stat-memory-used').textContent = system.memory.used_gb;
  document.getElementById('stat-memory-total').textContent = system.memory.total_gb;
  document.getElementById('stat-memory-progress').style.width = system.memory.percent + '%';

  // Disk
  document.getElementById('stat-disk-used').textContent = system.disk.used_gb;
  document.getElementById('stat-disk-total').textContent = system.disk.total_gb;
  document.getElementById('stat-disk-progress').style.width = system.disk.percent + '%';

  // Uptime (we'll get from system status API)
  // For now, use a placeholder
}

function updateGPUStats(gpuData, processes) {
  const gpuCards = document.getElementById('gpu-cards-grid');

  // Render GPU cards
  if (gpuData.gpus && gpuData.gpus.length > 0) {
    gpuCards.innerHTML = gpuData.gpus.map(gpu => {
      const memPercent = gpu.memory_total_mb > 0
        ? (gpu.memory_used_mb / gpu.memory_total_mb * 100).toFixed(1)
        : 0;

      const powerPercent = gpu.power_limit_w > 0
        ? (gpu.power_draw_w / gpu.power_limit_w * 100).toFixed(1)
        : 0;

      return `
        <div style="background: var(--card-bg); padding: 1rem; border-radius: 0.5rem; border: 1px solid var(--border-color);">
          <h3 style="font-weight: 600; margin-bottom: 0.75rem;">${gpu.name}</h3>

          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 0.75rem;">
            <div>
              <div style="font-size: 0.75rem; color: var(--text-secondary);">Utilização GPU</div>
              <div style="font-size: 1.5rem; font-weight: 600; color: var(--primary);">${gpu.utilization_gpu.toFixed(0)}%</div>
            </div>

            <div>
              <div style="font-size: 0.75rem; color: var(--text-secondary);">Temperatura</div>
              <div style="font-size: 1.5rem; font-weight: 600; color: ${gpu.temperature > 80 ? 'var(--danger)' : 'var(--success)'};">
                ${gpu.temperature.toFixed(0)}°C
              </div>
            </div>

            <div>
              <div style="font-size: 0.75rem; color: var(--text-secondary);">Memória</div>
              <div style="font-size: 1rem; font-weight: 600; color: var(--warning);">
                ${gpu.memory_used_mb.toFixed(0)} / ${gpu.memory_total_mb.toFixed(0)} MB
              </div>
              <div class="progress-bar mt-1">
                <div class="progress-fill" style="width: ${memPercent}%; background: var(--warning);"></div>
              </div>
            </div>

            <div>
              <div style="font-size: 0.75rem; color: var(--text-secondary);">Potência</div>
              <div style="font-size: 1rem; font-weight: 600; color: var(--info);">
                ${gpu.power_draw_w.toFixed(0)} / ${gpu.power_limit_w.toFixed(0)} W
              </div>
              <div class="progress-bar mt-1">
                <div class="progress-fill" style="width: ${powerPercent}%; background: var(--info);"></div>
              </div>
            </div>
          </div>
        </div>
      `;
    }).join('');

    // Update chart data
    updateGPUCharts(gpuData.gpus);
  }

  // Render GPU processes
  renderGPUProcesses(processes);
}

function updateGPUCharts(gpus) {
  // Only track first GPU for simplicity
  if (gpus.length === 0) return;

  const gpu = gpus[0];
  const now = new Date().toLocaleTimeString();

  // Add new data point
  gpuLabels.push(now);
  gpuUtilizationHistory.push(gpu.utilization_gpu);
  gpuMemoryHistory.push(gpu.memory_used_mb);

  // Keep only last N points
  if (gpuLabels.length > GPU_HISTORY_LENGTH) {
    gpuLabels.shift();
    gpuUtilizationHistory.shift();
    gpuMemoryHistory.shift();
  }

  // Update charts
  if (gpuUtilizationChart) {
    gpuUtilizationChart.data.labels = gpuLabels;
    gpuUtilizationChart.data.datasets[0].data = gpuUtilizationHistory;
    gpuUtilizationChart.update('none');
  }

  if (gpuMemoryChart) {
    gpuMemoryChart.data.labels = gpuLabels;
    gpuMemoryChart.data.datasets[0].data = gpuMemoryHistory;
    gpuMemoryChart.update('none');
  }
}

function updateCamerasGPUChart(cameras) {
  if (!camerasActiveChart) return;

  // Gerar label de tempo atual
  const now = new Date().toLocaleTimeString();

  // Garantir que gpuLabels está populado
  if (gpuLabels.length === 0 || gpuLabels[gpuLabels.length - 1] !== now) {
    gpuLabels.push(now);

    // Manter apenas últimos N pontos
    if (gpuLabels.length > GPU_HISTORY_LENGTH) {
      gpuLabels.shift();
    }
  }

  // Atualizar histórico de cada câmera
  cameras.forEach(cam => {
    const cameraName = cam.camera_name;
    const gpuMemory = cam.gpu_memory_mb;

    // Inicializar histórico se não existir
    if (!cameraGpuHistory[cameraName]) {
      cameraGpuHistory[cameraName] = [];
    }

    // Adicionar novo ponto
    cameraGpuHistory[cameraName].push(gpuMemory);

    // Manter apenas últimos N pontos
    if (cameraGpuHistory[cameraName].length > GPU_HISTORY_LENGTH) {
      cameraGpuHistory[cameraName].shift();
    }
  });

  // Remover câmeras que não existem mais
  const activeCameraNames = cameras.map(c => c.camera_name);
  Object.keys(cameraGpuHistory).forEach(name => {
    if (!activeCameraNames.includes(name)) {
      delete cameraGpuHistory[name];
    }
  });

  // Cores para as linhas (até 10 câmeras)
  const colors = [
    '#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6',
    '#ec4899', '#14b8a6', '#f97316', '#06b6d4', '#84cc16'
  ];

  // Criar datasets para o gráfico
  const datasets = Object.keys(cameraGpuHistory).sort().map((cameraName, index) => {
    const color = colors[index % colors.length];
    const data = cameraGpuHistory[cameraName];

    // Preencher com zeros se necessário para ter o mesmo tamanho dos labels
    while (data.length < gpuLabels.length) {
      data.unshift(0);
    }

    return {
      label: cameraName,
      data: data,
      borderColor: color,
      backgroundColor: color.replace(')', ', 0.1)').replace('rgb', 'rgba'),
      fill: false,
      tension: 0.4,
      borderWidth: 2,
      pointRadius: 3,
      pointHoverRadius: 5
    };
  });

  // Atualizar gráfico
  camerasActiveChart.data.labels = gpuLabels;
  camerasActiveChart.data.datasets = datasets;
  camerasActiveChart.options.plugins.legend.display = datasets.length > 0;
  camerasActiveChart.update('active');
}

function renderGPUProcesses(processes) {
  document.getElementById('gpu-process-count').textContent = processes ? processes.length : 0;
  const container = document.getElementById('gpu-processes-list');

  if (!processes || processes.length === 0) {
    container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 1rem;">Nenhum processo usando GPU</p>';
    return;
  }

  container.innerHTML = processes.map(proc => `
    <div style="background: var(--card-bg); padding: 0.75rem; margin-bottom: 0.5rem; border-radius: 0.375rem; border: 1px solid var(--border-color);">
      <div style="display: flex; justify-content: space-between; align-items: center;">
        <div style="flex: 1;">
          <div style="font-weight: 600; color: var(--text-primary);">PID ${proc.pid} • ${proc.name}</div>
          <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.25rem; font-family: monospace; word-break: break-all;">
            ${proc.cmdline}
          </div>
        </div>
        <div style="text-align: right; margin-left: 1rem;">
          <div style="font-size: 0.75rem; color: var(--text-secondary);">GPU RAM</div>
          <div style="font-weight: 600; color: var(--warning);">${proc.gpu_memory_mb.toFixed(0)} MB</div>
        </div>
      </div>
    </div>
  `).join('');
}

function initGPUCharts() {
  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    animation: false,
    plugins: {
      legend: { display: false }
    },
    scales: {
      y: {
        beginAtZero: true,
        grid: { color: 'rgba(255,255,255,0.05)' },
        ticks: { color: '#94a3b8' }
      },
      x: {
        grid: { display: false },
        ticks: {
          color: '#94a3b8',
          maxTicksLimit: 10
        }
      }
    }
  };

  // GPU Utilization Chart
  const ctxUtil = document.getElementById('gpu-utilization-chart').getContext('2d');
  gpuUtilizationChart = new Chart(ctxUtil, {
    type: 'line',
    data: {
      labels: gpuLabels,
      datasets: [{
        label: 'Utilização (%)',
        data: gpuUtilizationHistory,
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        fill: true,
        tension: 0.4
      }]
    },
    options: {
      ...chartOptions,
      scales: {
        ...chartOptions.scales,
        y: {
          ...chartOptions.scales.y,
          max: 100
        }
      }
    }
  });

  // GPU Memory Chart
  const ctxMem = document.getElementById('gpu-memory-chart').getContext('2d');
  gpuMemoryChart = new Chart(ctxMem, {
    type: 'line',
    data: {
      labels: gpuLabels,
      datasets: [{
        label: 'Memória (MB)',
        data: gpuMemoryHistory,
        borderColor: '#f59e0b',
        backgroundColor: 'rgba(245, 158, 11, 0.1)',
        fill: true,
        tension: 0.4
      }]
    },
    options: chartOptions
  });

  // Cameras GPU Usage Chart
  const ctxCameras = document.getElementById('cameras-active-chart');
  if (!ctxCameras) return;

  camerasActiveChart = new Chart(ctxCameras.getContext('2d'), {
    type: 'line',
    data: {
      labels: [],
      datasets: []
    },
    options: {
      ...chartOptions,
      scales: {
        ...chartOptions.scales,
        y: {
          ...chartOptions.scales.y,
          beginAtZero: true,
          title: {
            display: true,
            text: 'GPU Memory (MB)',
            color: '#94a3b8'
          }
        }
      },
      plugins: {
        legend: {
          display: true,
          position: 'top',
          labels: {
            color: '#94a3b8',
            usePointStyle: true,
            padding: 10,
            font: { size: 10 }
          }
        }
      }
    }
  });
}

function startGPUMonitoring() {
  if (gpuRefreshInterval) {
    clearInterval(gpuRefreshInterval);
  }

  gpuRefreshActive = true;
  document.getElementById('gpu-status-icon').textContent = '▶️';

  loadHardwareStatus(); // Load immediately
  gpuRefreshInterval = setInterval(loadHardwareStatus, gpuRefreshRate);
}

function stopGPUMonitoring() {
  if (gpuRefreshInterval) {
    clearInterval(gpuRefreshInterval);
    gpuRefreshInterval = null;
  }

  gpuRefreshActive = false;
  document.getElementById('gpu-status-icon').textContent = '⏸️';
}

function toggleGPUMonitoring() {
  if (gpuRefreshActive) {
    stopGPUMonitoring();
  } else {
    startGPUMonitoring();
  }
}

// =============================================================================
// SYSTEM STATUS
// =============================================================================

async function loadSystemStatus() {
  try {
    const response = await fetch(`${API_BASE}/admin/system/status`);
    const data = await response.json();

    // Uptime
    document.getElementById('stat-uptime').textContent = formatUptime(data.uptime_seconds);

    // Containers
    renderContainers(data.containers);

  } catch (error) {
    console.error('[Admin] Error loading system status:', error);
  }
}

function renderContainers(containers) {
  const containersList = document.getElementById('containers-list');

  if (!containers || containers.length === 0) {
    containersList.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 2rem;">Nenhum container encontrado</p>';
    return;
  }

  containersList.innerHTML = containers.map(container => {
    const isRunning = container.State === 'running';
    const statusColor = isRunning ? 'var(--success)' : 'var(--danger)';
    const statusText = isRunning ? 'RUNNING' : container.State.toUpperCase();

    return `
      <div style="background: var(--card-bg); padding: 0.75rem; margin-bottom: 0.5rem; border-radius: 0.375rem; border: 1px solid var(--border-color);">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-weight: 600; color: var(--text-primary);">${container.Service || container.Name}</div>
            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.25rem;">
              ${container.Image || 'N/A'}
            </div>
          </div>
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <span style="background: ${statusColor}; color: white; padding: 0.25rem 0.5rem; border-radius: 0.25rem; font-size: 0.75rem; font-weight: 600;">
              ${statusText}
            </span>
            <button class="btn btn-sm btn-ghost" onclick="restartContainer('${container.Service || container.Name}')">
              🔄
            </button>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

async function restartContainer(service) {
  if (!confirm(`Tem certeza que deseja reiniciar o container ${service}?`)) {
    return;
  }

  try {
    showLoading(true);

    const response = await fetch(`${API_BASE}/admin/docker/${service}/restart`, {
      method: 'POST'
    });

    const data = await response.json();

    if (response.ok) {
      showToast(`Container ${service} reiniciado`, 'success');
      setTimeout(() => {
        loadSystemStatus();
      }, 3000);
    } else {
      throw new Error(data.detail || 'Erro ao reiniciar container');
    }

  } catch (error) {
    console.error('[Admin] Error restarting container:', error);
    showToast('Erro ao reiniciar container: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// =============================================================================
// BACKUP
// =============================================================================

async function createBackup() {
  const customName = document.getElementById('backup-custom-name').value.trim();

  try {
    showLoading(true);

    const url = customName
      ? `${API_BASE}/admin/backup/create?custom_name=${encodeURIComponent(customName)}`
      : `${API_BASE}/admin/backup/create`;

    const response = await fetch(url, {
      method: 'POST'
    });

    const data = await response.json();

    if (response.ok) {
      showToast(`Backup criado: ${data.filename} (${data.size_mb} MB)`, 'success');
      document.getElementById('backup-custom-name').value = '';
      await loadBackups();
    } else {
      throw new Error(data.detail || 'Erro ao criar backup');
    }

  } catch (error) {
    console.error('[Admin] Error creating backup:', error);
    showToast('Erro ao criar backup: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

async function loadBackups() {
  try {
    const response = await fetch(`${API_BASE}/admin/backup/list`);
    const backups = await response.json();

    renderBackups(backups);

  } catch (error) {
    console.error('[Admin] Error loading backups:', error);
  }
}

function renderBackups(backups) {
  const backupList = document.getElementById('backup-list');

  if (!backups || backups.length === 0) {
    backupList.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 2rem;">Nenhum backup encontrado</p>';
    return;
  }

  backupList.innerHTML = backups.map(backup => {
    const date = new Date(backup.created_at);
    const dateStr = date.toLocaleString('pt-BR');

    return `
      <div style="background: var(--card-bg); padding: 0.75rem; margin-bottom: 0.5rem; border-radius: 0.375rem; border: 1px solid var(--border-color);">
        <div style="display: flex; justify-content: space-between; align-items: flex-start;">
          <div style="flex: 1;">
            <div style="font-weight: 600; color: var(--text-primary); word-break: break-all;">
              ${backup.filename}
            </div>
            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.25rem;">
              ${backup.size_mb} MB • ${dateStr}
            </div>
          </div>
          <div style="display: flex; gap: 0.25rem; margin-left: 0.5rem;">
            <button class="btn btn-sm btn-success" onclick="downloadBackup('${backup.filename}')">
              ⬇️
            </button>
            <button class="btn btn-sm btn-danger" onclick="deleteBackup('${backup.filename}')">
              🗑️
            </button>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

async function downloadBackup(filename) {
  try {
    window.open(`${API_BASE}/admin/backup/download/${filename}`, '_blank');
    showToast('Download iniciado', 'success');
  } catch (error) {
    console.error('[Admin] Error downloading backup:', error);
    showToast('Erro ao baixar backup', 'error');
  }
}

async function deleteBackup(filename) {
  if (!confirm(`Tem certeza que deseja deletar o backup ${filename}?`)) {
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/admin/backup/delete/${filename}`, {
      method: 'DELETE'
    });

    const data = await response.json();

    if (response.ok) {
      showToast('Backup deletado', 'success');
      await loadBackups();
    } else {
      throw new Error(data.detail || 'Erro ao deletar backup');
    }

  } catch (error) {
    console.error('[Admin] Error deleting backup:', error);
    showToast('Erro ao deletar backup: ' + error.message, 'error');
  }
}

// =============================================================================
// GIT
// =============================================================================

async function loadGitConfig() {
  try {
    const response = await fetch(`${API_BASE}/admin/git/config`);
    const config = await response.json();

    if (config.is_repo) {
      document.getElementById('git-user-name').value = config.user_name || '';
      document.getElementById('git-user-email').value = config.user_email || '';
      document.getElementById('git-remote-url').value = config.remote_url || '';
    }

  } catch (error) {
    console.error('[Admin] Error loading git config:', error);
  }
}

async function saveGitConfig() {
  try {
    const config = {
      user_name: document.getElementById('git-user-name').value,
      user_email: document.getElementById('git-user-email').value,
      remote_url: document.getElementById('git-remote-url').value
    };

    const response = await fetch(`${API_BASE}/admin/git/config`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(config)
    });

    const data = await response.json();

    if (response.ok) {
      showToast('Configuração Git salva', 'success');
      await loadGitStatus();
    } else {
      throw new Error(data.detail || 'Erro ao salvar configuração');
    }

  } catch (error) {
    console.error('[Admin] Error saving git config:', error);
    showToast('Erro ao salvar configuração Git: ' + error.message, 'error');
  }
}

async function loadGitStatus() {
  try {
    const response = await fetch(`${API_BASE}/admin/git/status`);
    const status = await response.json();

    renderGitStatus(status);

  } catch (error) {
    console.error('[Admin] Error loading git status:', error);
  }
}

function renderGitStatus(status) {
  const gitStatusDiv = document.getElementById('git-status');

  if (!status.is_repo) {
    gitStatusDiv.innerHTML = '<p style="color: var(--warning);">⚠️ Não é um repositório Git. Configure e salve para inicializar.</p>';
    return;
  }

  let html = `<p><strong>Branch:</strong> ${status.branch}</p>`;

  if (status.ahead > 0) {
    html += `<p style="color: var(--primary);">⬆️ ${status.ahead} commit(s) à frente do remote</p>`;
  }

  if (status.behind > 0) {
    html += `<p style="color: var(--warning);">⬇️ ${status.behind} commit(s) atrás do remote</p>`;
  }

  if (status.clean) {
    html += '<p style="color: var(--success);">✅ Working tree limpo</p>';
  } else {
    if (status.modified && status.modified.length > 0) {
      html += `<p style="color: var(--warning); margin-top:10px;"><strong>Modificados (${status.modified.length}):</strong></p>`;
      status.modified.forEach(file => {
        html += `<div style="background: var(--card-bg); padding: 0.25rem 0.5rem; margin: 0.25rem 0; border-radius: 0.25rem; border-left: 3px solid var(--warning);">M ${file}</div>`;
      });
    }

    if (status.untracked && status.untracked.length > 0) {
      html += `<p style="color: var(--primary); margin-top:10px;"><strong>Não rastreados (${status.untracked.length}):</strong></p>`;
      status.untracked.forEach(file => {
        html += `<div style="background: var(--card-bg); padding: 0.25rem 0.5rem; margin: 0.25rem 0; border-radius: 0.25rem; border-left: 3px solid var(--primary);">? ${file}</div>`;
      });
    }
  }

  gitStatusDiv.innerHTML = html;
}

async function gitCommit(push = false) {
  const message = document.getElementById('git-commit-message').value.trim();

  if (!message) {
    showToast('Digite uma mensagem de commit', 'error');
    return;
  }

  try {
    showLoading(true);

    const response = await fetch(`${API_BASE}/admin/git/commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: message,
        push: push
      })
    });

    const data = await response.json();

    if (response.ok) {
      let msg = `Commit criado: ${data.commit_sha}`;
      if (push) {
        msg += data.pushed ? ' e enviado!' : ' (push falhou)';
      }
      showToast(msg, 'success');

      document.getElementById('git-commit-message').value = '';

      await loadGitStatus();
      await loadGitLog();
    } else {
      throw new Error(data.detail || 'Erro ao fazer commit');
    }

  } catch (error) {
    console.error('[Admin] Error committing:', error);
    showToast('Erro ao fazer commit: ' + error.message, 'error');
  } finally {
    showLoading(false);
  }
}

// Funções gitPush e gitPull removidas por segurança
// Use "Enviar pro Git" (commit + push) ao invés de push solo

async function loadGitLog() {
  try {
    const response = await fetch(`${API_BASE}/admin/git/log?limit=5`);
    const commits = await response.json();

    renderGitLog(commits);

  } catch (error) {
    console.error('[Admin] Error loading git log:', error);
  }
}

function renderGitLog(commits) {
  const gitLogDiv = document.getElementById('git-log');

  if (!commits || commits.length === 0) {
    gitLogDiv.innerHTML = '<p style="color: var(--text-secondary); text-align: center; padding: 2rem;">Nenhum commit encontrado</p>';
    return;
  }

  gitLogDiv.innerHTML = commits.map(commit => {
    const date = new Date(commit.date);
    const dateStr = date.toLocaleString('pt-BR');

    return `
      <div style="background: var(--card-bg); padding: 0.75rem; margin-bottom: 0.5rem; border-radius: 0.375rem; border-left: 3px solid var(--primary);">
        <span style="font-family: monospace; color: var(--primary); font-weight: 600; font-size: 0.75rem;">${commit.sha}</span>
        <div style="color: var(--text-primary); margin: 0.25rem 0;">${commit.message}</div>
        <div style="font-size: 0.75rem; color: var(--text-secondary);">${commit.author} • ${dateStr}</div>
      </div>
    `;
  }).join('');
}

// =============================================================================
// LOGS
// =============================================================================

async function loadLogs() {
  const service = document.getElementById('log-service').value;

  try {
    const response = await fetch(`${API_BASE}/admin/docker/${service}/logs?lines=200`);
    const data = await response.json();

    document.getElementById('logs-viewer').textContent = data.logs || 'Nenhum log disponível';

    // Scroll to bottom
    const logsViewer = document.getElementById('logs-viewer');
    logsViewer.scrollTop = logsViewer.scrollHeight;

  } catch (error) {
    console.error('[Admin] Error loading logs:', error);
    showToast('Erro ao carregar logs', 'error');
  }
}

function autoRefreshLogs() {
  if (logsRefreshInterval) {
    clearInterval(logsRefreshInterval);
  }

  loadLogs();
  logsRefreshInterval = setInterval(loadLogs, 5000);
  showToast('Auto-refresh de logs ativado (5s)', 'success');
}

function stopAutoRefreshLogs() {
  if (logsRefreshInterval) {
    clearInterval(logsRefreshInterval);
    logsRefreshInterval = null;
    showToast('Auto-refresh de logs desativado', 'success');
  }
}

// =============================================================================
// INIT
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
  console.log('[Admin] Initializing modern admin panel');

  // Initialize GPU charts
  initGPUCharts();

  // Load initial data
  await Promise.all([
    loadHardwareStatus(),
    loadSystemStatus(),
    loadBackups(),
    loadGitConfig(),
    loadGitStatus(),
    loadGitLog()
  ]);

  // Start GPU monitoring by default
  startGPUMonitoring();

  // Auto-refresh system status every 30s
  setInterval(() => {
    loadSystemStatus();
  }, 30000);

  // Event listeners
  document.getElementById('btn-voltar')?.addEventListener('click', () => {
    window.location.href = '/index.html';
  });

  // GPU Controls
  document.getElementById('btn-toggle-gpu')?.addEventListener('click', toggleGPUMonitoring);
  document.getElementById('gpu-refresh-rate')?.addEventListener('change', (e) => {
    gpuRefreshRate = parseInt(e.target.value);
    if (gpuRefreshActive) {
      startGPUMonitoring(); // Restart with new rate
    }
  });

  // Backup
  document.getElementById('btn-criar-backup')?.addEventListener('click', createBackup);

  // Git
  document.getElementById('btn-save-git-config')?.addEventListener('click', saveGitConfig);
  document.getElementById('btn-git-commit')?.addEventListener('click', () => gitCommit(false));
  document.getElementById('btn-git-commit-push')?.addEventListener('click', () => gitCommit(true));

  // Logs
  document.getElementById('btn-load-logs')?.addEventListener('click', loadLogs);
  document.getElementById('btn-auto-refresh-logs')?.addEventListener('click', autoRefreshLogs);
  document.getElementById('btn-stop-refresh-logs')?.addEventListener('click', stopAutoRefreshLogs);

  console.log('[Admin] Initialization complete');
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  stopGPUMonitoring();
  stopAutoRefreshLogs();
});
