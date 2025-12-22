# Інсталяція Nginx на віртуальну машину

Створено Vagrantfile(більш детальні можна подивиттися відкривши його) в якому в нас одразу запускається скрипт provision.sh(більш детальні можна подивиттися відкривши його) для завантаження вееб серверу Nginx, запускаємо vagrant up, після успішного завантаженя переходиом за посиланням http://localhost:8081/ має зявитися стандарттна сторінка коли nginx встановлений 

![](./images/nginx-in-chrome.png)

за допомогою vargant ssh через термінал приєднуємося до віртуальної машини

![](./images/vagrant-ssh.png)

1. Як саме запускається сервіс і чим керується?

    Команда для перевірки статусу systemctl status nginx

    ![](./images/status-nginx.png)

        Main PID: 946 (nginx) - номер головного процесу (master process)
        Tasks: 3 кількість процесів nginx у системі.
        CGroup - ієрархія процесів
            946 (master process) - директор який виконує задачі
            947 та 948 (worker process) - робітники які виконують ці задачі

    тут є Loaded у ньомо вказаний шлях /usr/lib/systemd/system/nginx.service це інструкція для запуску, подивимося що там 

    ![](./images/cat-nginx-service.png)

        Секція Unit
            After=network-online.target - nginx не почне працювати поки не буде інтернету

        Секція Service
            Type=forking - Nginx створює свою копію(fork) початковий процес завертається, ця копія стає головним процесом та працює у фоновому режимі
            PIDFile=/run/nginx.pid - оскільки nginx працює у фоновому режимі, системі потрібно знати його Process ID щоб звернутися до нього
            ExecStart=/usr/sbin/nginx -c ${CONFFILE} - грубо кажучи воно каже запусти програму nginx з ось цим файлом конфігурацій
            ExecReload=/bin/sh -c "/bin/kill -s HUP $(/bin/cat /run/nginx.pid)" - як оновити сервер без його вимкнення
            ExecStop=/bin/sh -c "/bin/kill -s TERM $(/bin/cat /run/nginx.pid)" - як правильно вимкнути сервер

        Секція Install
            WantedBy=multi-user.target - запускай сервіс коли доступна мережа та є користувачі

2. Файлові дискриптори, що створюються процесом сервісу і навіщо кожен з них
    для того щоб дослідии нам потрібно дізнатися pid які існують

    ![](./images/pids.png)

    беремо один і ідем досліджувати

    ![](./images/pid-descriptors.png)

    дискриптори це числа від 0 - 9 що кожен з них означає
    0 - вхідний потік, оскільки nginx не чекає що ви будете щось писати йому в консоль, він заглушений
    1 - вихідний потік, nginx не виводить звичайний текст на екран тому цей канал теж заглужений.
    2 - помилоки системи, сюди записуються критичні збої самого процесу які виникають ще до того як nginx прочитав свій конфіг
    3 - це вухо яким nginx слухає порт 80
    4 - помилки додатка, цей дискриптор nginx відкрив сам щоб записувати туди помилки обробки запитів
    5 - сюди nginx записує вдалий або не вдалий вхід користувача на сайт, короче все
    6 - сокет для зєднання master process та worker process для того щоб вони могли спілкуватися між собою
    7 - теж слухав як і дискриптор 3 але 3 слухач IPv4 а цей IPv6
    8 - використовується для керування спільним сегментом пам'яті або передачі сигналів керування
    9 - ще один сокет для координація роботи кількох процесів робітників

3. Як читати логи сервера
    в нас є два головні фали для читання логів 
        access.log - тут фіксується кожен клік користувача
        error.log - сюди потрапляють повідомлення про помилки обробки запитів

    дивимося логи в реальному часі

    ![](./images/logs-real-life.png)

    перегляд всіх логів

    ![](./images/cat-logs.png)

    перегляд всіх логів гортаючи їх вихід (Q)

    ![](./images/less-logs.png)

    пошук логів на помилкою

    ![](./images/grep-logs.png)

4. Чи можемо ми змінити конфігурацію веб-сервера, не перезавантажуючи його
    Це одна з ключових переваг Nginx, яка дозволяє змінювати налаштування сайту(додавати нові папки або змінювати порти) без жодної секунди простою

    ![](./images/reload.png)

    Master PID (946) — залишився незмінним, це означає що деректор залишився
    Worker PID (947, 948) — змінилися на нові числа, це означає що старі робітники звільнилися, найнялися нові та стали працювати



PPA-репозиторій для Nginx

