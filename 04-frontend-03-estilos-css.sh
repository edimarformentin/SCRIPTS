#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 04-frontend-03: Estilos CSS (v3.7 - Correção de Alinhamento dos Botões)
#
# Aumenta a largura do contêiner de ações para evitar a quebra de
# linha dos botões na lista de câmeras.
# =================================================================

echo "--> 4.3: Aplicando estilos (v3.7 - Correção de Alinhamento dos Botões)..."
mkdir -p "$FRONTEND_DIR/css"

# --- cameras.css (COM A LARGURA DAS AÇÕES CORRIGIDA) ---
echo "    -> Criando css/cameras.css com a largura do contêiner de ações corrigida..."
cat << 'CSS_CAM_EOF' > "$FRONTEND_DIR/css/cameras.css"
.header-buttons { display: flex; gap: 10px; }
.client-info-card { background-color: var(--surface-color); padding: 25px; border-radius: 12px; box-shadow: var(--shadow); margin-bottom: 20px; display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; }
.info-item strong { display: block; color: var(--secondary-color); font-weight: 600; margin-bottom: 5px; }
.info-item span { word-break: break-word; }
.instructions { font-size: 0.9em; color: var(--secondary-color); margin-top: -10px; margin-bottom: 25px; }
small { color: var(--secondary-color); font-size: 0.85em; margin-top: 5px; display: block; }
.tabs-navigation { border-bottom: 2px solid var(--border-color); margin-bottom: 0; }
.tab-link { background: none; border: none; padding: 15px 25px; cursor: pointer; font-size: 1em; font-weight: 600; color: var(--secondary-color); border-bottom: 3px solid transparent; }
.tab-link.active { color: var(--primary-color); border-bottom-color: var(--primary-color); }
.tab-content { display: none; background-color: var(--surface-color); padding: 30px; border-radius: 0 0 12px 12px; box-shadow: var(--shadow); animation: fadeIn 0.5s; border: 1px solid var(--border-color); border-top: none; }
.tab-content.active { display: block; }
.list-section { margin-top: 50px; }
.camera-list-item { background-color: var(--surface-color); border: 1px solid var(--border-color); border-radius: 8px; padding: 15px 20px; display: flex; align-items: center; gap: 20px; margin-bottom: 10px; }
.item-name { font-weight: 600; flex-basis: 200px; }
.item-type { font-size: 0.8em; font-weight: bold; padding: 3px 8px; border-radius: 5px; color: white; margin-left: 10px; }
.item-type.rtmp { background-color: #007BFF; }
.item-type.rtsp { background-color: #198754; }
.item-path { font-family: monospace; color: var(--secondary-color); flex-grow: 1; word-break: break-all; }

/* --- AQUI ESTÁ A MODIFICAÇÃO --- */
.item-actions {
    flex-basis: 200px; /* Aumentado de 150px para 200px para caber os 4 botões */
    text-align: right;
}

.ai-icons { display: flex; align-items: center; gap: 12px; color: #ff6f00; font-size: 1.3em; }
.ai-icons i { cursor: help; }
.item-recording { display: flex; align-items: center; gap: 8px; color: var(--danger-color); font-size: 1.1em; font-weight: 600; cursor: help; }
.item-recording span { font-size: 0.9em; }
.choices { font-size: 16px; margin-bottom: 20px; }
.choices__inner { background-color: #fff; border: 1px solid var(--border-color); border-radius: 8px; padding: 7.5px 7.5px 4px; min-height: 48px; }
.choices[data-type*="select-multiple"] .choices__inner { padding-bottom: 4px; }
.choices__list--multiple .choices__item { background-color: var(--primary-color); border: 1px solid var(--primary-hover); border-radius: 6px; font-size: 14px; }
.choices__list--dropdown .choices__item--selectable.is-highlighted { background-color: var(--primary-color); }
.choices__input { font-size: 16px; background-color: #fff; border-radius: 4px; padding: 4px; margin-bottom: 5px; }
CSS_CAM_EOF

# --- Recria o style.css (sem alterações) ---
echo "    -> Recriando css/style.css (sem alterações)..."
cat << 'CSS_STYLE_EOF' > "$FRONTEND_DIR/css/style.css"
:root { --primary-color: #007BFF; --primary-hover: #0056b3; --secondary-color: #6c757d; --danger-color: #dc3545; --bg-color: #f8f9fa; --surface-color: #ffffff; --text-color: #212529; --border-color: #dee2e6; --shadow: 0 4px 8px rgba(0,0,0,0.05); }
body { font-family: 'Segoe UI', Roboto, sans-serif; background-color: var(--bg-color); color: var(--text-color); margin: 0; line-height: 1.6; }
.container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
header .container { display: flex; justify-content: space-between; align-items: center; margin-bottom: 40px; }
h1, h2, h3 { font-weight: 600; }
.btn { padding: 12px 24px; border: none; border-radius: 8px; cursor: pointer; font-size: 15px; font-weight: 600; color: white; text-decoration: none; display: inline-block; transition: all 0.3s ease; }
.btn-primary { background-color: var(--primary-color); } .btn-primary:hover { background-color: var(--primary-hover); }
.btn-secondary { background-color: var(--secondary-color); }
.modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5); }
.modal-content { background-color: var(--surface-color); margin: 10% auto; padding: 30px; width: 90%; max-width: 550px; border-radius: 12px; box-shadow: var(--shadow); }
.close-button { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
.form-group { margin-bottom: 20px; }
label { display: block; margin-bottom: 8px; font-weight: 600; font-size: 0.9em; }
input[type="text"], input[type="email"], textarea, select { width: 100%; padding: 12px; border-radius: 8px; border: 1px solid var(--border-color); box-sizing: border-box; }
.loader { border: 5px solid #e9ecef; border-top: 5px solid var(--primary-color); border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 40px auto; display: none; }
@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
table { width: 100%; border-collapse: separate; border-spacing: 0 10px; margin-top: 20px; }
th { text-align: left; padding: 12px 15px; color: var(--secondary-color); font-weight: 600; text-transform: uppercase; font-size: 0.85em; }
td { background: var(--surface-color); padding: 20px 15px; vertical-align: middle; }
tr.client-row { box-shadow: var(--shadow); border-radius: 8px; transition: all 0.2s ease; cursor: pointer; }
tr.client-row:hover { transform: translateY(-3px); box-shadow: 0 6px 12px rgba(0,0,0,0.08); }
td:first-child { border-top-left-radius: 8px; border-bottom-left-radius: 8px; }
td:last-child { border-top-right-radius: 8px; border-bottom-right-radius: 8px; text-align: right; }
.actions-cell { width: 120px; }
.icon-btn { background-color: #e9ecef; border: none; width: 38px; height: 38px; border-radius: 8px; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; font-size: 1.1em; margin-left: 5px; }
CSS_STYLE_EOF

echo "--- Tema (v3.7) com alinhamento de botões corrigido, aplicado com sucesso."

# --- PLAYER_MODAL_FIX_V1: Override de layout para o modal do player ---
# Escreve no cameras.css (carregado depois do style.css) para SOBRESCREVER
# o .modal-content padrão SOMENTE quando for no modal .video-modal.
cat >> "${FRONTEND_DIR}/css/cameras.css" <<'CSS'
/* PLAYER_MODAL_FIX_V1 */
.video-modal .modal-content{
  /* ocupa a largura da viewport sem estourar */
  width: min(95vw, 1100px);
  max-width: none;
  margin: 3vh auto;
  padding: 0;           /* remove padding para o vídeo encostar */
  background: #000;
  border-radius: 12px;
}
.video-modal .modal-header{
  display:flex; align-items:center; justify-content:space-between;
  padding: 12px 16px; background:#111; color:#fff;
  border-top-left-radius: 12px; border-top-right-radius: 12px;
}
.video-modal .video-container{
  width:100%;
  height:auto;
  max-height: calc(95vh - 56px); /* sobra para o header */
  overflow:hidden;
  background:#000;
}
.video-modal #live-video-player{
  width:100%;
  height:auto;
  max-height: inherit;   /* respeita o limite da container */
  display:block;
  background:#000;
  object-fit: contain;   /* mantém proporção */
}
/* fim PLAYER_MODAL_FIX_V1 */
CSS
# --- fim PLAYER_MODAL_FIX_V1 ---
