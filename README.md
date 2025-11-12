# PROJECT DEDICATE TO MONITORING DEVICES
## Ajustar permissões
```
# permissão para o Grafana escrever nos volumes
sudo chown -R 472:472 grafana_data
sudo chown -R 472:472 grafana_provisioning

# permissão para o Prometheus escrever
sudo chown -R 65534:65534 prometheus_data
```
# para tornar executável assim que o computador ligar, seguir o passo a passo
## Usando systemd
### Crie o arquivo de serviço
```
sudo nano /etc/systemd/system/monitoring-app.service
```
### conteúdo do arquivo /etc/systemd/system/monitoring-app.service
```
[Unit]
Description=Docker Compose Application Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/caminho/completo/para/sua/pasta/do/projeto
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```
### Substitua /caminho/completo/para/sua/pasta/do/projeto pelo caminho real da sua pasta
```
cd /pasta/do/seu/projeto
pwd
# Copie o resultado que aparecer
```
### Verificar caminho do docker-compose
```
which docker-compose
# Se for /usr/bin/docker-compose, ajuste no arquivo de serviço
```
## Ativar o serviço
```
# Recarregar systemd
sudo systemctl daemon-reload

# Habilitar para iniciar no boot
sudo systemctl enable monitoring-app.service

# Iniciar
sudo systemctl start monitoring-app.service

# Verificar status
sudo systemctl status monitoring-app.service
```
# importar o painel de id "1860" no grafana para ter um dashboard completo das métricas do node exporter
