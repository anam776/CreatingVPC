// configure the aws

provider "aws" {
region = "ap-south-1"
profile = "linux"
}

//creating vpc

resource "aws_vpc" "ownvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ownvpc"
  }
enable_dns_hostnames = true 
}


//creating two subnets  out of these two subnet one is private and anither one is public 

resource "aws_subnet" "subnet1" {
  depends_on = [ aws_vpc.ownvpc , ] 
  vpc_id     = "${aws_vpc.ownvpc.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone_id = "aps1-az1"

  tags = {
    Name = "subnet1"
  }
map_public_ip_on_launch=true
}


resource "aws_subnet" "subnet2" {
  depends_on = [ aws_vpc.ownvpc , ] 
  vpc_id     = "${aws_vpc.ownvpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone_id = "aps1-az1"

  tags = {
    Name = "subnet2"
  }
}


//creating a gateway 

resource "aws_internet_gateway" "Internetgateway" {

  depends_on = [ aws_vpc.ownvpc , ] 
  vpc_id = "${aws_vpc.ownvpc.id}"

tags = {
    Name = "Internetgateway"
  }
}

//creating a Route Table

resource "aws_route_table" "RouteTable" {
  depends_on = [ aws_vpc.ownvpc ,aws_internet_gateway.Internetgateway,   ] 
  vpc_id = "${aws_vpc.ownvpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.Internetgateway.id}"
  }


  tags = {
    Name = "RouteTable"
  }
}

//Route table assocation with public subnet

resource "aws_route_table_association" "publicassociation" {
  depends_on= [aws_subnet.subnet1 , aws_route_table.RouteTable , ]
  subnet_id  = aws_subnet.subnet1.id 
  route_table_id = aws_route_table.RouteTable.id

}

//creating security group for wordpress and mysql 


resource "aws_security_group" "allow_http" {
  depends_on = [ aws_vpc.ownvpc , ]
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = "${aws_vpc.ownvpc.id}"

  ingress {
    description = "TCP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from VPC"
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

  tags = {
    Name = "allow_http"
  }
}


//creating security group for SQL

resource "aws_security_group" "allow_sql" {
  name        = "allow_sql"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.ownvpc.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
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
    Name = "allow_sql"
  }
}

//creating a private key 

resource "tls_private_key" "MyPrivateKey" {
  algorithm   = "RSA"
  rsa_bits    = 4096

}

// The  access of Key as private key 


resource "aws_key_pair" "MyKey" {
  depends_on = [ tls_private_key.MyPrivateKey , ]
  key_name   = "MyKey"
  public_key = tls_private_key.MyPrivateKey.public_key_openssh
}
 
//creating  MySQL instance 

resource "aws_instance" "MySql" {
  depends_on = [ aws_security_group.allow_sql , ]
  ami           = "ami-0019ac6129392a0f2"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${ aws_security_group.allow_sql.id}"]
  subnet_id = "${aws_subnet.subnet2.id}"
  

  tags = {
    Name = "MySql"
  }
}

//creating WordPress instance 


resource "aws_instance" "MyWordPress" {
  depends_on = [ aws_security_group.allow_http , ]
  ami           = "ami-000cbce3e1b899ebd"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${ aws_security_group.allow_http.id}"]
  subnet_id = "${aws_subnet.subnet1.id}"
  

  tags = {
    Name = "MyWordPress"
  }
}

