#!/bin/bash

# =============================================================================
# Script de Validation - Exercice 5 : Kong Gateway + Microservices
# =============================================================================
# Description: Teste l'architecture Kong API Gateway avec microservices
# Services: PostgreSQL, Kong, 3 microservices, Redis
# Bugs corrigés: 16 problèmes critiques d'architecture et sécurité
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compteurs
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Fonction d'affichage
print_header() {
    echo ""
    echo -e "${BLUE}=====================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=====================================================================${NC}"
}

print_test() {
    echo -e "${YELLOW}TEST $TOTAL_TESTS: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED_TESTS++))
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED_TESTS++))
}

test_command() {
    ((TOTAL_TESTS++))
    print_test "$2"
    if eval "$1" > /dev/null 2>&1; then
        print_success "$2"
        return 0
    else
        print_error "$2"
        return 1
    fi
}

test_command_output() {
    ((TOTAL_TESTS++))
    print_test "$3"
    if eval "$1" | grep -q "$2"; then
        print_success "$3"
        return 0
    else
        print_error "$3"
        return 1
    fi
}

# =============================================================================
# SECTION 1 : STRUCTURE DES FICHIERS
# =============================================================================
print_header "SECTION 1 : STRUCTURE DES FICHIERS"

test_command "[ -f docker-compose.yml ]" "Fichier docker-compose.yml existe"
test_command "[ -f .env ]" "Fichier .env existe"
test_command "[ -f .env.example ]" "Fichier .env.example existe"
test_command "[ -f .gitignore ]" "Fichier .gitignore existe"
test_command "[ -f analyse.md ]" "Documentation analyse.md existe"
test_command "[ -f comparaison.md ]" "Documentation comparaison.md existe"
test_command "[ -f SYNTHESE.md ]" "Documentation SYNTHESE.md existe"
test_command "[ -d services ]" "Répertoire services/ existe"
test_command "[ -d services/user-service ]" "Répertoire user-service existe"
test_command "[ -d services/product-service ]" "Répertoire product-service existe"
test_command "[ -d services/order-service ]" "Répertoire order-service existe"

# =============================================================================
# SECTION 2 : VALIDATION YAML
# =============================================================================
print_header "SECTION 2 : VALIDATION YAML"

test_command "docker compose -f docker-compose.yml config > /dev/null" "Syntaxe YAML valide"
test_command "! grep -q \"^version:\" docker-compose.yml" "Pas de directive 'version' obsolète"
test_command "grep -q \"networks:\" docker-compose.yml" "Section networks définie"
test_command "grep -q \"volumes:\" docker-compose.yml" "Section volumes définie"
test_command "grep -q \"services:\" docker-compose.yml" "Section services définie"

# =============================================================================
# SECTION 3 : VARIABLES D'ENVIRONNEMENT
# =============================================================================
print_header "SECTION 3 : VARIABLES D'ENVIRONNEMENT"

test_command "grep -q \"POSTGRES_USER\" .env" ".env contient POSTGRES_USER"
test_command "grep -q \"POSTGRES_PASSWORD\" .env" ".env contient POSTGRES_PASSWORD"
test_command "grep -q \"POSTGRES_DB\" .env" ".env contient POSTGRES_DB"
test_command "grep -q \"KONG_PROXY_PORT\" .env" ".env contient KONG_PROXY_PORT"
test_command "grep -q \"KONG_PROXY_SSL_PORT\" .env" ".env contient KONG_PROXY_SSL_PORT"
test_command "grep -q \"KONG_ADMIN_PORT\" .env" ".env contient KONG_ADMIN_PORT"
test_command "grep -q \"KONG_ADMIN_SSL_PORT\" .env" ".env contient KONG_ADMIN_SSL_PORT"
test_command "grep -q \"REDIS_PASSWORD\" .env" ".env contient REDIS_PASSWORD"

test_command "! grep -q \"POSTGRES_PASSWORD=kong\" docker-compose.yml" "Pas de POSTGRES_PASSWORD hardcodé"
test_command "! grep -q \"KONG_PG_PASSWORD=kong\" docker-compose.yml" "Pas de KONG_PG_PASSWORD hardcodé"
test_command "grep -q \"\${POSTGRES_USER}\" docker-compose.yml" "Utilise variable POSTGRES_USER"
test_command "grep -q \"\${POSTGRES_PASSWORD}\" docker-compose.yml" "Utilise variable POSTGRES_PASSWORD"
test_command "grep -q \"\${REDIS_PASSWORD}\" docker-compose.yml" "Utilise variable REDIS_PASSWORD"

