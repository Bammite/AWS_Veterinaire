# EC2 Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-template-"
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  # Enforce encrypted EBS volume for security best practices
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = aws_kms_key.main.arn
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/scripts/user_data.sh", {
    bucket_name       = aws_s3_bucket.deploy.id
    db_secret_id      = aws_secretsmanager_secret.db_secret.name
    db_proxy_endpoint = aws_db_instance.db.address
    db_name           = "petclinic"
    aws_region        = var.aws_region
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name_prefix         = "${local.name_prefix}-asg-"
  vpc_zone_identifier = aws_subnet.private_app[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  force_delete        = true

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Tags are propagated to EC2 instances automatically
  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [
    aws_s3_object.app_jar
  ]
}

# Auto Scaling Target Tracking Policy based on CPU Utilization
resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "${local.name_prefix}-cpu-scaling-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
