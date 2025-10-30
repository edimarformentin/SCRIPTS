/**
 * Admin Panel JavaScript
 * Gerencia backup, git, logs, docker
 */

let autoRefreshInterval = null;

// =============================================================================
// INIT
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('[Admin] Initializing admin panel');

    // Carregar dados iniciais
    await loadSystemStatus();
    await loadBackups();
    await loadGitConfig();
    await loadGitStatus();
    await loadGitLog();

    // Auto-refresh status a cada 30s
    setInterval(() => {
        loadSystemStatus();
    }, 30000);
});

// =============================================================================
// SYSTEM STATUS
// =============================================================================

async function loadSystemStatus() {
    try {
        const response = await fetch('/api/admin/system/status');
        const data = await response.json();

        // CPU
        document.getElementById('cpuPercent').textContent = data.cpu_percent;

        // Memory
        document.getElementById('memoryUsed').textContent = data.memory_used_gb;
        document.getElementById('memoryTotal').textContent = data.memory_total_gb;
        document.getElementById('memoryProgress').style.width = data.memory_percent + '%';

        // Disk
        document.getElementById('diskUsed').textContent = data.disk_used_gb;
        document.getElementById('diskTotal').textContent = data.disk_total_gb;
        document.getElementById('diskProgress').style.width = data.disk_percent + '%';

        // Uptime
        const uptime = formatUptime(data.uptime_seconds);
        document.getElementById('uptime').textContent = uptime;

        // Containers
        renderContainers(data.containers);

    } catch (error) {
        console.error('[Admin] Error loading system status:', error);
        showToast('Erro ao carregar status do sistema', 'error');
    }
}

function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);

    return `${days}d ${hours}h ${minutes}m`;
}

function renderContainers(containers) {
    const containersList = document.getElementById('containersList');

    if (!containers || containers.length === 0) {
        containersList.innerHTML = '<p style="color:#64748b;">Nenhum container encontrado</p>';
        return;
    }

    containersList.innerHTML = containers.map(container => {
        const isRunning = container.State === 'running';
        const statusClass = isRunning ? 'status-running' : 'status-stopped';
        const statusText = isRunning ? 'RUNNING' : container.State.toUpperCase();

        return `
            <div class="container-item">
                <div>
                    <strong style="color:#f1f5f9;">${container.Service || container.Name}</strong>
                    <div style="font-size:12px; color:#94a3b8; margin-top:4px;">
                        ${container.Image || 'N/A'}
                    </div>
                </div>
                <span class="container-status ${statusClass}">${statusText}</span>
            </div>
        `;
    }).join('');
}

// =============================================================================
// BACKUP
// =============================================================================

