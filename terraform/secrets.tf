resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "_-"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "random_password" "django_secret_key" {
  length           = 50
  special          = true
  override_special = "!@#$%^&*(-_=+)"
}

resource "aws_secretsmanager_secret" "django_secret_key" {
  name                    = "${var.project_name}-django-secret-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "django_secret_key" {
  secret_id     = aws_secretsmanager_secret.django_secret_key.id
  secret_string = random_password.django_secret_key.result
}
