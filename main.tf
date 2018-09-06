####### Providers ######
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

#####################
######## Resources
#####################

#Networking

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = "beto-demo-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.50.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "beto-demo"
  }
}

########### LOAD BALANCER #

resource "aws_elb" "web" {
  name = "demo-nginx-elb"

  subnets         = ["${element(module.vpc.public_subnets, 0)}"]  
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.nginx1.id}", "${aws_instance.nginx2.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

# Instances SG #

resource "aws_security_group" "nginx-sg" {
  name   = "demo-nginx_sg"
  vpc_id = "${module.vpc.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "demo-ec2-sg"
    Environment = "demo-env"
  }

}

# ELB SG #
resource "aws_security_group" "elb-sg" {
  name   = "beto_nginx_elb_sg"
  vpc_id = "${module.vpc.vpc_id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "elb-sg"
    Environment = "demo-env"
  }
}

# INSTANCES #
resource "aws_instance" "nginx1" {
  ami                    = "ami-0ff8a91507f77f867"
  instance_type          = "t2.large"
  subnet_id              = "${element(module.vpc.public_subnets, 0)}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user = "ec2-user"
    private_key = "${file("${var.private_key_path}/${var.key_name}")}"
  }

  tags {
    Name = "tf-demo-nginx1"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Blue Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Blue Terraform demo</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html",
   ]
  }
}

resource "aws_instance" "nginx2" {
  ami                    = "ami-0ff8a91507f77f867"
  instance_type          = "t2.large"
  subnet_id              = "${element(module.vpc.public_subnets, 0)}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  key_name               = "${var.key_name}"

  connection {
    user = "ec2-user"
    private_key = "${file("${var.private_key_path}/${var.key_name}")}"
  }

  tags {
    Name = "tf-demo-nginx2"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "echo '<html><head><title>Green Team Server</title></head><body style=\"background-color:#77A032\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Green Terraform demo</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html",
    ]
  }
}

