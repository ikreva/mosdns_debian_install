#!/bin/bash
set -e

# 定义文件路径
MOSDNS_CONFIG="/usr/local/etc/mosdns"
MOSDNS_BIN="/usr/local/bin"
MOSDNS_TMP="/tmp/mosdns"

# 定义 MosDNS , v2dat 下载链接
MOSDNS_URL="https://gh.cooluc.com/https://github.com/IrineSistiana/mosdns/releases/download/v5.3.1/mosdns-linux-amd64.zip"
V2DAT_URL="https://gh.cooluc.com/https://github.com/ikreva/v2dat/releases/download/0.1/v2dat-linux-amd64.zip"

# 定义数据库下载链接
GEOSITE_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat"
GEOIP_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat"
ANTI_AD_URL="https://anti-ad.net/domains.txt"
MOSDNS_ADRULES_URL="https://adrules.top/mosdns_adrules.txt"
CLOUDFLARE_CIDR_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/rule/cloudflare-cidr.txt"
LOCAL_PTR_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/rule/local-ptr.txt"

# 下载文件方法
download_file() {
    local dest=$1
    local url=$2
    echo "开始下载 $url"
    if ! wget --show-progress -t 5 -T 10 -cqO "$dest" "$url"; then
        echo "下载文件 $url 失败，请检查网络连接。"
        exit 1
    fi
    echo "完成下载 $url"
}

# v2dat 解压缩包
unpack_data() {
    local file=$1
    local options=$2
    echo "开始解包geo数据"
    if ! v2dat unpack $file -o /var/mosdns $options $MOSDNS_TMP/$file.dat; then
        echo "解包失败，请检查文件是否正确。"
        exit 1
    fi
    echo "geo数据解包完成."
}

case $1 in
-i|install)

# 检查是否已经安装了 wget 和 unzip
for cmd in wget unzip; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd 没有安装，开始安装..."
        sudo apt update
        sudo apt install -y $cmd
    fi
done

echo "创建临时目录..."
mkdir -p $MOSDNS_TMP

download_file $MOSDNS_TMP/mosdns-linux-amd64.zip $MOSDNS_URL
download_file $MOSDNS_TMP/v2dat-linux-amd64.zip $V2DAT_URL
download_file $MOSDNS_TMP/geosite.dat $GEOSITE_URL
download_file $MOSDNS_TMP/geoip.dat $GEOIP_URL
download_file $MOSDNS_TMP/anti-ad-domains.txt $ANTI_AD_URL
download_file $MOSDNS_TMP/mosdns_adrules.txt $MOSDNS_ADRULES_URL
download_file $MOSDNS_TMP/cloudflare-cidr.txt $CLOUDFLARE_CIDR_URL
download_file $MOSDNS_TMP/local-ptr.txt $LOCAL_PTR_URL

echo "创建规则配置..."
mkdir -p $MOSDNS_CONFIG/rule/adlist
touch $MOSDNS_CONFIG/rule/blocklist.txt
touch $MOSDNS_CONFIG/rule/ddnslist.txt
touch $MOSDNS_CONFIG/rule/greylist.txt
touch $MOSDNS_CONFIG/rule/hosts.txt
touch $MOSDNS_CONFIG/rule/redirect.txt
touch $MOSDNS_CONFIG/rule/whitelist.txt
cp -f $MOSDNS_TMP/{cloudflare-cidr.txt,local-ptr.txt} $MOSDNS_CONFIG/rule/
cp -f $MOSDNS_TMP/{anti-ad-domains.txt,mosdns_adrules.txt} $MOSDNS_CONFIG/rule/adlist/

echo "安装 v2dat 文件..."
unzip -o -d $MOSDNS_TMP/ $MOSDNS_TMP/v2dat-linux-amd64.zip && mv -f $MOSDNS_TMP/v2dat $MOSDNS_BIN/v2dat && chmod +x $MOSDNS_BIN/v2dat

echo "开始解压地理位置数据..."
mkdir -p /var/mosdns
unpack_data geoip "-f cn"
unpack_data geosite "-f apple -f geolocation-!cn"
unpack_data geosite "-f cn -f apple-cn -f google-cn"
unpack_data geosite "-f category-ads-all"
echo "解压地理位置数据完成."

echo "创建 mosdns 配置文件..."
cat > $MOSDNS_CONFIG/config.yaml << EOF
log:
  level: info
  file: "/var/log/mosdns.log"

api:
  http: "0.0.0.0:9091"

include: []

