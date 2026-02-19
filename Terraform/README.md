# Підготовка та створення структури

Створюємо локально структуру Terraform

```bash
mkdir -p Terraform/{vpc_module,subnet_module,ec2_module}

touch Terraform/main.tf
touch Terraform/provider.tf

touch Terraform/vpc_module/main.tf
touch Terraform/vpc_module/variables.tf
touch Terraform/vpc_module/outputs.tf

touch Terraform/subnet_module/main.tf
touch Terraform/subnet_module/variables.tf
touch Terraform/subnet_module/outputs.tf

touch Terraform/ec2_module/main.tf
touch Terraform/ec2_module/variables.tf
touch Terraform/ec2_module/outputs.tf   
```

## Налаштування регіону

Вміст файлу provider.tf - цей файл повідомляє Terraform з яким провайдером (AWS) та в якому регіоні (eu-central-1) він має працювати

```bash
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}
```



## Модуль VPC vpc_module

Вміст файлу variables.tf - Оголошує змінні для CIDR VPC та префіксу імені

```bash
variable "vpc_cidr" { type = string }
variable "name_prefix" { type = string }
```

Вміст файлу main.tf-  створює aws_vpc та aws_internet_gateway

```bash
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.name_prefix}-VPC" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${var.name_prefix}-IGW" }
}
```

Вміст фалу output.tf - експортує ID створеного VPC та IGW

```bash
output "vpc_id" { value = aws_vpc.main.id }
output "igw_id" { value = aws_internet_gateway.gw.id }
```



## Модуль Підмереж subnet_module

Вміст файлу variables.tf - оголошує змінні для VPC ID, IGW ID, CIDR підмереж та AZ

```bash
variable "vpc_id" {}
variable "igw_id" {}
variable "public_cidr" {}
variable "private_cidr" {}
variable "az_public" {}
variable "az_private" {}
variable "name_prefix" {}
```

Вміст файлу main.tf - створює aws_subnet (public/private) та aws_route_table

```bash
# Публічна підмережа
resource "aws_subnet" "public" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_cidr
  availability_zone       = var.az_public
  map_public_ip_on_launch = true
  tags = { Name = "${var.name_prefix}-Public-Subnet" }
}

# Приватна підмережа
resource "aws_subnet" "private" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_cidr
  availability_zone       = var.az_private
  map_public_ip_on_launch = false
  tags = { Name = "${var.name_prefix}-Private-Subnet" }
}

# Route Table для публічної підмережі
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
  tags = { Name = "${var.name_prefix}-Public-RT" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

Вміст фалу output.tf - експортує ID публічної та приватної підмереж

```bash
output "public_subnet_id" { value = aws_subnet.public.id }
output "private_subnet_id" { value = aws_subnet.private.id }
```



## Модуль EC2 ec2_module

Вміст файлу variables.tf - оголошує змінні для AMI ID, ID публічної та приватної підмереж

```bash
variable "ami_id" {}
variable "public_subnet_id" {}
variable "private_subnet_id" {}
variable "name_prefix" {}
```

Вміст файлу main.tf - створює два інстанси aws_instance (один у публічній, один у приватній підмережі)

```bash
# Публічний сервер
resource "aws_instance" "public_server" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = var.public_subnet_id
  associate_public_ip_address = true
  tags = { Name = "${var.name_prefix}-Public-Server" }
}

# Приватний сервер
resource "aws_instance" "private_server" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  subnet_id     = var.private_subnet_id
  tags = { Name = "${var.name_prefix}-Private-Server" }
}
```

Вміст фалу output.tf - експортувати ID створених інстансів

```bash
output "public_instance_id" { value = aws_instance.public_server.id }
```

## Головний конфігураційний файл

Вміст файлу main.tf - викликає три створені модулі (vpc_module, subnet_module, ec2_module) та передає між ними значення (Inputs)
```bash
locals {
  prefix = "rostok-imported-stack"
  az_pub = "eu-central-1a"
  az_pri = "eu-central-1b"
  ami_id = "ami-0d527370828225502" 
}

# 1. Створення VPC
module "network" {
  source      = "./vpc_module"
  vpc_cidr    = "10.10.0.0/16"
  name_prefix = local.prefix
}

# 2. Створення Підмереж
module "subnets" {
  source          = "./subnet_module"
  vpc_id          = module.network.vpc_id      # Використовуємо output з модуля network
  igw_id          = module.network.igw_id      # Використовуємо output з модуля network
  public_cidr     = "10.10.1.0/24"
  private_cidr    = "10.10.2.0/24"
  az_public       = local.az_pub
  az_private      = local.az_pri
  name_prefix     = local.prefix
}

