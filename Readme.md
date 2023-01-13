# Implantar Laravel com Docker em produção

### Requisitos

- docker
- docker-compose


## Configuração para ambiente sem certificado:

1. Altere o arquivo docker/conf.d/nginx.conf para:

``` 
server {
    listen 80;

    index index.php index.html;

    root /var/www/public;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location / {
        try_files $uri $uri/ /index.php?$query_string;
        gzip_static on;
    }

    fastcgi_read_timeout 300;
    proxy_read_timeout 300;
}
``` 
2. Altere o arquivo docker-compose.prod.yml para: 
```
version: '3'

services:
  app:
    build:
      args:
       user: ubuntu
       uid: 1000
      context: .
      dockerfile: Dockerfile
    image: app
    container_name: app
    restart: unless-stopped
    tty: true
    environment:
      SERVICE_NAME: app
      SERVICE_TAGS: dev
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php.ini:/usr/local/etc/php/conf.d/php.ini
    networks:
      - app

  nginx:
      image: nginx:alpine
      container_name: nginx
      restart: unless-stopped
      tty: true
      ports:
        - "80:80"
        - "443:443"
      volumes:
        - ./:/var/www/
        - ./docker/conf.d/:/etc/nginx/conf.d/
      networks:
        - app
networks:
  app:
    driver: bridge

```

3. Rode o comando: 
```
docker-compose -f docker-compose.prod.yml up -d
```

## Configuração para ambiente com certificado SSL:

1. Antes de executar o comando Certbot, ative o contêiner Nginx no Docker para garantir que o site esteja funcionando. </br>
Altere o arquivo docker/conf.d/nginx.conf temporariamente para: 
```
server {
    listen 80;

    index index.php index.html;

    root /var/www/public;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;

    }
    location / {
        try_files $uri $uri/ /index.php?$query_string;
        gzip_static on;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    fastcgi_read_timeout 300;
    proxy_read_timeout 300;
}
``` 
2. Altere o arquivo docker-compose.prod.yml para: 
```
version: '3'

services:
  app:
    build:
      args:
       user: ubuntu
       uid: 1000
      context: .
      dockerfile: Dockerfile
    image: app
    container_name: app
    restart: unless-stopped
    tty: true
    environment:
      SERVICE_NAME: app
      SERVICE_TAGS: dev
    working_dir: /var/www
    volumes:
      - ./:/var/www
      - ./docker/php.ini:/usr/local/etc/php/conf.d/php.ini
    networks:
      - app

  nginx:
      image: nginx:alpine
      container_name: nginx
      restart: unless-stopped
      tty: true
      ports:
        - "80:80"
        - "443:443"
      volumes:
        - ./:/var/www/
        - ./docker/conf.d/:/etc/nginx/conf.d/
        - ./docker/certbot/www:/var/www/certbot
        - ./docker/certbot/conf:/etc/letsencrypt
      networks:
        - app
      command: "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"
  certbot:
      image: certbot/certbot
      volumes:
        - ./docker/certbot/conf:/etc/letsencrypt
        - ./docker/certbot/www:/var/www/certbot
      entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
networks:
  app:
    driver: bridge
```
3. Execute os containers:
```
docker-compose -f docker-compose.prod.yml up -d
```
#### Obs.: Verifique se o site está funcionando.

4. entre na pasta docker: 
```
cd docker
```

5. Edite o script init-letsencrypt.sh para adicionar seu(s) domínio(s) e seu endereço de e-mail.

6. execute o script init-letsencrypt.sh:
```
chmod +x init-letsencrypt.sh
```
e
```
sudo ./init-letsencrypt.sh
```

Tudo está no lugar agora. Os certificados iniciais foram obtidos e nossos contêineres estão prontos para serem lançados.

7. Altere o arquivo docker/conf.d/nginx.conf para redirecionar as requisições http para https do seu dominio. 
```
server {
    listen 80;
    server_name meudominio.com.br;
    server_tokens off;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
       return 301 https://meudominio.com.br$request_uri;
    }
}

server {
    listen 443 default_server ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate /etc/letsencrypt/live/meudominio.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/meudominio.com.br/privkey.pem;

    index index.php index.html;

    root /var/www/public;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;

    }
    location / {
        try_files $uri $uri/ /index.php?$query_string;
        gzip_static on;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    fastcgi_read_timeout 300;
    proxy_read_timeout 300;
}

```

8. Execute os containers:
```
docker-compose -f docker-compose.prod.yml up -d
```


