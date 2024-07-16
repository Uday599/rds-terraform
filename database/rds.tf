data "aws_secretsmanager_secret" "db_password" {
 name = "dev/mysql/password"
}

data "aws_secretsmanager_secret_version" "db_password_version" {
 secret_id = data.aws_secretsmanager_secret.db_password.id
}

resource "aws_db_subnet_group" "default" {
  name        = "default_subnet_group"
  description = "The default subnet group for all DBs in this architecture"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]

  tags = {
    env = "Dev"
  }
}

resource "aws_db_parameter_group" "log_db_parameter" {
  name   = "logs"
  family = "postgres16"

  parameter {
    value = "1"
    name  = "log_connections"
  }

  tags = {
    env = "Dev"
  }
}

## Creating RDS Instance

resource "aws_db_instance" "db1" {
  
  skip_final_snapshot     = true
  publicly_accessible     = false
  username                = var.db_username
  password                = data.aws_secretsmanager_secret_version.db_password_version.secret_string
  parameter_group_name    = aws_db_parameter_group.log_db_parameter.name
  instance_class          = "db.t3.micro"
  engine_version          = "5.7"
  db_name                 = "mysql"
  engine                  = "mysql"
  db_subnet_group_name    = aws_db_subnet_group.default.name
  backup_retention_period = 1
  allocated_storage       = 50  # allocated 50Gb
  multi_az                = true

  tags = {
    env = "Dev"
  }

  vpc_security_group_ids = [
    aws_security_group.sg.id
  ]
}

resource "aws_security_group" "sg" {
  name        = "db_sg"
  description = "Default sg for the database"
  vpc_id      = aws_vpc.amc-vpc.id

  tags = {
    Name = "db_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.sg.id
  referenced_security_group_id        = aws_security_group.ec2_sg.id
  from_port                = 5432
  ip_protocol              = "tcp"
  to_port                  = 5432
}

resource "aws_vpc_security_group_egress_rule" "allow_tls_eg" {
  security_group_id = aws_security_group.ec2_sg.id
  referenced_security_group_id        = aws_security_group.ec2_sg.id
  from_port   = 0
  ip_protocol = "tcp"
  to_port     = 65535
}

resource "aws_db_instance" "db_replica" {
  skip_final_snapshot     = true
  replicate_source_db     = aws_db_instance.db1.identifier
  publicly_accessible     = false
  parameter_group_name    = aws_db_parameter_group.log_db_parameter.name
  instance_class          = "db.t3.micro"
  identifier              = "db-replica"
  backup_retention_period = 7
  apply_immediately       = true

  tags = {
    replica = "true"
    env     = "Dev"
  }

  vpc_security_group_ids = [
    aws_security_group.sg.id,
  ]
}