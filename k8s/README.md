# Запуск попередніх ресурсів

у цьому завданні я буду використовувати minikube завантажте його та виконайте команду щоб його запустити 

    minikube start --driver=docker

дані нам потрібно увімкнути адони

    minikube addons enable storage-provisioner
    minikube addons enable default-storageclass

створимо два namespace для наших апок

    kubectl create namespace redis
    kubectl create namespace falco


# Завдання 1: Створення StatefulSet для Redis-кластера

ствоюємо маніфест сервісу

```bash
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: redis
spec:
  ports:
    - port: 6379        # Порт, за яким Redis приймає з'єднання
      name: redis
  clusterIP: None       # Він не дає загальну IP адресу, а дозволяє звертатися до подів за іменами: redis-0, redis-1.
  selector:
    app: redis          # Сервіс знає: "Я обслуговую тільки поди з міткою app: redis"
```

аплаємо маніфест

    kubectl apply -f redis-service.yaml

створюємо маніфест 

```bash
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: redis
spec:
  serviceName: "redis-service"      # Зв'язує цей набір з нашим сервісом вище
  replicas: 2                       # Створює рівно 2 поди: redis-0 та redis-1
  selector:
    matchLabels:
      app: redis                    # Шукає поди з цією міткою
  template:                         # Опис самого Пода (контейнера)
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7.0-alpine     # Легкий та швидкий образ
        ports:
        - containerPort: 6379
          name: redis
        volumeMounts:               # ПІДКЛЮЧЕННЯ ДИСКА
        - name: redis-data          # Назва тому (має збігатися з шаблоном нижче)
          mountPath: /data          # Куди в контейнері підключити диск (папка бази)
  volumeClaimTemplates:             # ШАБЛОН ДЛЯ АВТОМАТИЧНИХ ДИСКІВ
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]      # Диск може читати/писати тільки 1 вузол за раз
      resources:
        requests:
          storage: 1Gi              # Кожному поду виділяється окремий диск на 1 ГБ
```

аплаємо маніфест

    kubectl apply -f redis-sts.yaml

дивемося чи створені поди

    kubectl get pods -n redis

має зявитися такий текст

    NAME      READY   STATUS    RESTARTS      AGE
    redis-0   1/1     Running   4 (44m ago)   39h
    redis-1   1/1     Running   4 (44m ago)   39h


# Завдання 2: Налаштування Falco в Kubernetes за допомогою DaemonSet

створюємо манівест DaemonSet

```bash
# Використовуємо версію API apps/v1, оскільки DaemonSet — це контролер додатків
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: falco        # Розгортаємо в окремому ізольованому просторі імен для безпеки
  labels:
    app: falco            # Мітка для ідентифікації самого об'єкта DaemonSet
spec:
  selector:
    matchLabels:
      app: falco          # DaemonSet буде керувати тільки тими подами, які мають цю мітку
  template:
    metadata:
      labels:
        app: falco        # Ця мітка автоматично додається до кожного створеного пода
    spec:
      # hostPID: true — дозволяє контейнеру "бачити" дерево процесів хоста (вузла).
      # Це критично для Falco, щоб він міг визначити, яка саме програма на сервері зробила підозрілу дію.
      hostPID: true
      
      containers:
      - name: falco
        image: falcosecurity/falco:latest # Офіційний образ останньої версії Falco
        
        # SecurityContext з privileged: true дає контейнеру повні права адміністратора (root) на вузлі.
        # Falco це потрібно для взаємодії з ядром Linux (завантаження eBPF програм або модулів).
        securityContext:
          privileged: true 

        # Обмеження ресурсів згідно з технічним завданням:
        resources:
          requests:       # Гарантовані ресурси, які виділяються відразу при старті
            cpu: 100m     # 10% потужності одного процесорного ядра
            memory: 128Mi # 128 Мегабайтів оперативної пам'яті
          limits:         # Максимальний поріг, який контейнеру заборонено перевищувати
            cpu: 100m
            memory: 256Mi # Збільшений ліміт пам'яті для обробки великої кількості подій

        # volumeMounts — куди в файловій системі контейнера будуть підключені системні папки хоста
        volumeMounts:
        - name: proc
          mountPath: /host/proc       # Доступ до інформації про запущені процеси
          readOnly: true
        - name: boot
          mountPath: /host/boot       # Доступ до конфігурацій та символів ядра
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules # Доступ до модулів ядра (необхідно для роботи драйвера Falco)
          readOnly: true
        - name: usr
          mountPath: /host/usr        # Доступ до системних утиліт та бібліотек вузла
          readOnly: true
        - name: docker-sock
          mountPath: /host/var/run/docker.sock # Доступ до Docker-сокета для отримання метаданих контейнерів
          # Примітка: якщо в Minikube використовується containerd, шлях може бути іншим, 
          # але Docker-сокет є стандартною вимогою для контролю контейнерних подій.

      # volumes — опис того, які саме папки з фізичного вузла (Minikube) ми хочемо взяти
      volumes:
      - name: proc
        hostPath:
          path: /proc         # Процеси вузла
      - name: boot
        hostPath:
          path: /boot         # Дані завантаження та ядра
      - name: lib-modules
        hostPath:
          path: /lib/modules  # Модулі ядра Linux
      - name: usr
        hostPath:
          path: /usr          # Системні файли вузла
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock # Файл зв'язку з Docker-рантаймом
```

