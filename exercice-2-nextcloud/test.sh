#!/bin/bash

# 🧪 Script de test automatique - Exercice 2 Nextcloud
# Ce script valide que toutes les corrections ont été appliquées correctement

# Note: Pas de set -e car on gère les erreurs manuellement

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction de test
test_assert() {
    local description="$1"
    local command="$2"
    
    echo -n "Testing: $description... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "====================================="
echo "🧪 Tests de l'Exercice 2 Nextcloud"
echo "====================================="
echo ""

# Test 1: Fichiers requis
echo "📁 Tests des fichiers..."
test_assert "docker-compose.yml existe" "[ -f docker-compose.yml ]"
test_assert "docker-compose-buggy.yml existe" "[ -f docker-compose-buggy.yml ]"
test_assert ".env existe" "[ -f .env ]"
test_assert ".env.example existe" "[ -f .env.example ]"
test_assert ".gitignore existe" "[ -f .gitignore ]"
test_assert "README.md existe" "[ -f README.md ]"
test_assert "analyse.md existe" "[ -f analyse.md ]"
test_assert "comparaison.md existe" "[ -f comparaison.md ]"
echo ""

# Test 2: Syntaxe YAML
echo "📝 Tests de syntaxe YAML..."
test_assert "docker-compose.yml syntaxe valide" "docker-compose -f docker-compose.yml config --quiet"
test_assert "docker-compose-buggy.yml syntaxe valide" "docker-compose -f docker-compose-buggy.yml config --quiet"
echo ""

# Test 3: Variables d'environnement
echo "🔐 Tests des variables d'environnement..."
test_assert ".env contient POSTGRES_DB" "grep -q 'POSTGRES_DB=' .env"
test_assert ".env contient POSTGRES_USER" "grep -q 'POSTGRES_USER=' .env"
test_assert ".env contient POSTGRES_PASSWORD" "grep -q 'POSTGRES_PASSWORD=' .env"
test_assert ".env contient REDIS_PASSWORD" "grep -q 'REDIS_PASSWORD=' .env"
test_assert ".env contient NEXTCLOUD_PORT" "grep -q 'NEXTCLOUD_PORT=' .env"
test_assert ".env contient NEXTCLOUD_ADMIN_USER" "grep -q 'NEXTCLOUD_ADMIN_USER=' .env"
test_assert ".env contient NEXTCLOUD_ADMIN_PASSWORD" "grep -q 'NEXTCLOUD_ADMIN_PASSWORD=' .env"
test_assert ".env contient NEXTCLOUD_TRUSTED_DOMAINS" "grep -q 'NEXTCLOUD_TRUSTED_DOMAINS=' .env"
echo ""

# Test 4: Configuration docker-compose corrigé
echo "⚙️  Tests de configuration (version corrigée)..."
test_assert "Réseau custom défini" "grep -q 'nextcloud-network:' docker-compose.yml"
test_assert "PostgreSQL health check présent" "grep -q 'pg_isready' docker-compose.yml"
test_assert "Redis health check présent" "grep -q 'redis-cli' docker-compose.yml"
test_assert "Nextcloud health check présent" "grep -q 'status.php' docker-compose.yml"
test_assert "PostgreSQL utilise variables env" "grep -q '\${POSTGRES_PASSWORD}' docker-compose.yml"
test_assert "Redis avec mot de passe" "grep -q 'requirepass' docker-compose.yml"
test_assert "Nextcloud intègre Redis" "grep -q 'REDIS_HOST=redis' docker-compose.yml"
test_assert "Nextcloud depends_on avec condition" "grep -q 'condition: service_healthy' docker-compose.yml"
test_assert "Restart policy définie" "grep -q 'restart: unless-stopped' docker-compose.yml"
test_assert "Container names définis" "grep -q 'container_name:' docker-compose.yml"
test_assert "Volumes typés (driver: local)" "grep -q 'driver: local' docker-compose.yml"
test_assert "Config admin automatique" "grep -q 'NEXTCLOUD_ADMIN_USER' docker-compose.yml"
echo ""

# Test 5: Sécurité
echo "🔒 Tests de sécurité..."
test_assert ".env dans .gitignore" "grep -q '.env' .gitignore"
test_assert "Pas de password en clair dans docker-compose.yml" "! grep -E 'PASSWORD.*:.*[a-zA-Z0-9]{3,}$' docker-compose.yml | grep -v '\${'"
test_assert "PostgreSQL ne doit pas exposer le port 5432" "! grep -A5 'postgres:' docker-compose.yml | grep -q '5432:5432'"
test_assert "Redis ne doit pas exposer le port 6379" "! grep -A5 'redis:' docker-compose.yml | grep -q '6379:6379'"
echo ""

# Test 6: Bugs présents dans le fichier buggy
echo "🐛 Vérification que les bugs sont dans le fichier buggy..."
test_assert "Buggy: Variables env incorrectes" "grep -q 'POSTGRES_DB=nextcloud' docker-compose-buggy.yml"
test_assert "Buggy: depends_on simple" "! grep -q 'condition:' docker-compose-buggy.yml"
test_assert "Buggy: Credentials hardcodés" "grep -q 'POSTGRES_PASSWORD=nextcloud123' docker-compose-buggy.yml"
test_assert "Buggy: PostgreSQL port exposé" "grep -q '5432' docker-compose-buggy.yml"
test_assert "Buggy: Redis port exposé" "grep -q '6379' docker-compose-buggy.yml"
test_assert "Buggy: Pas de health check" "! grep -q 'healthcheck:' docker-compose-buggy.yml"
test_assert "Buggy: Redis non intégré" "! grep -q 'REDIS_HOST' docker-compose-buggy.yml"
test_assert "Buggy: Pas de config admin" "! grep -q 'NEXTCLOUD_ADMIN' docker-compose-buggy.yml"
echo ""

# Test 7: Documentation
echo "📚 Tests de documentation..."
test_assert "README contient section Déploiement" "grep -qi 'Déploiement\|deployment' README.md"
test_assert "README contient section Tests" "grep -qi 'Tests\|validation' README.md"
test_assert "analyse.md contient sections de bugs" "grep -qi 'BUG\|bug\|erreur' analyse.md"
test_assert "analyse.md contient au moins 10 bugs" "grep -ci 'bug #' analyse.md | awk '\$1 >= 10'"
test_assert "comparaison.md existe et non vide" "[ -s comparaison.md ]"
echo ""

# Test 8: Structure des services
echo "🏗️  Tests de structure des services..."
test_assert "3 services définis (postgres, redis, nextcloud)" "docker-compose -f docker-compose.yml config --services | wc -l | grep -q 3"
test_assert "Réseau défini dans le fichier" "grep -q 'networks:' docker-compose.yml"
test_assert "2 volumes définis" "docker-compose -f docker-compose.yml config | grep -E '^\s+nextcloud_data:|postgres_data:' | wc -l | grep -q 2"
echo ""

# Test 9: Modernité
echo "🔧 Tests de modernité..."
test_assert "Pas de directive 'version:' obsolète" "! grep -q '^version:' docker-compose.yml"
test_assert "Image tags spécifiés" "grep -q 'image:.*:' docker-compose.yml"
echo ""

# Résultats finaux
echo "====================================="
echo "📊 Résultats des tests"
echo "====================================="
echo -e "${GREEN}Tests réussis: $TESTS_PASSED${NC}"
echo -e "${RED}Tests échoués: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ Tous les tests sont passés !${NC}"
    echo ""
    echo "🎉 L'exercice 2 est correctement configuré !"
    exit 0
else
    echo -e "${RED}❌ Certains tests ont échoué${NC}"
    echo ""
    echo "Veuillez corriger les erreurs et relancer les tests."
    exit 1
fi
