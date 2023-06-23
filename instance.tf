# Provider configuration (adjust the AWS region)
provider "aws" {
  region = "us-west-2"
}

resource "aws_key_pair" "mykey" {
  key_name   = "mykey"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

# Variables
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_web_cidr" {
  default = "10.0.1.0/24"
}
variable "subnet_web1_cidr" {
  default = "10.0.4.0/24"
}
variable "subnet_app_cidr" {
  default = "10.0.2.0/24"
}

variable "subnet_db_cidr" {
  default = "10.0.3.0/24"
}

variable "instance_type" {
  default = "t2.micro"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "subnet_web" {
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "us-west-2a"
  cidr_block = var.subnet_web_cidr
}
resource "aws_subnet" "subnet_web1" {
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "us-west-2b"
  cidr_block = var.subnet_web1_cidr
}  
resource "aws_subnet" "subnet_app" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.subnet_app_cidr
}

resource "aws_subnet" "subnet_db" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.subnet_db_cidr
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.my_vpc.id

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

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.my_vpc.id

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
}

# EC2 Instances
resource "aws_instance" "web_instance" {
  count         = 2
  ami = "ami-07dfed28fcf95241c"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.subnet_web.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = aws_key_pair.mykey.key_name
  tags = {
    Name = "Web Instance ${count.index + 1}"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

resource "aws_instance" "app_instance" {
  count         = 2
  ami = "ami-07dfed28fcf95241c"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.subnet_app.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "App Instance ${count.index + 1}"
  }
}

resource "aws_instance" "db_instance" {
  ami = "ami-07dfed28fcf95241c"
  instance_type = var.instance_type
  subnet_id     = aws_subnet.subnet_db.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "DB Instance"
  }
}

# Application Load Balancer
resource "aws_lb" "application_lb" {
  name               = "hello-world-alb"
  internal           = true
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_web.id, aws_subnet.subnet_web1.id]

  # Add any additional configuration for your ALB
}

# CloudWatch monitoring
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "web-instance-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric checks the CPU utilization of the web instances"
  alarm_actions       = [] # Add actions to be taken when the alarm state is triggered
  dimensions = {
    InstanceId = aws_instance.web_instance.*.id[0]
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  name                 = "web-asg"
  min_size             = 2
  max_size             = 5
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.subnet_web.id]
  launch_configuration = aws_launch_configuration.web_lc.name
  target_group_arns    = [aws_lb_target_group.web_tg.arn]

}

# Launch Configuration
resource "aws_launch_configuration" "web_lc" {
  name_prefix          = "web-lc"
  image_id             = "ami-07dfed28fcf95241c" # Replace with the desired AMI ID
  instance_type        = var.instance_type
  security_groups      = [aws_security_group.ec2_sg.id]

}

# Target Group
resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
}

# AWS Backup
resource "aws_backup_vault" "backup_vault" {
  name        = "hello-world-backup-vault"
  kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab" # Replace with your KMS Key ARN
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Lambda Function
resource "aws_lambda_function" "stop_start_instances" {
  filename         = "lambda_function.zip"
  function_name    = "stop_start_instances"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handleri"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_iam_role_policy_attachment" "lambda_role_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create an IAM role for the application
resource "aws_iam_role" "hello_world_role" {
  name = "HelloWorldRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AD_OR_AZURE_AD_PROVIDER_ARN>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "<AD_OR_AZURE_AD_PROVIDER_ARN>:aud": "<PROVIDER_AUDIENCE>"
        }
      }
    }
  ]
}
EOF
}

# Attach necessary IAM policies to the role
resource "aws_iam_role_policy_attachment" "hello_world_policy_attachment" {
  role       = aws_iam_role.hello_world_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" # Example policy
}

# Output the IAM role ARN
output "role_arn" {
  value = aws_iam_role.hello_world_role.arn
}