аплаємо маніфест

    kubectl apply -f falco-ds.yaml

перевіряємо поди

    kubectl get pods -n falco -l app=falco

вивід

    NAME          READY   STATUS    RESTARTS   AGE
    falco-fm99z   1/1     Running   0          12s

перевірка логів

    kubectl logs -l app=falco -n falco

вивід

```test
  2026-01-29T13:05:12+0000: [libs]: libbpf: prog 'openat_e': failed to create tracepoint 'syscalls/sys_enter_openat' perf event: No such file or directory
  2026-01-29T13:05:12+0000: [libs]: libpman: failure while attaching TOCTOU mitigation program for 'openat' system call. Detection will continue to work, but TOCTOU mitigation may not properly work (errno: 2 | message: No such file or directory
  2026-01-29T13:20:21.464826410+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-auth gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465454518+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-account gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465517106+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-password gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465840698+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-session-noninteractive gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465907194+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/other gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465913175+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-auth gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465925548+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-account gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
  2026-01-29T13:20:21.465936279+0000: Warning Sensitive file opened for reading by non-trusted program | file=/etc/pam.d/common-password gparent=<NA> ggparent=<NA> gggparent=<NA> evt_type=openat user=root user_uid=0 user_loginuid=1000 process=pkexec proc_exepath=/usr/bin/pkexec parent=update-notifier command=pkexec /usr/lib/update-notifier/package-system-locked terminal=0 container_id=host container_name=host container_image_repository= container_image_tag= k8s_pod_name=<NA> k8s_ns_name=<NA>
```

# Виконайте минулі два завдання, створивши helm-chart

створюємо папки для чартів

    mkdir redis-helm-chart
    mkdir falco-helm-chart

також в кожній з створених папок виконуємо такі команди

    mkdir templates
    touch values.yaml
    touch Chart.yaml

створюємо відповідні файли redis-helm-chart/templates(redis-service.yaml, redis-sts.yaml) та falco-helm-chart/templates(falco-ds.yaml)

також створимо два окремі namespace

    kubectl create namespace redis-helm
    kubectl create namespace falco-helm


### redis-helm-chart

redis-helm-chart/Chart.yaml

```bash
apiVersion: v2
name: redis-chart
description: Helm chart для розгортання Redis кластера через StatefulSet
type: application
version: 0.1.0
appVersion: "7.0-alpine"
```

redis-helm-chart/values.yaml

```bash
namespace: redis-helm
replicas: 2
image: redis:7.0-alpine
service:
  port: 6379
storage:
  size: 1Gi
```

