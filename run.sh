#!/bin/sh

TOKEN=$1
DOMAIN_ID=$2
SUB_DOMAIN=$3
MAIN_DOMAIN=$4
DOMAIN=${SUB_DOMAIN}.${MAIN_DOMAIN}

NOW_IP=`dig ${DOMAIN} @119.29.29.29 | awk -F "[ ]+" '/IN/{print $1}' | awk 'NR==2 {print $5}'` && \
echo "Now ip of ${DOMAIN} is ---${NOW_IP}---" && \
echo ${NOW_IP} > /root/nowIp.txt && \
# check now ip useable
rm -f /root/nowIp.csv && \
/root/CloudflareST -dn 10 -tl 300 -tll 2 -sl 5 -p 1 -f /root/nowIp.txt -o "/root/nowIp.csv" >/dev/null 2>&1 && \
test_ip=`grep -s -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" /root/nowIp.csv| head -n 1` && \
if [ ! -f "/root/nowIp.csv" ]; then
   test_speed=0.00
else
   test_speed=`awk -F, 'NR==2{print $6}' /root/nowIp.csv`
fi && \

if [ ! -n "$test_ip" ] || [ `echo "$test_speed < 5.00" | bc` -eq 1 ]; then
   echo "now ip unavailable, continue"
else
   date
   echo "now ip available, no need to change"
   exit
fi && \
   
rm -f /root/result.csv && \
/root/CloudflareST -allip -dn 10 -tl 300 -tll 2 -sl 5 -p 1 -f /root/ip.txt >/dev/null 2>&1 && \
target_ip=`grep -s -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" /root/result.csv| head -n 1` && \
if [ ! -f "/root/result.csv" ]; then
   target_speed=0.00
else
   target_speed=`awk -F, 'NR==2{print $6}' /root/result.csv`
fi && \
if [ ! -n "$target_ip" ] || [ `echo "$target_speed < 5.00" | bc` -eq 1 ]; then
   echo "fail to found a target ip"
   exit
else
   echo "find a target IP $target_ip"
fi && \
RECORD_ID=`curl -s -X POST https://dnsapi.cn/Record.List -d 'login_token='"${TOKEN}"'&format=json&domain_id='"${DOMAIN_ID}"'&sub_domain='"${SUB_DOMAIN}"'&offset=0&length=3' | jq -r '.records' | grep -E -o '[0-9]{5,15}'` && \
if [ ! -n "$RECORD_ID" ]; then
    echo "Can't connect to dnspod api and get RECORD_ID,exit"
    exit
else
    echo "RECORD_ID is $RECORD_ID"
fi && \

if [ "${target_ip}" = "${NOW_IP}" ]; then
   echo "Domain IP not changed."
   exit 
fi && \

echo "start ddns refresh" && \
curl -X POST https://dnsapi.cn/Record.Ddns -d 'login_token='"${TOKEN}"'&format=json&domain_id='"${DOMAIN_ID}"'&record_id='"${RECORD_ID}"'&record_line_id=0&value='"${target_ip}"'&sub_domain='"${SUB_DOMAIN}"'' | jq && \
if [ $? -ne 0 ]; then
    echo "ddns refresh fail, check your token or domain input"
    exit
else
    echo "Finished"
fi && \
exit 0
