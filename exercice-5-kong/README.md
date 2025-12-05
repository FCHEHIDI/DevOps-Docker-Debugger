# 🏗️ Exercice 5 : Architecture Microservices avec Kong Gateway

## 🐛 Problèmes identifiés dans le fichier buggy

### 1. **Absence de réseau Docker**
- ❌ Pas de réseau défini, les services ne peuvent pas communiquer
- ✅ Création d'un réseau bridge `kong-network`
- **Raison** : Kong doit pouvoir contacter les microservices par leur nom

### 2. **Ordre de démarrage incorrect**
- ❌ Kong démarre avant que les migrations soient terminées
- ✅ Utilisation de `condition: service_completed_successfully` pour kong-migration
- **Raison** : Les migrations doivent être appliquées avant le démarrage de Kong

### 3. **Services backend exposés inutilement**
- ❌ Ports 3001, 3002, 3003 exposés publiquement
- ✅ Communication uniquement via Kong (pas d'exposition directe)
- **Raison** : Architecture API Gateway - tous les appels passent par Kong

### 4. **Absence de health checks**
- ❌ Pas de vérification de l'état des services
- ✅ Health checks pour tous les services (PostgreSQL, Kong, microservices)

### 5. **Mots de passe en clair**
- ❌ Credentials hardcodés
- ✅ Variables d'environnement via `.env`

### 6. **Configuration Kong incomplète**
- ❌ Pas de configuration des services/routes dans Kong
- ✅ Script `kong-setup.sh` pour automatiser la configuration

### 7. **Redis non protégé**
- ❌ Redis sans authentification
- ✅ Redis avec mot de passe

### 8. **Fichiers HTML manquants**
- ❌ Volumes montés mais répertoires inexistants
- ✅ Suppression des volumes HTML (configuration dans nginx.conf)

## 🚀 Déploiement

```bash
# 1. Démarrer les services
docker-compose up -d

# 2. Vérifier que tous les services sont up
docker-compose ps

# 3. Attendre que Kong soit prêt (environ 30-40 secondes)
docker-compose logs -f kong

# 4. Configurer les routes Kong
bash kong-setup.sh

# 5. Tester les endpoints
curl http://localhost:8000/users/api/users
curl http://localhost:8000/products/api/products
curl http://localhost:8000/orders/api/orders
```

## 🔍 Vérification de la configuration Kong

### Lister les services
```bash
curl http://localhost:8001/services
```

### Lister les routes
```bash
curl http://localhost:8001/routes
```

### Lister les plugins
```bash
curl http://localhost:8001/plugins
```

## 📊 Architecture

```
Client
  ↓
Kong Gateway (8000)
  ↓
  ├─→ user-service (réseau interne)
  ├─→ product-service (réseau interne)
  └─→ order-service (réseau interne)
```

## ✅ Tests de validation

### 1. Test direct des services (health checks)
```bash
docker-compose exec user-service wget -qO- http://localhost/health
docker-compose exec product-service wget -qO- http://localhost/health
docker-compose exec order-service wget -qO- http://localhost/health
```

### 2. Test via Kong Gateway
```bash
# User Service
curl http://localhost:8000/users/api/users
curl http://localhost:8000/users/api/users/count

# Product Service
curl http://localhost:8000/products/api/products
curl http://localhost:8000/products/api/products/count

# Order Service
curl http://localhost:8000/orders/api/orders
curl http://localhost:8000/orders/api/orders/count
```

### 3. Test du Rate Limiting
```bash
# Effectuer plus de 100 requêtes en 1 minute
for i in {1..110}; do
  curl -s http://localhost:8000/users/api/users
done
# Les dernières requêtes devraient être bloquées (HTTP 429)
```

### 4. Test CORS
```bash
curl -H "Origin: http://example.com" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: Content-Type" \
     -X OPTIONS \
     http://localhost:8000/users/api/users -v
```

## 🛠️ Bonnes pratiques appliquées

- ✅ Réseau Docker isolé pour les microservices
- ✅ API Gateway comme point d'entrée unique
- ✅ Health checks sur tous les services
- ✅ Variables d'environnement externalisées
- ✅ Pas d'exposition directe des services backend
- ✅ Rate Limiting activé
- ✅ CORS configuré
- ✅ Migrations Kong gérées correctement
- ✅ Restart policy configurée
- ✅ Redis sécurisé avec mot de passe

## 🔧 Commandes utiles

### Voir les logs Kong
```bash
docker-compose logs -f kong
```

### Redémarrer Kong
```bash
docker-compose restart kong
```

### Ajouter un nouveau service manuellement
```bash
curl -i -X POST http://localhost:8001/services/ \
  --data name=new-service \
  --data url='http://new-service:80'

curl -i -X POST http://localhost:8001/services/new-service/routes \
  --data 'paths[]=/new' \
  --data name=new-route
```

### Supprimer un service
```bash
curl -i -X DELETE http://localhost:8001/services/user-service
```

## 📚 Plugins Kong disponibles

- **Rate Limiting** : Limite le nombre de requêtes par minute
- **CORS** : Gestion des requêtes cross-origin
- **Key Authentication** : Authentification par clé API
- **JWT** : Authentification par token JWT
- **Request Transformer** : Modification des requêtes
- **Response Transformer** : Modification des réponses

## 🔐 Sécurisation avancée (optionnel)

### Activer l'authentification par clé API
```bash
curl -i -X POST http://localhost:8001/plugins/ \
  --data name=key-auth

# Créer un consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data username=myapp

# Créer une clé API
curl -i -X POST http://localhost:8001/consumers/myapp/key-auth \
  --data key=my-secret-key

# Tester
curl http://localhost:8000/users/api/users \
  -H 'apikey: my-secret-key'
```