plugins:
  - tag: geosite_cn
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_cn.txt"
        - "/var/mosdns/geosite_apple-cn.txt"
        - "/var/mosdns/geosite_google-cn.txt"

  - tag: geoip_cn
    type: ip_set
    args:
      files:
        - "/var/mosdns/geoip_cn.txt"

  - tag: geosite_apple
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_apple.txt"

  - tag: geosite_no_cn
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_geolocation-!cn.txt"

  - tag: whitelist
    type: domain_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/whitelist.txt"

  - tag: blocklist
    type: domain_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/blocklist.txt"

  - tag: greylist
    type: domain_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/greylist.txt"

  - tag: ddnslist
    type: domain_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/ddnslist.txt"

  - tag: hosts
    type: hosts
    args:
      files:
        - "$MOSDNS_CONFIG/rule/hosts.txt"

  - tag: redirect
    type: redirect
    args:
      files:
        - "$MOSDNS_CONFIG/rule/redirect.txt"

  - tag: adlist
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_category-ads-all.txt"
        - "$MOSDNS_CONFIG/rule/adlist/anti-ad-domains.txt"
        - "$MOSDNS_CONFIG/rule/adlist/mosdns_adrules.txt"

  - tag: local_ptr
    type: domain_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/local-ptr.txt"

  - tag: cloudflare_cidr
    type: ip_set
    args:
      files:
        - "$MOSDNS_CONFIG/rule/cloudflare-cidr.txt"

  - tag: lazy_cache
    type: cache
    args:
      size: 8000
      lazy_cache_ttl: 86400

  - tag: forward_xinfeng_udp
    type: forward
    args:
      concurrent: 2
      upstreams:
        - addr: "114.114.114.114"
        - addr: "114.114.115.115"

  - tag: forward_local
    type: forward
    args:
      concurrent: 1
      upstreams:
        - addr: "223.5.5.5"
          bootstrap: 223.6.6.6
          enable_pipeline: false
          insecure_skip_verify: false
          idle_timeout: 30
        - addr: "119.29.29.29"
          bootstrap: 223.6.6.6
          enable_pipeline: false
          insecure_skip_verify: false
          idle_timeout: 30

  - tag: forward_remote
    type: forward
    args:
      concurrent: 1
      upstreams:
        - addr: "tls://8.8.8.8"
          bootstrap: 223.6.6.6
          enable_pipeline: false
          insecure_skip_verify: false
          idle_timeout: 30
        - addr: "tls://1.1.1.1"
          bootstrap: 223.6.6.6
          enable_pipeline: false
          insecure_skip_verify: false
          idle_timeout: 30

  - tag: forward_remote_upstream
    type: sequence
    args:
      - exec: prefer_ipv4
      - exec: \$forward_remote

  - tag: modify_ttl
    type: sequence
    args:
      - exec: ttl 0-0

  - tag: modify_ddns_ttl
    type: sequence
    args:
      - exec: ttl 5-5

  - tag: has_resp_sequence
    type: sequence
    args:
      - matches: qname \$ddnslist
        exec: \$modify_ddns_ttl
      - matches: "!qname \$ddnslist"
        exec: \$modify_ttl
      - matches: has_resp
        exec: accept

  - tag: query_is_non_local_ip
    type: sequence
    args:
      - exec: \$forward_local
      - matches: "!resp_ip \$geoip_cn"
        exec: drop_resp

  - tag: fallback
    type: fallback
    args:
      primary: forward_remote_upstream
      secondary: forward_remote_upstream
      threshold: 500
      always_standby: true

  - tag: apple_domain_fallback
    type: fallback
    args:
      primary: query_is_non_local_ip
      secondary: forward_xinfeng_udp
      threshold: 100
      always_standby: true

  - tag: query_is_apple_domain
    type: sequence
    args:
      - matches: "!qname \$geosite_apple"
        exec: return
      - exec: \$apple_domain_fallback

  - tag: query_is_ddns_domain
    type: sequence
    args:
      - matches: qname \$ddnslist
        exec: \$forward_local

  - tag: query_is_local_domain
    type: sequence
    args:
      - matches: qname \$geosite_cn
        exec: \$forward_local

  - tag: query_is_no_local_domain
    type: sequence
    args:
      - matches: qname \$geosite_no_cn
        exec: \$forward_remote_upstream

  - tag: query_is_whitelist_domain
    type: sequence
    args:
      - matches: qname \$whitelist
        exec: \$forward_local

  - tag: query_is_greylist_domain
    type: sequence
    args:
      - matches: qname \$greylist
        exec: \$forward_remote_upstream

  - tag: query_is_reject_domain
    type: sequence
    args:
      - matches: qname \$blocklist
        exec: reject 3
      - matches: qname \$adlist
        exec: reject 3
      - matches:
        - qtype 12
        - qname \$local_ptr
        exec: reject 3
      - matches: qtype 65
        exec: reject 3

  - tag: main_sequence
    type: sequence
    args:
      - exec: \$hosts
      - exec: jump has_resp_sequence
      - matches:
        - "!qname \$ddnslist"
        - "!qname \$blocklist"
        - "!qname \$adlist"
        - "!qname \$local_ptr"
        exec: \$lazy_cache
      - exec: \$redirect
      - exec: jump has_resp_sequence
      - exec: \$query_is_apple_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_ddns_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_whitelist_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_reject_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_greylist_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_local_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_no_local_domain
      - exec: jump has_resp_sequence
      - exec: \$fallback

  - tag: udp_server
    type: udp_server
    args:
      entry: main_sequence
      listen: ":53"

  - tag: tcp_server
    type: tcp_server
    args:
      entry: main_sequence
      listen: ":53"