async function createBackup() {
    try {
        showLoading(true);

        const response = await fetch('/api/admin/backup/create', {
            method: 'POST'
        });

        const data = await response.json();

        if (response.ok) {
            showToast(`Backup criado: ${data.filename} (${data.size_mb} MB)`, 'success');
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
        const response = await fetch('/api/admin/backup/list');
        const backups = await response.json();

        renderBackups(backups);

    } catch (error) {
        console.error('[Admin] Error loading backups:', error);
        showToast('Erro ao carregar backups', 'error');
    }
}

function renderBackups(backups) {
    const backupList = document.getElementById('backupList');

    if (!backups || backups.length === 0) {
        backupList.innerHTML = '<p style="color:#64748b; text-align:center; padding:20px;">Nenhum backup encontrado</p>';
        return;
    }

    backupList.innerHTML = backups.map(backup => {
        const date = new Date(backup.created_at);
        const dateStr = date.toLocaleString('pt-BR');

        return `
            <div class="backup-item">
                <div class="backup-info">
                    <div class="backup-name">${backup.filename}</div>
                    <div class="backup-meta">
                        ${backup.size_mb} MB • ${dateStr}
                    </div>
                </div>
                <div class="backup-actions">
                    <button class="btn-admin btn-small btn-success" onclick="downloadBackup('${backup.filename}')">
                        ⬇️ Download
                    </button>
                    <button class="btn-admin btn-small btn-danger" onclick="deleteBackup('${backup.filename}')">
                        🗑️ Deletar
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

async function downloadBackup(filename) {
    try {
        window.open(`/api/admin/backup/download/${filename}`, '_blank');
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
        const response = await fetch(`/api/admin/backup/delete/${filename}`, {
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
        const response = await fetch('/api/admin/git/config');
        const config = await response.json();

        if (config.is_repo) {
            document.getElementById('gitUserName').value = config.user_name || '';
            document.getElementById('gitUserEmail').value = config.user_email || '';
            document.getElementById('gitRemoteUrl').value = config.remote_url || '';
        }

    } catch (error) {
        console.error('[Admin] Error loading git config:', error);
    }
}

async function saveGitConfig() {
    try {
        const config = {
            user_name: document.getElementById('gitUserName').value,
            user_email: document.getElementById('gitUserEmail').value,
            remote_url: document.getElementById('gitRemoteUrl').value
        };

        const response = await fetch('/api/admin/git/config', {
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
        const response = await fetch('/api/admin/git/status');
        const status = await response.json();

        renderGitStatus(status);

    } catch (error) {
        console.error('[Admin] Error loading git status:', error);
    }
}

function renderGitStatus(status) {
    const gitStatusDiv = document.getElementById('gitStatus');

    if (!status.is_repo) {
        gitStatusDiv.innerHTML = '<p style="color:#eab308;">⚠️ Não é um repositório Git. Configure e salve para inicializar.</p>';
        return;
    }

    let html = `<p><strong>Branch:</strong> ${status.branch}</p>`;

    if (status.ahead > 0) {
        html += `<p style="color:#3b82f6;">⬆️ ${status.ahead} commit(s) à frente do remote</p>`;
    }

    if (status.behind > 0) {
        html += `<p style="color:#eab308;">⬇️ ${status.behind} commit(s) atrás do remote</p>`;
    }

    if (status.clean) {
        html += '<p style="color:#10b981;">✅ Working tree limpo</p>';
    } else {
        if (status.modified && status.modified.length > 0) {
            html += `<p style="color:#eab308; margin-top:10px;"><strong>Modificados (${status.modified.length}):</strong></p>`;
            status.modified.forEach(file => {
                html += `<div class="git-file git-modified">M ${file}</div>`;
            });
        }

        if (status.untracked && status.untracked.length > 0) {
            html += `<p style="color:#3b82f6; margin-top:10px;"><strong>Não rastreados (${status.untracked.length}):</strong></p>`;
            status.untracked.forEach(file => {
                html += `<div class="git-file git-untracked">? ${file}</div>`;
            });
        }
    }

    gitStatusDiv.innerHTML = html;
}

async function gitCommit(push = false) {
    const message = document.getElementById('commitMessage').value.trim();

    if (!message) {
        showToast('Digite uma mensagem de commit', 'error');
        return;
    }

    try {
        showLoading(true);

        const response = await fetch('/api/admin/git/commit', {
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

            document.getElementById('commitMessage').value = '';

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

async function gitPush() {
    try {
        showLoading(true);

        const response = await fetch('/api/admin/git/push', {
            method: 'POST'
        });

        const data = await response.json();

        if (response.ok) {
            showToast('Push realizado com sucesso', 'success');
            await loadGitStatus();
        } else {
            throw new Error(data.detail || 'Erro ao fazer push');
        }

    } catch (error) {
        console.error('[Admin] Error pushing:', error);
        showToast('Erro ao fazer push: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

async function gitPull() {
    try {
        showLoading(true);

        const response = await fetch('/api/admin/git/pull', {
            method: 'POST'
        });

        const data = await response.json();

        if (response.ok) {
            showToast('Pull realizado com sucesso', 'success');
            await loadGitStatus();
            await loadGitLog();
        } else {
            throw new Error(data.detail || 'Erro ao fazer pull');
        }

    } catch (error) {
        console.error('[Admin] Error pulling:', error);
        showToast('Erro ao fazer pull: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

async function loadGitLog() {
    try {
        const response = await fetch('/api/admin/git/log?limit=5');
        const commits = await response.json();

        renderGitLog(commits);

    } catch (error) {
        console.error('[Admin] Error loading git log:', error);
    }
}

function renderGitLog(commits) {
    const gitLogDiv = document.getElementById('gitLog');

    if (!commits || commits.length === 0) {
        gitLogDiv.innerHTML = '<p style="color:#64748b; text-align:center; padding:20px;">Nenhum commit encontrado</p>';
        return;
    }

    gitLogDiv.innerHTML = commits.map(commit => {
        const date = new Date(commit.date);
        const dateStr = date.toLocaleString('pt-BR');

        return `
            <div class="commit-log">
                <span class="commit-sha">${commit.sha}</span>
                <div class="commit-message">${commit.message}</div>
                <div class="commit-meta">${commit.author} • ${dateStr}</div>
            </div>
        `;
    }).join('');
}

// =============================================================================
// LOGS
// =============================================================================

async function loadLogs() {
    const service = document.getElementById('logService').value;

    try {
        const response = await fetch(`/api/admin/docker/${service}/logs?lines=200`);
        const data = await response.json();

        document.getElementById('logsViewer').textContent = data.logs || 'Nenhum log disponível';

        // Scroll to bottom
        const logsViewer = document.getElementById('logsViewer');
        logsViewer.scrollTop = logsViewer.scrollHeight;

    } catch (error) {
        console.error('[Admin] Error loading logs:', error);
        showToast('Erro ao carregar logs', 'error');
    }
}

function autoRefreshLogs() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
    }

    loadLogs();
    autoRefreshInterval = setInterval(loadLogs, 5000);
    showToast('Auto-refresh ativado (5s)', 'success');
}

function stopAutoRefresh() {
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
        showToast('Auto-refresh desativado', 'success');
    }
}

// =============================================================================
// DOCKER
// =============================================================================

async function restartContainer(service) {
    if (!confirm(`Tem certeza que deseja reiniciar o container ${service}?`)) {
        return;
    }

    try {
        showLoading(true);

        const response = await fetch(`/api/admin/docker/${service}/restart`, {
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
// UTILS
// =============================================================================

function showLoading(show) {
    const overlay = document.getElementById('loadingOverlay');
    overlay.style.display = show ? 'flex' : 'none';
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    if (!toast) {
        console.warn('Toast element not found');
        return;
    }

    toast.textContent = message;
    toast.className = `toast toast-${type} show`;

    setTimeout(() => {
        toast.className = 'toast';
    }, 3000);
}
