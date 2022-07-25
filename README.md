# Дипломный практикум в YandexCloud

## Регистрация доменного имени

- Зарегистрирован домен `ZHUKOPS.RU`;
- Настроено управление DNS для домена `ZHUKOPS.RU`;
>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/DNS.PNG)  

Создан S3 bucket в YC аккаунте.
>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/s3%20baket.png)  

## Развертывание инфраструктуры
Развертывание инфраструктуры производится командой `terraform apply` из каталога `Terraform` данного репозитория:

- `providers.tf` Содержит настройки для подключения к провайдеру;
- `variables.tf` Содержит переменную с зарезервированным статичным адресом. Данный адрес будет назначаться front/bastion instans;
- `network.tf` Содержит настройки сетей;
- `meta.txt` Содержит перечень пользователей и их открытые ключи, которые будут создаваться в виртуальных машинах;
- `app.tf`, `gitlab.tf`, `monitoring.tf`. `MySQL.tf`, `runner.tf`, `zhukops.tf` Содержат манифесты для создания виртуальных машин в YC.
>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/apply.png)
>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/yc.png)

## Установка Nginx и LetsEncrypt
Все необходимые роли находятся в каталоге `Ansible` и разделены по сервисам. Минимальная версия `Ansible` 2.9. В файле `hosts` находится inventory для playbook и переменные для ansible ssh proxy.

Первым следует выполнить playbook `front.yml`. Он установит и настроит `Nginx`, `LetsEncrypt`, службу `proxy`, `Node_Exporter` на front машину. Далеее запросит и получит необходимые сертификаты.


Для переключения между `stage` и `prod` запросами сертификатов следует отредактировать tasks с именем  `Create letsencrypt certificate` в файле `Ansible\roles\Install_Nginx_LetsEncrypt\tasks\main.yml`, добавив или удалив в них флаг `--staging` :
```
- name: Create letsencrypt certificate front
  shell: letsencrypt certonly -n --webroot --staging -w /var/www/letsencrypt -m {{ letsencrypt_email }} --agree-tos -d {{ domain_name }}
  args:
    creates: /etc/letsencrypt/live/{{ domain_name }}
```

## Установка кластера MySQL

Теперь пора выполнить playbook `MySQL.yml`. В файле `Ansible\roles\Install_MySQL\defaults\main.yml` находятся настройки MySQL кластера. Дополнительно в файле `hosts` передаются переменные для настройки репликации базы  между db01 и db02. 


>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/MySQL.png)

Убедимся, что репликация настроена и проходит успешно.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/Replica.png)

## Установка WordPress

Для установки `WordPress` служит playbook `wordpress.yml`.  Playbook устанавливает и настраивает `nginx`, `memcached`, `php5`, `wordpress`. В файле `wordpress.yml` так же передаются переменные, необходимые для корректной настройки wordpress.

```yml
  vars:
    - domain: "zhukops.ru"
    - download_url: "http://wordpress.org/latest.tar.gz"
    - wpdirectory: "/var/www"
```
>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/wp.png)

Теперь сайт zhukops.ru доступен по https.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/zhukops.png)

## Установка Gitlab CE и Gitlab Runner

Для установки Gitlab создан playbook `Gitlab`. Настройки данной роли вынесены в файл `Ansible\roles\Gitlab\defaults\main.yml`. Выполнение данного playbook может занять продолжительное время.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/gitlab.png)

Теперь локальный `Gitlab` доступен по https.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/gitweb.png)

Данные для входа -root/5iveL!fe. Если не удается залогиниться с указанными учетными данными, следует на instans gitlab.zhukops.ru выполнить команду `sudo gitlab-rake "gitlab:password:reset[root]"`, которая сбросит пароль пользователя root и запросит новый.

Для установки Gitlab Runner следует выполнить playbook - `Runner`. В файле `Ansible\roles\gitlab-runner\defaults\main.yml`  необходимо указать `gitlab_runner_coordinator_url` (адрес сервера GitLab), а также `gitlab_runner_registration_token` (его можно узнать в интерфейсе гитлаба).  

Если все выполнено верно, Runner подключиться к Gitlab.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/runner.PNG)


Для выполнения задачи deploy из GitLab  в app.zhukops.ru была разработана следующая job:

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
    - ssh -o StrictHostKeyChecking=no smarzhic@app.zhukops.ru sudo chown smarzhic /var/www/wordpress/ -R
    - rsync -vz -e "ssh -o StrictHostKeyChecking=no" ./* smarzhic@app.zhukops.ru:/var/www/wordpress/
    - ssh -o StrictHostKeyChecking=no smarzhic@app.zhukops.ru rm -rf /var/www/wordpress/.git
    - ssh -o StrictHostKeyChecking=no smarzhic@app.zhukops.ru sudo chown www-data /var/www/wordpress/ -R
```

Для ее корректной работы необходимо наличие переменной с закрытым ключом, по которому осуществляется доступ к целевому серверу. Создадим ее:

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/key.PNG)

Убедимся, что данная job выполняется верно.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/job1.PNG)

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/job2.PNG)

Теперь при commit в репозитории GitLab изменения будут отправляться на сервер c wordpress(app.zhukops.ru).

## Установка Prometheus, Alert Manager, Node Exporter и Grafana

Для настройки данных служб следует использовать playbook `NodeExporter.yml`, который установит `Node Exporter` на хосты. А затем Playbook  `monitoring.yml`, он установит и настроит `Prometheus`, `Alert Manager` и `Grafana`. В файле `Ansible\roles\monitoring\templates\prometheus.yml` содержаться настройки Prometheus. В файле `Ansible\roles\monitoring\templates\alert.yml` указываются обрабатываемые alert.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/monitoring.png)

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/nodeexporter.png)

Интерфейс `Grafana`, `Prometheus` и `alertmanager` теперь доступны по https. Данные для входа в `Grafana` admin/admin.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/prometheus.png)

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/grafanaweb.png)

Перейдя в интерфейс следует указать источник данных - Prometheus.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/grafanprom.png)

Импортировать шаблоны из каталога `templates_grafana`.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/importdashboard.png)

Теперь на `dashboard` Grafana доступны метрики со всех instans.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/nodemon.png)

При выключении одной из машин можно увидеть, что срабатывает созданный alert.

>![PID 1](https://github.com/Smarzhic/dip/blob/main/img/alert.png)

Далее, полученный alert можно отправить, например, на почту. Для этого необходимо внести изменения в файл конфигурации `/etc/alertmanager/alertmanager.yml`:
```
global:
route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 10m
  repeat_interval: 60m
  receiver: 'email'
receivers:
- name: 'email'
  email_configs:
  - to: 'адрес_электронной_почты_получателя'
    from: 'адрес_электронной_почты_отправителя'
    smarthost: 'SMTP_хост:порт'
    auth_username: 'имя_пользователя'
    auth_identity: 'имя_пользователя'
    auth_password: 'пароль'
```
