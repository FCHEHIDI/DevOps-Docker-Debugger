# Analyse Détaillée - Exercice 5 : Kong Gateway + Microservices

## Vue d'Ensemble

**Objectif** : Déboguer une architecture API Gateway avec Kong et microservices (User, Product, Order) + Redis.

**Complexité** : Niveau Expert ⭐⭐⭐⭐⭐

**Services** : 
- Kong Gateway 3.4 (API Gateway)
- PostgreSQL 13 (DB Kong)
- Kong Migration (init DB)
- User Service (microservice Nginx)
- Product Service (microservice Nginx)
- Order Service (microservice Nginx)
- Redis Alpine (cache)

**Bugs Identifiés** : 16 problèmes critiques d'architecture et de sécurité

---

## 🐛 Bug #1 : Version Docker Compose Obsolète

### Symptômes
```yaml
version: '3.8'
```
- Warning lors de `docker compose up`
- Syntaxe dépréciée depuis Docker Compose v2

### Diagnostic
La directive `version` n'est plus nécessaire et génère des avertissements.

### Solution
**SUPPRIMER** complètement la ligne `version: '3.8'`

---

## 🐛 Bug #2 : Absence de Réseau Dédié

### Symptômes
```yaml
services:
  kong-database:
    # Pas de configuration réseau
  kong:
    # Pas de configuration réseau
  user-service:
    # Pas de configuration réseau
```
- Tous les services sur le réseau bridge par défaut
- Pas d'isolation réseau
- **Sécurité compromise**

### Diagnostic
Sans réseau personnalisé, impossible d'isoler la stack Kong des autres conteneurs et de contrôler la communication inter-services.

### Solution
```yaml
networks:
  kong-network:
    driver: bridge

services:
  kong-database:
    networks:
      - kong-network
  kong:
    networks:
      - kong-network
  # ... tous les services
```

### Impact
- ✅ Isolation complète de la stack
- ✅ Communication sécurisée
- ✅ Résolution DNS interne

---

## 🐛 Bug #3 : Pas de Health Checks

### Symptômes
```yaml
kong-database:
  image: postgres:13
  # Pas de healthcheck

kong:
  image: kong:3.4
  # Pas de healthcheck

user-service:
  image: nginx:alpine
  # Pas de healthcheck
```
- Kong démarre avant que PostgreSQL soit prêt
- Migration échoue silencieusement
- Services démarrent dans le désordre

### Diagnostic
Une stack API Gateway nécessite un démarrage orchestré strict :
1. PostgreSQL ready
2. Migration complete
3. Kong ready
4. Microservices ready

### Solution

#### PostgreSQL Health Check
```yaml
kong-database:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
```

#### Kong Health Check
```yaml
kong:
  healthcheck:
    test: ["CMD", "kong", "health"]
    interval: 10s
    timeout: 10s
    retries: 10
    start_period: 40s
```

#### Microservices Health Check
```yaml
user-service:
  healthcheck:
    test: ["CMD", "wget", "-q", "--spider", "http://localhost/health"]
    interval: 10s
    timeout: 5s
    retries: 3
```

#### Redis Health Check
```yaml
redis:
  healthcheck:
    test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Impact
- ✅ 7 health checks pour orchestration complète
- ✅ Démarrage fiable à 100%

---

## 🐛 Bug #4 : depends_on Simple Sans Conditions

### Symptômes
```yaml
kong-migration:
  depends_on:
    - kong-database  # Simple dependency

kong:
  depends_on:
    - kong-migration  # Simple dependency
```
- Migration démarre avant que PostgreSQL soit prêt
- Kong démarre avant la fin de la migration
- **Erreurs de migration critiques**

### Diagnostic
Kong nécessite une séquence stricte :
1. PostgreSQL healthy
2. Migration completed successfully (pas juste démarrée!)
3. Kong démarre

### Solution
```yaml
kong-migration:
  depends_on:
    kong-database:
      condition: service_healthy

kong:
  depends_on:
    kong-database:
      condition: service_healthy
    kong-migration:
      condition: service_completed_successfully
```

### Nouveauté
`service_completed_successfully` : Le service a terminé avec exit code 0 (migration réussie)

### Impact
- ✅ Migration garantie avant Kong
- ✅ Pas d'erreurs de schema

---

## 🐛 Bug #5 : Credentials Hardcodés (CRITIQUE!)

### Symptômes
```yaml
kong-database:
  environment:
    - POSTGRES_USER=kong
    - POSTGRES_DB=kong
    - POSTGRES_PASSWORD=kong  # ❌ DANGER!

