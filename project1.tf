
provider "aws"{
	region = "us-east-1"
	access_key = "AKIASLUDTJBNN2UBEUIT"
	secret_key = "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"
}

variable "subnet_prefix" {
	description = "cidr block for the subnet"
}


resource "aws_vpc" "prod-vpc"{
	cidr_block = "10.0.0.0/16"
	tags = {
	name = "production"
	}
}

resource "aws_internet_gateway" "gw"{
vpc_id = aws_vpc.prod-vpc.id
}


resource "aws_route_table" "prod-route-table" {
 vpc_id = aws_vpc.prod-vpc.id

 route {
   cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
   }

  route {
   ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
   }

  tags = {
     Name = "Prod"
   }
 }



resource "aws_subnet" "subnet-1" {
	vpc_id = aws_vpc.prod-vpc.id
	cidr_block = "10.0.1.0/24"
	availability_zone = "us-east-1a"

	tags = {
	Name = "prod_subnet"
	}
}

resource "aws_route_table_association" "a"{
	subnet_id = aws_subnet.subnet-1.id
	route_table_id = aws_route_table.prod-route-table.id

	}


resource "aws_security_group" "allow_web"{
	name = "allow_web_traffic"
	description = "allow web inbound traffic"
	vpc_id = aws_vpc.prod-vpc.id

	ingress{
	description = "https"
	from_port = 443
	to_port = 443
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	}

	ingress{
	description = "http"
	from_port = 80
	to_port = 80
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
}
ingress{
	description = "ssh"
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	}
	egress{
	from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = ["0.0.0.0/0"]
	}

	tags = {
	Name ="allow_web"
	}
}

resource "aws_network_interface" "web-server-nic"{
	subnet_id = aws_subnet.subnet-1.id
	private_ips = ["10.0.1.50"]
	security_groups = [aws_security_group.allow_web.id]

	}


resource "aws_eip" "one"{
	vpc  = true
	network_interface  = aws_network_interface.web-server-nic.id
	associate_with_private_ip = "10.0.1.50"
	depends_on = [aws_internet_gateway.gw]
}



 output "server_public_ip" {
   value = aws_eip.one.public_ip
 }



resource "aws_instance" "web-server-instance"{
	ami = "ami-0ee02acd56a52998e"
	instance_type = "t2.micro"
	availability_zone = "us-east-1a"
	key_name ="mainkey"

	network_interface{
	device_index = 0
	network_interface_id = aws_network_interface.web-server-nic.id
	}

	user_data = <<-EOF
	               #!/bin/bash
	                 sudo apt update -y
	                 sudo apt install apache2 -y
	                 sudo systemctl start apache2
	                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
	                EOF
	  tags = {
	     Name = "web-server"
	   }
	 }