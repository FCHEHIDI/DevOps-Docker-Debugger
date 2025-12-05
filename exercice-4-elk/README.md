# 🔧 Exercice 4 : Stack ELK (Elasticsearch + Logstash + Kibana)

## 🐛 Problèmes identifiés dans le fichier buggy

### 1. **Problèmes de mémoire Elasticsearch**
- ❌ ES_JAVA_OPTS=-Xms512m -Xmx512m (insuffisant)
- ✅ ES_JAVA_OPTS=-Xms1g -Xmx1g + ulimits configurés
- **Raison** : Elasticsearch nécessite minimum 1GB de RAM

### 2. **Memory Lock non configuré**
- ❌ Pas de `bootstrap.memory_lock=true`
- ✅ Ajout de memory lock + ulimits memlock
- **Raison** : Empêche le swap et améliore les performances

### 3. **Absence de health checks**
- ❌ Pas de vérification de l'état des services
- ✅ Health checks pour tous les services ELK
- **Raison** : Garantit que les services sont prêts avant de démarrer les dépendants

### 4. **Ordre de démarrage non garanti**
- ❌ `depends_on` simple ne garantit pas que Elasticsearch est prêt
- ✅ Utilisation de `condition: service_healthy`

### 5. **Configuration Logstash incomplète**
- ❌ Pipeline basique sans gestion des erreurs
- ✅ Pipeline avec filtres, multi-inputs (tcp/udp/beats) et stdout debug

### 6. **Filebeat mal configuré**
- ❌ Pas de permissions adaptées pour lire les logs Docker
- ✅ `user: root` + `-strict.perms=false` + volumes Docker montés

### 7. **Absence de réseau isolé**
- ❌ Utilisation du réseau par défaut
- ✅ Création d'un réseau bridge dédié

### 8. **Ports exposés inutilement**
- ❌ Port 9300 Elasticsearch exposé (communication interne cluster)
- ✅ Suppression des ports inutiles

### 9. **Volumes manquants**
- ❌ Pas de volumes pour Logstash, Kibana, Filebeat
- ✅ Ajout de volumes pour la persistance de tous les services

## 🚀 Déploiement

```bash
# Créer les répertoires nécessaires
mkdir -p logstash/config logstash/pipeline filebeat

# Démarrer les services
docker-compose up -d

# Vérifier les logs
docker-compose logs -f

# Vérifier l'état des services
docker-compose ps
```

## 🔍 Vérification du fonctionnement

### 1. Elasticsearch
```bash
# Vérifier l'état du cluster
curl http://localhost:9200/_cluster/health?pretty

# Lister les indices
curl http://localhost:9200/_cat/indices?v
```

### 2. Logstash
```bash
# Vérifier l'état de Logstash
curl http://localhost:9600/_node/stats?pretty

# Voir les logs Logstash
docker-compose logs -f logstash
```

### 3. Kibana
- Accéder à http://localhost:5601
- Aller dans "Stack Management" > "Index Management"
- Vérifier que les indices Filebeat apparaissent

### 4. Filebeat
```bash
# Vérifier que Filebeat envoie des logs
docker-compose logs -f filebeat

# Vérifier dans Kibana
# Menu > Discover > Créer un index pattern "filebeat-*"
```

## ✅ Tests de validation

1. **Elasticsearch opérationnel** : `curl http://localhost:9200`
2. **Kibana accessible** : http://localhost:5601
3. **Logs ingérés** : Vérifier dans Kibana > Discover
4. **Pipeline Logstash actif** : `curl http://localhost:9600`

## 🛠️ Bonnes pratiques appliquées

- ✅ Réseau Docker isolé
- ✅ Health checks sur tous les services
- ✅ Memory lock pour Elasticsearch
- ✅ Ulimits configurés
- ✅ Variables d'environnement externalisées
- ✅ Restart policy configurée
- ✅ Volumes nommés pour la persistance
- ✅ Pipeline Logstash avec filtres
- ✅ Filebeat avec permissions correctes

## 🔧 Commandes utiles

```bash
# Redémarrer Elasticsearch
docker-compose restart elasticsearch

# Voir les métriques Elasticsearch
curl http://localhost:9200/_nodes/stats?pretty

# Supprimer un index
curl -X DELETE http://localhost:9200/filebeat-8.11.0-2025.12.05

# Forcer un refresh des indices
curl -X POST http://localhost:9200/_refresh
```

## ⚠️ Prérequis système

- **RAM minimum** : 4GB (recommandé 8GB)
- **vm.max_map_count** : Pour Linux, exécuter :
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  ```

## 📊 Architecture

```
Logs Docker → Filebeat → Logstash → Elasticsearch → Kibana
                            ↓
                        Filtrage
```