# 3. Створення EC2 Інстансів
module "servers" {
  source              = "./ec2_module"
  ami_id              = local.ami_id
  public_subnet_id    = module.subnets.public_subnet_id   # Використовуємо output з модуля subnets
  private_subnet_id   = module.subnets.private_subnet_id  # Використовуємо output з модуля subnets
  name_prefix         = local.prefix
}
```



# Переходимо до AWS
потрібно зробити Access Keys для того щоб ми могли в майбутньому зробити import


У сервісі IAM переходимо до користувача у розділі "Security credentials" ви створили Access Key для "Command Line Interface (CLI)"
Ви отримали та зберегли aws_access_key_id та aws_secret_access_key їх потрібно зберегти

створюємо папку 

```bash
mkdir -p ~/.aws
```

створюємо файл

```bash
nano ~/.aws/credentials
```

та вмістити
```bash
[default]
aws_access_key_id = YOUR_ACCESS_KEY_ID
aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
```

## Переходимо до сервісу VPC

Створюємо VPC з діапазоном 10.10.0.0/16 - vpc-0db600b87dbb99b0a

Створюємо Internet Gateway(IGW) та приєднуємо його до створеного раніше VPC - igw-08131916b62de30d2

Створюємо публічну підмережу у eu-central-1a (10.10.1.0/24) з увімкненим публічним IP - subnet-0dbff548ec84ee6b3

Створено приватну підмережу у eu-central-1b (10.10.2.0/24) з вимкненим публічним IP - subnet-085b72401909f6e39

Створено Route Table яка направляє трафік 0.0.0.0/0 через IGW, та зєднує її лише з публічною підмережею - rtb-0d1b95aa5fdbe1d47

## Переходимо до сервісу EC2

Публічний EC2 був розміщений у публічній підмережі та отримав публічну IP-адресу - i-08c86ea4747cc147e

Приватний EC2 був розміщений у приватній підмережі і не має публічної IP - i-0b60626fe24dd560d

# Синхронізація та імпорт

Ініціалізуємо Terraform

```bash    
terraform init
```

Імпортуємо

```bash
# 1. VPC 
terraform import 'module.network.aws_vpc.main' vpc-0db600b87dbb99b0a

# 2. IGW 
terraform import 'module.network.aws_internet_gateway.gw' igw-08131916b62de30d2

# 3. Публічна Підмережа 
terraform import 'module.subnets.aws_subnet.public' subnet-0dbff548ec84ee6b3

# 4. Приватна Підмережа 
terraform import 'module.subnets.aws_subnet.private' subnet-085b72401909f6e39

# 5. Публічний EC2
terraform import 'module.servers.aws_instance.public_server' i-08c86ea4747cc147e

# 6. Приватний EC2
terraform import 'module.servers.aws_instance.private_server' i-0b60626fe24dd560d

# 7. Route Table 
terraform import 'module.subnets.aws_route_table.public' rtb-0d1b95aa5fdbe1d47 

# 8. Асоціація Підмережі з Route Table (ВИПРАВЛЕНО: SubnetID/RouteTableID)
terraform import 'module.subnets.aws_route_table_association.public' subnet-0dbff548ec84ee6b3/rtb-0d1b95aa5fdbe1d47
```

перевіряємо

```bash
terraform plan
```

результат
```text
module.network.aws_vpc.main: Refreshing state... [id=vpc-0db600b87dbb99b0a]
module.network.aws_internet_gateway.gw: Refreshing state... [id=igw-08131916b62de30d2]
module.subnets.aws_subnet.private: Refreshing state... [id=subnet-085b72401909f6e39]
module.subnets.aws_subnet.public: Refreshing state... [id=subnet-0dbff548ec84ee6b3]
module.subnets.aws_route_table.public: Refreshing state... [id=rtb-0d1b95aa5fdbe1d47]
module.servers.aws_instance.private_server: Refreshing state... [id=i-0b60626fe24dd560d]
module.subnets.aws_route_table_association.public: Refreshing state... [id=rtbassoc-06ee78e8280dcdece]
module.servers.aws_instance.public_server: Refreshing state... [id=i-08c86ea4747cc147e]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # module.network.aws_vpc.main will be updated in-place
  ~ resource "aws_vpc" "main" {
      ~ enable_dns_hostnames                 = false -> true
        id                                   = "vpc-0db600b87dbb99b0a"
        tags                                 = {
            "Name" = "rostok-imported-stack-VPC"
        }
        # (18 unchanged attributes hidden)
    }

  # module.servers.aws_instance.private_server must be replaced
