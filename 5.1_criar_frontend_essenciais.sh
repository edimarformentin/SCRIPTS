#!/bin/bash
# Nome do arquivo: 5.1_criar_frontend_essenciais.sh (v5 - com BEM e CSS de Componentes)
set -e
echo "==== FRONTEND (1/3): Criando essenciais com CSS externo e de componentes... ===="
cd /home/edimar/SISTEMA
mkdir -p GESTAO_WEB/templates
mkdir -p GESTAO_WEB/static/css

# 1. CRIAR O ARQUIVO CSS PRINCIPAL
echo "--> Criando GESTAO_WEB/static/css/main.css"
cat <<'CSS_MAIN_EOF' > GESTAO_WEB/static/css/main.css
:root {
    --primary-color: #0d6efd; --primary-hover: #0b5ed7;
    --secondary-color: #6c757d; --secondary-hover: #5c636a;
    --success-color: #198754; --success-hover: #157347;
    --danger-color: #dc3545; --danger-hover: #bb2d3b;
    --light-gray: #f8f9fa; --white: #ffffff;
    --border-radius: 0.5rem; --box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08 );
    --transition: all 0.2s ease-in-out;
}
body { font-family: 'Inter', sans-serif; background-color: var(--light-gray); }
.navbar { background: linear-gradient(90deg, #0d6efd, #0a58ca); box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
.card { border: none; border-radius: var(--border-radius); box-shadow: var(--box-shadow); transition: var(--transition); }
.card:hover { transform: translateY(-3px); box-shadow: 0 6px 16px rgba(0, 0, 0, 0.1); }
.card-header { background-color: var(--white); border-bottom: 1px solid #dee2e6; font-weight: 600; }
.btn { border-radius: var(--border-radius); font-weight: 500; padding: 0.5rem 1rem; transition: var(--transition); box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
.btn:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
.btn-sm { padding: 0.25rem 0.5rem; }
.form-control, .form-select { border-radius: var(--border-radius); }
.form-control:focus, .form-select:focus { box-shadow: 0 0 0 0.25rem rgba(13, 110, 253, 0.25); border-color: var(--primary-color); }
.list-group-item { transition: background-color 0.2s ease; }
.list-group-item-action:hover { background-color: #e9ecef; }
CSS_MAIN_EOF

# 2. CRIAR O ARQUIVO CSS DE COMPONENTES
echo "--> Criando GESTAO_WEB/static/css/components.css para BEM"
cat <<'CSS_COMP_EOF' > GESTAO_WEB/static/css/components.css
/* === Componente: Lista de Câmeras (camera-list) === */
.camera-list {
    /* O ul.list-group já cuida da maior parte */
    padding-left: 0;
    list-style: none;
}

.camera-list__item {
    /* O li.list-group-item já cuida da maior parte */
    padding: 1rem;
}

.camera-list__row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem; /* Adiciona um espaço entre os detalhes e os botões */
}

.camera-list__details {
    flex-grow: 1; /* Faz com que esta div ocupe o espaço disponível */
}

.camera-list__name {
    font-weight: 600;
}

.camera-list__actions {
    flex-shrink: 0; /* Impede que os botões encolham */
}

.camera-list__status-tags {
    margin-top: 0.75rem;
    display: flex;
    gap: 0.5rem; /* Adiciona espaço entre os badges de status */
}
CSS_COMP_EOF

# 3. CRIAR O TEMPLATE BASE (base.html) JÁ COM OS DOIS LINKS DE CSS
echo "--> Criando base.html com link para main.css e components.css"
cat <<'HTML_EOF' > GESTAO_WEB/templates/base.html
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <title>{% block title %}Sistema de Monitoramento{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <!-- Nossos CSS Customizados -->
    <link rel="stylesheet" href="/static/css/main.css">
    <link rel="stylesheet" href="/static/css/components.css">
</head>
<body class="bg-light">
    <nav class="navbar navbar-expand-lg navbar-dark">
        <div class="container">
            <a class="navbar-brand" href="/"><i class="bi bi-camera-video-fill me-2"></i><strong>Sistema de Monitoramento</strong></a>
            <div class="ms-auto">
                <a href="/novo_cliente" class="btn btn-outline-light"><i class="bi bi-person-plus me-2"></i>Novo Cliente</a>
            </div>
        </div>
    </nav>
    <main class="container my-4">
        {% block content %}{% endblock %}
    </main>
    <div class="modal fade" id="videoPlayerModal" tabindex="-1"><div class="modal-dialog modal-lg"><div class="modal-content"><div class="modal-header"><h5 class="modal-title" id="videoPlayerModalLabel">Ao Vivo</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div><div class="modal-body"><video id="videoPlayer" class="w-100" controls autoplay muted></video></div></div></div></div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
    <script>
        var tooltipTriggerList=[].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'  ));
        var tooltipList=tooltipTriggerList.map(function(el){return new bootstrap.Tooltip(el)});
    </script>
    {% block scripts %}{% endblock %}
</body>
</html>
HTML_EOF

# 4. Recriar os outros arquivos essenciais para manter a consistência do script
echo "--> Recriando novo_cliente.html"
cat <<'EOT' > GESTAO_WEB/templates/novo_cliente.html
{% extends "base.html" %}{% block title %}Novo Cliente{% endblock %}{% block content %}<div class="row justify-content-center"><div class="col-lg-8"><div class="card shadow-sm"><div class="card-header"><h3><i class="bi bi-person-plus-fill me-2"></i>Cadastrar Novo Cliente</h3></div><div class="card-body p-4">{% if error %}<div class="alert alert-danger" role="alert"><i class="bi bi-exclamation-triangle-fill me-2"></i>{{ error }}</div>{% endif %}<form action="/novo_cliente" method="post"><div class="row g-3"><div class="col-md-12"><label for="nome" class="form-label">Nome Completo</label><input type="text" id="nome" name="nome" class="form-control" value="{{ form_data.nome if form_data else '' }}" required></div><div class="col-md-6"><label for="cpf" class="form-label">CPF</label><input type="text" id="cpf" name="cpf" class="form-control" value="{{ form_data.cpf if form_data else '' }}" required></div><div class="col-md-6"><label for="telefone" class="form-label">Telefone</label><input type="text" id="telefone" name="telefone" class="form-control" value="{{ form_data.telefone if form_data else '' }}" required></div><div class="col-md-12"><label for="email" class="form-label">E-mail</label><input type="email" id="email" name="email" class="form-control" value="{{ form_data.email if form_data else '' }}" required></div><div class="col-md-4"><label for="cep" class="form-label">CEP</label><input type="text" id="cep" name="cep" class="form-control" value="{{ form_data.cep if form_data else '' }}" required></div><div class="col-md-8"><label for="endereco" class="form-label">Endereço</label><input type="text" id="endereco" name="endereco" class="form-control" value="{{ form_data.endereco if form_data else '' }}" required></div></div><div class="mt-4 d-flex justify-content-between"><a href="/" class="btn btn-secondary">Cancelar</a><button type="submit" class="btn btn-success">Cadastrar Cliente</button></div></form></div></div></div></div>{% endblock %}
EOT

echo "--> Recriando editar_cliente.html"
cat <<'EOT' > GESTAO_WEB/templates/editar_cliente.html
{% extends "base.html" %}{% block title %}Editar {{ cliente.nome }}{% endblock %}{% block content %}<div class="row justify-content-center"><div class="col-lg-8"><div class="card shadow-sm"><div class="card-header"><h3><i class="bi bi-pencil-square me-2"></i>Editando Cliente: {{ cliente.nome }}</h3></div><div class="card-body p-4"><form action="/cliente/{{ cliente.id }}/editar" method="post"><div class="row g-3"><div class="col-md-6"><label class="form-label">Nome</label><input type="text" name="nome" class="form-control" value="{{ cliente.nome }}" required></div><div class="col-md-6"><label class="form-label">CPF</label><input type="text" name="cpf" class="form-control" value="{{ cliente.cpf }}" required></div><div class="col-md-6"><label class="form-label">E-mail</label><input type="email" name="email" class="form-control" value="{{ cliente.email }}" required></div><div class="col-md-6"><label class="form-label">Telefone</label><input type="text" name="telefone" class="form-control" value="{{ cliente.telefone }}" required></div><div class="col-md-4"><label class="form-label">CEP</label><input type="text" name="cep" class="form-control" value="{{ cliente.cep }}" required></div><div class="col-md-8"><label class="form-label">Endereço</label><input type="text" name="endereco" class="form-control" value="{{ cliente.endereco }}" required></div></div><div class="mt-4 d-flex justify-content-between"><a href="/cliente/{{ cliente.id }}" class="btn btn-secondary">Cancelar</a><button type="submit" class="btn btn-primary">Salvar Alterações</button></div></form></div></div></div></div>{% endblock %}
EOT

echo "--> Recriando home.html"
cat <<'EOT' > GESTAO_WEB/templates/home.html
{% extends "base.html" %}
{% block title %}Clientes{% endblock %}
{% block content %}
<h1 class="mb-4">Clientes</h1>
{% if clientes %}
<div class="list-group">
    {% for cliente in clientes %}
    <div class="list-group-item d-flex justify-content-between align-items-center mb-2 card flex-row p-3">
        <a href="/cliente/{{ cliente.id }}" class="text-decoration-none text-dark flex-grow-1">
            <div class="fw-bold">{{ cliente.nome }}</div>
            <small class="text-muted">{{ cliente.cpf }}</small>
        </a>
        <div class="d-flex align-items-center">
            <span class="badge bg-primary rounded-pill me-3">{{ cliente.cameras|length }} câmeras</span>
            <div class="btn-group btn-group-sm">
                <a href="/cliente/{{ cliente.id }}/editar" class="btn btn-outline-secondary" title="Editar Cliente"><i class="bi bi-pencil"></i></a>
                <form action="/cliente/{{ cliente.id }}/excluir" method="post" class="d-inline" onsubmit="return confirm('Tem certeza que deseja excluir este cliente e todos os seus dados? Esta ação é irreversível.');">
                    <button type="submit" class="btn btn-outline-danger" title="Excluir Cliente"><i class="bi bi-trash"></i></button>
                </form>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% else %}
<div class="text-center py-5 card">
    <div class="card-body">
        <p class="lead">Nenhum cliente cadastrado.</p>
        <a href="/novo_cliente" class="btn btn-success btn-lg mt-3">Cadastrar Primeiro Cliente</a>
    </div>
</div>
{% endif %}
{% endblock %}
EOT

echo "==== PARTE 1/3 CONCLUÍDA (com CSS de Componentes) ===="
