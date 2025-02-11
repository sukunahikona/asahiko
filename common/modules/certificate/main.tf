resource "aws_acm_certificate" "cert" {
  # *.domain certificate creating
  domain_name               = "*.${var.infra-basic-settings.name}.${var.infra-basic-settings.domain-name}"
  subject_alternative_names = [var.infra-basic-settings.domain-name]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.infra-basic-settings.name}-certificate"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name = each.value.name
  records = [each.value.record]
  type = each.value.type
  ttl = "300"

  # zone id
  zone_id = "${var.infra-basic-settings.zone-id}"
}