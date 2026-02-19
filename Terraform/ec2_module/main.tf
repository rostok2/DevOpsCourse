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