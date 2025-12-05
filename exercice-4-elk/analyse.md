# Analyse Détaillée - Exercice 4 : ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)

## Vue d'Ensemble

**Objectif** : Déboguer une stack ELK complète pour la collecte, le traitement et la visualisation de logs.

**Complexité** : Niveau Avancé ⭐⭐⭐⭐

**Services** : 
- Elasticsearch 8.11.0 (moteur de recherche et stockage)
- Logstash 8.11.0 (traitement et enrichissement des logs)
- Kibana 8.11.0 (visualisation et dashboards)
- Filebeat 8.11.0 (collecteur de logs légers)

**Bugs Identifiés** : 14 problèmes critiques et de performance

---

## 🐛 Bug #1 : Version Docker Compose Obsolète

### Symptômes
```yaml
version: '3.8'
```
- Warning lors de `docker compose up`
- Syntaxe dépréciée depuis Docker Compose v2

### Diagnostic
La directive `version` n'est plus nécessaire et génère des avertissements inutiles.

### Solution
**SUPPRIMER** complètement la ligne `version: '3.8'`

### Impact
- ✅ Pas de warnings
- ✅ Code moderne et propre

---

## 🐛 Bug #2 : Absence de Réseau Dédié

### Symptômes
```yaml
services:
  elasticsearch:
    # Pas de configuration réseau
  logstash:
    # Pas de configuration réseau
  # etc...
```
- Services sur le réseau bridge par défaut
- Pas d'isolation réseau
- Communication non sécurisée

### Diagnostic
Sans réseau personnalisé, la stack ELK n'est pas isolée des autres conteneurs sur l'hôte.

### Solution
```yaml
networks:
  elk-network:
    driver: bridge

services:
  elasticsearch:
    networks:
      - elk-network
  logstash:
    networks:
      - elk-network
  kibana:
    networks:
      - elk-network
  filebeat:
    networks:
      - elk-network
```

### Impact
- ✅ Isolation réseau complète
- ✅ Communication sécurisée entre services ELK
- ✅ Pas d'accès externe non autorisé

---

## 🐛 Bug #3 : Pas de Health Checks

### Symptômes
```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
  # Pas de healthcheck

logstash:
  # Pas de healthcheck

kibana:
  # Pas de healthcheck
```
- Services démarrent dans le désordre
- Kibana/Logstash tentent de se connecter avant qu'Elasticsearch soit prêt
- Erreurs de connexion massives au démarrage

### Diagnostic
Elasticsearch met ~60s à démarrer, Kibana ~90s. Sans health checks, impossible de garantir un démarrage orchestré.

### Solution

#### Elasticsearch Health Check
```yaml
elasticsearch:
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 5
    start_period: 60s
```
- Endpoint `/_cluster/health` : Status du cluster ES
- `start_period: 60s` : Temps d'initialisation nécessaire

#### Logstash Health Check
```yaml
logstash:
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:9600/_node/stats || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 5
    start_period: 60s
```
- Endpoint `/_node/stats` : Monitoring API Logstash
- Port 9600 : API de monitoring

#### Kibana Health Check
```yaml
kibana:
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 5
    start_period: 90s
```
- Endpoint `/api/status` : Status API Kibana
- `start_period: 90s` : Kibana est lent au démarrage

### Impact
- ✅ Démarrage fiable et orchestré
- ✅ Pas d'erreurs de connexion
- ✅ Monitoring de santé des services

---

## 🐛 Bug #4 : depends_on Simple Sans Condition

### Symptômes
```yaml
logstash:
  depends_on:
    - elasticsearch  # Simple dependency

kibana:
  depends_on:
    - elasticsearch  # Simple dependency

filebeat:
  depends_on:
    - elasticsearch
    - logstash
```
- Logstash/Kibana démarrent avant qu'Elasticsearch soit prêt
- Filebeat démarre avant que Logstash soit prêt
- **Erreurs massives** : `Connection refused [elasticsearch:9200]`

### Diagnostic
`depends_on` simple ne garantit que l'ordre de création des conteneurs, pas leur état "ready".

### Solution
```yaml
logstash:
  depends_on:
    elasticsearch:
      condition: service_healthy

kibana:
  depends_on:
    elasticsearch:
      condition: service_healthy

filebeat:
  depends_on:
    elasticsearch:
      condition: service_healthy
    logstash:
      condition: service_healthy
```

