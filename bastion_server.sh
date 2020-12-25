#!/bin/bash

NFSIP=10.150.9.0/24
bastion_ip=10.150.9.100      
master1_ip=10.150.9.111
master2_ip=10.150.9.112
master3_ip=10.150.9.113
worker1_ip=10.150.9.114
worker2_ip=10.150.9.115
worker3_ip=10.150.9.116
bootstrap_ip=10.150.9.110
harbor_ip=10.150.3.7
ocp_vers=4.6.6




setenforce 0
sed -i 's/enforcing/permissive/g' /etc/selinux/config
cat << EOF > epel-jjk.repo
[rhel-7-server-rpms]
name=rhel-7-server-rpms
baseurl=http://10.150.5.100:8080/repos/rhel-7-server-rpms/
gpgcheck=0
enable=1

[rhel-7-server-extras-rpms]
name=rhel-7-server-extras-rpms
baseurl=http://10.150.5.100:8080/repos/rhel-7-server-extras-rpms/
gpgcheck=0
enable=1

[rhel-7-server-ose-4.6-rpms]
name=rhel-7-server-ose-4.6-rpms
baseurl=http://10.150.5.100:8080/repos/rhel-7-server-ose-4.6-rpms/
gpgcheck=0
enable=1

[rhel-7-server-ansible-2.9-rpms]
name=rhel-7-server-ansible-2.9-rpms
baseurl=http://10.150.5.100:8080/repos/rhel-7-server-ansible-2.9-rpms/
gpgcheck=0
enabled=1
EOF
yum clean all
yum repolist
yum install -y httpd bind bind-utils haproxy nfs-utils epel-relase
firewall-cmd --permanent --add-port={6443,22623,8080}/tcp
firewall-cmd --permanent --add-service={http,https,nfs,dns}
firewall-cmd --reload

yum install -y httpd bind bind-utils haproxy nfs-utils epel-relase
firewall-cmd --permanent --add-port={6443,22623,8080}/tcp
firewall-cmd --permanent --add-service={http,https,nfs,dns}
firewall-cmd --reload
sed  's/80/8080/g' /etc/httpd/conf/httpd.conf
mkdir -pv /var/www/html/ocp4
cp rhcos-4.5.6-x86_64-metal.x86_64.raw.gz /var/www/html/ocp4/rhcos.raw.gz
chmod -R 755 /var/www/html/ocp4
systemctl enable --now httpd
systemctl enable --now nfs-server
mkdir -pv /var/nfsshare/registry
chmod -R 777 /var/nfsshare
chown -R nfsnobody:nfsnobody /var/nfsshare
echo "/var/nfsshare $NFSIP(rw,sync,root_squash)" > /etc/exports
exportfs -r
systemctl restart nfs-server
showmount -e
sleep 5
mkdir -pv /root/ocp4
mv {openshift-client-linux-4.6.6.tar.gz,openshift-install-linux-4.6.6.tar.gz} /root/ocp4
cd /root/ocp4
tar zxvf openshift-client-linux-4.6.6.tar.gz
tar zxvf openshift-install-linux-4.6.6.tar.gz
mv kubectl oc openshift-install /usr/local/bin/


sed -i 's/127.0.0.1/any/g' /etc/named.conf
sed -i 's/localhost/any/g' /etc/named.conf
cat << EOF > /etc/named.rfc1912.zones

zone "master.jjk.com" IN {
    type master;
    file "master.jjk.com.zone";
    allow-update { none; };
};
zone "9.150.10.in-addr.arpa" IN {
    type master;
    file "master.jjk.com.rev";
    allow-update { none; };
};
EOF


if [ ! -f /var/named/master.jjk.com.zone ]; then
cat << EOF > /var/named/master.jjk.com.zone
"$"TTL 1D
@       IN SOA  @ bastion.master.jjk.com. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum

; name servers - NS records
        NS     bastion.master.jjk.com.

; OpenShift Container Platform Cluster - A records
master-1        IN      A       $master1_ip
master-2        IN      A       $master2_ip
master-3        IN      A       $master3_ip
worker-1        IN      A       $worker1_ip
worker-2        IN      A       $worker2_ip
worker-3        IN      A       $worker3_ip
bootstrap       IN      A       $bootstrap_ip
bastion         IN      A       $bastion_ip

