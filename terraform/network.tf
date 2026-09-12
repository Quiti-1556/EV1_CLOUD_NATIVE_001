resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${local.name}-public-${count.index}" }
}
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-app-${count.index}" }
}
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${local.name}-db-${count.index}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_eip" "nat" {
  count  = var.multi_az ? 2 : 1
  domain = "vpc"
}
resource "aws_nat_gateway" "main" {
  count         = var.multi_az ? 2 : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.main]
}
resource "aws_route_table" "app" {
  count  = 2
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.multi_az ? count.index : 0].id
  }
}
resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
}
resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}
resource "aws_security_group" "link" {
  name   = "${local.name}-link"
  vpc_id = aws_vpc.main.id
}
resource "aws_security_group" "alb" {
  name   = "${local.name}-alb"
  vpc_id = aws_vpc.main.id
}
resource "aws_security_group" "app" {
  name   = "${local.name}-app"
  vpc_id = aws_vpc.main.id
}
resource "aws_security_group" "db" {
  name   = "${local.name}-db"
  vpc_id = aws_vpc.main.id
}
resource "aws_security_group_rule" "link_out" {
  type                     = "egress"
  security_group_id        = aws_security_group.link.id
  source_security_group_id = aws_security_group.alb.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "alb_in" {
  type                     = "ingress"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.link.id
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "alb_out" {
  type                     = "egress"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "app_in" {
  type                     = "ingress"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "app_https" {
  type              = "egress"
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
}
resource "aws_security_group_rule" "app_db" {
  type                     = "egress"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.db.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
}
resource "aws_security_group_rule" "db_in" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
}
