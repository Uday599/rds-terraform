module "secrets_manager" {
  source      = "./secrets_manager"
  db_password = var.db_password
}

module "rds_database" {
  source      = "./database"
  db_username = var.db_username
}

