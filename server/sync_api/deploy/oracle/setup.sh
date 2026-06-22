#!/usr/bin/env bash
# Instala Docker y despliega POSIA Sync API en Oracle Cloud Always Free (ARM).
# Uso en la VM Ubuntu:
#   curl -fsSL .../setup.sh | bash
# o desde el repo clonado:
#   sudo bash deploy/oracle/setup.sh
set -euo pipefail

POSIA_USER="${SUDO_USER:-ubuntu}"
POSIA_HOME="$(eval echo "~${POSIA_USER}")"
REPO_DIR="${POSIA_HOME}/POSIA"
SYNC_DIR="${REPO_DIR}/server/sync_api"

echo "==> POSIA hub — Oracle Always Free setup"

if [[ "$(id -u)" -ne 0 ]]; then
	echo "Ejecuta con sudo: sudo bash $0"
	exit 1
fi

echo "==> Paquetes base"
apt-get update -qq
apt-get install -y -qq ca-certificates curl git wget gnupg iptables-persistent

echo "==> Docker"
if ! command -v docker >/dev/null 2>&1; then
	curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "${POSIA_USER}" || true
systemctl enable docker
systemctl start docker

echo "==> Puertos en iptables (OCI Ubuntu suele bloquearlos)"
for PORT in 22 80 443; do
	iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null \
		|| iptables -I INPUT 6 -m state --state NEW -p tcp --dport "${PORT}" -j ACCEPT
done
netfilter-persistent save 2>/dev/null || true

echo "==> Repositorio"
if [[ ! -d "${REPO_DIR}/.git" ]]; then
	sudo -u "${POSIA_USER}" git clone https://github.com/TU_USUARIO/POSIA.git "${REPO_DIR}" \
		|| echo "AVISO: Clona manualmente tu repo en ${REPO_DIR}"
fi

if [[ ! -f "${SYNC_DIR}/.env" ]]; then
	cp "${SYNC_DIR}/.env.example" "${SYNC_DIR}/.env"
	chown "${POSIA_USER}:${POSIA_USER}" "${SYNC_DIR}/.env"
	echo ""
	echo "EDITA ${SYNC_DIR}/.env con DATABASE_URL (Neon) y API_KEY, luego:"
	echo "  cd ${SYNC_DIR} && docker compose -f docker-compose.prod.yml up -d --build"
	exit 0
fi

echo "==> Build y arranque"
cd "${SYNC_DIR}"
docker compose -f docker-compose.prod.yml up -d --build

echo ""
echo "Listo. Verifica:"
echo "  curl -s http://127.0.0.1:8080/v1/health"
echo "  curl -s https://TU_DOMINIO/v1/health"
echo ""
echo "POSIA_HUB_URL en cajas: https://TU_DOMINIO"
