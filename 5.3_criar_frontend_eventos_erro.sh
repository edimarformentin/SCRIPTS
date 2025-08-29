#!/bin/bash
# Nome do arquivo: 5.3_criar_frontend_eventos_erro.sh (v5 - FINAL COM SLIDER E LIMITES DE ZOOM)
set -e
echo "==== FRONTEND (3/3): Criando template de eventos final (COM SLIDER E LIMITES)... ===="
cd /home/edimar/SISTEMA
mkdir -p GESTAO_WEB/templates

# 1. TEMPLATE VER_EVENTOS (ver_eventos.html) - VERSÃO FINAL E POLIDA
echo "--> Criando ver_eventos.html com slider de zoom e limites de movimento..."
cat <<'EOT' > GESTAO_WEB/templates/ver_eventos.html
{% extends "base.html" %}

{% block title %}Eventos de {{ cliente.nome }}{% endblock %}

{% block content %}
<style>
    .event-image {
        aspect-ratio: 16/9; object-fit: cover; background-color: #eee;
        cursor: pointer; transition: transform 0.2s ease-in-out;
    }
    .event-image:hover { transform: scale(1.03); }

    #modalImageContainer {
        overflow: hidden; cursor: grab; touch-action: none;
        display: flex; align-items: center; justify-content: center;
    }
    #modalImage {
        transition: transform 0.15s ease-out;
        transform-origin: center center;
        max-width: 100%; max-height: 100%;
    }
    .zoom-controls {
        display: flex; align-items: center; gap: 0.5rem;
    }
</style>

<div class="d-flex justify-content-between align-items-center mb-4">
    <h1><i class="bi bi-camera-reels"></i> Eventos de IA - {{ cliente.nome }}</h1>
    <a href="/cliente/{{ cliente.id }}" class="btn btn-secondary"><i class="bi bi-arrow-left"></i> Voltar para o Cliente</a>
</div>

{% if not eventos_por_camera %}
<div class="text-center py-5 card"><div class="card-body">
    <p class="lead">Nenhum evento de detecção de IA foi encontrado.</p>
    <p class="text-muted">Verifique se a "Detecção de Objetos (IA)" está ativa nas câmeras.</p>
</div></div>
{% else %}
    {% for cam_nome, eventos in eventos_por_camera.items() %}
    <div class="card shadow-sm mb-4">
        <div class="card-header"><h5 class="mb-0"><i class="bi bi-camera-video"></i> Câmera: {{ cam_nome }}</h5></div>
        <div class="card-body"><div class="row row-cols-1 row-cols-sm-2 row-cols-md-3 row-cols-lg-4 g-3">
            {% for evento in eventos %}
            <div class="col"><div class="card h-100">
                <img src="{{ evento.url }}" class="card-img-top event-image"
                     alt="Snapshot do evento"
                     data-image-url="{{ evento.url }}"
                     data-image-title="Evento: {{ evento.objeto | capitalize }} em {{ evento.data }} às {{ evento.hora }}"
                     loading="lazy">
                <div class="card-body p-2">
                    <p class="card-text mb-1"><i class="bi bi-tag"></i> <strong>{{ evento.objeto | capitalize }}</strong></p>
                    <p class="card-text small text-muted"><i class="bi bi-calendar-event"></i> {{ evento.data }} <i class="bi bi-clock ms-1"></i> {{ evento.hora }}</p>
                </div>
            </div></div>
            {% endfor %}
        </div></div>
    </div>
    {% endfor %}
{% endif %}

<!-- Modal Final com Controles de Zoom -->
<div class="modal fade" id="imageViewerModal" tabindex="-1">
  <div class="modal-dialog modal-xl modal-dialog-centered">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="imageViewerModalLabel">Visualizador de Evento</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body p-0" id="modalImageContainer">
        <img id="modalImage" src="" alt="Imagem do Evento">
      </div>
      <div class="modal-footer d-flex justify-content-between">
         <a id="downloadButton" href="#" download class="btn btn-success"><i class="bi bi-download"></i> Baixar</a>
         <div class="zoom-controls">
            <button id="zoomOutBtn" class="btn btn-secondary btn-sm"><i class="bi bi-zoom-out"></i></button>
            <input type="range" id="zoomSlider" class="form-range" min="1" max="5" step="0.1" value="1" style="width: 150px;">
            <button id="zoomInBtn" class="btn btn-secondary btn-sm"><i class="bi bi-zoom-in"></i></button>
         </div>
         <button type="button" class="btn btn-primary" data-bs-dismiss="modal">Fechar</button>
      </div>
    </div>
  </div>
</div>
{% endblock %}

