#!/usr/bin/env bash
set -euo pipefail

WAZUH_MANAGER_IP="${1:-192.168.1.97}"
AGENT_NAME="${2:-notebook-sidwilson0}"
OSSEC_CONF="/var/ossec/etc/ossec.conf"
CLIENT_KEYS="/var/ossec/etc/client.keys"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: ejecuta este script con sudo."
  echo "Uso: sudo $0 [IP_WAZUH_MANAGER] [NOMBRE_AGENTE]"
  exit 1
fi

if [ ! -x /var/ossec/bin/agent-auth ]; then
  echo "ERROR: no encuentro /var/ossec/bin/agent-auth. Verifica que wazuh-agent este instalado."
  exit 1
fi

if [ ! -f "$OSSEC_CONF" ]; then
  echo "ERROR: no existe $OSSEC_CONF."
  exit 1
fi

echo "[+] Probando conectividad con Wazuh Manager $WAZUH_MANAGER_IP..."
for port in 1514 1515; do
  timeout 5 bash -c "</dev/tcp/$WAZUH_MANAGER_IP/$port" 2>/dev/null \
    && echo "    Puerto $port OK" \
    || { echo "ERROR: no se puede conectar a $WAZUH_MANAGER_IP:$port"; exit 1; }
done

echo "[+] Deteniendo wazuh-agent..."
systemctl stop wazuh-agent || true

echo "[+] Respaldando configuracion..."
cp "$OSSEC_CONF" "$OSSEC_CONF.bak.$(date +%Y%m%d%H%M%S)"

echo "[+] Configurando manager en $OSSEC_CONF..."
python3 - "$OSSEC_CONF" "$WAZUH_MANAGER_IP" "$AGENT_NAME" <<'PY'
import sys
import re

path, manager_ip, agent_name = sys.argv[1:4]
with open(path, "r", encoding="utf-8") as fh:
    data = fh.read()

client_block = f"""  <client>
    <server>
      <address>{manager_ip}</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <enrollment>
      <enabled>yes</enabled>
      <manager_address>{manager_ip}</manager_address>
      <port>1515</port>
      <agent_name>{agent_name}</agent_name>
    </enrollment>
  </client>"""

if re.search(r"<client>.*?</client>", data, flags=re.S):
    data = re.sub(r"\s*<client>.*?</client>", "\n" + client_block, data, count=1, flags=re.S)
else:
    data = re.sub(r"</ossec_config>", client_block + "\n</ossec_config>", data, count=1)

with open(path, "w", encoding="utf-8") as fh:
    fh.write(data)
PY

if [ "${FORCE_ENROLL:-0}" = "1" ]; then
  rm -f "$CLIENT_KEYS"
fi

if [ -s "$CLIENT_KEYS" ]; then
  echo "[+] Ya existe client.keys; se conserva la clave actual."
  echo "    Si el dashboard no lo marca Active, elimina el agente viejo en Wazuh y ejecuta:"
  echo "    sudo FORCE_ENROLL=1 $0 $WAZUH_MANAGER_IP $AGENT_NAME"
else
  echo "[+] Registrando agente como '$AGENT_NAME'..."
  /var/ossec/bin/agent-auth -m "$WAZUH_MANAGER_IP" -A "$AGENT_NAME"
fi

echo "[+] Habilitando y reiniciando wazuh-agent..."
systemctl enable wazuh-agent
systemctl restart wazuh-agent

echo "[+] Estado local:"
systemctl --no-pager --full status wazuh-agent | sed -n '1,18p'

echo "[+] Listo. Revisa en Wazuh Dashboard: Agents management > Summary."
echo "    Nombre esperado: $AGENT_NAME"
echo "    Estado esperado: Active"
