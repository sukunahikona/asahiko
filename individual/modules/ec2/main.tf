# AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

# security group
resource "aws_security_group" "sg-batch" {
  name        = "${var.infra-basic-settings.name}-batch-sg"
  description = "For EC2 Linux"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.infra-basic-settings.name}-batch-sg"
  }

  # inbound rule
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# key pair
# Algorithm
resource "tls_private_key" "batch" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# Key Pair
resource "aws_key_pair" "batch" {
  key_name   = "${var.infra-basic-settings.name}-batch"
  public_key = tls_private_key.batch.public_key_openssh

  tags = {
    Name = "${var.infra-basic-settings.name}-batch"
  }
}

# File Output
resource "local_sensitive_file" "keypair_pem_batch" {
    filename = "${path.module}/${var.infra-basic-settings.name}-batch.pem"
    content = tls_private_key.batch.private_key_pem
    file_permission = "0600" # add execute permission
}

resource "local_sensitive_file" "keypair_pub_batch" {
    filename = "${path.module}/${var.infra-basic-settings.name}-batch.pub"
    content = tls_private_key.batch.public_key_openssh
}


# ec2
resource "aws_instance" "batch" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t1.micro"
  availability_zone           = "ap-northeast-1a"
  vpc_security_group_ids      = [aws_security_group.sg-batch.id]
  #subnet_id                   = var.private_subnet_ids[0]
  subnet_id                   = var.private_subnet_id_map["ap-northeast-1a"]
  associate_public_ip_address = "true"
  key_name                    = aws_key_pair.batch.key_name
  user_data                   = file("${path.module}/script.sh")
  tags = {
    Name = "${var.infra-basic-settings.name}-ec2-batch"
  }
}