{% block scripts %}
<script>
document.addEventListener('DOMContentLoaded', function () {
    const modalEl = document.getElementById('imageViewerModal');
    const imageViewerModal = new bootstrap.Modal(modalEl);
    const modalImageContainer = document.getElementById('modalImageContainer');
    const modalImage = document.getElementById('modalImage');
    const downloadButton = document.getElementById('downloadButton');
    const zoomSlider = document.getElementById('zoomSlider');
    const zoomInBtn = document.getElementById('zoomInBtn');
    const zoomOutBtn = document.getElementById('zoomOutBtn');

    let scale = 1, isPanning = false, start = { x: 0, y: 0 }, translate = { x: 0, y: 0 };

    function applyTransform() {
        const containerRect = modalImageContainer.getBoundingClientRect();
        const imageRect = modalImage.getBoundingClientRect();
        const maxTranslateX = (imageRect.width * scale - containerRect.width) / 2;
        const maxTranslateY = (imageRect.height * scale - containerRect.height) / 2;

        translate.x = Math.max(-maxTranslateX, Math.min(maxTranslateX, translate.x));
        translate.y = Math.max(-maxTranslateY, Math.min(maxTranslateY, translate.y));

        modalImage.style.transform = `translate(${translate.x}px, ${translate.y}px) scale(${scale})`;
    }

    function updateZoom(newScale) {
        scale = Math.max(1, Math.min(5, newScale));
        zoomSlider.value = scale;
        applyTransform();
    }

    function resetZoom() {
        translate = { x: 0, y: 0 };
        updateZoom(1);
    }

    document.querySelectorAll('.event-image').forEach(image => {
        image.addEventListener('click', function () {
            modalImage.src = this.dataset.imageUrl;
            document.getElementById('imageViewerModalLabel').textContent = this.dataset.imageTitle;
            downloadButton.href = this.dataset.imageUrl;
            downloadButton.download = `evento_${new Date().toISOString().split('T')[0]}.jpg`;
            resetZoom();
            imageViewerModal.show();
        });
    });

    modalImageContainer.addEventListener('wheel', e => {
        e.preventDefault();
        updateZoom(scale - e.deltaY * 0.005);
    }, { passive: false });

    modalImageContainer.addEventListener('mousedown', e => {
        if (scale > 1) {
            e.preventDefault();
            isPanning = true;
            start = { x: e.clientX - translate.x, y: e.clientY - translate.y };
            modalImageContainer.style.cursor = 'grabbing';
        }
    });

    window.addEventListener('mousemove', e => {
        if (isPanning) {
            e.preventDefault();
            translate.x = e.clientX - start.x;
            translate.y = e.clientY - start.y;
            applyTransform();
        }
    });

    window.addEventListener('mouseup', () => {
        if (isPanning) {
            isPanning = false;
            modalImageContainer.style.cursor = 'grab';
        }
    });

    zoomSlider.addEventListener('input', e => updateZoom(parseFloat(e.target.value)));
    zoomInBtn.addEventListener('click', () => updateZoom(scale + 0.2));
    zoomOutBtn.addEventListener('click', () => updateZoom(scale - 0.2));
    modalEl.addEventListener('hidden.bs.modal', resetZoom);
});
</script>
{% endblock %}
EOT

# 2. TEMPLATE ERRO (erro.html) - Mantido como estava
echo "--> Recriando erro.html (versão moderna)"
cat <<'EOT' > GESTAO_WEB/templates/erro.html
{% extends "base.html" %}{% block title %}Página Não Encontrada{% endblock %}{% block content %}<style>.error-container{text-align:center;padding:60px 20px;}.error-code{font-size:8rem;font-weight:700;color:#6c757d;text-shadow:2px 2px 4px rgba(0,0,0,0.1);}.error-heading{font-size:2.5rem;font-weight:300;margin-top:-20px;margin-bottom:20px;}.error-message{font-size:1.25rem;color:#6c757d;margin-bottom:40px;}.error-actions .btn{margin:0 10px;min-width:200px;}</style><div class="error-container"><div class="error-code">404</div><h1 class="error-heading">Oops! Página não encontrada.</h1><p class="error-message">{{ message or "O recurso que você está procurando não existe ou foi movido." }}</p><div class="error-actions"><a href="/" class="btn btn-primary btn-lg"><i class="bi bi-house-door-fill"></i> Voltar para o Início</a><button class="btn btn-outline-secondary btn-lg" data-bs-toggle="modal" data-bs-target="#searchModal"><i class="bi bi-search"></i> Procurar por CPF</button></div></div><div class="modal fade" id="searchModal" tabindex="-1"><div class="modal-dialog"><div class="modal-content"><div class="modal-header"><h5 class="modal-title" id="searchModalLabel"><i class="bi bi-search"></i> Procurar Cliente por CPF</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div><div class="modal-body"><form id="search-form"><div class="mb-3"><label for="cpf-search" class="form-label">Digite o CPF do cliente:</label><input type="text" class="form-control" id="cpf-search" placeholder="000.000.000-00" required></div><button type="submit" class="btn btn-primary w-100">Procurar</button></form><div id="search-result" class="mt-3"></div></div></div></div></div>{% endblock %}{% block scripts %}<script>document.addEventListener('DOMContentLoaded',function(){const searchForm=document.getElementById('search-form');if(searchForm){const searchInput=document.getElementById('cpf-search');const searchResult=document.getElementById('search-result');searchForm.addEventListener('submit',function(event){event.preventDefault();const cpf=searchInput.value;searchResult.innerHTML='<div class="d-flex justify-content-center"><div class="spinner-border" role="status"><span class="visually-hidden">Loading...</span></div></div>';fetch(`/api/buscar_cliente_por_cpf?cpf=${encodeURIComponent(cpf)}`).then(response=>response.json()).then(data=>{if(data.id){searchResult.innerHTML=`<div class="alert alert-success">Cliente encontrado! <a href="/cliente/${data.id}" class="alert-link">Clique aqui para ir para a página de ${data.nome}</a>.</div>`;}else{searchResult.innerHTML=`<div class="alert alert-danger">${data.detail||'Nenhum cliente encontrado com este CPF.'}</div>`;}}).catch(error=>{console.error('Erro na busca:',error);searchResult.innerHTML='<div class="alert alert-danger">Ocorreu um erro ao realizar a busca.</div>';});});}});</script>{% endblock %}
EOT

echo "==== PARTE 3/3 CONCLUÍDA (VERSÃO FINAL) ===="
