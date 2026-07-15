# Optional managed MySQL — default OFF (enable_rds=false) so the default
# plan costs $0 extra. See .claude/levels/level-17-rds-optional.md.
#
# Tradeoff: the in-cluster MySQL StatefulSet (charts/travellog, on the data
# node group) is free but you manage backups/patching yourself
# (scripts/backup_mysql_to_s3.sh already does the backup half). RDS costs
# ~$0.03+/hr for db.t3.small but adds automated backups, patching, and
# Multi-AZ failover (if later upgraded). Requires a subnet group spanning 2
# AZs even though the instance itself is single-AZ.
#
# To try it: terraform apply -var enable_rds=true, verify, then
# terraform apply -var enable_rds=false to destroy it — never leave it on.

locals {
  # RDS only makes sense alongside EKS now (no EC2 host to talk to it
  # otherwise); enforced via variable validation below, this local just
  # keeps every count expression in this file consistent with that.
  rds_on = var.enable_rds && var.enable_eks ? 1 : 0
}

resource "aws_db_subnet_group" "main" {
  count      = local.rds_on
  name       = "travellog-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = {
    Name = "travellog-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  count       = local.rds_on
  name        = "travellog-rds"
  description = "RDS MySQL: only from the EKS cluster (nodes/pods)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EKS nodes/pods"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "travellog-rds"
  }
}

resource "aws_db_instance" "mysql" {
  count      = local.rds_on
  identifier = "travellog-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.rds_instance_class

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.mysql_database
  username = var.mysql_user
  password = var.mysql_password

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false
  multi_az               = false

  skip_final_snapshot = true # drill/practice environment — not for real prod data
  deletion_protection = false

  tags = {
    Name = "travellog-mysql"
  }
}
