# 📁 Exercice 2 : Nextcloud + PostgreSQL

## 🐛 Problèmes identifiés dans le fichier buggy

### 1. **Variables d'environnement incorrectes pour Nextcloud**
- ❌ Nextcloud utilise `POSTGRES_*` au lieu de préfixes corrects
- ✅ Doit utiliser les variables attendues par l'image Nextcloud

### 2. **Redis non intégré**
- ❌ Redis présent mais non configuré pour Nextcloud
- ✅ Ajout de `REDIS_HOST` et `REDIS_HOST_PASSWORD`

### 3. **Absence de health checks**
- ❌ Aucun health check pour vérifier l'état des services
- ✅ Ajout de health checks pour PostgreSQL, Redis et Nextcloud

### 4. **Ordre de démarrage non garanti**
- ❌ `depends_on` simple ne garantit pas que PostgreSQL est prêt
- ✅ Utilisation de `condition: service_healthy`

### 5. **Absence de réseau isolé**
- ❌ Utilisation du réseau par défaut
- ✅ Création d'un réseau bridge dédié

### 6. **Mots de passe en clair**
- ❌ Credentials hardcodés dans le fichier
- ✅ Utilisation de variables d'environnement via `.env`

### 7. **Ports exposés inutilement**
- ❌ PostgreSQL et Redis exposent leurs ports
- ✅ Suppression des ports exposés (communication interne uniquement)

## 🚀 Déploiement

```bash
# Démarrer les services
docker-compose up -d

# Vérifier les logs
docker-compose logs -f

# Vérifier l'état des services
docker-compose ps

# Accéder à Nextcloud
http://localhost:8080
```

## 🔐 Credentials par défaut (à modifier dans .env)

- **Admin Nextcloud** : admin / admin_secure_password_123
- **PostgreSQL** : nextcloud / nextcloud_secure_password_123
- **Redis** : redis_secure_password_123

## ✅ Tests de validation

1. **Accès à Nextcloud** : http://localhost:8080
2. **Connexion avec le compte admin**
3. **Vérification du cache Redis** dans les paramètres
4. **Upload d'un fichier test**

## 🛠️ Bonnes pratiques appliquées

- ✅ Réseau Docker isolé
- ✅ Health checks sur tous les services
- ✅ Variables d'environnement externalisées
- ✅ Restart policy configurée
- ✅ Volumes nommés pour la persistance
- ✅ Pas d'exposition inutile de ports
