# VPC
resource "aws_vpc" "main-vpc" {
    cidr_block = var.vpc-settings.cidr
    enable_dns_support = "true"
    enable_dns_hostnames = "true"
    tags = {
        Name = var.vpc-settings.name
    }
}

# subnets
resource "aws_subnet" "public" {
    count = length(var.vpc-settings.public-subnets)
    cidr_block = values(var.vpc-settings.public-subnets)[count.index].cidr
    availability_zone = values(var.vpc-settings.public-subnets)[count.index].availability_zone

    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.public-subnets)[count.index]}"
    }
}

resource "aws_subnet" "private" {
    count = length(var.vpc-settings.private-subnets)
    cidr_block = values(var.vpc-settings.private-subnets)[count.index].cidr
    availability_zone = values(var.vpc-settings.private-subnets)[count.index].availability_zone

    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.private-subnets)[count.index]}"
    }
}

# internet gateway
resource "aws_internet_gateway" "main-igw" {
    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.infra-basic-settings.name}-igw"
    }
}

# routes
resource "aws_route_table" "public" {
    count = length(var.vpc-settings.public-subnets)
    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.public-subnets)[count.index]}-route"
    }
}

resource "aws_route_table" "private" {
    count = length(var.vpc-settings.private-subnets)
    vpc_id = aws_vpc.main-vpc.id
    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.private-subnets)[count.index]}-route"
    }
}

# route associations
resource "aws_route_table_association" "public" {
    count = length(var.vpc-settings.public-subnets)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table_association" "private" {
    count = length(var.vpc-settings.private-subnets)
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route" "igw" {
    count = length(var.vpc-settings.public-subnets)
    route_table_id = aws_route_table.public[count.index].id
    gateway_id = aws_internet_gateway.main-igw.id
    destination_cidr_block = "0.0.0.0/0"
}

# elastic ip for natgateway
resource "aws_eip" "nat_gateway" {
    count = length(var.vpc-settings.public-subnets)
    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.public-subnets)[count.index]}-ngw-eip"
    }
}

resource "aws_nat_gateway" "private" {
    count = length(var.vpc-settings.public-subnets)

    allocation_id = aws_eip.nat_gateway[count.index].id
    subnet_id = aws_subnet.public[count.index].id

    tags = {
        Name = "${var.infra-basic-settings.name}-${keys(var.vpc-settings.public-subnets)[count.index]}-ngw"
    }
}

resource "aws_route" "ngw" {
    count = length(var.vpc-settings.private-subnets)
    route_table_id         = aws_route_table.private[count.index].id
    nat_gateway_id         = aws_nat_gateway.private[count.index].id
    destination_cidr_block = "0.0.0.0/0"
}
