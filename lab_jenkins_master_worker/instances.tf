#Get Linux AMI ID using SSM Parameter endpoint in us-east-1
data "aws_ssm_parameter" "JenkinsMasterAmi" {
  provider = aws.region-master
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Get Linux AMI ID using SSM Parameter endpoint in us-west-2
data "aws_ssm_parameter" "JenkinsWorkerAmi" {
  provider = aws.region-worker
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

#Create key-pair for logging into EC2 in us-east-1
resource "aws_key_pair" "master-key" {
  provider   = aws.region-master
  key_name   = "jenkins-master"
  public_key = file("~/.ssh/id_rsa.pub")
}

#Create key-pair for logging into EC2 in us-west-2
resource "aws_key_pair" "worker-key" {
  provider   = aws.region-worker
  key_name   = "jenkins-worker"
  public_key = file("~/.ssh/id_rsa.pub")
}

#Create and bootstrap EC2 in us-east-1
resource "aws_instance" "jenkins-master" {
  provider                    = aws.region-master
  ami                         = data.aws_ssm_parameter.JenkinsMasterAmi.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.master-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.subnet_1.id
  provisioner "local-exec" {
    command = <<EOF
#!/bin/bash
while true; do
  import_task_status_command="aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-master} --instance-ids ${self.id}"
  echo "Running command: ${import_task_status_command}"
  import_task_status=$(${import_task_status_command})
  echo "Import task [${import_task_id}] status is [${import_task_status}]."

  if [[ "$import_task_status" == "" ]]; then
    echo "Completed, exiting..."
    break
  elif [[ "$import_task_status" == "active" ]]; then
    echo "Waiting 1 minute..."
    sleep 60
  else
    echo "Error, exiting..."
    exit 1
  fi
done
# To support WSL run, see: https://github.com/ansible/ansible/issues/42388#issuecomment-408774520
export ANSIBLE_CONFIG=./ansible.cfg
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name}' ansible_templates/install_jenkins.yaml
EOF
  }
  tags = {
    Name = "jenkins_master_tf"
  }
  depends_on = [aws_main_route_table_association.set-master-default-rt-assoc]
}

#Create EC2 in us-west-2
resource "aws_instance" "jenkins-worker-oregon" {
  provider                    = aws.region-worker
  count                       = var.workers-count
  ami                         = data.aws_ssm_parameter.JenkinsWorkerAmi.value
  instance_type               = var.instance-type
  key_name                    = aws_key_pair.worker-key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg-oregon.id]
  subnet_id                   = aws_subnet.subnet_1_oregon.id

  # Comment out depricated feature
  # Issue: https://github.com/hashicorp/terraform/issues/24076 
  # provisioner "remote-exec" {
  #   when = destroy
  #   inline = [
  #     "java -jar /home/ec2-user/jenkins-cli.jar -auth @/home/ec2-user/jenkins_auth -s http://${aws_instance.jenkins-master.private_ip}:8080 -auth @/home/ec2-user/jenkins_auth delete-node ${self.private_ip}"
  #   ]
  #   connection {
  #     type        = "ssh"
  #     user        = "ec2-user"
  #     private_key = file("~/.ssh/id_rsa")
  #     host        = self.public_ip
  #   }
  # }

  provisioner "local-exec" {
    command = <<EOF
#!/bin/bash
while true; do
  import_task_status_command="aws --profile ${var.profile} ec2 wait instance-status-ok --region ${var.region-worker} --instance-ids ${self.id}"
  echo "Running command: ${import_task_status_command}"
  import_task_status=$(${import_task_status_command})
  echo "Import task [${import_task_id}] status is [${import_task_status}]."

  if [[ "$import_task_status" == "" ]]; then
    echo "Completed, exiting..."
    break
  elif [[ "$import_task_status" == "active" ]]; then
    echo "Waiting 1 minute..."
    sleep 60
  else
    echo "Error, exiting..."
    exit 1
  fi
done
# To support WSL run, see: https://github.com/ansible/ansible/issues/42388#issuecomment-408774520
export ANSIBLE_CONFIG=./ansible.cfg
ansible-playbook --extra-vars 'passed_in_hosts=tag_Name_${self.tags.Name} master_ip=${aws_instance.jenkins-master.private_ip}' ansible_templates/install_worker.yaml
EOF
  }
  tags = {
    Name = join("_", ["jenkins_worker_tf", count.index + 1])
  }
  depends_on = [aws_main_route_table_association.set-worker-default-rt-assoc, aws_instance.jenkins-master]
}
