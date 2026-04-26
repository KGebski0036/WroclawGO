resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL access only from App Runner and admin CIDR"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Admin access - restrict admin_cidr to your IP in production"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description     = "Allow inbound PostgreSQL from backend EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.9"

  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  family            = "postgres15"

  create_db_subnet_group = true
  db_subnet_group_name   = "${var.project_name}-subnet-group"

  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  create_random_password = false

  subnet_ids             = module.vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = false
  skip_final_snapshot = true

  tags = { Project = var.project_name }
}