ppa не має

![](./images/not-ppa.png)

встановлюємо ppa
sudo add-apt-repository ppa:ondrej/nginx -y
sudo apt update

ppa зявилося

![](./images/ppa.png)

встановлюємо версію ppa
sudo apt install nginx -y

![](./images/install-ppa.png)


Видалення PPA через ppa-purge
встановлення ppa-purge

![](./images/install-ppa-purge.png)

виконуємо команду для очищення
sudo ppa-purge ppa:ondrej/nginx

перевіряємо

![](./images/after-ppa-purge.png)


# Додаткове завдання із *

змінюємо vagrantfile для того щоб створити файл
Створюємо файл віртуального диска на 5 ГБ
file_to_disk = "web_data.vdi" # пишемо змінну в якій зберігаємо назву фалу
unless File.exist?(file_to_disk) # перевіряє чи файл не був створений так як якщо ви будемо перезапускати віртуалку воно захоче створити такий самий фал і буде видавати помилку так як він вже існує
vb.customize ['createhd', '--filename', file_to_disk, '--size', 5120] # пряма команда для створення нового жорсткого диска (але вона ще не підключена до віртуальної машини)
end

Ця команда каже візьми той фал який ми створили і встав його в порт віртуальної машини
vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]

робимо vagrant reload заходимо в віртуалку та дивимося чи вставився файл

![](./images/sdb.png)

створюємо розділ диску

![](./images/sdb1.png)

створюємо фалову систему та монтуємо диск

![](./images/mounting.png)

далі потрібно автоматичне монтування тому що якщо віртуалка перезавантажить диск відпаде - потрібно взяти UUID та вставити його в /etc/fstab

![](./images/faund-UUID.png)

![](./images/UUID.png)

далі на новому диску створюємо папку та права, вставляємо html сторінки для виводу, далі потрібно /etc/nginx/conf.d/default.conf(це інструкці nginx яка каже де брати файли при завантаженні сторінки), зберігаємо та перезапускаємо nginx

![](./images/nginx-reload.png)

![](./images/nginx-instruction.png)

дивимося сорінку

![](./images/new-html-page.png)


# для того щоб розгорнути додаток я зніс повністю віртуалку створив нову та добавив 3 окремі диски

config.vm.provider "virtualbox" do |vb|
    vb.name = "VagrantVM_Full_Infra"
    vb.memory = "2048"
    vb.cpus = 2

    # Масив дисків для створення (Назва => Розмір у МБ)
    disks = {
      "web_data.vdi" => 5120,    для сайту
      "db_data.vdi"  => 5120,    для бази даних
      "backups.vdi"  => 10240    для бекапів
    }

    disks.each_with_index do |(name, size), index|
      unless File.exist?(name)
        vb.customize ['createhd', '--filename', name, '--size', size]
      end
      # Порти SATA: 1, 2, 3 (Порт 0 зайнятий ОС)
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', 
                    '--port', index + 1, '--device', 0, '--type', 'hdd', '--medium', name]
    end
  end

# 1.монтуємо диски за трохи новим алгоритмом

створення дисків Натискайте: n, p, 1, Enter, Enter, w

sudo fdisk /dev/sdb  
sudo fdisk /dev/sdc
sudo fdisk /dev/sdd

створення файлової системи

sudo mkfs.ext4 /dev/sdb1
sudo mkfs.ext4 /dev/sdc1
sudo mkfs.ext4 /dev/sdd1

створення точок монтування та підключення

створення папок

sudo mkdir -p /mnt/webdata /mnt/dbdata /mnt/backups

монтуємо диски до папок

sudo mount /dev/sdb1 /mnt/webdata
sudo mount /dev/sdc1 /mnt/dbdata
sudo mount /dev/sdd1 /mnt/backups

налаштування автоматичного монтування

дізнаємося UUID

sudo blkid | grep -E 'sdb1|sdc1|sdd1'

заходимо в sudo nano /etc/fstab та вставляємо

UUID=bfc9ab25-a36e-4579-9c60-ad49a542e360  /mnt/webdata  ext4  defaults  0  2
UUID=f1454462-25e9-4c75-917d-4c05a7fffb92  /mnt/dbdata   ext4  defaults  0  2
UUID=1533a08d-58e9-4f22-8b97-6a354ddccc9c /mnt/backups  ext4  defaults  0  2


оновимо конфігурацію системи

sudo systemctl daemon-reload


# 2.створення користувача 
створення користувача deploy-user для того щоб він керував сайтом

