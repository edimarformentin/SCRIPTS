#!/bin/bash
# =================================================================
source "/home/edimar/SCRIPTS/00-configuracao-central.sh"
# Script 03-api-03: Lógica CRUD (v3.7 - get_all Câmeras)
#
# Adiciona a função get_all em crud_camera.py para listar
# todas as câmeras do sistema, necessário para o orquestrador.
# =================================================================
echo "--> 3.3: Criando a lógica CRUD da API (v3.7 - get_all Câmeras)..."
CRUD_DIR="$API_DIR/app/crud"
mkdir -p "$CRUD_DIR" && touch "$CRUD_DIR/__init__.py"

# --- crud_client.py (recriado a partir da v3.6) ---
echo "    -> Recriando app/crud/crud_client.py (v3.6)..."
cat << 'CRUD_C_EOF' > "$CRUD_DIR/crud_client.py"
import psycopg2
from psycopg2.extras import RealDictCursor
from slugify import slugify
import random, string
from uuid import UUID, uuid4
from app.schemas.client_schema import ClientCreate, ClientUpdate

def generate_readable_id(db: psycopg2.extensions.connection, name: str) -> str:
    first_name = name.split()[0]
    base_slug = slugify(first_name)
    while True:
        random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        readable_id = f"{base_slug}-{random_suffix}"
        with db.cursor() as cur:
            cur.execute("SELECT id FROM clientes WHERE id_legivel = %s;", (readable_id,))
            if cur.fetchone() is None: return readable_id

def create(db: psycopg2.extensions.connection, *, client_in: ClientCreate):
    readable_id = generate_readable_id(db, client_in.nome)
    client_id = client_in.id or uuid4()
    sql = "INSERT INTO clientes (id, id_legivel, nome, email, cpf, endereco) VALUES (%s, %s, %s, %s, %s, %s) RETURNING *;"
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, (str(client_id), readable_id, client_in.nome, client_in.email, client_in.cpf, client_in.endereco))
        new_client = cur.fetchone()
        db.commit()
        return new_client

def get(db: psycopg2.extensions.connection, *, client_id: UUID):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM clientes WHERE id = %s;", (str(client_id),))
        return cur.fetchone()

def get_all(db: psycopg2.extensions.connection, *, skip: int = 0, limit: int = 100):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM clientes ORDER BY nome ASC LIMIT %s OFFSET %s;", (limit, skip))
        return cur.fetchall()

def update(db: psycopg2.extensions.connection, *, client_id: UUID, client_in: ClientUpdate):
    update_data = client_in.model_dump(exclude_unset=True)
    if not update_data: return get(db, client_id=client_id)
    set_query = ", ".join([f"{key} = %s" for key in update_data.keys()])
    values = list(update_data.values())
    values.append(str(client_id))
    sql = f"UPDATE clientes SET {set_query}, data_atualizacao = CURRENT_TIMESTAMP WHERE id = %s RETURNING *;"
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, tuple(values))
        updated_client = cur.fetchone()
        db.commit()
        return updated_client

def remove(db: psycopg2.extensions.connection, *, client_id: UUID):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("DELETE FROM clientes WHERE id = %s RETURNING id;", (str(client_id),))
        deleted_client = cur.fetchone()
        db.commit()
        return deleted_client
CRUD_C_EOF

# --- crud_camera.py (COM A NOVA FUNÇÃO get_all) ---
echo "    -> Criando app/crud/crud_camera.py com a nova função get_all..."
cat << 'CRUD_CAM_EOF' > "$CRUD_DIR/crud_camera.py"
import psycopg2
from slugify import slugify
from uuid import UUID
from psycopg2.extras import RealDictCursor
from app.schemas.camera_schema import CameraCreate, CameraUpdate
from app.crud import crud_client

def get_all(db: psycopg2.extensions.connection, *, skip: int = 0, limit: int = 1000):
    """
    Retorna todas as câmeras cadastradas no sistema.
    """
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM cameras ORDER BY data_criacao ASC LIMIT %s OFFSET %s;", (limit, skip))
        return cur.fetchall()

def get(db: psycopg2.extensions.connection, *, camera_id: UUID):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM cameras WHERE id = %s;", (str(camera_id),))
        return cur.fetchone()

def get_by_client(db: psycopg2.extensions.connection, *, client_id: UUID):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM cameras WHERE cliente_id = %s ORDER BY nome_camera ASC;", (str(client_id),))
        return cur.fetchall()

def create(db: psycopg2.extensions.connection, *, camera_in: CameraCreate):
    client = crud_client.get(db, client_id=camera_in.cliente_id)
    if not client:
        return None

    if camera_in.url_rtsp:
        sql = "INSERT INTO cameras (cliente_id, nome_camera, url_rtsp, dias_gravacao, detectar_carros, detectar_pessoas) VALUES (%s, %s, %s, %s, %s, %s) RETURNING *;"
        params = (str(camera_in.cliente_id), camera_in.nome_camera, camera_in.url_rtsp, camera_in.dias_gravacao, camera_in.detectar_carros, camera_in.detectar_pessoas)
    else:
        rtmp_path = f"live/{client['id_legivel']}/{slugify(camera_in.nome_camera)}"
        sql = "INSERT INTO cameras (cliente_id, nome_camera, url_rtmp_path, dias_gravacao, detectar_carros, detectar_pessoas) VALUES (%s, %s, %s, %s, %s, %s) RETURNING *;"
        params = (str(camera_in.cliente_id), camera_in.nome_camera, rtmp_path, camera_in.dias_gravacao, camera_in.detectar_carros, camera_in.detectar_pessoas)

    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        new_camera = cur.fetchone()
        db.commit()
        return new_camera

def update(db: psycopg2.extensions.connection, *, camera_id: UUID, camera_in: CameraUpdate):
    update_data = camera_in.model_dump(exclude_unset=True)
    if not update_data:
        return get(db, camera_id=camera_id)

    cam_to_update = get(db, camera_id=camera_id)
    if 'nome_camera' in update_data and cam_to_update.get('url_rtmp_path'):
        client = crud_client.get(db, client_id=cam_to_update['cliente_id'])
        update_data['url_rtmp_path'] = f"live/{client['id_legivel']}/{slugify(update_data['nome_camera'])}"

    set_query = ", ".join([f"{key} = %s" for key in update_data.keys()])
    values = list(update_data.values())
    values.append(str(camera_id))

    sql = f"UPDATE cameras SET {set_query}, data_atualizacao = CURRENT_TIMESTAMP WHERE id = %s RETURNING *;"

    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, tuple(values))
        updated_camera = cur.fetchone()
        db.commit()
        return updated_camera

def remove(db: psycopg2.extensions.connection, *, camera_id: UUID):
    with db.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("DELETE FROM cameras WHERE id = %s RETURNING id;", (str(camera_id),))
        deleted_camera = cur.fetchone()
        db.commit()
        return deleted_camera
CRUD_CAM_EOF
echo "--- Lógica CRUD da API (v3.7) com get_all para câmeras criada com sucesso."
