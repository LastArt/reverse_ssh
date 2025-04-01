#!/bin/bash
# revers_ssh_server.sh
# Этот скрипт настраивает сервер для обратного SSH-туннелирования внутри Docker-контейнера.
# Он:
# 1. Проверяет наличие Docker.
# 2. Запрашивает у пользователя необходимые параметры.
# 3. Генерирует Dockerfile.
# 4. Собирает Docker-образ.
# 5. Запускает контейнер с пробросом указанного порта.
#
# Контейнер устанавливает openssh-server, настраивает его с GatewayPorts yes,
# создаёт пользователя "sshuser" с паролем "password" и открывает порт 22.

# Функция для запроса данных у пользователя с возможностью задать значение по умолчанию
prompt() {
    local varname=$1
    local prompt_text=$2
    local default_val=$3

    if [ -n "$default_val" ]; then
        read -p "$prompt_text [$default_val]: " input
    else
        read -p "$prompt_text: " input
    fi
    if [ -z "$input" ] && [ -n "$default_val" ]; then
        eval $varname="'$default_val'"
    else
        eval $varname="'$input'"
    fi
}

echo "=== Настройка серверного Docker-контейнера для ReversSSH ==="

# Проверяем, установлен ли Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker не установлен. Пожалуйста, установите Docker и повторите попытку."
    exit 1
fi

# Запрос параметров у пользователя
prompt HOST_SSH_PORT "Введите порт на хосте для проброса SSH" "22"
prompt CONTAINER_NAME "Введите имя контейнера" "reversssh_server"
prompt IMAGE_NAME "Введите имя Docker-образа" "reversssh_server_image"

# Генерируем Dockerfile (будет сохранён в текущей директории как Dockerfile.server)
DOCKERFILE="Dockerfile.server"
cat > $DOCKERFILE <<'EOF'
FROM ubuntu:latest

# Установка openssh-server
RUN apt-get update && apt-get install -y openssh-server

# Создаём директорию для демона ssh
RUN mkdir /var/run/sshd

# Включаем проброс портов (GatewayPorts yes)
RUN echo "GatewayPorts yes" >> /etc/ssh/sshd_config

# Создаём пользователя sshuser с паролем "password"
RUN useradd -m sshuser && echo "sshuser:password" | chpasswd

# Открываем порт 22
EXPOSE 22

# Запускаем SSH-сервер в режиме демона
CMD ["/usr/sbin/sshd", "-D"]
EOF

echo "Dockerfile создан в файле $DOCKERFILE."

# Сборка Docker-образа
echo "Сборка Docker-образа $IMAGE_NAME ..."
docker build -t $IMAGE_NAME -f $DOCKERFILE .
if [ $? -ne 0 ]; then
    echo "Ошибка сборки Docker-образа."
    exit 1
fi

# Если контейнер с таким именем уже существует, удаляем его
if docker ps -a --format '{{.Names}}' | grep -w "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Контейнер с именем $CONTAINER_NAME уже существует. Останавливаем и удаляем его..."
    docker rm -f "$CONTAINER_NAME"
fi

# Запуск контейнера с пробросом порта
echo "Запуск контейнера $CONTAINER_NAME с пробросом порта $HOST_SSH_PORT (хост) -> 22 (контейнер)..."
docker run -d --name "$CONTAINER_NAME" -p ${HOST_SSH_PORT}:22 $IMAGE_NAME
if [ $? -eq 0 ]; then
    echo "Контейнер запущен успешно!"
    echo "Для подключения по SSH используйте:"
    echo "ssh sshuser@<IP_хоста> -p ${HOST_SSH_PORT}"
    echo "Пароль для sshuser: password"
else
    echo "Ошибка при запуске контейнера."
fi
