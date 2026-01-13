#!/usr/bin/env bash
# install_github_runner_local.sh
# Ubuntu 24.04 - Runner local para deploy sem SSH com labels da stack Wilson

set -euo pipefail

RUNNER_USER="${RUNNER_USER:-cicd-example-runner}"
RUNNER_NAME="${RUNNER_NAME:-cicd-example-prod-01}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,cicd-example-prod-01,ubuntu24,onprem,env-prod}"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"
WORK_DIR="_work"

echo "==> [1/7] Preparando usuário de serviço: ${RUNNER_USER}"
if ! id -u "${RUNNER_USER}" >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash "${RUNNER_USER}"
fi
sudo -u "${RUNNER_USER}" mkdir -p "${RUNNER_DIR}"

echo "==> [2/7] Dependências"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates

echo "==> [3/7] Baixando runner (último release)"
cd "${RUNNER_DIR}"
sudo -u "${RUNNER_USER}" bash -lc '
  curl -fsSL -o actions-runner-linux-x64.tar.gz     https://github.com/actions/runner/releases/latest/download/actions-runner-linux-x64.tar.gz
  tar xzf actions-runner-linux-x64.tar.gz
'

echo "==> [4/7] Capturando URL e Token de registro"
read -rp "GITHUB_URL (ex.: https://github.com/<org>/<repo> ou https://github.com/<org>): " GITHUB_URL
read -rp "GITHUB_TOKEN (da página New self-hosted runner): " GITHUB_TOKEN

echo "==> [5/7] Configurando runner (labels da stack)"
sudo -u "${RUNNER_USER}" bash -lc "
  cd '${RUNNER_DIR}' &&   ./config.sh     --url '${GITHUB_URL}'     --token '${GITHUB_TOKEN}'     --name '${RUNNER_NAME}'     --labels '${RUNNER_LABELS}'     --work '${WORK_DIR}'
"

echo "==> [6/7] (Opcional) Habilitando Docker/Compose para deploy local"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker não encontrado. Deseja instalar? [y/N]"
  read -r INSTALL_DOCKER
  if [[ "${INSTALL_DOCKER}" =~ ^[Yy]$ ]]; then
    sudo apt-get install -y docker.io
    sudo systemctl enable --now docker
  fi
fi
if command -v docker >/dev/null 2>&1; then
  sudo usermod -aG docker "${RUNNER_USER}" || true
fi

echo "==> [7/7] Instalando como serviço systemd"
cd "${RUNNER_DIR}"
sudo ./svc.sh install "${RUNNER_USER}"
sudo systemctl enable --now "actions.runner.${RUNNER_NAME}.service"

echo
echo "✅ Runner '${RUNNER_NAME}' instalado com labels:"
echo "   ${RUNNER_LABELS}"
echo "Verifique em GitHub > Settings > Actions > Runners."
echo "Logs: journalctl -u actions.runner.${RUNNER_NAME}.service -f"
echo "Diag: ${RUNNER_DIR}/_diag/"