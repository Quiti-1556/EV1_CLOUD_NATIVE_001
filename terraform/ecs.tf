resource "aws_ecr_repository" "backend" {
  name                 = "${local.name}-backend"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.environment == "prod" ? 90 : 14
}
locals {
  ecs_trust      = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  execution_role = var.existing_execution_role_arn != "" ? var.existing_execution_role_arn : aws_iam_role.execution[0].arn
  task_role      = var.existing_task_role_arn != "" ? var.existing_task_role_arn : aws_iam_role.task[0].arn

  # Definición común: migration no depende del valor normalizado por AWS
  # de aws_ecs_task_definition.backend durante el mismo apply.
  ecs_container_base = {
    name                   = "backend"
    image                  = "${aws_ecr_repository.backend.repository_url}:bootstrap"
    essential              = true
    user                   = "65532:65532"
    readonlyRootFilesystem = true
    linuxParameters = {
      capabilities = {
        add  = []
        drop = ["ALL"]
      }
    }
    mountPoints = [{
      sourceVolume  = "tmp"
      containerPath = "/tmp"
      readOnly      = false
    }]
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]
    systemControls = []
    volumesFrom    = []
    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = "aws" },
      { name = "DB_URL", value = "jdbc:postgresql://${aws_db_instance.db.endpoint}/solicitudes?sslmode=verify-full&sslrootcert=/app/rds-ca.pem" },
      { name = "DB_USER", value = "solicitudes_app" },
      { name = "APP_IDENTITY_MODE", value = "gateway" }
    ]
    secrets = [{
      name      = "DB_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.app.arn}:password::"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "backend"
      }
    }
    stopTimeout = 30
  }
}
resource "aws_iam_role" "execution" {
  count              = var.existing_execution_role_arn == "" ? 1 : 0
  name               = "${local.name}-execution"
  assume_role_policy = local.ecs_trust
}
resource "aws_iam_role_policy" "execution" {
  count = var.existing_execution_role_arn == "" ? 1 : 0
  role  = aws_iam_role.execution[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
    { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"], Resource = aws_ecr_repository.backend.arn },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.backend.arn}:*" },
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [aws_db_instance.db.master_user_secret[0].secret_arn, aws_secretsmanager_secret.app.arn] }
  ] })
}
resource "aws_iam_role" "task" {
  count              = var.existing_task_role_arn == "" ? 1 : 0
  name               = "${local.name}-task"
  assume_role_policy = local.ecs_trust
}
resource "aws_ecs_cluster" "backend" {
  name = local.name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = local.execution_role
  task_role_arn            = local.task_role
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  # Plantilla, no se inicia: publicar-ecs.sh sustituye la imagen por digest ECR.
  container_definitions = jsonencode([local.ecs_container_base])
  volume {
    name = "tmp"
  }
}
resource "aws_ssm_parameter" "task_template" {
  name        = "/${local.name}/task-template"
  type        = "String"
  value       = aws_ecs_task_definition.backend.arn
  description = "Revision exacta administrada por Terraform; los scripts solo sustituyen la imagen."
}
resource "aws_lb" "backend" {
  name                       = local.name
  internal                   = true
  load_balancer_type         = "application"
  subnets                    = aws_subnet.app[*].id
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection
}
resource "aws_lb_target_group" "backend" {
  name                 = local.name
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip"
  deregistration_delay = 30
  health_check {
    path                = "/actuator/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
resource "aws_ecs_service" "backend" {
  name                               = "${local.name}-backend"
  cluster                            = aws_ecs_cluster.backend.id
  task_definition                    = aws_ecs_task_definition.backend.arn
  desired_count                      = 0
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = 120
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = aws_subnet.app[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 8080
  }
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
  depends_on = [aws_lb_listener.backend, aws_iam_role_policy.execution]
}

resource "aws_ecs_task_definition" "migration" {
  family                   = "${local.name}-migration"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = local.execution_role
  task_role_arn            = local.task_role
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([merge(local.ecs_container_base, {
    environment = concat([
      for item in local.ecs_container_base.environment : item
      if !contains(["SPRING_PROFILES_ACTIVE", "DB_USER"], item.name)
      ], [
      { name = "SPRING_PROFILES_ACTIVE", value = "aws-migrate" },
      { name = "DB_USER", value = aws_db_instance.db.username }
    ])
    secrets = [
      { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.db.master_user_secret[0].secret_arn}:password::" },
      { name = "APP_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.app.arn}:password::" }
    ]
  })])
  volume {
    name = "tmp"
  }
}
resource "aws_ssm_parameter" "migration_template" {
  name  = "/${local.name}/migration-template"
  type  = "String"
  value = aws_ecs_task_definition.migration.arn
}
