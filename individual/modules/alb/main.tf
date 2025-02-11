#sg
resource "aws_security_group" "alb_ingress_all" {
    name = "alb-ingress-all"
    description = "Allow TLS inbound traffic"
    vpc_id = var.vpc_id

    ingress {
        description = "Ingress 80"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Ingress https"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_lb" "main" {
  name               = "${var.infra-basic-settings.name}-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_ingress_all.id]
  subnets = var.public_subnet_ids
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "main" {
  name        = "${var.infra-basic-settings.name}-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  deregistration_delay = 60
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.cert_arn
  default_action {
    #type             = "forward"
    #target_group_arn = aws_lb_target_group.main.arn
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "503 Service Temporarily Unavailable [${var.infra-basic-settings.name}-service]"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
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

####################################################
# Route53 record for ALB
####################################################
resource "aws_route53_record" "a_record_for_app_subdomain" {
  name    = "alb.${var.infra-basic-settings.name}.${var.infra-basic-settings.domain-name}"
  type    = "A"
  zone_id = var.infra-basic-settings.zone-id
  alias {
    evaluate_target_health = true
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
  }
}