; OpenShift internal cluster IPs - A records
api             IN      A    $bastion_ip
api-int         IN      A    $bastion_ip
*.apps          IN      A    $bastion_ip
etcd-0          IN      A    $master1_ip
etcd-1          IN      A    $master2_ip
etcd-2          IN      A    $master3_ip

; OpenShift internal cluster IPs - SRV records
_etcd-server-ssl._tcp.master.jjk.com.   IN SRV  0   0   2380    etcd-0.master.jjk.com.
                                     IN SRV  0   0   2380    etcd-1.master.jjk.com.
                                     IN SRV  0   0   2380    etcd-2.master.jjk.com.

EOF
sed -i 's/"$"/$/g' /var/named/master.jjk.com.zone 
fi

if [ ! -f /var/named/master.jjk.com.rev ]; then
cat << EOF > /var/named/master.jjk.com.rev
"$"TTL 1D
@       IN SOA  @ bastion.master.jjk.com. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
; name servers - NS records
        NS     bastion.master.jjk.com.

; OpenShift Container Platform Cluster - PTR records
110     IN      PTR   bootstrap.master.jjk.com.
111     IN      PTR   master-1.master.jjk.com.
112     IN      PTR   master-2.master.jjk.com.
113     IN      PTR   master-3.master.jjk.com.
114     IN      PTR   worker-1.master.jjk.com.
115     IN      PTR  worker-2.master.jjk.com.
116     IN      PTR  worker-3.master.jjk.com.
100     IN      PTR  bastion.master.jjk.com.
100     IN      PTR  api.master.jjk.com.
100     IN      PTR  api-int.master.jjk.com.
EOF
sed -i 's/"$"/$/g' /var/named/master.jjk.com.rev
fi

chmod 644 /var/named/master.jjk.com*
named-checkconf /etc/named.conf 
sleep 3
named-checkconf /etc/named.rfc1912.zones
sleep 3
named-checkzone master.jjk.com /var/named/master.jjk.com.zone
sleep 3
systemctl enable --now named

if [ ! -f /etc/haproxy/haproxy.cfg ]; then
mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
fi
cat << EOF > /etc/haproxy/haproxy.cfg 
# Global settings
#---------------------------------------------------------------------
global
    maxconn     20000
    log         /dev/log local0 info
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          300s
    timeout server          300s
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 20000

frontend openshift-api-server
    bind *:6443
    default_backend openshift-api-server
    mode tcp
    option tcplog

backend openshift-api-server
    balance source
    mode tcp
    server bootstrap $bootstrap_ip:6443 check fall 3 rise 2
    server master-1 $master1_ip:6443 check fall 3 rise 2
    server master-2 $master2_ip:6443 check fall 3 rise 2
    server master-3 $master3_ip:6443 check fall 3 rise 2

frontend machine-config-server
    bind *:22623
    default_backend machine-config-server
    mode tcp
    option tcplog

backend machine-config-server
    balance source
    mode tcp
    server bootstrap $boostrap_ip:22623 check fall 3 rise 2
    server master-1 $master1_ip:22623 check fall 3 rise 2
    server master-2 $master2_ip:22623 check fall 3 rise 2
    server master-3 $master3_ip:22623 check fall 3 rise 2

frontend ingress-http
    bind *:80
    default_backend ingress-http
    mode tcp
    option tcplog

backend ingress-http
    balance source
    mode tcp
    server worker-1 $worker1_ip:80 check fall 3 rise 2
    server worker-2 $worker2_ip:80 check fall 3 rise 2 
    server worker-3 $worker3_ip:80 check fall 3 rise 2

frontend ingress-https
    bind *:443
    default_backend ingress-https
    mode tcp
    option tcplog

backend ingress-https
    balance source
    mode tcp
    server worker-1 $worker1_ip:443 check fall 3 rise 2
    server worker-2 $worker2_ip:443 check fall 3 rise 2
    server worker-3 $worker3_ip:443 check fall 3 rise 2
EOF
systemctl enable --now haproxy
mv /root/ca.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
echo " ===================================STOP!!!!!!!!!!!!!!!!!============================================"
echo "https://cloud.redhat.com/openshift/install/metal/user-provisioned"
echo " 위 주소에서 Pull secret을 가져와서 /root/ocp4/pull-secret에 저장해주세요"
echo "Pull Secret 과정은 본인 클립보드에 복사되기 때문에 스크립트 불가! "