### Impact
- ✅ Chaque service attend que ses dépendances soient healthy
- ✅ Démarrage séquentiel correct : ES → Logstash/Kibana → Filebeat
- ✅ Pas de retry inutiles

---

## 🐛 Bug #5 : Ports Hardcodés

### Symptômes
```yaml
elasticsearch:
  ports:
    - "9200:9200"  # Hardcodé
    - "9300:9300"

logstash:
  ports:
    - "5044:5044"
    - "5000:5000/tcp"
    - "5000:5000/udp"

kibana:
  ports:
    - "5601:5601"
```
- Impossible de changer les ports sans éditer le YAML
- Conflit potentiel si ports déjà utilisés

### Diagnostic
Les ports d'exposition doivent être configurables via variables d'environnement.

### Solution
```yaml
elasticsearch:
  ports:
    - "${ELASTICSEARCH_PORT}:9200"

logstash:
  ports:
    - "${LOGSTASH_BEATS_PORT}:5044"
    - "${LOGSTASH_TCP_PORT}:5000/tcp"
    - "${LOGSTASH_UDP_PORT}:5000/udp"

kibana:
  ports:
    - "${KIBANA_PORT}:5601"
```

Avec `.env` :
```bash
ELASTICSEARCH_PORT=9200
LOGSTASH_BEATS_PORT=5044
LOGSTASH_TCP_PORT=5000
LOGSTASH_UDP_PORT=5000
KIBANA_PORT=5601
```

### Impact
- ✅ Configuration flexible
- ✅ Évite les conflits de ports
- ✅ Multi-instances possibles

---

## 🐛 Bug #6 : Variables Mémoire Hardcodées

### Symptômes
```yaml
elasticsearch:
  environment:
    - ES_JAVA_OPTS=-Xms512m -Xmx512m  # Hardcodé

logstash:
  environment:
    - LS_JAVA_OPTS=-Xmx256m -Xms256m  # Hardcodé
```
- Impossible d'ajuster la mémoire selon l'environnement
- 512m peut être insuffisant pour Elasticsearch en production

### Diagnostic
La mémoire JVM doit être configurable selon les ressources disponibles.

### Solution
```yaml
elasticsearch:
  environment:
    - ES_JAVA_OPTS=-Xms${ES_MEMORY} -Xmx${ES_MEMORY}

logstash:
  environment:
    - LS_JAVA_OPTS=-Xmx${LOGSTASH_MEMORY} -Xms${LOGSTASH_MEMORY}
```

Avec `.env` :
```bash
ES_MEMORY=1g
LOGSTASH_MEMORY=512m
```

### Recommandations Mémoire
- **Dev** : ES 512m-1g, Logstash 256m-512m
- **Prod** : ES 2g-4g+, Logstash 1g-2g

### Impact
- ✅ Mémoire ajustable sans éditer YAML
- ✅ Optimisation par environnement

---

## 🐛 Bug #7 : Pas de Container Names

### Symptômes
```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
  # Pas de container_name
```
- Noms auto-générés : `exercice-4-elk-elasticsearch-1`
- Difficile à identifier dans `docker ps`

### Diagnostic
Les container names explicites facilitent l'administration et le debugging.

### Solution
```yaml
elasticsearch:
  container_name: elk-elasticsearch

logstash:
  container_name: elk-logstash

kibana:
  container_name: elk-kibana

filebeat:
  container_name: elk-filebeat
```

### Impact
- ✅ Identification claire
- ✅ Commandes docker plus simples
- ✅ Logs facilement traçables

---

## 🐛 Bug #8 : Pas de Restart Policies

### Symptômes
```yaml
elasticsearch:
  # Pas de restart policy

logstash:
  # Pas de restart policy
```
- Services ne redémarrent pas après un crash
- Pas de reprise après reboot serveur

### Diagnostic
En production, les services ELK doivent redémarrer automatiquement.

### Solution
```yaml
elasticsearch:
  restart: unless-stopped

logstash:
  restart: unless-stopped

kibana:
  restart: unless-stopped

filebeat:
  restart: unless-stopped
```

### Impact
- ✅ Haute disponibilité
- ✅ Reprise automatique après incident

---

## 🐛 Bug #9 : Pas d'ulimits pour Elasticsearch (CRITIQUE!)

### Symptômes
```yaml
elasticsearch:
  # Pas d'ulimits configurés
```
- **Erreur au démarrage** : `max virtual memory areas vm.max_map_count [65530] is too low`
- Elasticsearch refuse de démarrer ou crashe sous charge
- **Performance dégradée** avec trop de fichiers ouverts

