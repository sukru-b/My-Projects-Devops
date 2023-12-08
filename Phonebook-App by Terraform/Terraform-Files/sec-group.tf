resource "aws_security_group" "alb-sg" {
  name        = "ALB-SecurityGroup"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}



resource "aws_security_group" "server-sg" {
  name   = "WebServer-SecurityGroup"
  vpc_id = data.aws_vpc.default-vpc.id
  tags = {
    name = "ServerSecurityGroup-by-Terraform"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id] # not all 80, only 80 from ALB
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


resource "aws_security_group" "rds-sg" {
  name   = "RDS-SecurityGroup"
  vpc_id = data.aws_vpc.default-vpc.id
  tags = {
    name = "RDSSecurityGroup-by-Terraform"
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.server-sg.id] # only 3306 from Servers
  }


  egress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.server-sg.id]
  }

}
