#! /bin/sh

# General
username=$1

ansible_hosts_file="../ansible/hosts"
vars_file="../ansible/vars/main.yml"
vol_dir=$(sed 's/[\/&]/\\&/g' <<< $(echo VOL_DIR=/home/$username/volumes))
username_var=$(echo "username:" $username)
sed -i "1s/.*/$username_var/g" $vars_file

vpn_hostname=$2
vpn_public_ip=$3
vpn_private_key_file=$4

vpn_host=$(sed 's/[\/&]/\\&/g' <<< $(echo $vpn_hostname 'ansible_host='$vpn_public_ip 'ansible_user='$username 'ansible_connection=ssh ansible_ssh_private_key_file='$vpn_private_key_file))
l
compose_env_file="../ansible/roles/wireguard/files/compose/wireguard/.env"
compose_file="../ansible/roles/wireguard/files/compose/wireguard/docker-compose.yml"
sed -i "2s/.*/$vpn_host/g" $ansible_hosts_file
sed -i "1s/.*/$vol_dir/g" $compose_env_file 

admin_hostname=$5
admin_public_ip=$6
admin_private_key_file=$7
admin_host=$(sed 's/[\/&]/\\&/g' <<< $(echo $admin_hostname 'ansible_host='$admin_public_ip 'ansible_user='$username 'ansible_connection=ssh ansible_ssh_private_key_file='$admin_private_key_file))
sed -i "3s/.*/$admin_host/g" $ansible_hosts_file

todo_hostname=$8
todo_private_ip=$9
todo_host=$(sed 's/[\/&]/\\&/g' <<< $(echo $todo_hostname 'ansible_host='$todo_private_ip 'ansible_user='$username 'ansible_connection=ssh ansible_ssh_private_key_file=/secrets/'$todo_hostname))
sed -i "6s/.*/$todo_host/g" $ansible_hosts_file

todo2_hostname=${10}
todo2_private_ip=${11}
todo2_host=$(sed 's/[\/&]/\\&/g' <<< $(echo $todo2_hostname 'ansible_host='$todo2_private_ip 'ansible_user='$username 'ansible_connection=ssh ansible_ssh_private_key_file=/secrets/'$todo2_hostname))
sed -i "7s/.*/$todo2_host/g" $ansible_hosts_file

update_script="../ansible/roles/ansible/files/update-todo.sh"
command=$(sed 's/[\/&]/\\&/g' <<< $(echo 'ssh' $todo_private_ip '-i /secrets/todo "cd ~/compose/todo && docker compose pull && docker compose up -d && docker image prune -af"'))
sed -i "3s/.*/$command/g" $update_script

command=$(sed 's/[\/&]/\\&/g' <<< $(echo 'ssh' $todo2_private_ip '-i /secrets/todo2 "cd ~/compose/todo && docker compose pull && docker compose up -d && docker image prune -af"'))
sed -i "4s/.*/$command/g" $update_script

sleep 60s
ANSIBLE_CONFIG=../ansible/ansible.cfg ansible-playbook ../ansible/run.yml

ssh $username@$admin_public_ip -o 'StrictHostKeyChecking=no' -i ../secrets/admin 'ANSIBLE_CONFIG=~/ansible/ansible.cfg /usr/bin/ansible-playbook ~/ansible/run_local.yml'