redis-helm-chart/templates/redis-service.yaml

```bash
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: {{ .Values.namespace }}
spec:
  ports:
    - port: {{ .Values.service.port }}
      name: redis
  clusterIP: None
  selector:
    app: redis
```

redis-helm-chart/templates/redis-sts.yaml

```bash
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: {{ .Values.namespace }}
spec:
  serviceName: "redis-service"
  replicas: {{ .Values.replicas }}
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: {{ .Values.image }}
        ports:
        - containerPort: {{ .Values.service.port }}
          name: redis
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: {{ .Values.storage.size }}
```

застосовуємо

    helm install redis-release ./redis-helm-chart -n redis-helm

має вивестись

```test
  NAME: redis-release
  LAST DEPLOYED: Thu Jan 29 23:07:21 2026
  NAMESPACE: redis-helm
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
```

### falco-helm-chart

falco-helm-chart/Chart.yaml

```bash
apiVersion: v2
name: falco-chart
description: Helm chart для розгортання Falco через DaemonSet
type: application
version: 0.1.0
appVersion: "latest"
```

falco-helm-chart/values.yaml

```bash
namespace: falco-helm
image: falcosecurity/falco:latest
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 100m
    memory: 256Mi
```

falco-helm-chart/templates/falco-ds.yaml

```bash
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: falco
  namespace: {{ .Values.namespace }}
  labels:
    app: falco
spec:
  selector:
    matchLabels:
      app: falco
  template:
    metadata:
      labels:
        app: falco
    spec:
      hostPID: true
      containers:
      - name: falco
        image: {{ .Values.image }}
        securityContext:
          privileged: true
        resources:
          requests:
            cpu: {{ .Values.resources.requests.cpu }}
            memory: {{ .Values.resources.requests.memory }}
          limits:
            cpu: {{ .Values.resources.limits.cpu }}
            memory: {{ .Values.resources.limits.memory }}
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: boot
          mountPath: /host/boot
          readOnly: true
        - name: lib-modules
          mountPath: /host/lib/modules
          readOnly: true
        - name: usr
          mountPath: /host/usr
          readOnly: true
        - name: docker-sock
          mountPath: /host/var/run/docker.sock
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: boot
        hostPath:
          path: /boot
      - name: lib-modules
        hostPath:
          path: /lib/modules
      - name: usr
        hostPath:
          path: /usr
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
```

застосовуємо

    helm install falco-release ./falco-helm-chart -n falco-helm

має вивестись

```text
  NAME: falco-release
  LAST DEPLOYED: Thu Jan 29 23:11:04 2026
  NAMESPACE: falco-helm
  STATUS: deployed
  REVISION: 1
  TEST SUITE: None
```

### перевірка усіх под

команда

    kubectl get pods -A

вивід

```test
NAMESPACE     NAME                               READY   STATUS    RESTARTS        AGE
falco-helm    falco-4kjzb                        1/1     Running   0               96s
falco         falco-fm99z                        1/1     Running   1 (9m46s ago)   8h
kube-system   coredns-66bc5c9577-q45k5           1/1     Running   6 (9m46s ago)   5d2h
kube-system   etcd-minikube                      1/1     Running   6 (9m46s ago)   5d2h
kube-system   kube-apiserver-minikube            1/1     Running   6 (9m46s ago)   5d2h
kube-system   kube-controller-manager-minikube   1/1     Running   6 (9m46s ago)   5d2h
kube-system   kube-proxy-5w5hg                   1/1     Running   6 (9m46s ago)   5d2h
kube-system   kube-scheduler-minikube            1/1     Running   6 (9m46s ago)   5d2h
kube-system   storage-provisioner                1/1     Running   11 (9m5s ago)   5d2h
redis-helm    redis-0                            1/1     Running   0               5m19s
redis-helm    redis-1                            1/1     Running   0               5m18s
redis         redis-0                            1/1     Running   6 (9m46s ago)   4d23h
redis         redis-1                            1/1     Running   6 (9m46s ago)   4d23h
```