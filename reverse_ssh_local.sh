#!/bin/bash
# reverse_ssh_local.sh
# Скрипт для настройки обратного SSH‑туннеля с устройства с динамическим IP

# Запрос данных у пользователя
read -p "Введите IP-адрес сервера тунелирования: " SERVER_IP
read -p "Введите имя пользователя на сервере: " SERVER_USER
read -p "Введите локальный SSH-порт (по умолчанию 22): " LOCAL_PORT
LOCAL_PORT=${LOCAL_PORT:-22}
read -p "Введите удалённый порт для туннеля (например, 2222): " REMOTE_PORT

echo ""
echo "Настройка обратного SSH‑туннеля:"
echo "Сервер: $SERVER_IP"
echo "Пользователь на сервере: $SERVER_USER"
echo "Локальный порт (устройство): $LOCAL_PORT"
echo "Удалённый порт (на сервере): $REMOTE_PORT"
echo ""

# Проверка наличия autossh
if command -v autossh >/dev/null 2>&1; then
    echo "Найден autossh для мониторинга туннеля."
    read -p "Использовать autossh для автоматического восстановления соединения? [Y/n]: " use_autossh
    if [[ "$use_autossh" =~ ^[Yy] || -z "$use_autossh" ]]; then
        CMD="autossh -M 0 -N -o 'ServerAliveInterval 30' -o 'ServerAliveCountMax 3' -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${SERVER_USER}@${SERVER_IP}"
    else
        CMD="ssh -N -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${SERVER_USER}@${SERVER_IP}"
    fi
else
    echo "autossh не найден, будет использована стандартная команда ssh."
    CMD="ssh -N -R ${REMOTE_PORT}:localhost:${LOCAL_PORT} ${SERVER_USER}@${SERVER_IP}"
fi

echo ""
echo "Выполняется команда для установки обратного туннеля:"
echo "$CMD"
echo ""

# Запуск команды (будет оставаться активной, т.к. используется -N)
eval "$CMD"
