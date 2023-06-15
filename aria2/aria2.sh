#!bin/bash
sudo apt-get update
sudo apt-get install aria2 
sudo mkdir /etc/aria2
#新建session文件
sudo touch /etc/aria2/aria2.session
#设置aria2.session可写
sudo chmod 777 /etc/aria2/aria2.session 
sudo nano /etc/aria2/aria2.conf 
sudo aria2c --conf-path=/etc/aria2/aria2.conf -D
