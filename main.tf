# we have created resouce of vpc and we can check the details in aws panel left side and then see explorer then resources then go to EC@::VPC.
# also we can check how many resources deployed we can check in terraform.tfstate file.
resource "aws_vpc" "mtc_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

# here we have given the id. aws_vpc is the resource and mtc_vpc is the name of that resource. we declared this thing above
# we basically created the public subnet for our application.
resource "aws_subnet" "mtc_public_subnet" {
  vpc_id                  = aws_vpc.mtc_vpc.id
  cidr_block              = "10.123.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "dev-public"
  }
}

# internet gateway is the way to go to internet by providing internet gateway.check "name" {
resource "aws_internet_gateway" "mtc_internet_gateway" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev-igw"
  }
}


# now we will create route table to route traffic from public subnet through IGW.
# we below created route table.
resource "aws_route_table" "mtc_public_rt" {
  vpc_id = aws_vpc.mtc_vpc.id

  tags = {
    Name = "dev-public-rt"
  }
}

# now we will create a route
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.mtc_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.mtc_internet_gateway.id
}


# now we will  associate this route table with our public subnet by providing route tabale association.
resource "aws_route_table_association" "mtc_public_assoc" {
  subnet_id      = aws_subnet.mtc_public_subnet.id
  route_table_id = aws_route_table.mtc_public_rt.id
}

# now we will add security group. 
# first, let's create a security group
resource "aws_security_group" "mtc_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.mtc_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# data source is query of AWS API and it returns information about existing resources.
# we created ami in datasources.tf file


# now we create key pair.
resource "aws_key_pair" "mtc_auth" {
  key_name = "mtckey"
  public_key = file("~/.ssh/mtckey.pub")   # ~/ means home directory means C:\Users\katha.
}


# finally we will create EC2 instance. 
resource "aws_instance" "dev_node" {
  instance_type = "t2.micro"
  ami = data.aws_ami.server_ami.id
  key_name = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id = aws_subnet.mtc_public_subnet.id
  user_data = file("userdata.tpl")

  root_block_device {
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  # we add provisioner to access aws instance from our vscode terminal
  provisioner "local-exec" {
    command = templatefile("windows-ssh-config.tpl", {
      hostname = self.public_ip,
      user = "ubuntu",
      identityfile = "~/.ssh/mtckey"
    })
    interpreter = [ "Powershell", "-Command" ]
  }
}


# we have gone inside the instnce from our terminal. to do that do following: 
# 1. create ssh key using: ssh-keygen -t ed25519 => and then give location: C:\Users\katha/.ssh/mtckey  then run following command to check whether key is generated and stored or not: ls ~/.ssh and it will list all the files stored inside that.
# 2. by running following: ssh -i C:\Users\katha\.ssh\mtckey ubuntu@44.203.98.79     => here 44.203.98.79 is public ip of our instance.
# 3. we can find public ip by following: 1. run terraform state list then select instance and copy that entire name. and then write following command: 
                                        # 2. run terraform state show aws_instance.dev_node  => here aws_instance.dev_node is our instance. and then from output find public ip and paste that after ubuntu@ in second step.

# in above step 2 is used to go into ubuntu terminal. paste it as it is in terminal.


# if you want to run linux shell then paste following link in command prompt. ssh AWS-Server