1. Форкніть проєкт:
    ![](./images/fork-repo.png)

Завдання 1: Деплой Jenkins
в даному репозиторії розміщена папка Jenkins в якій знаходиться docker-compose через який били запущені два контейнера
    ![](./images/work-conteiners.png)


Завдання 2: Налаштувати Freestyle Job
1. Створіть Freestyle Job у Jenkins:
    Пишемо назву Job яку нам потрібно створити обираємо тип freestyle project та натискаємо ОК
    ![](./images/Freestyle-project.png)

2. У налаштуваннях:
    В пункті Управління вихідним кодом нам потрібно обрати Git та вписати данні які зображені на скріншоті посилання на репозиторій та гілку так як по замовчуванню йде master в нашому репозиторії main
    ![](./images/git-repo.png)

    натискаємо на add build step обираємо Invoke top-level Maven targets обираємо версію Maven(потрібно було автоматично його добавити через Tools) та команду clean install(mvn писати не потрібно так як він додасця автоматично)
    також потрібно прописати шлях до папки де лежить pom.xml файл так як якщо його не буле то воне почне його шукати в коріні репозиторію але не знайде і білд не спрацює томупотрібно прописати до нього шлях
    ![](./images/build-steps.png)

    Maven додати в ручну Manage Jenkins(справа зверну шестерня) → Tools → Maven Installations → Add Maven та прописати назву
    ![](./images/Maven-install.png)

    натискаємо add post-build action обираємо Archive the artifacts та прописуємо де в нас буде створено артефакт натискаємо Save
    ![](./images/post-build.png)

    Результат натискаємо Build Now та чекаємо на завершення
    ![](./images/start-bild_and_finish.png)

    та спостерігаємо що білд пройшов успішно та артефакт створено
    ![](./images/build-status.png)
    ![](./images/faund-jar-in-terminal.png)

Висновок:
    Jenkins це інструмент який одєднує CI/CD процеси це свого роду кухня на якій готуються різні процеси, Maven робітник який буде робити продук(артефакт) .jar фбо .war



Завдання із зірочкою: налаштувати декларативний пайплайн
cтворюємо pipeline
![](./images/pipeline.png)

Є два варіанти

1. Спосіб
добавляємо скрипт та Save далі Build Now
![](./images/pipeline-enter-script.png)

pipeline {
    agent any

    tools {
        maven 'Maven3' 
    }

    stages {
        stage('Get Code from Git') {
            steps {
                    
                git branch: 'main', url: 'https://github.com/rostok2/gs-spring-boot.git'
            }
        }
        
        stage('Build Maven Project') {
            steps {
                echo 'Start building...'
                
                dir('complete') {
                    sh 'mvn clean install'
                }
            }
        }
    }

    post {
        success {
            echo 'Build Successful! Archiving artifacts...'
            archiveArtifacts artifacts: 'complete/target/*.jar', allowEmptyArchive: false
        }
        failure {
            echo 'Build Failed :('
        }
    }
}
2. Спосіб
добавляємо в репозиторій jenkinsfile
![](./images/jenkinsfile-in-git.png)

pipeline {
    agent any

    tools {
        maven 'Maven3' 
    }

    stages {        
        stage('Build Maven Project') {
            steps {
                echo 'Start building...'
                
                dir('complete') {
                    sh 'mvn clean install'
                }
            }
        }
    }

    post {
        success {
            echo 'Build Successful! Archiving artifacts...'
            archiveArtifacts artifacts: 'complete/target/*.jar', allowEmptyArchive: false
        }
        failure {
            echo 'Build Failed :('
        }
    }
}

заповнюємо поля наведені в картинках
![](./images/pipeline-git-add-repo.png)
![](./images/pipeline-git-add-repo-2.png)

в обох випадках результат має бути однаковий

білд пройшов успішно
![](./images/pipeline-overview.png)
![](./images/pipeline-overview.png)

