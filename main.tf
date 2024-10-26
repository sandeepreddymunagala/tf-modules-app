terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}
resource "aws_iam_policy" "policy" {
  name        = "${var.component}-${var.env}-ssm-pm-policy"
  path        = "/"
  description = "${var.component}-${var.env}-ssm-pm-policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameterHistory",
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource": [
          "arn:aws:ssm:us-east-1:339712793158:parameter/roboshop.${var.env}.${var.component}.*",
        ]
      }
    ]
  })
}

resource "aws_iam_role" "role" {
  name = "${var.component}-${var.env}-ec2-role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.component}-${var.env}-ec2-role"
  role = aws_iam_role.role.name
}
resource "aws_iam_role_policy_attachment" "policy-attach" {
  role = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}
resource "aws_security_group" "sg" {
  name = "${var.component}-${var.env}-sg"
  description = "${var.component}-${var.env}-sg"

  ingress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name ="${var.component}-${var.env}-sg"}
}

resource "aws_instance" "instance" {
  ami = data.aws_ami.ami.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  tags = {
    Name = "${var.component}-${var.env}-sg"
  }
}

resource "aws_route53_record" "dns" {
  name    = "${var.component}-dev"
  type    = "A"
  zone_id = "Z000681610YP12S51X5A5"
  ttl = 30
  records = [aws_instance.instance.private_ip]
}
resource "null_resource" "ansible" {
  depends_on = [aws_instance.instance,aws_route53_record.dns]
  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "centos"
      password = "DevOps321"
      host = aws_instance.instance.public_ip
    }

    inline =[
    "sudo labauto ansible",
      "ansible-pull -i localhost -U https://github.com/sandeepreddymunagala/roboshop-ansible main.yml -e env=${var.env} -e role_name=${var.component}"
    ]
  }
}