#  - tag: tls_server
#    type: tcp_server
#    args:
#      entry: main_sequence
#      listen: ":853"
#      cert: "/path/to/cert"
#      key: "/path/to/key"
#      idle_timeout: 10

#  - tag: doh_server
#    type: http_server
#    args:
#      entries:
#        - path: /dns-query
#        exec: main_sequence
#      src_ip_header: "X-Forwarded-For"
#      listen: ":443"
#      cert: "/path/to/cert"
#      key: "/path/to/key"
#      idle_timeout: 30
EOF

cat > $MOSDNS_CONFIG/config_custom.yaml << EOF
log:
  level: info
  file: "/var/log/mosdns.log"

# API 入口设置
api:
  http: "0.0.0.0:9091"

include: []

plugins:
  # 国内域名
  - tag: geosite_cn
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_cn.txt"

  # 国内 IP
  - tag: geoip_cn
    type: ip_set
    args:
      files:
        - "/var/mosdns/geoip_cn.txt"

  # 国外域名
  - tag: geosite_no_cn
    type: domain_set
    args:
      files:
        - "/var/mosdns/geosite_geolocation-!cn.txt"

  # 缓存
  - tag: lazy_cache
    type: cache
    args:
      size: 20000
      lazy_cache_ttl: 86400
      dump_file: "$MOSDNS_CONFIG/cache.dump"
      dump_interval: 600

  # 转发至本地服务器
  - tag: forward_local
    type: forward
    args:
      upstreams:
        - addr: "https://doh.pub/dns-query"
          bootstrap: 180.76.76.76
        - addr: 119.29.29.29

  # 转发至远程服务器
  - tag: forward_remote
    type: forward
    args:
      upstreams:
        - addr: tls://8.8.8.8
          enable_pipeline: false

  # 国内解析
  - tag: local_sequence
    type: sequence
    args:
      - exec: \$forward_local

  # 国外解析
  - tag: remote_sequence
    type: sequence
    args:
      - exec: prefer_ipv4
      - exec: \$forward_remote

  # 有响应终止返回
  - tag: has_resp_sequence
    type: sequence
    args:
      - matches: has_resp
        exec: accept

  # fallback 用本地服务器 sequence
  # 返回非国内 ip 则 drop_resp
  - tag: query_is_local_ip
    type: sequence
    args:
      - exec: \$local_sequence
      - matches: "!resp_ip \$geoip_cn"
        exec: drop_resp

  # fallback 用远程服务器 sequence
  - tag: query_is_remote
    type: sequence
    args:
      - exec: \$remote_sequence

  # fallback 用远程服务器 sequence
  - tag: fallback
    type: fallback
    args:
      primary: query_is_local_ip
      secondary: query_is_remote
      threshold: 500
      always_standby: true

  # 查询国内域名
  - tag: query_is_local_domain
    type: sequence
    args:
      - matches: qname \$geosite_cn
        exec: \$local_sequence

  # 查询国外域名
  - tag: query_is_no_local_domain
    type: sequence
    args:
      - matches: qname \$geosite_no_cn
        exec: \$remote_sequence

  # 主要的运行逻辑插件
  # sequence 插件中调用的插件 tag 必须在 sequence 前定义，
  # 否则 sequence 找不到对应插件。
  - tag: main_sequence
    type: sequence
    args:
      - exec: \$lazy_cache
      - exec: \$query_is_local_domain
      - exec: jump has_resp_sequence
      - exec: \$query_is_no_local_domain
      - exec: jump has_resp_sequence
      - exec: \$fallback

  # 启动 udp 服务器。
  - tag: udp_server
    type: udp_server
    args:
      entry: main_sequence
      listen: ":5335"

  # 启动 tcp 服务器。
  - tag: tcp_server
    type: tcp_server
    args:
      entry: main_sequence
      listen: ":5335"

#  - tag: tls_server
#    type: tcp_server
#    args:
#      entry: main_sequence
#      listen: ":853"
#      cert: "/path/to/cert"
#      key: "/path/to/key"
#      idle_timeout: 10

#  - tag: doh_server
#    type: http_server
#    args:
#      entries:
#        - path: /dns-query
#        exec: main_sequence
#      src_ip_header: "X-Forwarded-For"
#      listen: ":443"
#      cert: "/path/to/cert"
#      key: "/path/to/key"
#      idle_timeout: 30
EOF

