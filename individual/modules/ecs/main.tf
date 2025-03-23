# sg
resource "aws_security_group" "sg_ecs" {
  name        = "${var.infra-basic-settings.name}-ecs-sg"
  description = "For ECS"
  vpc_id      = var.vpc_id
  # アウトバウンドルール
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.infra-basic-settings.name}-ecs-sg"
  }
}

resource "aws_security_group_rule" "ecs_http80" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_ecs.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ecs_https" {
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.sg_ecs.id
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

# iam_role
resource "aws_iam_role" "ecs_deploy" {
  name = "ecs_deploy_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      },
    ]
  })
  
  inline_policy {
    name = "allow_logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents",
          ],
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_iam_policy" "ecs_deploy_policy" {
  name = "ecs_deploy_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "attach" {
  name       = "iam-attach"
  roles      = ["${aws_iam_role.ecs_deploy.name}"]
  policy_arn = aws_iam_policy.ecs_deploy_policy.arn
}

# log_group
resource "aws_cloudwatch_log_group" "app" {
  name = "${var.infra-basic-settings.name}-log-app-group"
}
resource "aws_cloudwatch_log_group" "web" {
  name = "${var.infra-basic-settings.name}-log-web-group"
}

# ecs_cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.infra-basic-settings.name}-ecs-cluster"

  tags = {
    Name = "${var.infra-basic-settings.name}-ecs-cluster"
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# task_definition
data "template_file" "task-def-app" {
  template = "${file("${path.module}/task_defs/task_def_app.json")}"

  vars = {
    rds-endpoint = "${var.aws_rds_endpoint}"
    log-group = aws_cloudwatch_log_group.app.name
    image-url = "${var.aws_ecr_repository_main_repository_url}:latest"
    rds-user = "${var.rds_user_name}"
    rds-password = "${var.rds_password}"
  }
}
data "template_file" "task-def-web" {
  template = "${file("${path.module}/task_defs/task_def_web.json")}"

  vars = {
    log-group = aws_cloudwatch_log_group.web.name
    image-url = "${var.aws_ecr_repository_web_repository_url}:latest"
  }
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.infra-basic-settings.name}-app-def"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_deploy.arn
  task_role_arn            = aws_iam_role.ecs_deploy.arn

  container_definitions = "[${data.template_file.task-def-app.rendered},${data.template_file.task-def-web.rendered}]"
}  

# ecs_service
resource "aws_ecs_service" "main" {
  name                = "${var.infra-basic-settings.name}-service"
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.main.arn
  desired_count       = 3
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  propagate_tags = "SERVICE"

  network_configuration {
    security_groups = [aws_security_group.sg_ecs.id]
    subnets = var.private_subnet_ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_tg_main_arn
    container_name   = "web"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS" # Default Setting
    #type = "CODE_DEPLOY"
  }
}
resource "aws_lb_listener_rule" "main" {
  listener_arn = var.aws_lb_listener_https_arn
  priority     = 50000
  action {
    type             = "forward"
    target_group_arn = var.alb_tg_main_arn
  }
  condition {
    path_pattern { values = ["/*"] }
  }
}