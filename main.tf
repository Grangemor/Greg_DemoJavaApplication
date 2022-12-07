terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.1.0/24"
  availability_zone                   = "us-east-1a"
  map_public_ip_on_launch             = true
  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.2.0/24"
  availability_zone                   = "us-east-1b"
  map_public_ip_on_launch             = true
  tags = {
    Name = "subnet2"
  }
}

#Private-Subnet
resource "aws_subnet" "privatesub" {
  vpc_id                              = aws_vpc.main.id
  cidr_block                          = "10.0.3.0/24"
  availability_zone                   = "us-east-1b"
  map_public_ip_on_launch             = true
  tags = {
    Name = "privatesub"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }

}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main.id
route {
cidr_block = "0.0.0.0/0"
gateway_id = aws_internet_gateway.gw.id
}
  tags = {
    Name = "routetable"
  }

}

#assiociation of route table to subnet1 
resource "aws_route_table_association" "greg_RT_ass_01" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.routetable.id
}

#assiociation of route table to subnet2 
resource "aws_route_table_association" "greg_RT_ass_02" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.routetable.id
}

# Create Frontend Security Group
resource "aws_security_group" "greg_FrontEnd_SG" {
  name        = "greg_FrontEnd_SG"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from aws_vpc.main.id"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "Allow jenkins from greg_VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Allow http from greg_VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow http from greg_VPC"
    from_port   = 8085
    to_port     = 8085
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
    Name = "greg_FrontEnd_SG"
  }
}


# creating key pair 
resource "aws_key_pair" "tform_key" {
  key_name = "tformkey"
  public_key = file("~/Documents/DevOps/Greg_DemoJavaApplication/tform.pub")   
  #public_key = file("/Users/grego/Documents/DevOpsGreg_DemoJavaApplication/tform.pub")
  tags = {
    Name = "tformkey"
  }
}

# Create tomcat server
#============================================================================
resource "aws_instance" "tomcat_server" {
  ami                         = "ami-0b0dcb5067f052a63"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.greg_FrontEnd_SG.id]
  key_name                    = aws_key_pair.tform_key.key_name
  associate_public_ip_address = true

user_data = <<-EOF
#! /bin/bash
sudo su
yum update -y
yum install java-1.8.0-openjdk-devel -y
groupadd --system tomcat
useradd -d /usr/share/tomcat -r -s /bin/false -g tomcat tomcat
yum -y install wget
cd /opt
wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.70/bin/apache-tomcat-9.0.70.tar.gz
tar -xvf apache-tomcat-9.0.70.tar.gz
mv apache-tomcat-9.0.70 tomcat9
rm -rf apache-tomcat-9.0.70.tar.gz
chown -R tomcat:tomcat /opt/tomcat9
cd tomcat9/bin/
chmod +x startup.sh
chmod +x shutdown.sh
ln -s /opt/tomcat9/bin/startup.sh /usr/sbin/tomcatup
ln -s /opt/tomcat9/bin/shutdown.sh /usr/sbin/tomcatdown
tomcatup
tomcatdown
cat <<EOT > /opt/tomcat9/webapps/host-manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
<!--  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOT
cat <<EOT > /opt/tomcat9/webapps/manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
<!--  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOT
cat <<EOT > /opt/tomcat9/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
<role rolename="manager-gui"/>
<role rolename="manager-script"/>
<role rolename="manager-jmx"/>
<role rolename="manager-status"/>
<user username="admin" password="admin@123" roles="manager-gui, manager-script, manager-jmx, manager-status"/>
<user username="deployer" password="deployer@123" roles="manager-script"/>
<user username="tomcat" password="team3@s3cret" roles="manager-gui"/>
</tomcat-users>
EOT
cat << EOT > /opt/tomcat9/conf/server.xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />  
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" /> 
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />  
  <GlobalNamingResources>    
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>  
  <Service name="Catalina">    
    <Connector port="8085" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />       
    <Engine name="Catalina" defaultHost="localhost">
            <Realm className="org.apache.catalina.realm.LockOutRealm">        
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>
      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOT
tomcatdown
tomcatup
EOF
  tags = {
    Name = "tomcatserver"
  }
}