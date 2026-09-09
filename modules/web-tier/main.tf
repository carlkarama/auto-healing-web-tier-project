locals {
  prefix = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
data "aws_ec2_managed_prefix_list" "cloudfront_ipv6" {
  name = "com.amazonaws.global.ipv6.cloudfront.origin-facing"
}
resource "aws_security_group" "web" {
  name        = "${local.prefix}-web-sg"
  description = "NGINX origins reachable only from CloudFront over IPv6"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.prefix}-web-sg" }
}
resource "aws_vpc_security_group_ingress_rule" "cloudfront_http" {
  security_group_id = aws_security_group.web.id
  description       = "CloudFront IPv6 origin connections"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_ipv6.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
resource "aws_vpc_security_group_ingress_rule" "ipv6_packet_too_big" {
  security_group_id = aws_security_group.web.id
  description       = "IPv6 path MTU discovery"
  cidr_ipv6         = "::/0"
  from_port         = 2
  to_port           = 0
  ip_protocol       = "icmpv6"
}
resource "aws_vpc_security_group_egress_rule" "ipv6" {
  security_group_id = aws_security_group.web.id
  description       = "IPv6 package downloads and response traffic"
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}
# AWS Cloud Control exposes public IPv6 DNS settings absent from aws_network_interface.
# The ENI, its address and its DNS name outlive the replaceable VM.
resource "awscc_ec2_network_interface" "web" {
  for_each                                  = var.subnets
  subnet_id                                 = each.value.id
  description                               = "${local.prefix} stable web slot ${each.key}"
  group_set                                 = [aws_security_group.web.id]
  ipv_6_address_count                       = 1
  enable_primary_ipv_6                      = true
  public_ip_dns_hostname_type_specification = "public-ipv6-dns-name"
  tags = [
    for k, v in merge(local.tags, { Name = "${local.prefix}-web-${each.key}-eni" }) :
    { key = k, value = v }
  ]
}
resource "aws_launch_template" "web" {
  for_each      = var.subnets
  name_prefix   = "${local.prefix}-${each.key}-"
  description   = "Replacement VM for stable web slot ${each.key}"
  image_id      = var.ami_id
  instance_type = "t4g.nano"
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    container_image = var.container_image
  }))
  network_interfaces {
    device_index          = 0
    network_interface_id  = awscc_ec2_network_interface.web[each.key].id
    delete_on_termination = false
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 8
      encrypted             = true
      delete_on_termination = true
    }
  }
  credit_specification {
    cpu_credits = "standard"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${local.prefix}-web-${each.key}"
      Slot = each.key
    })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, { Name = "${local.prefix}-web-${each.key}-root" })
  }
  tags = { Name = "${local.prefix}-web-${each.key}-lt" }
}
# An existing primary ENI requires one instance per group and availability_zones,
# rather than vpc_zone_identifier. Together the two groups maintain two VMs.
resource "aws_autoscaling_group" "web" {
  for_each           = var.subnets
  name               = "${local.prefix}-web-${each.key}-asg"
  min_size           = 1
  desired_capacity   = 1
  max_size           = 1
  availability_zones = [each.value.availability_zone]
  health_check_type  = "EC2"
  launch_template {
    id      = aws_launch_template.web[each.key].id
    version = aws_launch_template.web[each.key].latest_version
  }
  # The old instance must release its ENI before a replacement can attach it.
  instance_maintenance_policy {
    min_healthy_percentage = 0
    max_healthy_percentage = 100
  }
  dynamic "tag" {
    for_each = merge(local.tags, { Name = "${local.prefix}-web-${each.key}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  depends_on = [aws_vpc_security_group_egress_rule.ipv6]
}
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}
resource "aws_cloudfront_function" "balance" {
  name    = "${local.prefix}-balance"
  runtime = "cloudfront-js-2.0"
  comment = "Balance static requests and retry the other VM on failure"
  publish = true
  code    = file("${path.module}/balance.js")
}
resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.prefix} two-VM web tier"
  wait_for_deployment = true
  dynamic "origin" {
    for_each = var.subnets
    content {
      origin_id           = "web-${origin.key}"
      domain_name         = awscc_ec2_network_interface.web[origin.key].public_ip_dns_name_options.public_ipv_6_dns_name
      connection_attempts = 1
      connection_timeout  = 2
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
        ip_address_type        = "ipv6"
        origin_read_timeout    = 3
      }
    }
  }
  origin_group {
    origin_id = "web-origins"
    failover_criteria {
      status_codes = [500, 502, 503, 504]
    }
    member {
      origin_id = "web-a"
    }
    member {
      origin_id = "web-b"
    }
  }
  default_cache_behavior {
    target_origin_id       = "web-origins"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    compress               = true
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.balance.arn
    }
  }
  # Avoid caching transient origin errors.
  dynamic "custom_error_response" {
    for_each = toset([500, 502, 503, 504])
    content {
      error_code            = custom_error_response.value
      error_caching_min_ttl = 0
    }
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = { Name = "${local.prefix}-edge" }
}
