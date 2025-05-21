# Caddy Installation Command

``curl -sSL https://raw.githubusercontent.com/p-shubh/installation_scripts/main/server.essentials/caddy.sh | bash``

In CaddyFile:

* nano /etc/caddy/Caddyfile

```
#(cors) {
#       @origin{args.0} header Origin {args.0}
#       header @origin{args.0} Access-Control-Allow-Origin "{args.0}"
#       header Access-Control-Allow-Headers "*"
#       header Access-Control-Allow-Methods "HEAD, GET, POST, PUT, PATCH, DELETE, OPTIONS"
#       header Access-Control-Allow-Credentials true
#}

subdomain.example.com {
    #import cors "https://example.com"
    #import cors "http://127.0.0.1:8000"

    reverse_proxy / 127.0.0.1:3000
    log {
        output file /var/log/caddy/subdomain.example.com.access.log {
            roll_size 3MiB
            roll_keep 5
            roll_keep_for 48h
        }
        format console
    }
    encode gzip zstd

    tls email@example.com {
        protocols tls1.2 tls1.3
    }
}
website.example.com {
    root /var/www/html
    encode gzip zstd
    fastcgi / /run/php/php7.0-fpm.sock php
    rewrite {
        if {path} not_match ^\/wp-admin
        to {path} {path}/ /index.php?_url={uri}
    }
    log {
        output file /var/log/caddy/website.example.com.access.log {
            roll_size 3MiB
            roll_keep 5
            roll_keep_for 48h
        }
        format console
    }
    tls email@example.com {
        protocols tls1.2 tls1.3
    }
}
```

next after setup

**caddy restart**
sudo systemctl restart caddy

**caddy status**
sudo systemctl status caddy