kong:
  environment:
    - KONG_PG_USER=kong
    - KONG_PG_PASSWORD=kong  # ❌ DANGER!

redis:
  image: redis:alpine
  # ❌ Pas de password du tout!
```
- **Mot de passe "kong" en clair**
- Visible dans Git et Docker inspect
- Redis sans authentification
- **RISQUE DE SÉCURITÉ CRITIQUE**

### Diagnostic
Les credentials sont hardcodés dans le YAML, accessibles à tous.

### Solution
```yaml
kong-database:
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    POSTGRES_DB: ${POSTGRES_DB}

kong:
  environment:
    KONG_PG_USER: ${POSTGRES_USER}
    KONG_PG_PASSWORD: ${POSTGRES_PASSWORD}

redis:
  command: redis-server --requirepass ${REDIS_PASSWORD}
```

Avec `.env` :
```bash
POSTGRES_PASSWORD=kong_secure_password_123
REDIS_PASSWORD=redis_secure_password_123
```

### Impact
- ✅ Secrets dans .env (protégé par .gitignore)
- ✅ Redis avec authentification
- ✅ Sécurité renforcée

---

## 🐛 Bug #6 : Ports Hardcodés Partout

### Symptômes
```yaml
kong:
  ports:
    - "8000:8000"  # Proxy
    - "8443:8443"  # Proxy SSL
    - "8001:8001"  # Admin
    - "8444:8444"  # Admin SSL

user-service:
  ports:
    - "3001:80"

product-service:
  ports:
    - "3002:80"

order-service:
  ports:
    - "3003:80"

redis:
  ports:
    - "6379:6379"
```
- Impossible de changer les ports
- Conflits potentiels
- Pas de flexibilité

### Diagnostic
Tous les ports doivent être configurables via variables.

### Solution
```yaml
kong:
  ports:
    - "${KONG_PROXY_PORT}:8000"
    - "${KONG_PROXY_SSL_PORT}:8443"
    - "${KONG_ADMIN_PORT}:8001"
    - "${KONG_ADMIN_SSL_PORT}:8444"
```

**Note** : Les microservices NE DOIVENT PAS exposer de ports ! Ils doivent être accessibles uniquement via Kong (API Gateway pattern).

### Impact
- ✅ Ports configurables
- ✅ Architecture API Gateway respectée

---

## 🐛 Bug #7 : Pas de Container Names

### Symptômes
```yaml
kong-database:
  image: postgres:13
  # Pas de container_name

kong:
  image: kong:3.4
  # Pas de container_name
```
- Noms auto-générés complexes
- Difficile à identifier

### Diagnostic
Les container names facilitent l'administration.

### Solution
```yaml
kong-database:
  container_name: kong-postgres

kong-migration:
  container_name: kong-migration

kong:
  container_name: kong-gateway

user-service:
  container_name: user-service

product-service:
  container_name: product-service

order-service:
  container_name: order-service

redis:
  container_name: kong-redis
```

### Impact
- ✅ Identification claire
- ✅ Administration simplifiée

---

## 🐛 Bug #8 : Pas de Restart Policies

### Symptômes
```yaml
kong-database:
  # Pas de restart

kong:
  # Pas de restart
```
- Services ne redémarrent pas après crash
- Pas de reprise après reboot

### Diagnostic
En production, tous les services doivent redémarrer automatiquement.

### Solution
```yaml
kong-database:
  restart: unless-stopped

kong:
  restart: unless-stopped

user-service:
  restart: unless-stopped

# ... tous les services
```

### Exception
```yaml
kong-migration:
  restart: on-failure
```
Migration redémarre uniquement en cas d'échec.

### Impact
- ✅ Haute disponibilité
- ✅ Reprise automatique

---

## 🐛 Bug #9 : Kong-Migration Sans restart: on-failure

### Symptômes
```yaml
kong-migration:
  command: kong migrations bootstrap
  # Pas de restart policy
```
- Si la migration échoue (DB pas prête), elle ne retry pas
- Migration manuelle nécessaire

### Diagnostic
La migration peut échouer temporairement si PostgreSQL est lent à démarrer.

### Solution
```yaml
kong-migration:
  restart: on-failure
```

### Impact
- ✅ Retry automatique en cas d'échec
- ✅ Plus robuste

---

## 🐛 Bug #10 : Kong Sans condition: service_completed_successfully

### Symptômes
```yaml
kong:
  depends_on:
    - kong-migration  # Simple dependency