### Diagnostic
Elasticsearch nécessite des limites système spécifiques pour fonctionner correctement :
1. **memlock** : Verrouillage mémoire pour éviter le swap
2. **nofile** : Nombre de fichiers ouverts (indices, shards)

### Solution
```yaml
elasticsearch:
  ulimits:
    memlock:
      soft: -1
      hard: -1
    nofile:
      soft: 65536
      hard: 65536
```

### Explication
- `memlock: -1` : Illimité (permet le verrouillage mémoire)
- `nofile: 65536` : 65k fichiers ouverts (suffisant pour gros clusters)

### Note Système
Sur l'hôte, il faut aussi :
```bash
sudo sysctl -w vm.max_map_count=262144
```

### Impact
- ✅ Elasticsearch démarre correctement
- ✅ Performance optimale
- ✅ Pas de crash sous charge

---

## 🐛 Bug #10 : Pas de bootstrap.memory_lock

### Symptômes
```yaml
elasticsearch:
  environment:
    - discovery.type=single-node
    - ES_JAVA_OPTS=-Xms512m -Xmx512m
    # Manque bootstrap.memory_lock=true
```
- Mémoire Elasticsearch peut être swappée sur disque
- **Performance catastrophique** si swap activé
- Latence des requêtes x100

### Diagnostic
Le swap est le cauchemar d'Elasticsearch. Il faut verrouiller la mémoire en RAM.

### Solution
```yaml
elasticsearch:
  environment:
    - bootstrap.memory_lock=true
```

Combiné avec :
```yaml
ulimits:
  memlock:
    soft: -1
    hard: -1
```

### Impact
- ✅ Mémoire JVM verrouillée en RAM
- ✅ Performance maximale
- ✅ Latence prévisible

---

## 🐛 Bug #11 : Volumes Read-Only Manquants

### Symptômes
```yaml
logstash:
  volumes:
    - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml
    - ./logstash/pipeline:/usr/share/logstash/pipeline
    # Pas de :ro (read-only)

filebeat:
  volumes:
    - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml
    - /var/log:/var/log:ro  # Celui-ci est OK
```
- Conteneurs peuvent modifier les fichiers de configuration
- **Risque de sécurité** : corruption des configs
- Pas de protection contre les modifications accidentelles

### Diagnostic
Les fichiers de configuration montés doivent être en lecture seule.

### Solution
```yaml
logstash:
  volumes:
    - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
    - ./logstash/pipeline:/usr/share/logstash/pipeline:ro

filebeat:
  volumes:
    - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
```

### Impact
- ✅ Protection des configurations
- ✅ Sécurité renforcée
- ✅ Immuabilité des configs

---

## 🐛 Bug #12 : Volume logstash_data Manquant

### Symptômes
```yaml
logstash:
  volumes:
    - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml
    - ./logstash/pipeline:/usr/share/logstash/pipeline
    # Pas de volume pour /usr/share/logstash/data
```
- Données Logstash non persistantes (plugins, queues)
- Perte des queues persistentes après redémarrage
- Réinstallation des plugins à chaque restart

### Diagnostic
Logstash utilise `/usr/share/logstash/data` pour :
- Persistent queues (PQ)
- Dead letter queues (DLQ)
- Plugins installés

### Solution
```yaml
logstash:
  volumes:
    - logstash_data:/usr/share/logstash/data

volumes:
  logstash_data:
    driver: local
```

### Impact
- ✅ Queues persistantes
- ✅ Pas de perte de données
- ✅ Plugins conservés

---

## 🐛 Bug #13 : Volume kibana_data Manquant

### Symptômes
```yaml
kibana:
  # Pas de volume pour /usr/share/kibana/data
```
- Dashboards et visualisations perdus après redémarrage
- Configuration Kibana non persistante
- Saved objects supprimés

### Diagnostic
Kibana stocke dans `/usr/share/kibana/data` :
- Dashboards
- Visualizations
- Saved searches
- Index patterns

### Solution
```yaml
kibana:
  volumes:
    - kibana_data:/usr/share/kibana/data

volumes:
  kibana_data:
    driver: local
```

### Impact
- ✅ Dashboards persistants
- ✅ Configuration conservée
- ✅ Pas de réinitialisation

---

## 🐛 Bug #14 : Filebeat user root Manquant

