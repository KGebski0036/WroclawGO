resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = { Project = var.project_name }
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Security group for backend EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow inbound HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound traffic"
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

resource "aws_iam_role" "backend_instance_role" {
  name = "${var.project_name}-backend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "backend_runtime_policy" {
  name = "${var.project_name}-backend-runtime-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.django_secret_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.media.arn,
          "${aws_s3_bucket.media.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_runtime_attach" {
  role       = aws_iam_role.backend_instance_role.name
  policy_arn = aws_iam_policy.backend_runtime_policy.arn
}

resource "aws_iam_role_policy_attachment" "backend_ecr_readonly_attach" {
  role       = aws_iam_role.backend_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "backend_ssm_attach" {
  role       = aws_iam_role.backend_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-instance-profile"
  role = aws_iam_role.backend_instance_role.name
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = var.backend_instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.backend.id]
  iam_instance_profile        = aws_iam_instance_profile.backend.name
  associate_public_ip_address = true
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/ec2_user_data.sh.tftpl", {
    aws_region             = var.aws_region
    db_host                = module.db.db_instance_address
    db_port                = tostring(module.db.db_instance_port)
    db_name                = var.db_name
    db_username            = var.db_username
    db_password_secret_arn = aws_secretsmanager_secret.db_password.arn
    django_secret_arn      = aws_secretsmanager_secret.django_secret_key.arn
    ecr_repo_url           = aws_ecr_repository.backend.repository_url
    image_tag              = var.backend_image_tag
    frontend_origin        = module.s3.website_url
  })

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-backend"
    Project = var.project_name
  }

  depends_on = [module.db]
}
