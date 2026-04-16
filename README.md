# 📡 Monitoring Stack — Grafana + Prometheus + Zabbix + Loki

Stack completa de monitoramento e segurança para redes locais e hosts remotos, construída com Docker Compose, deploy automatizado e integração com systemd.

| Componente | Função |
|-----------|------|
| **Node Exporter** | Métricas do sistema (CPU, memória, disco, rede) |
| **Prometheus** | Coleta e armazenamento de métricas (time-series) |
| **Grafana** | Visualização unificada (métricas, logs, dados Zabbix) |
| **Zabbix Server** | Monitoramento de rede e hosts remotos (com/sem agente) |
| **Zabbix Web** | Interface de administração do Zabbix |
| **Zabbix Agent 2** | Monitoramento local do host + métricas Docker |
| **Loki** | Agregação e indexação de logs |
| **Promtail** | Coleta de logs (syslog, auth, kernel, containers Docker) |

---

![](assets/panel.png)

---

## ✨ Funcionalidades

* Visualização completa de métricas do sistema via Grafana
* Monitoramento de CPU, memória, disco e rede com Node Exporter
* Monitoramento de rede local e hosts remotos com Zabbix (com e sem agente)
* Agregação centralizada de logs com Loki + Promtail
* Detecção de eventos de segurança (logins falhados, escalação de privilégios, comandos sudo)
* Coleta e análise de logs de containers Docker
* Provisioning automático de dashboards, datasources e alertas
* Deploy automatizado com serviço systemd para início no boot
* Armazenamento persistente para todos os serviços

---

## 🏗 Arquitetura

```
┌──────────────────── Docker Compose (single host) ────────────────────┐
│                                                                       │
│  ┌─────────────┐   scrape   ┌─────────────────┐                      │
│  │Node Exporter├───────────►│   Prometheus     │                      │
│  └─────────────┘            └────────┬────────┘                      │
│                                      │                                │
│  ┌─────────────┐   push     ┌───────┴────────┐    ┌──────────────┐  │
│  │  Promtail   ├───────────►│     Loki       ├───►│   Grafana    │  │
│  └──────┬──────┘            └────────────────┘    │  (unified    │  │
│         │ reads                                    │   dashboard) │  │
│    /var/log/*                                      └──────┬───────┘  │
│    Docker logs                                            │          │
│                                                           │ Zabbix   │
│  ┌──────────────┐          ┌──────────────┐              │ plugin   │
│  │ Zabbix Agent ├─────────►│Zabbix Server ├──────────────┘          │
│  └──────────────┘          └──────┬───────┘                          │
│                                   │                                   │
│  ┌──────────────┐          ┌──────┴───────┐                          │
│  │  PostgreSQL  │◄─────────┤  Zabbix Web  │                          │
│  └──────────────┘          └──────────────┘                          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

Hosts remotos (LAN):
  • Com agente:    Zabbix Agent → Zabbix Server (checks ativos/passivos)
  • Sem agente:    Zabbix Server → host (ICMP ping, TCP port, SNMP)
```

---

## 📦 Requisitos

* Debian ou Ubuntu (testado em Debian 12+)
* **6 GB RAM mínimo** (8 GB+ recomendado)
* Privilégios sudo
* git, docker, docker-compose (v1 ou v2)
* openssl (para geração automática de senhas)

---

## 🚀 Instalação

Instale os pacotes necessários:

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose openssl
```

Clone o repositório:

```bash
git clone https://github.com/MatheusFLB/monitoring-project.git
cd monitoring-project
```

Torne o script de deploy executável:

```bash
chmod +x deploy.sh
```

Execute o deploy (como root):

```bash
sudo ./deploy.sh
```

O script irá:
* Verificar recursos disponíveis no sistema
* Solicitar senhas, portas e timezone interativamente
* Gerar automaticamente a senha do banco Zabbix
* Criar diretórios persistentes com permissões corretas
* Iniciar todos os containers
* Criar e habilitar serviço systemd para boot automático

---

## 🌐 Pontos de Acesso

| Serviço | URL Padrão | Credenciais |
|---------|-------------|-------------|
| **Grafana** | `http://localhost:3000` | admin / *(definida no deploy)* |
| **Prometheus** | `http://localhost:9090` | — |
| **Zabbix Web** | `http://localhost:8080` | Admin / zabbix |
| **Loki API** | `http://localhost:3100` | — |

