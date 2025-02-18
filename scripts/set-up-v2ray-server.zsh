set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

DOMAIN=$1
EXPOSED_PORT=10998
UUID="d50a19aa-9e89-4de9-a664-74fbaec09dde"
CONFIG_PATH="/usr/local/etc/v2ray/config.json"
echo "Domain: $DOMAIN"

# Check if system is Ubuntu 20.04
if ! grep -q "Ubuntu 20.04" /etc/os-release; then
    echo "This script only works on Ubuntu 20.04"
    exit 1
fi

sudo apt update
sudo apt install -y certbot


#  install v2ray
wget https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh

sudo bash install-release.sh

sudo tee "$CONFIG_PATH" << EOF > /dev/null
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $EXPOSED_PORT,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "level": 0,
                        "email": "love@v2fly.org"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/websocket",
                        "dest": 1234,
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {   
                            "certificateFile": "/etc/ssl/v2ray/fullchain.pem",
                            "keyFile": "/etc/ssl/v2ray/privkey.pem"
                        }
                    ]
                }
            }
        },
        {
            "port": 1234,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "level": 0,
                        "email": "love@v2fly.org"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/websocket"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ],
    "routing": {
        "domainStrategy": "AsIs"
    }
}
EOF

sudo systemctl enable v2ray
sudo systemctl start v2ray

# disable ipv6
# Disable IPv6 by adding ipv6.disable=1 to GRUB
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity"/GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity ipv6.disable=1"/' /etc/default/grub

# Update GRUB
sudo update-grub

# request domain certificate 
sudo certbot certonly -d $DOMAIN --standalone -m zsluedem06@gmail.com --agree-tos --no-eff-email

# restart v2ray
install -d -o nobody -g nogroup /etc/ssl/v2ray/

install -m 644 -o nobody -g nogroup /etc/letsencrypt/live/$DOMAIN/fullchain.pem -t /etc/ssl/v2ray/
install -m 600 -o nobody -g nogroup /etc/letsencrypt/live/$DOMAIN/privkey.pem -t /etc/ssl/v2ray/

# Create and set up renewal hook for automatic certificate renewal
HOOK_PATH="/etc/letsencrypt/renewal-hooks/deploy/v2ray.sh"
sudo mkdir -p "$(dirname "$HOOK_PATH")"

# Create renewal hook script
sudo tee "$HOOK_PATH" << 'EOF' >/dev/null
#!/bin/bash

V2RAY_DOMAIN='DOMAIN_PLACEHOLDER'

if [[ "$RENEWED_LINEAGE" == "/etc/letsencrypt/live/$V2RAY_DOMAIN" ]]; then
    install -m 644 -o nobody -g nogroup "/etc/letsencrypt/live/$V2RAY_DOMAIN/fullchain.pem" -t /etc/ssl/v2ray/
    install -m 600 -o nobody -g nogroup "/etc/letsencrypt/live/$V2RAY_DOMAIN/privkey.pem" -t /etc/ssl/v2ray/

    sleep "$((RANDOM % 2048))"
    systemctl restart v2ray.service
fi
EOF

# Replace placeholder with actual domain
sudo sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/" "$HOOK_PATH"

# Make the hook script executable
sudo chmod +x "$HOOK_PATH"

# Set up automatic certificate renewal
# Create systemd timer and service for certificate renewal
sudo tee "/etc/systemd/system/certbot-renewal.service" << EOF > /dev/null
[Unit]
Description=Certbot Renewal Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet

[Install]
WantedBy=multi-user.target
EOF

sudo tee "/etc/systemd/system/certbot-renewal.timer" << EOF > /dev/null
[Unit]
Description=Timer for Certbot Renewal

[Timer]
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=86400
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable and start the timer
sudo systemctl enable certbot-renewal.timer
sudo systemctl start certbot-renewal.timer

sudo reboot
