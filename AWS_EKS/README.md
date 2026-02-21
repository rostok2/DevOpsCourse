# Створення та Налаштування Кластера EKS

Створюємо файл eks-cluster.yaml
```bash
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: rostok-eks-cluster
  region: us-east-1
  version: "1.29"

nodeGroups:
  - name: ng-public-1
    instanceType: t3.medium
    desiredCapacity: 2
    amiFamily: AmazonLinux2
    labels: {role: worker}
    tags:
      Name: eks-worker-node-public

```

створюємо кластер
```bash
eksctl create cluster -f eks-cluster.yaml
```

!!!Чесно кажучи задовбався чекати поки ця команда відпрацює, тільки з другої спроби пройшла так на тому регіоні якийй обрав був заповнений!!!

перевірка очікуємо на 2 вузли у стані Ready
```bash
kubectl get nodes
```

результат
```test
NAME                             STATUS   ROLES    AGE   VERSION
ip-192-168-18-242.ec2.internal   Ready    <none>   60s   v1.29.15-eks-ecaa3a6
ip-192-168-58-150.ec2.internal   Ready    <none>   55s   v1.29.15-eks-ecaa3a6
```

# Розгортання Статичного Вебсайту

## Створення ConfigMap

Створюємо файл з назвою configmap.yaml
```bash
apiVersion: v1
kind: ConfigMap
metadata:
  name: website-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Hello-World</title>
    </head>
    <body>
        <h1>HI!</h1>
        <p>Privet</p>
    </body>
    </html>
```

аплаємо файл
```bash
kubectl apply -f configmap.yaml
```

перевірка
```bash
kubectl get cm website-content
```

результат
```test
NAME              DATA   AGE
website-content   1      24s
```

## Створення Deployment

Створюємо файл з назвою deployment-nginx.yaml
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: static-website
spec:
  replicas: 2
  selector:
    matchLabels:
      app: static-website
  template:
    metadata:
      labels:
        app: static-website
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content-volume
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: content-volume
        configMap:
          name: website-content
```

аплаємо файл
```bash
kubectl apply -f deployment-nginx.yaml
```

перевірка
```bash
kubectl get pods -l app=static-website
```

результат
```test
NAME                              READY   STATUS    RESTARTS   AGE
static-website-5c86dfb9d5-7xqzk   1/1     Running   0          31s
static-website-5c86dfb9d5-htqsd   1/1     Running   0          31s
```

## Створення Service типу LoadBalancer

Створюємо файл з назвою service-lb.yaml
```bash
apiVersion: v1
kind: Service
metadata:
  name: static-website-service
spec:
  type: LoadBalancer
  selector:
    app: static-website
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

аплаємо файл
```bash
kubectl apply -f service-lb.yaml
```

перевірка
```bash
kubectl get svc static-website-service
```

результат
```test
NAME                     TYPE           CLUSTER-IP       EXTERNAL-IP                                                              PORT(S)        AGE
static-website-service   LoadBalancer   10.100.238.231   a97cb5b849aeb49b3a797ae8dd802a07-210374111.us-east-1.elb.amazonaws.com   80:30668/TCP   9s
```

можна перейти за посилланням
```test
a97cb5b849aeb49b3a797ae8dd802a07-210374111.us-east-1.elb.amazonaws.com
```

# PersistentVolumeClaim та Job

## Створення PersistentVolumeClaim

Створюємо файл з назвою pvc.yaml
```bash
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: gp2
```

аплаємо файл
```bash
kubectl apply -f pvc.yaml
```

перевірка
```bash
kubectl get pvc data-pvc
```

результат
```test
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
data-pvc   Bound    pvc-e542163a-1e0c-483c-9d5a-9d41cb337ea0   5Gi        RWO            gp2            <unset>                 9m30s
```

## Розгортання Pod з використанням PVC

Створюємо файл з назвою pod-with-pvc.yaml
```bash
apiVersion: v1
kind: Pod
metadata:
  name: data-writer-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ["/bin/sh", "-c", "date >> /data/test.log; sleep 3600"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: data-pvc
```

аплаємо файл
```bash
kubectl apply -f pod-with-pvc.yaml
```

перевірка
```bash
kubectl get pod data-writer-pod
```

