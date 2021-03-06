terraform {
  /* 
  backend "remote" {
    organization = "Landmark25"

    workspaces {
      name = "provisioners"
    }
  } */

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.64.2"
    }
  }
}

provider "aws" {
  # Configuration options
  profile = "default"
  region  = "us-east-2"
}


data "aws_vpc" "main" {
  id = var.vpc_id
}

data "template_file" "userdata" {

  template = file("./userdata.yaml")

}
resource "aws_security_group" "myserver_SG" {
  name        = "myserver_SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.main.id

  ingress = [
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
  ]

  egress = [
    {
      description      = "Outgoing Traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = {
    Name = "allow_HTTP"
  }
}

resource "aws_key_pair" "development_key" {
  key_name   = "development_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCydfnUREx9zx54e3lQQZokZ6gnKcsfhVh60rS6X4pnOABSOx3Hd1MLM0SdQP5QrsnfvhvMupQkmEWAYKNGh2g72M2HGv1dwB3o18QLPc0ViA59jgM4/UUdRRiUgwnlmEnQ57g3xkk8lzNsvE5j2U+Xi/eudm60/ARtcrM6ZWN8pdLz6BY76IaTuroqcxxWpsr5KOsyEvyY3m0Thkx4b1qFsrbF6ntKK3yVqoBLjSGP2RD2zYeJXeoo+kXOAAd3gzIL1LXTZ8Sv4gltsczLyKj9e8SpxWrKmCOPPN4dKbvGSeZs+FAGiLhQRkrLWFPeQ8yNZCRk3NG7aOtcm51f7T7TWidmnq+y+wro740jWpApN5l5jzmaAglDMQjzTeOUXHpbjtvYiR5eD6fUQvnx4+noqfZ/aW8QEThA3PnppqljR6k8ugo0IYjCvfGvU/BMrNA37/MCCZ+C/meUyBFMFI5ocsyzbAqlQLtTrDMYp3KY1J1QnlO+CRjSp/lyt+Hw1oM= kops@ip-172-31-21-93"
}

resource "aws_instance" "milua_server" {
  ami                    = "ami-0f19d220602031aed"
  instance_type          = var.instance_type
  key_name               = aws_key_pair.development_key.id
  vpc_security_group_ids = [aws_security_group.myserver_SG.id]
  user_data              = data.template_file.userdata.rendered

  /*
  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ips.txt"
  }
  */

  provisioner "remote-exec" {
    inline = [
      "echo ${self.private_ip} >> /home/ec2-user/private_ips.txt"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${file("~/.ssh/id_rsa")}"
      host        = "${self.public_ip}"
    }
  }

  tags = {
    Name        = "Milua-sever" # use of interpolation
    environment = "dev"
  }
}

output "public_ip_address" {
  value = aws_instance.milua_server.private_ip
}

output "private_ip_address" {
  value = aws_instance.milua_server.public_ip
}