> ⚠️ Altere a senha padrão do Zabbix imediatamente após o primeiro login.

---

## 🧠 Como Funciona

### Métricas (Prometheus + Node Exporter)
* **Node Exporter** exporta métricas de CPU, memória, disco e rede do host central
* **Prometheus** coleta métricas a cada 15 segundos e armazena com retenção de 30 dias
* Visualizado no Grafana via datasource Prometheus provisionado automaticamente

### Monitoramento de Rede e Hosts (Zabbix)
* **Zabbix Server** gerencia monitoramento de hosts locais e remotos
* **Zabbix Agent 2** roda no host central para métricas detalhadas + monitoramento Docker
* Hosts remotos podem ser monitorados de duas formas:
  * **Com agente** — Instale o Zabbix Agent nos hosts remotos apontando para o IP do servidor
  * **Sem agente** — Configure ICMP ping, checks TCP ou SNMP via Zabbix Web
* Dados do Zabbix são visualizados no Grafana via plugin Zabbix ou na interface nativa

### Logs e Eventos de Segurança (Loki + Promtail)
* **Promtail** coleta logs de:
  * `/var/log/syslog` — eventos do sistema
  * `/var/log/auth.log` — eventos de autenticação
  * `/var/log/kern.log` — mensagens do kernel
  * Logs de containers Docker via socket
* **Loki** indexa e armazena logs com retenção de 30 dias
* Eventos de segurança são classificados automaticamente:
  * Logins falhados/bem-sucedidos, comandos sudo, usuários inválidos, sessões
* Logs são classificados com labels operacionais (`job`, `host`, `level`, `action`) para filtragem no Grafana
* Queries via LogQL no Grafana usando o datasource Loki

### Central de Logs (Dashboard)
* Dashboard Grafana provisionado para análise centralizada de logs
* Filtros por host, origem do log e nível (`INFO`, `WARNING`, `ERROR`)
* Gráficos de tendência de volume por severidade ao longo do tempo
* Lista de alertas ativos e alerta gerenciado para picos de `ERROR`

---

## 📡 Adicionando Hosts Remotos

### Com Zabbix Agent (recomendado para hosts gerenciados)

Instale o Zabbix Agent no host remoto:

```bash
# Debian/Ubuntu
wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo apt update && sudo apt install -y zabbix-agent2
```

Configure o agente (`/etc/zabbix/zabbix_agent2.conf`):

```ini
Server=<IP_DO_HOST_MONITORAMENTO>
ServerActive=<IP_DO_HOST_MONITORAMENTO>
Hostname=<NOME_UNICO_DO_HOST>
```

