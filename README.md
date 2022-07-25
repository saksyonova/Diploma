# дипломный практикум в YandexCloud

## 1. регистрация доменного имени  
  
- зарегистрировано доменное имя `devopsy.ru`; 
   
- настроены необходимые DNS-записи для домена `devopsy.ru`;  
>![DNS](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/1_DNS.png)  
  
- создан S3 bucket в YC:  
>![S3 bucket](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/2_YC%203S%20bucket.png)  
  
  
## 2. создание инфраструктуры  
  
инфраструктура дипломного проекта разворачивается через `terraform apply` из каталога terraform текущего репозитория:  
  
- `app.tf`, `devopsy.tf`, `gitlab.tf`, `monitoring.tf`, `MySQL.tf`, `runner.tf` - содержат манифесты для создания ВМ в YC;  
- `meta.txt` - содержит основного пользователя и его открытый ключ, который будет создаваться в ВМ;  
- `network.tf` - содержит настройки сетей;  
- `providers.tf` - содержит настройки для подключения к провайдеру;  
- `variables.tf` - содержит переменную с зарезервированным статичным адресом, который используется в том числе при настройке DNS-записей.  
>![terraform apply 1](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/3_terraform%20apply%201.png) 
  
>![terraform apply 2](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/3_terraform%20apply%202.png)
  
  
## 3. установка Nginx и LetsEncrypt  
  
все необходимые роли находятся в каталоге ansible\roles и разделены по сервисам. минимальная версия Ansible - 2.9. в файле `hosts` находится inventory для плейбуков и переменные для Ansible ssh proxy.  
  
первым выполняем плейбук `front.yml`, он установит Nginx, LetsEncrypt, службу proxy, Node_Exporter на нашу front-машину.
далее запросит и получит необходимые сертификаты:  
>![front](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/4_front.png)  
  
  
## 4. установка кластера MySQL  
  
далее выполняем плейбук `MySQL.yml`, в файле `main.yml` каталога ansible\roles\Install_MySQL\defaults указаны настройки для MySQL кластера. в файле `hosts` переданы переменные для настройки репликации базы между db01 и db02.  
>![MySQL](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/5_MySQL.png)  
  
проверяем, что репликация настроена успешно:  
>![replica status](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/5_replica%20status.png) 
  
  
## 5. установка WordPress
  
для установки WordPress запускаем плейбук `wordpress.yml`, который устанавливает и настраивает nginx, memcached, php5 и wordpress. в файлике `wordpress.yml` также указаны переменные, необходимые для корректной работы wordpress:  
  
```yml
  vars:
    - domain: "devopsy.ru"
    - download_url: "http://wordpress.org/latest.tar.gz"
    - wpdirectory: "/var/www"
```
  
>![wordpress](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/6_wordpress.png)  
  
теперь наш сайт devopsy.ru доступен по https:  
>![wordpress start page](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/6_devopsy%20start%20page.png)  
  
  
## 6. установка GitLab CE и GitLab Runner
  
для установки GitLab используем плейбук `Gitlab.yml`. настройки для этой роли находятся в файлике `main.yml` каталога ansible\roles\Gitlab\defaults.  
>![GitLab](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/8_GitLab.png) 
  
теперь локальный GitLab доступен по https:  
>![GitLab start page](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/9_GitLab%20devopsy.png) 
  
аутентификация осуществляется по root/!QAZ2wsx.  
  
для установки GitLab Runner запускаем плейбук `runner.yml`. в файлике `main.yml` каталога ansible\roles\gitlab-runner\defaults указываем `gitlab_runner_coordinator_url` - адрес нашего GitLab, и `gitlab_runner_registration_token` - его можно взять из интерфейса GitLab.
>![runner](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/10_runner.png) 

после успешного выполнения плейбука Runner подключается к GitLab:  
>![runner GitLab](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/10_runner_GitLab.png)
  
  
создаём job, который при любом коммите в репозитории будет отправлять изменения на сервер WordPress (`app.devopsy.ru`): 
>![job script](https://github.com/saksyonova/Diploma/blob/main/images/12_job.png?raw=true)  
  
  
```
before_script:

  - eval $(ssh-agent -s)

  - echo "$ssh_key" | tr -d '\r' | ssh-add -

  - mkdir -p ~/.ssh
  - chmod 700 ~/.ssh

stages:         
  - deploy

deploy-job:      
  stage: deploy
  script:
    - echo "Deploying application..." 
    - ssh -o StrictHostKeyChecking=no sania@app.devopsy.ru sudo chown sania /var/www/wordpress/ -R
    - rsync -vz -e "ssh -o StrictHostKeyChecking=no" ./* sania@app.devopsy.ru:/var/www/wordpress/
    - ssh -o StrictHostKeyChecking=no sania@app.devopsy.ru rm -rf /var/www/wordpress/.git
    - ssh -o StrictHostKeyChecking=no sania@app.devopsy.ru sudo chown www-data /var/www/wordpress/ -R
```
  
для корректной работы job необходимо добавить переменную с локальным закрытым ключом, по которому осуществляется текущий доступ к целевому серверу:  
>![ssh variable](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/12_ssh%20variable.png)  
  
проверяем, что наш job выполняется корректно:  
>![successful job](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/12_successful%20job.png)  
  
>![successful job 2](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/12_successful%20job%202.png)  
  
  
## 7. установка Prometheus, Alert Manager, Node Exporter и Grafana  
  
для установки этих служб выполняем плейбук `NodeExporter.yml`, который установит Node Exporter на наши хосты:  
>![node exporter](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/11_node_exporter.png)  
  
далее выполняем плейбук `monitoring.yml`, который установит и настроит Prometheus, Alert Manager и Grafana. в файлике `prometheus.yml` каталога ansible\roles\monitoring\templates указаны настройки Prometheus, в файлике `alert.yml` того же каталога - настройки для обрабатываемых алертов.  
>![monitoring](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/13_monitoring.png)  
  
интерфейсы Grafana (аутентификация по admin\admin), Prometheus и AlertManager теперь доступны по https:
>![grafana start page](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/14_grafana.png)

в интерфейсе Графаны указываем источником данных Prometheus:  
>![grafana datasource](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/14_grafana%20datasource.png)  
  
импортируем шаблон `node-exporter-full_rev27.json` из каталога templates_grafana, чтобы по всем инстансам были доступны метрики в дашборде Grafana:
>![grafana dashboard](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/14_grafana%20dashboard.png)
  
данные Prometheus:  
>![prometheus 1](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/16_prometheus%201.png)
  
>![prometheus 2](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/16_prometheus%202.png)  

при выключении любой ВМ срабатывают алерты в AlertManager:  
>![alert](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/15_alertmanager.png)

