# Завдання 1: Встановлення Docker

1. Налаштуйте apt репозиторій Docker

    ```bash
    #Add Docker's official GPG key:
    sudo apt update
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    #Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
    Types: deb
    URIs: https://download.docker.com/linux/ubuntu
    Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    Components: stable
    Signed-By: /etc/apt/keyrings/docker.asc
    EOF

    sudo apt update
    ```

2. Встановіть пакети Docker.

        sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    
    щоб перевірити чи Docker працює скористайтеся

        sudo systemctl status docker

    
    якщо вимкнена то скористайтеся командою

        sudo systemctl start docker

# Завдання 2: Створення файлу

1. Створіть новий каталог для вашого проєкту 

        mkdir web-app

2. Створіть docker-compose.yml файл

        nano docker-compose.yml

    туди вскавляємо код

        version: '3.8' #версія

        services:   # описуємо що саме будемо розгортати
            web:    # по ідеї може бути люба назва яку ми захоче головне щоб було зрозуміло що тут знаходиться
                image: nginx:latest    # використовуємо останій образ Nginx
                ports:     # прокидання портів
                    - "8080:80"    # коли ви заходите на 8080 то запит перенаправляється на порт 80 в середині контейнера
                volumes:
                    - ./index.html:/usr/share/nginx/html/index.html    # монтуємо html в папку Nginx
                    - web-data:/var/www/html    # грубо кажучи все що лежить в web-data має бути в контейнері за адресою /var/www/html 
                networks:
                    - appnet    # грубо кажучи якщо дозволяє нам щоб сервіси у яких є точно така сама стрічка можуть спілкуватися між собою напряму, тобто працювати в одній мережі

            db:
                image: postgres:latest
                environment:    # тут описуються початкові налаштування бази
                    POSTGRES_USER: postger
                    POSTGRES_PASSWORD: postgres
                    POSTGRES_DB: mydb
                volumes:
                    - db-data:/var/lib/postgresql     # зберігає данні на диску навіть якщо видалиться контейнер данні не зникнуть 
                networks:
                    - appnet

            cache:
                image: redis:latest
                networks:
                    - appnet

        volumes:
            db-data:    # назва тому для бази
            web-data:    # назва тому для веб

        networks:
            appnet:     # створюємо віртуальну мережу

    створюємо файл 

        nano index.html

    та вставляємо код

        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>My Docker App</title>
        </head>
        <body>
            <h1>Hello from Docker!</h1>
        </body>
        </html>

# Завдання 3: Запуск багатоконтейнерного застосунку

1. Запустіть застосунок за допомогою Docker Compose

    docker compose up -d

2. Перевірте стан запущених сервісів

        docker compose ps

    має видати

        NAME              IMAGE             COMMAND                  SERVICE   CREATED         STATUS         PORTS
        web-app-cache-1   redis:latest      "docker-entrypoint.s…"   cache     7 seconds ago   Up 6 seconds   6379/tcp
        web-app-db-1      postgres:latest   "docker-entrypoint.s…"   db        7 seconds ago   Up 6 seconds   5432/tcp
        web-app-web-1     nginx:latest      "/docker-entrypoint.…"   web       7 seconds ago   Up 6 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp


3. Перевірте роботу вебсервера

    воно в мене відкрилося за посиланням

        http://localhost:8080/index.html

# Завдання 4: Налаштування мережі й томів

1. Досліджуйте створені мережі та томи

    перегляд мереж

        docker network ls

    те що має вивестись

        NETWORK ID     NAME             DRIVER    SCOPE
        30b6f0475dee   bridge           bridge    local
        749b5995320f   host             host      local
        bcde2257e859   none             null      local
        6cf67146ca35   web-app_appnet   bridge    local

    перегляд томів

        docker volume ls

    те що має вивестись

        DRIVER    VOLUME NAME
        local     9dd119612054a66e470f62b156ba0c148985144d7e9f2a7e974fae2e59096ec7
        local     bd409e5b038842363dff5f7a3d02f8b0fbf36122b1fb99c1c7c06164f3c7aab7
        local     web-app_db-data
        local     web-app_web-data

2. Перевірте підключення до бази даних

    підключаємося до контейнера

        docker exec -it web-app-db-1 bash

    підключаємося до бази

        psql -U postger -d mydb

    після має вивести 

        psql (18.1 (Debian 18.1-1.pgdg13+2))
        Type "help" for help.

        mydb=#

    щоб вийти 

        \q

# Завдання 5: Масштабування сервісів

1. Масштабуйте вебсервер

        docker compose up -d --scale web=3

2. Перевірте стан масштабованих сервісів

    тут зіткнувся з проблемою що два нові контейнери зависли в статусі Created але вони не запускаються

    це сталося тому що в docker-compose жорстко прописаний порт і треба дати можливість призначати docker різні порти для копій тому в секції ports у web робимо таку махінацію

        ports:
        - "8080-8082:80"

    перевірка

        docker compose ps

    зявиться щось накшталт

        NAME              IMAGE             COMMAND                  SERVICE   CREATED         STATUS         PORTS
        web-app-cache-1   redis:latest      "docker-entrypoint.s…"   cache     7 seconds ago   Up 6 seconds   6379/tcp
        web-app-db-1      postgres:latest   "docker-entrypoint.s…"   db        7 seconds ago   Up 6 seconds   5432/tcp
        web-app-web-1     nginx:latest      "/docker-entrypoint.…"   web       7 seconds ago   Up 6 seconds   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp
        web-app-web-2     nginx:latest      "/docker-entrypoint.…"   web       7 seconds ago   Up 6 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
        web-app-web-3     nginx:latest      "/docker-entrypoint.…"   web       7 seconds ago   Up 6 seconds   0.0.0.0:8082->80/tcp, [::]:8082->80/tcp