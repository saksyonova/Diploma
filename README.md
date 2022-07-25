# дипломный практикум в YandexCloud

## 1. регистрация доменного имени  
  
- зарегистрировано доменное имя `devopsy.ru`; 
   
- настроены необходимые DNS-записи для домена `devopsy.ru`;  
>![DNS](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/1_DNS.png)  
  
- создан S3 bucket в YC:  
>![S3 bucket](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/2_YC%203S%20bucket.png)  
  
  
## 2. создание инфраструктуры  
  
инфраструктура дипломного проекта разворачивается через `terraform apply` из каталога Terraform нашего репозитория:  
  
- `app.tf`, `devopsy.tf`, `gitlab.tf`, `monitoring.tf`, `MySQL.tf`, `runner.tf` - содержат манифесты для создания ВМ в YC;  
- `meta.txt` - содержит основного пользователя и его открытый ключ, который будет создаваться в ВМ;  
- `network.tf` - содержит настройки сетей;  
- `providers.tf` - содержит настройки для подключения к провайдеру;  
- `variables.tf` - содержит переменную с зарезервированным статичным адресом, который используется в том числе при настройке DNS-записей.  
>![terraform apply 1](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/3_terraform%20apply%201.png) 
  
>![terraform apply 2](https://raw.githubusercontent.com/saksyonova/Diploma/main/images/3_terraform%20apply%202.png)
  
  
## 3. установка Nginx и LetsEncrypt  
  
все необходимые роли находятся в каталоге Ansible и разделены по сервисам. минимальная версия Ansible - 2.9. в файле `hosts` находится inventory для плейбуков и переменные для Ansible ssh proxy.