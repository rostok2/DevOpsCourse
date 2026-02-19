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