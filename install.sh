#!/bin/bash

/usr/bin/dnf check-release-update
dnf upgrade -y --releasever=2023.7.20250623
sudo dnf install -y kernel6.12
version=$(rpm -q --qf '%{version}-%{release}.%{arch}\n' kernel6.12 | sort -V | tail -1) 
sudo grubby --set-default "/boot/vmlinuz-$version" 

sudo dnf install -y rsyslog
sudo systemctl enable rsyslog --now

sudo dnf -y install dnf-plugins-core
wget https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz
tar -xf docker-27.3.1.tgz
sudo mv docker/* /usr/bin/
sudo yum install -y iptables git mdadm
sudo groupadd docker

sudo yum -y install bash-completion
sudo curl https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker_completion.sh
wget https://downloads.mongodb.com/compass/mongodb-mongosh-2.5.0.aarch64.rpm
sudo rpm -i mongodb-mongosh-2.5.0.aarch64.rpm
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
sudo yum install lvm2 -y

cat <<EOF > /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target docker.socket firewalld.service containerd.service time-set.target
Wants=network-online.target containerd.service
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /usr/lib/systemd/system/containerd.service
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
#uncomment to enable the experimental sbservice (sandboxed) version of containerd/cri integration
#Environment="ENABLE_CRI_SANDBOXES=sandboxed"
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /usr/lib/systemd/system/docker.socket
[Unit]
Description=Docker Socket for the API

[Socket]
# If /var/run is not implemented as a symlink to /run, you may need to
# specify ListenStream=/var/run/docker.sock instead.
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /root/createuser.sh
#!/bin/bash
user=\$1
key=\$2
cmd="id \$user"
\$cmd
if [[ \$? -ne 0 ]] 
then
  useradd -m -s /bin/bash \$user || true
  echo "\$user:\$user" | chpasswd
fi
if [[ ! -d /home/\$user/.ssh ]]
then
  mkdir /home/\$user/.ssh
fi
echo \$key >> /home/\$user/.ssh/authorized_keys
chown -R \$user:\$user /home/\$user
usermod -aG docker \$user
usermod -aG wheel \$user
EOF

bash /root/createuser.sh keshav 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDK4bS8lXHABe1kfZguhSLK/l4z70oK4KB4uCcaBXJ8F keshavprasad@Keshavs-MacBook-Pro.local'

systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl enable --now containerd
sudo systemctl enable docker
sudo systemctl enable containerd
