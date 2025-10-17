terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  backend "s3" {
    bucket = "lacrei-terraform-state"
    key    = "lacrei-devops/terraform.tfstate"
    region = "sa-east-1"
  }
}

provider "aws" {
  region = var.region
}

############################
# Networking (VPC + Subnets públicas)
############################

resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { 
    Name = "${var.project_name}-${var.environment}-vpc" 
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project_name}-igw" }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags                    = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.20.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags                    = { Name = "${var.project_name}-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.project_name}-rt-public" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

############################
# Security Groups
############################

# ALB SG: 80 e 443 abertos
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # saída liberada (pull de imagem, updates)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# EC2 SG: recebe somente do ALB na porta da aplicação
resource "aws_security_group" "ecs_instances_sg" {
  name        = "${var.project_name}-ecs-instances-sg"
  description = "ECS EC2 instances SG"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-instances-sg" }
}

############################
# ECR (repositório privado)
############################

resource "aws_ecr_repository" "repo" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project_name}-ecr" }
}

############################
# IAM para ECS on EC2
############################

# Role para EC2 executar o agente ECS
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecsInstanceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

############################
# ECS Cluster
############################

resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

############################
# Launch Template + ASG (EC2)
############################

data "aws_ami" "ecs_amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "image-id"
    values = [var.ecs_ami_id]
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${var.project_name}-ecs-lt-"
  image_id      = data.aws_ami.ecs_amazon_linux2.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "ECS_CLUSTER=${aws_ecs_cluster.this.name}" >> /etc/ecs/ecs.config
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-ecs-ec2" }
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "${var.project_name}-ecs-asg"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  health_check_type   = "EC2"
  force_delete        = true

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-ec2"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################
# ALB + Target Group + Listeners
############################

resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags = { Name = "${var.project_name}-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  health_check {
    path                = "/status"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
  tags = { Name = "${var.project_name}-tg" }
}

# HTTP 80 -> redirect 443
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Certificado ACM com validação DNS (ativado somente se domain_name e hosted_zone_id preenchidos)
resource "aws_acm_certificate" "cert" {
  count             = length(var.domain_name) > 0 ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "cert_validation" {
  count   = length(var.domain_name) > 0 ? 1 : 0
  name    = lookup(element(aws_acm_certificate.cert[0].domain_validation_options, 0), "resource_record_name")
  type    = lookup(element(aws_acm_certificate.cert[0].domain_validation_options, 0), "resource_record_type")
  zone_id = var.hosted_zone_id
  records = [lookup(element(aws_acm_certificate.cert[0].domain_validation_options, 0), "resource_record_value")]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = length(var.domain_name) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [aws_route53_record.cert_validation[0].fqdn]
}

resource "aws_lb_listener" "https" {
  count             = length(var.domain_name) > 0 ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation[0].certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

############################
# ECS Task Definition + Service
############################

# Role de execução ECS Task (pull ECR + logs CloudWatch)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-app"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-container",
      image     = var.container_image,
      essential = true,
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }],
      environment = [
        { "name": "NODE_ENV", "value": "staging" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs"
        }
      },
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/status || exit 1"],
        interval    = 30,
        timeout     = 5,
        retries     = 3,
        startPeriod = 10
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.app
  ]

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
}

############################
# Outputs
############################

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.repo.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}
