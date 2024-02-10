#!/bin/bash

# 定义文件路径
MOSDNS_CONFIG="/usr/local/etc/mosdns"
MOSDNS_BIN="/usr/local/bin"

echo "删除 mosdns 服务..."
systemctl stop mosdns
systemctl disable mosdns
rm -f /etc/systemd/system/mosdns.service
systemctl daemon-reload

echo "删除 mosdns 配置文件及数据文件..."
rm -rf $MOSDNS_CONFIG
rm -rf /var/mosdns
rm -f $MOSDNS_BIN/{v2dat,mosdns,update_geodata.sh}

echo "删除自动更新数据库的计划任务"
# 检查是否已经存在相同的计划任务
if crontab -l | grep -q "$MOSDNS_BIN/update_geodata.sh"; then
    # 删除计划任务
    crontab -l | grep -v "$MOSDNS_BIN/update_geodata.sh" | crontab -
    echo "计划任务已经删除。"
else
    echo "没有找到计划任务。"
fi