```
- Kong démarre dès que kong-migration démarre
- Ne attend pas que la migration soit TERMINÉE
- Kong peut démarrer avec schema incomplet

### Diagnostic
Il faut attendre que kong-migration soit completed successfully (exit 0).

### Solution
```yaml
kong:
  depends_on:
    kong-database:
      condition: service_healthy
    kong-migration:
      condition: service_completed_successfully
```

### Impact
- ✅ Kong démarre seulement après migration complète
- ✅ Schema toujours valide

---

## 🐛 Bug #11 : Volumes Non Read-Only

### Symptômes
```yaml
user-service:
  volumes:
    - ./services/user-service/nginx.conf:/etc/nginx/nginx.conf
    # Pas de :ro

product-service:
  volumes:
    - ./services/product-service/nginx.conf:/etc/nginx/nginx.conf
    - ./services/product-service/html:/usr/share/nginx/html
    # Pas de :ro
```
- Conteneurs peuvent modifier les configs
- Risque de corruption

### Diagnostic
Les configurations nginx doivent être en lecture seule.

### Solution
```yaml
user-service:
  volumes:
    - ./services/user-service/nginx.conf:/etc/nginx/nginx.conf:ro

product-service:
  volumes:
    - ./services/product-service/nginx.conf:/etc/nginx/nginx.conf:ro
```

### Impact
- ✅ Configs immuables
- ✅ Sécurité renforcée

---

## 🐛 Bug #12 : Services Exposés Directement (ANTI-PATTERN!)

### Symptômes
```yaml
user-service:
  ports:
    - "3001:80"  # ❌ Exposé directement!

product-service:
  ports:
    - "3002:80"  # ❌ Exposé directement!

order-service:
  ports:
    - "3003:80"  # ❌ Exposé directement!

redis:
  ports:
    - "6379:6379"  # ❌ Exposé directement!
```
- **Bypass complet de Kong!**
- Pas de rate limiting
- Pas d'authentification
- Pas de load balancing
- **ARCHITECTURE BRISÉE**

### Diagnostic
Dans une architecture API Gateway, les microservices NE DOIVENT JAMAIS être exposés directement. Tout doit passer par Kong.

### Solution
**SUPPRIMER** tous les ports exposés des microservices :
```yaml
user-service:
  # PAS de ports exposés
  networks:
    - kong-network

product-service:
  # PAS de ports exposés

order-service:
  # PAS de ports exposés

redis:
  # PAS de ports exposés (sauf debug)
```

### Accès correct
```
Client → Kong (port 8000) → user-service (interne)
Client → Kong (port 8000) → product-service (interne)
Client → Kong (port 8000) → order-service (interne)
```

### Impact
- ✅ Architecture API Gateway respectée
- ✅ Sécurité maximale
- ✅ Contrôle centralisé

---

## 🐛 Bug #13 : Redis Sans Password

### Symptômes
```yaml
redis:
  image: redis:alpine
  # Pas de command --requirepass
```
- Redis accessible sans authentification
- **RISQUE DE SÉCURITÉ MAJEUR**
- Données exposées

### Diagnostic
Redis doit toujours avoir un mot de passe en production.

### Solution
```yaml
redis:
  command: redis-server --requirepass ${REDIS_PASSWORD}
```

Avec `.env` :
```bash
REDIS_PASSWORD=redis_secure_password_123
```

### Impact
- ✅ Redis sécurisé
- ✅ Authentification obligatoire

---

## 🐛 Bug #14 : Format Environment Variables

### Symptômes
```yaml
kong-database:
  environment:
    - POSTGRES_USER=kong  # Format liste (-)
    - POSTGRES_DB=kong
```

### Diagnostic
Format `- KEY=value` est valide mais moins lisible que `KEY: value`.

### Solution
```yaml
kong-database:
  environment:
    POSTGRES_USER: ${POSTGRES_USER}
    POSTGRES_DB: ${POSTGRES_DB}
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

### Impact
- ✅ Plus lisible
- ✅ Cohérence du code

---

## 🐛 Bug #15 : Pas de Health Endpoint Microservices

### Symptômes
```yaml
user-service:
  volumes:
    - ./services/user-service/nginx.conf:/etc/nginx/nginx.conf
    - ./services/user-service/html:/usr/share/nginx/html
```
- Pas d'endpoint `/health` configuré
- Health check ne peut pas fonctionner

### Diagnostic
Les microservices ont besoin d'un endpoint health pour les health checks.

