terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "devopsy.ru"
    region     = "ru-central1"
    key        = "./devopsy.ru.tfstate"
    access_key = "YCAJEiI_-Rre0dfw2-1TFpK8c"
    secret_key = "YCOxOWptXHrontgfFQpFy6EI2duF8tpNExuAPtV-"


    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

provider "yandex" {
  token     = "AQAAAAAyCXGtAATuwRqVKNAXe0FomtIQ_IWl3FA"
  cloud_id  = "b1glptti2hjffghqmm9n"
  folder_id = "b1gdm3ufr8nd44nfirld"
  zone      = "ru-central1-a"
}