sudo useradd -m -s /bin/bash deploy-user

додаємо його до групи www-data

sudo usermod -aG www-data deploy-user

передаємо права на диск новому користувачу

sudo chown -R deploy-user:deploy-user /mnt/webdata /mnt/backups

встановлюємо права доступу такі що власник може все всі інші тільки читати

sudo chmod -R 755 /mnt/webdata /mnt/backups

# 3.postgresql на окремому диску /mnt/dbdata

зупинка postgresql

sudo systemctl stop postgresql

перенесення данних

sudo rsync -av /var/lib/postgresql/16/main /mnt/dbdata/

зміна конфігурацій
відкрити файл конфігурацій   sudo nano /etc/postgresql/16/main/postgresql.conf
змінити шлях   data_directory = '/mnt/dbdata/main'

налаштування прав
системного користувача postgres    sudo chown -R postgres:postgres /mnt/dbdata/main
права що тільки влласник має доступ sudo chmod 700 /mnt/dbdata/main

запускаємо базу та дивимося чи працює

sudo systemctl start postgresql

sudo -u postgres psql -c "SHOW data_directory;"


# 4. Деплой артефактів на диск /mnt/webdata

вхід під створеним користувачем

sudo -u deploy-user -i
cd /mnt/webdata

клонування репозиторію
    тут при клонуванні зявляється проблема
    git clone https://gitlab.com/iross335/skill_quest.git .
    fatal: destination path '.' already exists and is not an empty directory.
    ізза того що в нас при форматуванні диска в ext4 створилася системна папка lost+found, але папака в яку ми робимо клон має бути повністю пустою
    тому ми виходимо з юзера

    повне очищення папки

    sudo rm -rf /mnt/webdata/*
    sudo rm -rf /mnt/webdata/.* 2>/dev/null

    далі заходимо назад в юзера та робимо клон

    git clone https://gitlab.com/iross335/skill_quest.git .

створення віртуального серидовищя

python3 -m venv venv
source venv/bin/activate

встановлення бібліотек

pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn psycopg2-binary python-dotenv

створення конфігурацій

nano .env

та вставляємо 

DATABASE_URL=postgresql://skilluser:postgres@localhost/skill_quest_db
SECRET_KEY=super-secret-key-for-skillquest
FLASK_APP=run.py

створення бази та користувача всередині pstgresql

sudo -u postgres psql

створюємо базу юзера та даємо права

CREATE DATABASE skill_quest_db;
CREATE USER skilluser WITH PASSWORD 'postgres';
GRANT ALL PRIVILEGES ON DATABASE skill_quest_db TO skilluser;

підключаємося до бази та даємо права схемі

GRANT ALL ON SCHEMA public TO skilluser;

міграції
flask db upgrade

# 5. Автоматизація та автозапуск

виходимо з юзера в якому робили міграцію
створюємо фали сервісу
sudo nano /etc/systemd/system/skillquest.service

вставляємо the right way
[Unit]
Description=gunicorn instance to serve skill_quest app
After=network.target postgresql.service

[Service]
User=deploy-user
Group=www-data
WorkingDirectory=/mnt/webdata
Environment="PATH=/mnt/webdata/venv/bin"
Environment="DATABASE_URL=postgresql://skilluser:postgres@localhost/skill_quest_db"
Environment="SECRET_KEY=super-secret-key-for-skillquest"
Environment="FLASK_APP=run.py"

ExecStart=/mnt/webdata/venv/bin/gunicorn \
    --workers 3 \
    --bind unix:/mnt/webdata/skillquest.sock \
    run:app

Restart=always

[Install]
WantedBy=multi-user.target

активуємо сервіс та перевіряємо статус

sudo systemctl daemon-reload
sudo systemctl enable skillquest
sudo systemctl start skillquest

systemctl status skillquest


# 6. налаштовуємо nginx
відкриваємо конфігурацію nginx

sudo nano /etc/nginx/conf.d/default.conf

там має бути такий server
server {
    listen 80;
    server_name localhost;

    location /static/ {
        alias /mnt/webdata/app/static/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/mnt/webdata/skillquest.sock;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

перевіряєємо чи не має помилок
sudo nginx -t

перезапускаємо nginx щоб застосувати зміни
sudo systemctl restart nginx


# Дивимося працездатність
заходимо за посилання http://localhost:8081/ я прокидував на порт 8081
сторінка сайту

![](./images/web-site.png)

логи

![](./images/web-site-logs.png)