### Solution
Dans `nginx.conf` :
```nginx
location /health {
    return 200 "OK\n";
    add_header Content-Type text/plain;
}
```

Health check :
```yaml
user-service:
  healthcheck:
    test: ["CMD", "wget", "-q", "--spider", "http://localhost/health"]
```

### Impact
- ✅ Health checks fonctionnels
- ✅ Monitoring actif

---

## 🐛 Bug #16 : Volume Driver Manquant

### Symptômes
```yaml
volumes:
  kong_data:
    # Pas de driver explicite
```

### Diagnostic
Le driver devrait être explicite pour clarté.

### Solution
```yaml
volumes:
  kong_data:
    driver: local
```

### Impact
- ✅ Configuration explicite
- ✅ Code plus clair

---

## 📊 Résumé des Corrections

| Bug | Catégorie | Gravité | Impact |
|-----|-----------|---------|--------|
| #1 - Version obsolète | Syntaxe | ⚠️ Moyenne | Warnings |
| #2 - Pas de réseau | Sécurité | 🔴 Haute | Isolation |
| #3 - Health checks absents | Fiabilité | 🔴 CRITIQUE | Orchestration |
| #4 - depends_on simple | Fiabilité | 🔴 CRITIQUE | Migration échoue |
| #5 - Credentials hardcodés | Sécurité | 🔴 CRITIQUE | Fuite secrets |
| #6 - Ports hardcodés | Configuration | ⚠️ Moyenne | Flexibilité |
| #7 - Container names | Maintenabilité | 🟡 Basse | Lisibilité |
| #8 - Restart policies | Production | 🔴 Haute | Disponibilité |
| #9 - Migration restart | Robustesse | ⚠️ Moyenne | Retry |
| #10 - completed_successfully | Fiabilité | 🔴 Haute | Schema invalide |
| #11 - Volumes read-only | Sécurité | ⚠️ Moyenne | Protection configs |
| #12 - Services exposés | Architecture | 🔴 CRITIQUE | Bypass Kong |
| #13 - Redis sans password | Sécurité | 🔴 CRITIQUE | Redis exposé |
| #14 - Format env vars | Style | 🟡 Basse | Lisibilité |
| #15 - Health endpoints | Fonctionnel | ⚠️ Moyenne | Monitoring |
| #16 - Volume driver | Configuration | 🟡 Basse | Clarté |

### Statistiques
- **Total bugs** : 16
- **Critiques** : 5 (health checks, depends_on, credentials, services exposés, Redis)
- **Hautes** : 3 (réseau, restart, completed_successfully)
- **Moyennes** : 6
- **Basses** : 2

---

## 🎯 Points Clés Kong Gateway

### Architecture API Gateway
1. **Tous les appels passent par Kong** (port 8000)
2. **Microservices ne sont PAS exposés** directement
3. **Kong route vers les services** via le réseau interne
4. **Rate limiting, auth, cache** gérés par Kong

### Séquence de Démarrage
```
1. PostgreSQL healthy (30s)
2. Kong Migration runs → completed successfully
3. Kong starts → healthy (40s)
4. Microservices start → healthy
5. Stack opérationnelle
```

### Ports Kong
- **8000** : Proxy HTTP (API publique)
- **8443** : Proxy HTTPS
- **8001** : Admin API (gestion Kong)
- **8444** : Admin API HTTPS

### Configuration Kong
Après démarrage, configurer les routes :
```bash
# Ajouter service user
curl -i -X POST http://localhost:8001/services/ \
  --data name=user-service \
  --data url='http://user-service:80'

# Ajouter route
curl -i -X POST http://localhost:8001/services/user-service/routes \
  --data 'paths[]=/users'
```

---

## 🚀 Validation

Pour valider les corrections :

```bash
cd exercice-5-kong
chmod +x test.sh
./test.sh
```

Le script vérifie :
- ✅ Structure des fichiers
- ✅ Syntaxe YAML
- ✅ Variables d'environnement
- ✅ Configuration Kong et services
- ✅ Health checks (7 services)
- ✅ Orchestration complexe
- ✅ Sécurité (no exposed ports)
- ✅ Tous les bugs corrigés

---

**Date d'analyse** : 2024-12-05  
**Niveau de difficulté** : Expert ⭐⭐⭐⭐⭐  
**Temps de résolution estimé** : 90-120 minutes  
**Stack** : Kong Gateway 3.4 + PostgreSQL 13 + 3 Microservices + Redis
