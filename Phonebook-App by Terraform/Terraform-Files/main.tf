data "aws_vpc" "default-vpc" {
  default = true # chosing of default vpc
}

data "aws_subnets" "pb-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default-vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = ["default*"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}


resource "aws_launch_template" "asg-lt" {
  name                   = "phonebook-lt"
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = var.key-name
  vpc_security_group_ids = [aws_security_group.server-sg.id]
  user_data              = base64encode(templatefile("${path.module}/user-data.sh", { github-token = var.git-token, github-username = var.git-name }))
  depends_on             = [github_repository_file.dbendpoint]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Web Server of Phonebook App"
    }
  }
}

resource "aws_alb_target_group" "phonebook-tg" {
  name        = "phonebook-targetgroup"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default-vpc.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_alb" "phonebook-alb" {
  name               = "phonebook-ALB"
  ip_address_type    = "ipv4"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = data.aws_subnets.pb-subnets.ids
}

resource "aws_alb_listener" "phonebook-listener" {
  load_balancer_arn = aws_alb.phonebook-alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.phonebook-tg.arn
  }

}

resource "aws_autoscaling_group" "phonebook-asg" {
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  name                      = "phonebook-ASG"
  health_check_grace_period = 300
  health_check_type         = "ELB"
  target_group_arns         = [aws_alb_target_group.phonebook-tg.arn]
  vpc_zone_identifier       = aws_alb.phonebook-alb.subnets
  launch_template {
    id      = aws_launch_template.asg-lt.id
    version = aws_launch_template.asg-lt.latest_version
  }

}

resource "aws_db_instance" "phonebook-rds" {
  instance_class              = "db.t2.micro"
  allocated_storage           = 20
  vpc_security_group_ids      = [aws_security_group.rds-sg.id]
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = 0
  identifier                  = "phonebook-rds-database"
  db_name                     = "phonebook"
  engine                      = "mysql"
  engine_version              = "8.0.28"
  username                    = "admin"
  password                    = "Sukru1313"
  monitoring_interval         = 0
  multi_az                    = false
  port                        = 3306
  publicly_accessible         = false
  skip_final_snapshot         = true
}

resource "github_repository_file" "dbendpoint" {
  content             = aws_db_instance.phonebook-rds.address
  file                = "dbserver.endpoint"
  repository          = "phonebook"
  overwrite_on_create = true
  branch              = "main"
}

data "aws_route53_zone" "R53HZ" {
  name = var.hosted-zone

}

resource "aws_route53_record" "phonebook-route53" {
  zone_id = data.aws_route53_zone.R53HZ.zone_id
  name    = "phonebook.${var.hosted-zone}"
  type    = "A"

  alias {
    name                   = aws_alb.phonebook-alb.dns_name
    zone_id                = aws_alb.phonebook-alb.zone_id
    evaluate_target_health = true

  }

}