результат
```test
NAME              READY   STATUS    RESTARTS   AGE
data-writer-pod   1/1     Running   0          9m53s
```

## Проблеми які були з pod та pvc

бола проблема що pod та pvc були в статусі pending що вказувало на те що воркер ноди не могли ініціювати створення постійного тому AWS EBS
хоча кластер EKS був створений за допомогою eksctl для коректної роботи динамічного надання томів через EBS CSI Driver потрібні були специфічні дозволи IAM які не були автоматично активовані
вручну приєднали AmazonEBSCSIDriverPolicy до IAM Role яка використовується воркер нодами
після цього проблема вирішилася

## Запуск завдання за допомогою Job

Створюємо файл з назвою pvc.yaml
```bash
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      containers:
      - name: hello-container
        image: busybox
        command: ["echo", "Hello from EKS!"]
      restartPolicy: OnFailure
  backoffLimit: 4
```

аплаємо файл
```bash
kubectl apply -f job-echo.yaml
```

перевірка
```bash
kubectl get jobs
POD_NAME=$(kubectl get pods --selector=job-name=hello-job -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME
```

результат
```test
NAME        COMPLETIONS   DURATION   AGE
hello-job   1/1           3s         52s
Hello from EKS!
```

# Розгортання Тестового Застосунку та Робота з Неймспейсами

## Розгортання Тестового Застосунку

Створюємо файл з назвою deployment-test-app.yaml
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app-deployment
  labels:
    app: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: httpd-container
        image: httpd:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-clusterip
spec:
  type: ClusterIP
  selector:
    app: test-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

аплаємо файл
```bash
kubectl apply -f deployment-test-app.yaml
```

перевірка
```bash
kubectl get deploy test-app-deployment
kubectl get svc test-app-clusterip
```

результат
```test
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
test-app-deployment   2/2     2            2           9s
NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
test-app-clusterip   ClusterIP   10.100.93.103   <none>        80/TCP    11s
```

## Робота з Неймспейсами

Створення Namespace
```bash
kubectl create namespace dev
```

перевірка
```bash
kubectl get ns dev
```

результат
```text
NAME   STATUS   AGE
dev    Active   6s
```

Створюємо файл з назвою deployment-busybox-dev.yaml
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-sleep
  namespace: dev
spec:
  replicas: 5
  selector:
    matchLabels:
      app: busybox-sleep
  template:
    metadata:
      labels:
        app: busybox-sleep
    spec:
      containers:
      - name: sleep-container
        image: busybox
        command: ["sleep", "3600"]
```

аплаємо файл
```bash
kubectl apply -f deployment-busybox-dev.yaml
```

перевірка
```bash
kubectl get pods -n dev
```

результат
```test
NAME                             READY   STATUS    RESTARTS   AGE
busybox-sleep-784b77684f-2shbd   1/1     Running   0          7s
busybox-sleep-784b77684f-f9pvp   1/1     Running   0          7s
busybox-sleep-784b77684f-mxkzl   1/1     Running   0          7s
busybox-sleep-784b77684f-n7j4n   1/1     Running   0          7s
busybox-sleep-784b77684f-pqmrp   1/1     Running   0          7s
```

# Очищення

## Видалення ресурсів у Namespace dev

```bash
kubectl delete deployment busybox-sleep -n dev
kubectl delete ns dev
```

## Видалення ресурсів у Namespace

```bash
# Job
kubectl delete job hello-job

# Статичний Вебсайт (Service, Deployment, ConfigMap)
kubectl delete svc static-website-service
kubectl delete deploy static-website
kubectl delete cm website-content

# Тестовий Застосунок (Deployment, Service)
kubectl delete svc test-app-clusterip
kubectl delete deploy test-app-deployment

# PVC (Видалення PVC має ініціювати видалення PV, якщо StorageClass налаштований на 'Delete')
# Навіть якщо він не видаляється, ми його видаляємо
kubectl delete pvc data-pvc
# Видалення пода, який міг заважати видаленню PVC
kubectl delete pod data-writer-pod --ignore-not-found=true
```

## Перевірка, що все видалено

```bash
kubectl get all
```

## Видалення Кластера EKS та Інфраструктури AWS

```bash
eksctl delete cluster --name=rostok-eks-cluster --region=us-east-1
```