# Vérifier .env.example (pas de vraies valeurs)
test_command "grep -q \"POSTGRES_PASSWORD=\" .env.example" ".env.example contient POSTGRES_PASSWORD"
test_command "! grep -q \"POSTGRES_PASSWORD=kong_secure_password\" .env.example" ".env.example n'a pas de vraie valeur"

# Vérifier .gitignore
test_command "grep -q \"^.env$\" .gitignore" ".gitignore contient .env"

# =============================================================================
# SECTION 4 : RÉSEAU
# =============================================================================
print_header "SECTION 4 : RÉSEAU"

test_command "grep -q \"kong-network:\" docker-compose.yml" "Réseau kong-network défini"
test_command_output "docker compose config" "kong-network" "Réseau configuré correctement"

# Vérifier que tous les services sont sur le réseau
test_command "grep -A 50 \"kong-database:\" docker-compose.yml | grep -q \"networks:\"" "kong-database a networks"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"networks:\"" "kong a networks"
test_command "grep -A 50 \"user-service:\" docker-compose.yml | grep -q \"networks:\"" "user-service a networks"
test_command "grep -A 50 \"product-service:\" docker-compose.yml | grep -q \"networks:\"" "product-service a networks"
test_command "grep -A 50 \"order-service:\" docker-compose.yml | grep -q \"networks:\"" "order-service a networks"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"networks:\"" "redis a networks"

# =============================================================================
# SECTION 5 : SERVICE KONG-DATABASE (PostgreSQL)
# =============================================================================
print_header "SECTION 5 : SERVICE KONG-DATABASE"

test_command "grep -q \"kong-database:\" docker-compose.yml" "Service kong-database défini"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"container_name: kong-postgres\"" "Container name kong-postgres"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"image: postgres:13\"" "Image postgres:13"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "Restart policy unless-stopped"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"healthcheck:\"" "Health check défini"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"pg_isready\"" "Health check pg_isready"
test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"kong_data:/var/lib/postgresql/data\"" "Volume kong_data monté"

# =============================================================================
# SECTION 6 : SERVICE KONG-MIGRATION
# =============================================================================
print_header "SECTION 6 : SERVICE KONG-MIGRATION"

test_command "grep -q \"kong-migration:\" docker-compose.yml" "Service kong-migration défini"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"container_name: kong-migration\"" "Container name kong-migration"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"image: kong:3.4\"" "Image kong:3.4"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"command: kong migrations bootstrap\"" "Command migrations bootstrap"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"restart: on-failure\"" "Restart on-failure (pas unless-stopped)"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"depends_on:\"" "Depends_on défini"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"condition: service_healthy\"" "Condition service_healthy sur DB"

# =============================================================================
# SECTION 7 : SERVICE KONG (Gateway)
# =============================================================================
print_header "SECTION 7 : SERVICE KONG GATEWAY"

test_command "grep -q \"kong:\" docker-compose.yml" "Service kong défini"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"container_name: kong-gateway\"" "Container name kong-gateway"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"image: kong:3.4\"" "Image kong:3.4"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "Restart unless-stopped"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"healthcheck:\"" "Health check défini"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"kong health\"" "Health check 'kong health'"

# Vérifier depends_on avec conditions
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -A 10 \"depends_on:\" | grep -q \"condition: service_healthy\"" "Depend on database healthy"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -A 10 \"depends_on:\" | grep -q \"condition: service_completed_successfully\"" "Depend on migration completed_successfully"

# Vérifier ports variables
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"\\\${KONG_PROXY_PORT}:8000\"" "Port proxy variable"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"\\\${KONG_PROXY_SSL_PORT}:8443\"" "Port proxy SSL variable"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"\\\${KONG_ADMIN_PORT}:8001\"" "Port admin variable"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"\\\${KONG_ADMIN_SSL_PORT}:8444\"" "Port admin SSL variable"

# =============================================================================
# SECTION 8 : MICROSERVICES (user, product, order)
# =============================================================================
print_header "SECTION 8 : MICROSERVICES"