### Symptômes
```yaml
filebeat:
  image: docker.elastic.co/beats/filebeat:8.11.0
  # Pas de user: root
  volumes:
    - /var/log:/var/log:ro
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
```
- **Erreur** : `Permission denied` sur `/var/log`, `/var/run/docker.sock`
- Filebeat ne peut pas lire les logs système
- Pas d'accès au Docker socket

### Diagnostic
Filebeat a besoin de privilèges root pour accéder aux logs système et au Docker socket.

### Solution
```yaml
filebeat:
  user: root
  volumes:
    - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
    - filebeat_data:/usr/share/filebeat/data
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
  command: filebeat -e -strict.perms=false
```

### Explications
- `user: root` : Nécessaire pour accès système
- `-strict.perms=false` : Permet les permissions 644 sur le config
- Volume `filebeat_data` : Persistance du registry

### Sécurité
En production, utiliser des capabilities spécifiques plutôt que root complet.

### Impact
- ✅ Filebeat peut lire les logs
- ✅ Accès au Docker socket
- ✅ Collecte fonctionnelle

---

## 📊 Résumé des Corrections

| Bug | Catégorie | Gravité | Impact |
|-----|-----------|---------|--------|
| #1 - Version obsolète | Syntaxe | ⚠️ Moyenne | Warnings |
| #2 - Pas de réseau | Sécurité | 🔴 Haute | Isolation |
| #3 - Health checks absents | Fiabilité | 🔴 CRITIQUE | Erreurs démarrage |
| #4 - depends_on simple | Fiabilité | 🔴 CRITIQUE | Connexions échouées |
| #5 - Ports hardcodés | Configuration | ⚠️ Moyenne | Flexibilité |
| #6 - Mémoire hardcodée | Performance | ⚠️ Moyenne | Optimisation |
| #7 - Container names | Maintenabilité | 🟡 Basse | Lisibilité |
| #8 - Restart policies | Production | 🔴 Haute | Disponibilité |
| #9 - ulimits manquants | Performance | 🔴 CRITIQUE | Crash ES |
| #10 - memory_lock absent | Performance | 🔴 Haute | Swap/Latence |
| #11 - Volumes read-only | Sécurité | ⚠️ Moyenne | Protection |
| #12 - logstash_data | Persistance | ⚠️ Moyenne | Perte données |
| #13 - kibana_data | Persistance | ⚠️ Moyenne | Perte dashboards |
| #14 - Filebeat user root | Fonctionnel | 🔴 CRITIQUE | Permission denied |

### Statistiques
- **Total bugs** : 14
- **Critiques** : 4 (health checks, depends_on, ulimits, filebeat user)
- **Hautes** : 3 (réseau, restart, memory_lock)
- **Moyennes** : 6
- **Basses** : 1

---

## 🎯 Points Clés ELK Stack

### Pour Elasticsearch
- **ulimits obligatoires** (memlock + nofile)
- **bootstrap.memory_lock=true** pour éviter le swap
- **Health check sur /_cluster/health**
- **Mémoire** : Minimum 1g, recommandé 2-4g prod
- **Port 9200** : API REST
- **Port 9300** : Communication inter-nodes (pas nécessaire en single-node)

### Pour Logstash
- **Volume data obligatoire** pour persistent queues
- **Health check sur :9600/_node/stats**
- **Dépendance strict d'Elasticsearch**
- **Configurations read-only**
- **Port 5044** : Beats input
- **Port 5000** : TCP/UDP input

### Pour Kibana
- **Volume data pour dashboards**
- **Health check sur :5601/api/status**
- **Start period 90s** (initialisation longue)
- **Dépendance d'Elasticsearch**

### Pour Filebeat
- **user: root obligatoire**
- **-strict.perms=false** dans la commande
- **Volumes read-only pour configs**
- **Volume data pour registry**
- **Dépendances : Elasticsearch + Logstash**

---

## 🚀 Validation

Pour valider les corrections :

```bash
cd exercice-4-elk
chmod +x test.sh
./test.sh
```

Le script vérifie :
- ✅ Structure des fichiers
- ✅ Syntaxe YAML
- ✅ Variables d'environnement
- ✅ Configuration des 4 services
- ✅ Health checks et ulimits
- ✅ Volumes et persistance
- ✅ Security best practices
- ✅ Tous les bugs corrigés

---

**Date d'analyse** : 2024-12-05  
**Niveau de difficulté** : Avancé ⭐⭐⭐⭐  
**Temps de résolution estimé** : 60-90 minutes  
**Stack Version** : Elastic Stack 8.11.0
