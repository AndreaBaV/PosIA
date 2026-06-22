# Hub POSIA en Oracle Cloud Always Free

Despliegue **gratis y 24/7** del sync API en una VM ARM de Oracle, con Postgres en **Neon** (también free).

```
Cajas POSIA  ──HTTPS──►  Oracle VM (hub + Caddy)  ──SSL──►  Neon Postgres
```

## Qué obtienes gratis

| Recurso | Oracle Always Free | Uso POSIA |
|---------|-------------------|-----------|
| VM **Ampere A1** | hasta 4 OCPU / 24 GB RAM total | 1 VM con **1 OCPU + 6 GB** basta |
| Ancho de banda | 10 TB/mes salida | Más que suficiente para 30+ negocios |
| IP pública | 1 por VM | URL del hub |
| Neon Postgres | plan free aparte | Base de datos |

No se duerme como Render free.

---

## Requisitos previos

1. Cuenta [Oracle Cloud](https://www.oracle.com/cloud/free/) (tarjeta para verificación; no cobra si te quedas en Always Free).
2. Proyecto **Neon** con `DATABASE_URL` (ya en `platform/.env`).
3. Dominio o subdominio gratuito para **HTTPS** (recomendado):
   - [DuckDNS](https://www.duckdns.org/) → `posia-tuempresa.duckdns.org`
   - O un subdominio tuyo (`hub.tunegocio.com`) con registro **A** a la IP de Oracle.

---

## Paso 1 — Crear la VM en Oracle

1. **Compute → Instances → Create instance**
2. **Name:** `posia-hub`
3. **Image:** Ubuntu 22.04 Minimal **aarch64**
4. **Shape:** `VM.Standard.A1.Flex` → **1 OCPU**, **6 GB** RAM
5. **Networking:** crear VCN si no existe; asignar IP pública
6. **SSH keys:** pega tu clave pública (`~/.ssh/id_ed25519.pub`)
7. Crear instancia y anota la **IP pública**

### Security List (firewall de Oracle)

En la VCN → Security List → Ingress rules:

| Puerto | Protocolo | Origen | Descripción |
|--------|-----------|--------|-------------|
| 22 | TCP | Tu IP o `0.0.0.0/0` | SSH |
| 80 | TCP | `0.0.0.0/0` | HTTP (Let's Encrypt) |
| 443 | TCP | `0.0.0.0/0` | HTTPS hub |

No expongas el puerto 8080 a internet; Caddy hace de proxy.

---

## Paso 2 — Conectar por SSH

```bash
ssh ubuntu@TU_IP_PUBLICA
```

(Si usaste otra imagen, el usuario puede ser `opc`.)

---

## Paso 3 — Clonar repo y configurar

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose-v2
sudo usermod -aG docker $USER
# Cierra sesión SSH y vuelve a entrar

git clone https://github.com/TU_USUARIO/POSIA.git
cd POSIA/server/sync_api
cp deploy/oracle/.env.example .env
nano .env
```

Contenido mínimo de `.env`:

```env
POSIA_HUB_DOMAIN=posia-tuempresa.duckdns.org
DATABASE_URL=postgresql://...@ep-xxx.neon.tech/neondb?sslmode=require
API_KEY=tu-clave-secreta-igual-en-todas-partes
POSIA_ENV=production
PORT=8080
```

Edita también `deploy/oracle/Caddyfile` con el mismo dominio (o usa variable `POSIA_HUB_DOMAIN` en `.env` — Caddy la lee del entorno del compose).

### Abrir puertos en iptables (importante en OCI)

```bash
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Script automático (alternativa)

```bash
sudo bash deploy/oracle/setup.sh
```

---

## Paso 4 — Apuntar dominio a la IP

En DuckDNS (o tu DNS):

- Tipo **A** → `posia-tuempresa.duckdns.org` → **IP pública de Oracle**

Espera 1–5 minutos y comprueba:

```bash
ping posia-tuempresa.duckdns.org
```

---

## Paso 5 — Arrancar el hub

```bash
cd ~/POSIA/server/sync_api
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml logs -f
```

Verificación:

```bash
curl -s http://127.0.0.1:8080/v1/health
curl -s https://posia-tuempresa.duckdns.org/v1/health
```

---

## Paso 6 — Configurar POSIA

### `platform/.env` (en tu PC)

```env
DATABASE_URL=postgresql://...   # mismo Neon
API_KEY=tu-clave-secreta
POSIA_HUB_URL=https://posia-tuempresa.duckdns.org
```

### Provisionar tenants

```powershell
cd platform\tenant_registry
dart run bin/posia_tenants.dart provision --tenant <UUID>
```

### App móvil / cajas

```env
POSIA_HUB_URL=https://posia-tuempresa.duckdns.org
POSIA_HUB_API_KEY=tu-clave-secreta
```

O en el asistente técnico de la caja al instalar.

---

## Mantenimiento

```bash
cd ~/POSIA/server/sync_api
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

Ver logs:

```bash
docker compose -f docker-compose.prod.yml logs -f sync_api
```

Reiniciar:

```bash
docker compose -f docker-compose.prod.yml restart
```

---

## Solución de problemas

| Problema | Solución |
|----------|----------|
| No responde desde internet | Revisa Security List OCI + iptables en la VM |
| Caddy no obtiene certificado | Dominio debe apuntar a la IP; puertos 80/443 abiertos |
| Hub crash al arrancar | Revisa `DATABASE_URL` y `API_KEY` en `.env` |
| 401 en cajas | Misma `API_KEY` en servidor y app |
| ARM build lento | Normal la primera vez; luego usa caché Docker |

---

## Coste estimado

| Componente | Costo |
|------------|-------|
| Oracle VM Always Free | $0 |
| Neon Postgres free | $0 |
| DuckDNS | $0 |
| **Total** | **$0/mes** (dentro de límites Always Free) |

---

## Referencias

- [DEPLOYMENT.md](DEPLOYMENT.md) — opciones de despliegue
- [PRODUCCION.md](PRODUCCION.md) — checklist completo
- `server/sync_api/docker-compose.prod.yml` — compose producción