# User Service
test_command "grep -q \"user-service:\" docker-compose.yml" "Service user-service défini"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"container_name: user-service\"" "Container name user-service"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"image: nginx:alpine\"" "Image nginx:alpine"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "user-service restart"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"healthcheck:\"" "user-service health check"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"nginx.conf:ro\"" "user-service volume read-only"

# Product Service
test_command "grep -q \"product-service:\" docker-compose.yml" "Service product-service défini"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"container_name: product-service\"" "Container name product-service"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "product-service restart"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"healthcheck:\"" "product-service health check"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"nginx.conf:ro\"" "product-service volume read-only"

# Order Service
test_command "grep -q \"order-service:\" docker-compose.yml" "Service order-service défini"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"container_name: order-service\"" "Container name order-service"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "order-service restart"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"healthcheck:\"" "order-service health check"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"nginx.conf:ro\"" "order-service volume read-only"

# =============================================================================
# SECTION 9 : ARCHITECTURE API GATEWAY (PAS DE PORTS EXPOSÉS)
# =============================================================================
print_header "SECTION 9 : ARCHITECTURE API GATEWAY"

# Vérifier que les microservices NE SONT PAS exposés
test_command "! grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"ports:\"" "user-service PAS de ports exposés"
test_command "! grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"ports:\"" "product-service PAS de ports exposés"
test_command "! grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"ports:\"" "order-service PAS de ports exposés"

# Vérifier que Redis N'EST PAS exposé
test_command "! grep -A 20 \"redis:\" docker-compose.yml | grep -q \"ports:\"" "Redis PAS de ports exposés"

# Seul Kong doit avoir des ports
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"ports:\"" "Kong a des ports exposés (seul point d'entrée)"

# =============================================================================
# SECTION 10 : SERVICE REDIS
# =============================================================================
print_header "SECTION 10 : SERVICE REDIS"

test_command "grep -q \"redis:\" docker-compose.yml" "Service redis défini"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"container_name: kong-redis\"" "Container name kong-redis"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"image: redis:alpine\"" "Image redis:alpine"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "Restart unless-stopped"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"healthcheck:\"" "Health check défini"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"redis-cli\"" "Health check redis-cli"

# CRITIQUE: Redis doit avoir --requirepass
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"requirepass\"" "Redis avec --requirepass (sécurité)"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"\\\${REDIS_PASSWORD}\"" "Redis password depuis variable"

# =============================================================================
# SECTION 11 : HEALTH CHECKS COMPLETS
# =============================================================================
print_header "SECTION 11 : HEALTH CHECKS"

test_command "grep -c \"healthcheck:\" docker-compose.yml | grep -q \"7\"" "7 health checks définis (tous les services sauf migration)"

# Vérifier les start_period
test_command "grep -A 50 \"kong-database:\" docker-compose.yml | grep -A 7 \"healthcheck:\" | grep -q \"start_period: 30s\"" "kong-database start_period 30s"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -A 7 \"healthcheck:\" | grep -q \"start_period: 40s\"" "kong start_period 40s"

# =============================================================================
# SECTION 12 : DEPENDS_ON AVANCÉ
# =============================================================================
print_header "SECTION 12 : DEPENDS_ON AVEC CONDITIONS"

# Migration depend on database healthy
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -A 5 \"depends_on:\" | grep -q \"kong-database:\"" "Migration depends_on kong-database"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -A 5 \"depends_on:\" | grep -q \"condition: service_healthy\"" "Migration attend database healthy"

# Kong depend on migration completed
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -A 10 \"depends_on:\" | grep -q \"kong-migration:\"" "Kong depends_on kong-migration"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -A 10 \"depends_on:\" | grep -q \"service_completed_successfully\"" "Kong attend migration completed_successfully"

# Microservices depend on kong healthy
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -A 5 \"depends_on:\" | grep -q \"condition: service_healthy\"" "user-service attend kong healthy"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -A 5 \"depends_on:\" | grep -q \"condition: service_healthy\"" "product-service attend kong healthy"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -A 5 \"depends_on:\" | grep -q \"condition: service_healthy\"" "order-service attend kong healthy"

# =============================================================================
# SECTION 13 : VOLUMES
# =============================================================================
print_header "SECTION 13 : VOLUMES"

test_command "grep -q \"volumes:\" docker-compose.yml" "Section volumes définie"
test_command "grep -A 5 \"volumes:\" docker-compose.yml | grep -q \"kong_data:\"" "Volume kong_data défini"
test_command "grep -A 5 \"volumes:\" docker-compose.yml | grep -q \"driver: local\"" "Volume avec driver local"

