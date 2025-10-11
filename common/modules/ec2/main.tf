# AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }
}

# security group
resource "aws_security_group" "sg-board" {
  name        = "${var.infra-basic-settings.name}-board-sg"
  description = "For EC2 Linux"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.infra-basic-settings.name}-board-sg"
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
resource "tls_private_key" "main" {
    algorithm = "RSA"
    rsa_bits = 4096
}

# Key Pair
resource "aws_key_pair" "board" {
  key_name   = "${var.infra-basic-settings.name}-board"
  public_key = tls_private_key.main.public_key_openssh

  tags = {
    Name = "${var.infra-basic-settings.name}-board"
  }
}

# File Output
resource "local_sensitive_file" "keypair_pem" {
    filename = "${path.module}/${var.infra-basic-settings.name}-board.pem"
    content = tls_private_key.main.private_key_pem
    file_permission = "0600" # add execute permission
}

resource "local_sensitive_file" "keypair_pub" {
    filename = "${path.module}/${var.infra-basic-settings.name}-board.pub"
    content = tls_private_key.main.public_key_openssh
}


# ec2
resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  #instance_type               = "t2.nano"
  #instance_type               = "t1.micro"
  instance_type               = "m4.large"
  availability_zone           = "ap-northeast-1a"
  vpc_security_group_ids      = [aws_security_group.sg-board.id]
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = "true"
  key_name                    = aws_key_pair.board.key_name
  user_data                   = file("${path.module}/script.sh")
  tags = {
    Name = "${var.infra-basic-settings.name}-ec2-board"
  }
}
