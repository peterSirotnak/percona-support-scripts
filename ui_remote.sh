sudo apt update -y
sudo apt upgrade -y
sudo useradd -m -s /bin/bash peter
echo 'peter:Cerven789' | sudo chpasswd
sudo usermod -aG sudo peter
sudo apt install xfce4 xfce4-goodies xrdp -y
echo "startxfce4" > /home/peter/.xsession
chown peter:peter /home/peter/.xsession
sudo systemctl restart xrdp