Reinicie o agente:

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable zabbix-agent2
```

Adicione o host em **Zabbix Web → Data collection → Hosts → Create host**.

### Sem Agente (ICMP/TCP/SNMP)

Em **Zabbix Web → Data collection → Hosts → Create host**:
1. Defina o endereço IP do host
2. Vincule o template **ICMP Ping** (ou **Generic SNMP** para dispositivos SNMP)
3. O Zabbix Server executará os checks diretamente — sem agente necessário

---

## 🔐 Notas de Segurança

* **Credenciais:**
  * `.env` contém todas as senhas — protegido com modo `600` e excluído do Git
  * Senha do banco Zabbix é gerada automaticamente com `openssl rand`
  * Altere a senha padrão do Zabbix Web (`Admin / zabbix`) após o primeiro login

* **Volumes persistentes contêm dados sensíveis:**
  * `data/grafana/` — usuários, hashes de senha, sessões
  * `data/zabbix-db/` — banco completo incluindo inventário de hosts
  * `data/loki/` — logs agregados (podem conter eventos sensíveis do sistema)

* **Portas expostas:**
  * Todos os serviços fazem bind em `0.0.0.0` por padrão — restrinja com firewall se exposto à internet
  * Porta 10051 do Zabbix Server deve ser acessível pelos agentes remotos

* **Boas práticas:**
  * Use firewall (`ufw`, `iptables`) para restringir acesso a IPs confiáveis
  * Faça backup regular dos volumes com arquivos criptografados
  * Considere um reverse proxy (Nginx) com TLS para ambientes de produção
  * Não exponha o Docker socket a containers não confiáveis

---

## 📁 Estrutura do Projeto

```
monitoring-project/
├── docker-compose.yml                # Orquestração de todos os serviços
├── deploy.sh                         # Script de deploy automatizado
├── .env.example                      # Template de variáveis de ambiente
├── .gitignore                        # Exclusões do Git
├── .gitattributes                    # Configuração de linguagem para GitHub
├── README.md                         # Esta documentação
│
├── config/                           # ── Configurações dos serviços ──
│   ├── prometheus/
│   │   └── prometheus.yml            # Targets de coleta de métricas
│   ├── loki/
│   │   └── loki.yml                  # Servidor de agregação de logs
│   ├── promtail/
│   │   └── promtail.yml              # Regras de coleta e classificação de logs
│   └── grafana/
│       └── provisioning/
│           ├── datasources/
│           │   └── datasources.yml   # Fontes de dados (Prometheus, Loki, Zabbix)
│           ├── dashboards/
│           │   ├── dashboards.yml    # Configuração do provider de dashboards
│           │   ├── node-exporter-full.json   # Dashboard: métricas do host
│           │   ├── monitoring-overview.json  # Dashboard: painel principal
│           │   └── logs-central.json         # Dashboard: central de logs
│           ├── alerting/
│           │   └── error_logs.yml    # Regras de alerta (pico de ERROR)
│           └── plugins/
│               └── plugins.yml       # Habilitação de plugins (Zabbix app)
│
├── data/                             # ── Dados persistentes (gitignored) ──
│   ├── grafana/                      # Estado do Grafana (users, sessions)
│   ├── prometheus/                   # TSDB do Prometheus (métricas)
│   ├── loki/                         # Chunks e índices do Loki (logs)
│   ├── zabbix-db/                    # Banco PostgreSQL do Zabbix
│   └── zabbix-server/               # Estado do Zabbix Server
│
├── systemd/
│   └── monitoring-app.service.template  # Template do serviço systemd
│
└── assets/
    └── panel.png                     # Screenshot do dashboard
```

---

## 🛠 Casos de Uso Típicos

* Monitoramento de servidores físicos ou virtuais em rede local
* Monitoramento de disponibilidade de rede (ICMP, TCP, SNMP) via Zabbix
* Visualização em tempo real de métricas de infraestrutura
* Análise centralizada de logs de segurança (logins falhados, intrusões, sudo)
* Monitoramento de saúde e logs de containers Docker
* Alertas e dashboards para equipes DevOps ou SysAdmin
* Base para expansão com exporters adicionais e templates Zabbix

---

## ⚠️ Considerações de Recursos

A stack roda 9 containers. Em hardware limitado (dual-core, 6 GB RAM):
* Consumo típico: ~3–4 GB RAM em idle
* Cache do Zabbix DB configurado conservadoramente (`ZBX_CACHESIZE=32M`)
* Retenção do Prometheus: 30 dias — monitore o uso de disco
* Retenção do Loki: 30 dias com compactação automática
* Se recursos forem insuficientes, pare o serviço menos crítico temporariamente:
  ```bash
  docker-compose stop loki promtail   # Pausar coleta de logs
  docker-compose stop zabbix-web      # Pausar UI do Zabbix (server continua coletando)
  ```

---

## 👤 Autor

Projeto criado por **[Matheus Bissoli](https://www.linkedin.com/in/matheusbissoli/)** — stack completa de monitoramento e segurança para infraestrutura Linux.