echo "安装 mosdns 文件..."
unzip -o -d $MOSDNS_TMP $MOSDNS_TMP/mosdns-linux-amd64.zip && mv -f $MOSDNS_TMP/mosdns $MOSDNS_BIN/ && chmod +x $MOSDNS_BIN/mosdns

echo "清理临时文件..."
rm -rf $MOSDNS_TMP/

echo "创建 mosdns 服务..."
cat > /etc/systemd/system/mosdns.service << EOF
[Unit]
Description=mosdns daemon, DNS server.
After=network-online.target

[Service]
Type=simple
Restart=always
ExecStart=$MOSDNS_BIN/mosdns start -c $MOSDNS_CONFIG/config.yaml -d $MOSDNS_CONFIG

[Install]
WantedBy=multi-user.target
EOF

echo "启动 mosdns 服务..."
systemctl daemon-reload
systemctl enable mosdns --now


echo "添加自动更新数据库的计划任务"
cat > $MOSDNS_BIN/update_geodata.sh << 'EOF'
#!/bin/bash
set -e

# 定义文件路径
MOSDNS_CONFIG="/usr/local/etc/mosdns"
MOSDNS_BIN="/usr/local/bin"
MOSDNS_TMP="/tmp/mosdns"

# 定义数据库下载链接
GEOSITE_URL="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"
GEOIP_URL="https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
ANTI_AD_URL="https://anti-ad.net/domains.txt"
MOSDNS_ADRULES_URL="https://adrules.top/mosdns_adrules.txt"
CLOUDFLARE_CIDR_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/rule/cloudflare-cidr.txt"
LOCAL_PTR_URL="https://gh.cooluc.com/https://raw.githubusercontent.com/sbwml/luci-app-mosdns/v5/luci-app-mosdns/root/etc/mosdns/rule/local-ptr.txt"

download_file() {
    local dest=$1
    local url=$2
    echo "开始下载 $url"
    if ! wget --show-progress -t 5 -T 10 -cqO "$dest" "$url"; then
        echo "下载文件 $url 失败，请检查网络连接。"
        exit 1
    fi
    echo "完成下载 $url"
}

unpack_data() {
    local file=$1
    local options=$2
    echo "开始解包geo数据"
    if ! v2dat unpack $file -o /var/mosdns $options $MOSDNS_TMP/$file.dat; then
        echo "解包失败，请检查文件是否正确。"
        exit 1
    fi
    echo "geo数据解包完成."
}

echo "创建临时目录..."
mkdir -p $MOSDNS_TMP

download_file $MOSDNS_TMP/geosite.dat $GEOSITE_URL
download_file $MOSDNS_TMP/geoip.dat $GEOIP_URL
download_file $MOSDNS_TMP/anti-ad-domains.txt $ANTI_AD_URL
download_file $MOSDNS_TMP/mosdns_adrules.txt $MOSDNS_ADRULES_URL
download_file $MOSDNS_TMP/cloudflare-cidr.txt $CLOUDFLARE_CIDR_URL
download_file $MOSDNS_TMP/local-ptr.txt $LOCAL_PTR_URL

echo "开始复制规则文件..."
cp -f $MOSDNS_TMP/{cloudflare-cidr.txt,local-ptr.txt} $MOSDNS_CONFIG/rule/
cp -f $MOSDNS_TMP/{anti-ad-domains.txt,mosdns_adrules.txt} $MOSDNS_CONFIG/rule/adlist/
echo "复制规则文件完成."

echo "开始解压地理位置数据..."
unpack_data geoip "-f cn"
unpack_data geosite "-f apple -f geolocation-!cn"
unpack_data geosite "-f cn -f apple-cn -f google-cn"
unpack_data geosite "-f category-ads-all"
echo "解压地理位置数据完成."

echo "清理临时文件..."
rm -rf $MOSDNS_TMP/

echo "开始重启 MosDNS..."
systemctl restart mosdns
echo "重启 MosDNS 完成."
EOF

chmod +x $MOSDNS_BIN/update_geodata.sh

# 检查是否已经存在相同的计划任务
if crontab -l | grep -q "$MOSDNS_BIN/update_geodata.sh"; then
    echo "计划任务已经存在。"
else
    # 将计划任务添加到 crontab
    (crontab -l 2>/dev/null; echo "0 5 * * * $MOSDNS_BIN/update_geodata.sh") | crontab -
    echo "计划任务已经添加。"
fi

;;

-u|uninstall|remove)

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

;;

-up|update)

$MOSDNS_BIN/update_geodata.sh

;;

*)
echo "安装参数 -i | install"
echo "更新数据库参数 -up | update"
echo "卸载参数 -u | uninstall | remove"
;;
esac