# Vérifier volumes read-only pour configs
test_command "grep -c \":ro\" docker-compose.yml | grep -q \"[6-9]\"" "Au moins 6 volumes en read-only"

# =============================================================================
# SECTION 14 : RESTART POLICIES
# =============================================================================
print_header "SECTION 14 : RESTART POLICIES"

test_command "grep -A 20 \"kong-database:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "kong-database restart unless-stopped"
test_command "grep -A 30 \"kong-migration:\" docker-compose.yml | grep -q \"restart: on-failure\"" "kong-migration restart on-failure"
test_command "grep -A 50 \"kong:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "kong restart unless-stopped"
test_command "grep -A 20 \"user-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "user-service restart unless-stopped"
test_command "grep -A 20 \"product-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "product-service restart unless-stopped"
test_command "grep -A 20 \"order-service:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "order-service restart unless-stopped"
test_command "grep -A 20 \"redis:\" docker-compose.yml | grep -q \"restart: unless-stopped\"" "redis restart unless-stopped"

# =============================================================================
# SECTION 15 : DOCUMENTATION
# =============================================================================
print_header "SECTION 15 : DOCUMENTATION"

test_command "[ -s 'analyse.md' ]" "analyse.md non vide"
test_command "[ -s 'comparaison.md' ]" "comparaison.md non vide"
test_command "[ -s 'SYNTHESE.md' ]" "SYNTHESE.md non vide"

test_command "grep -q \"16\" analyse.md" "analyse.md mentionne 16 bugs"
test_command "grep -qi \"kong\" analyse.md" "analyse.md mentionne Kong"
test_command "grep -qi \"microservice\" analyse.md" "analyse.md mentionne microservices"
test_command "grep -qi \"api gateway\" analyse.md" "analyse.md mentionne API Gateway"

# =============================================================================
# SECTION 16 : SÉCURITÉ
# =============================================================================
print_header "SECTION 16 : SÉCURITÉ"

# Pas de credentials hardcodés
test_command "! grep -q \"POSTGRES_PASSWORD=kong\" docker-compose.yml" "Pas de POSTGRES_PASSWORD=kong hardcodé"
test_command "! grep -q \"KONG_PG_PASSWORD=kong\" docker-compose.yml" "Pas de KONG_PG_PASSWORD=kong hardcodé"

# Variables utilisées
test_command "grep -q \"\${POSTGRES_PASSWORD}\" docker-compose.yml" "Utilise \${POSTGRES_PASSWORD}"
test_command "grep -q \"\${REDIS_PASSWORD}\" docker-compose.yml" "Utilise \${REDIS_PASSWORD}"

# .gitignore protège .env
test_command "grep -q \".env\" .gitignore" ".gitignore protège .env"
test_command "! grep -q \"!.env\" .gitignore" ".gitignore ne whitelist pas .env"

# =============================================================================
# RÉSULTATS FINAUX
# =============================================================================
print_header "RÉSULTATS FINAUX"

echo ""
echo -e "${BLUE}Total de tests exécutés : ${NC}${TOTAL_TESTS}"
echo -e "${GREEN}Tests réussis : ${NC}${PASSED_TESTS}"
echo -e "${RED}Tests échoués : ${NC}${FAILED_TESTS}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}=====================================================================${NC}"
    echo -e "${GREEN}   ✓✓✓ TOUS LES TESTS PASSÉS ! EXERCICE 5 VALIDÉ ! ✓✓✓${NC}"
    echo -e "${GREEN}=====================================================================${NC}"
    echo ""
    echo -e "${GREEN}Architecture Kong Gateway + Microservices parfaitement configurée !${NC}"
    echo -e "${GREEN}16 bugs corrigés, orchestration complète, sécurité maximale.${NC}"
    echo ""
    exit 0
else
    PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${YELLOW}=====================================================================${NC}"
    echo -e "${YELLOW}   Score: ${PERCENTAGE}% (${PASSED_TESTS}/${TOTAL_TESTS})${NC}"
    echo -e "${YELLOW}=====================================================================${NC}"
    echo ""
    echo -e "${RED}Certains tests ont échoué. Vérifiez les erreurs ci-dessus.${NC}"
    echo ""
    exit 1
fi