-/+ resource "aws_instance" "private_server" {
      ~ ami                                  = "ami-0bae57ee7c4478e01" -> "ami-0d527370828225502" # forces replacement
      ~ arn                                  = "arn:aws:ec2:eu-central-1:798974632222:instance/i-0b60626fe24dd560d" -> (known after apply)
      ~ associate_public_ip_address          = false -> (known after apply)
      ~ availability_zone                    = "eu-central-1b" -> (known after apply)
      ~ cpu_core_count                       = 1 -> (known after apply)
      ~ cpu_threads_per_core                 = 2 -> (known after apply)
      ~ disable_api_stop                     = false -> (known after apply)
      ~ disable_api_termination              = false -> (known after apply)
      ~ ebs_optimized                        = true -> (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      - hibernation                          = false -> null
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      ~ id                                   = "i-0b60626fe24dd560d" -> (known after apply)
      ~ instance_initiated_shutdown_behavior = "stop" -> (known after apply)
      + instance_lifecycle                   = (known after apply)
      ~ instance_state                       = "running" -> (known after apply)
      ~ instance_type                        = "t3.micro" -> "t2.micro"
      ~ ipv6_address_count                   = 0 -> (known after apply)
      ~ ipv6_addresses                       = [] -> (known after apply)
      ~ key_name                             = "terraform-key" -> (known after apply)
      ~ monitoring                           = false -> (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      ~ placement_partition_number           = 0 -> (known after apply)
      ~ primary_network_interface_id         = "eni-06ecd0b47cf7d431f" -> (known after apply)
      ~ private_dns                          = "ip-10-10-2-199.eu-central-1.compute.internal" -> (known after apply)
      ~ private_ip                           = "10.10.2.199" -> (known after apply)
      + public_dns                           = (known after apply)
      + public_ip                            = (known after apply)
      ~ secondary_private_ips                = [] -> (known after apply)
      ~ security_groups                      = [] -> (known after apply)
      + spot_instance_request_id             = (known after apply)
        tags                                 = {
            "Name" = "rostok-imported-stack-Private-Server"
        }
      ~ tenancy                              = "default" -> (known after apply)
      + user_data                            = (known after apply)
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      ~ vpc_security_group_ids               = [
          - "sg-0bb7b8063bfcb0e2f",
        ] -> (known after apply)
        # (4 unchanged attributes hidden)

      ~ capacity_reservation_specification (known after apply)
      - capacity_reservation_specification {
          - capacity_reservation_preference = "open" -> null
        }

      ~ cpu_options (known after apply)
      - cpu_options {
          - core_count       = 1 -> null
          - threads_per_core = 2 -> null
            # (1 unchanged attribute hidden)
        }

      - credit_specification {
          - cpu_credits = "unlimited" -> null
        }

      ~ ebs_block_device (known after apply)

      ~ enclave_options (known after apply)
      - enclave_options {
          - enabled = false -> null
        }

      ~ ephemeral_block_device (known after apply)

      ~ instance_market_options (known after apply)

      ~ maintenance_options (known after apply)
      - maintenance_options {
          - auto_recovery = "default" -> null
        }

      ~ metadata_options (known after apply)
      - metadata_options {
          - http_endpoint               = "enabled" -> null
          - http_protocol_ipv6          = "disabled" -> null
          - http_put_response_hop_limit = 2 -> null
          - http_tokens                 = "required" -> null
          - instance_metadata_tags      = "disabled" -> null
        }

      ~ network_interface (known after apply)

      ~ private_dns_name_options (known after apply)
      - private_dns_name_options {
          - enable_resource_name_dns_a_record    = false -> null
          - enable_resource_name_dns_aaaa_record = false -> null
          - hostname_type                        = "ip-name" -> null
        }

      ~ root_block_device (known after apply)
      - root_block_device {
          - delete_on_termination = true -> null
          - device_name           = "/dev/xvda" -> null
          - encrypted             = false -> null
          - iops                  = 3000 -> null
          - tags                  = {} -> null
          - tags_all              = {} -> null
          - throughput            = 125 -> null
          - volume_id             = "vol-05c5735c34e9ce4b4" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp3" -> null
            # (1 unchanged attribute hidden)
        }
    }

  # module.servers.aws_instance.public_server must be replaced
-/+ resource "aws_instance" "public_server" {
      ~ ami                                  = "ami-0bae57ee7c4478e01" -> "ami-0d527370828225502" # forces replacement
      ~ arn                                  = "arn:aws:ec2:eu-central-1:798974632222:instance/i-08c86ea4747cc147e" -> (known after apply)
      ~ availability_zone                    = "eu-central-1a" -> (known after apply)
      ~ cpu_core_count                       = 1 -> (known after apply)
      ~ cpu_threads_per_core                 = 2 -> (known after apply)
      ~ disable_api_stop                     = false -> (known after apply)
      ~ disable_api_termination              = false -> (known after apply)
      ~ ebs_optimized                        = true -> (known after apply)
      + enable_primary_ipv6                  = (known after apply)
      - hibernation                          = false -> null
      + host_id                              = (known after apply)
      + host_resource_group_arn              = (known after apply)
      + iam_instance_profile                 = (known after apply)
      ~ id                                   = "i-08c86ea4747cc147e" -> (known after apply)
      ~ instance_initiated_shutdown_behavior = "stop" -> (known after apply)
      + instance_lifecycle                   = (known after apply)
      ~ instance_state                       = "running" -> (known after apply)
      ~ instance_type                        = "t3.micro" -> "t2.micro"
      ~ ipv6_address_count                   = 0 -> (known after apply)
      ~ ipv6_addresses                       = [] -> (known after apply)
      ~ key_name                             = "terraform-key" -> (known after apply)
      ~ monitoring                           = false -> (known after apply)
      + outpost_arn                          = (known after apply)
      + password_data                        = (known after apply)
      + placement_group                      = (known after apply)
      ~ placement_partition_number           = 0 -> (known after apply)
      ~ primary_network_interface_id         = "eni-0482a114b9be65a2d" -> (known after apply)
      ~ private_dns                          = "ip-10-10-1-10.eu-central-1.compute.internal" -> (known after apply)
      ~ private_ip                           = "10.10.1.10" -> (known after apply)
      + public_dns                           = (known after apply)
      ~ public_ip                            = "35.158.123.76" -> (known after apply)
      ~ secondary_private_ips                = [] -> (known after apply)
      ~ security_groups                      = [] -> (known after apply)
      + spot_instance_request_id             = (known after apply)
        tags                                 = {
            "Name" = "rostok-imported-stack-Public-Server"
        }
      ~ tenancy                              = "default" -> (known after apply)
      + user_data                            = (known after apply)
      + user_data_base64                     = (known after apply)
      + user_data_replace_on_change          = false
      ~ vpc_security_group_ids               = [
          - "sg-0ff33538aff4f858c",
        ] -> (known after apply)
        # (5 unchanged attributes hidden)

      ~ capacity_reservation_specification (known after apply)
      - capacity_reservation_specification {
          - capacity_reservation_preference = "open" -> null
        }

      ~ cpu_options (known after apply)
      - cpu_options {
          - core_count       = 1 -> null
          - threads_per_core = 2 -> null
            # (1 unchanged attribute hidden)
        }

      - credit_specification {
          - cpu_credits = "unlimited" -> null
        }

      ~ ebs_block_device (known after apply)

      ~ enclave_options (known after apply)
      - enclave_options {
          - enabled = false -> null
        }

      ~ ephemeral_block_device (known after apply)

      ~ instance_market_options (known after apply)

      ~ maintenance_options (known after apply)
      - maintenance_options {
          - auto_recovery = "default" -> null
        }

      ~ metadata_options (known after apply)
      - metadata_options {
          - http_endpoint               = "enabled" -> null
          - http_protocol_ipv6          = "disabled" -> null
          - http_put_response_hop_limit = 2 -> null
          - http_tokens                 = "required" -> null
          - instance_metadata_tags      = "disabled" -> null
        }

      ~ network_interface (known after apply)

      ~ private_dns_name_options (known after apply)
      - private_dns_name_options {
          - enable_resource_name_dns_a_record    = false -> null
          - enable_resource_name_dns_aaaa_record = false -> null
          - hostname_type                        = "ip-name" -> null
        }

      ~ root_block_device (known after apply)
      - root_block_device {
          - delete_on_termination = true -> null
          - device_name           = "/dev/xvda" -> null
          - encrypted             = false -> null
          - iops                  = 3000 -> null
          - tags                  = {} -> null
          - tags_all              = {} -> null
          - throughput            = 125 -> null
          - volume_id             = "vol-06b2937ae711f7601" -> null
          - volume_size           = 8 -> null
          - volume_type           = "gp3" -> null
            # (1 unchanged attribute hidden)
        }
    }

  # module.subnets.aws_subnet.public will be updated in-place
  ~ resource "aws_subnet" "public" {
        id                                             = "subnet-0dbff548ec84ee6b3"
      ~ map_public_ip_on_launch                        = false -> true
        tags                                           = {
            "Name" = "rostok-imported-stack-Public-Subnet"
        }
        # (19 unchanged attributes hidden)
    }

Plan: 2 to add, 2 to change, 2 to destroy.
```