#!/bin/bash

# Script de Test Complet - Exercice 4 : ELK Stack
# Valide tous les aspects du debugging ELK (Elasticsearch, Logstash, Kibana, Filebeat)

set +e  # Continue même en cas d'erreur

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Compteurs
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

test_result() {
    local test_name=$1
    local result=$2
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Test $TOTAL_TESTS: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} Test $TOTAL_TESTS: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║        Tests Exercice 4 : ELK Stack                        ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

# ============================================================================
# SECTION 1 : TESTS DE STRUCTURE
# ============================================================================
echo -e "${BOLD}${YELLOW}[1] Tests de Structure des Fichiers${NC}"

[ -f "docker-compose-buggy.yml" ]
test_result "docker-compose-buggy.yml existe" $?

[ -f "docker-compose.yml" ]
test_result "docker-compose.yml existe" $?

[ -f ".env" ]
test_result ".env existe" $?

[ -f ".env.example" ]
test_result ".env.example existe" $?

[ -f ".gitignore" ]
test_result ".gitignore existe" $?

[ -f "analyse.md" ]
test_result "analyse.md existe" $?

[ -f "comparaison.md" ]
test_result "comparaison.md existe" $?

[ -f "SYNTHESE.md" ]
test_result "SYNTHESE.md existe" $?

[ -d "logstash" ]
test_result "Répertoire logstash/ existe" $?

[ -d "filebeat" ]
test_result "Répertoire filebeat/ existe" $?

# ============================================================================
# SECTION 2 : TESTS SYNTAXE YAML
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[2] Tests de Syntaxe YAML${NC}"

docker compose -f docker-compose-buggy.yml config > /dev/null 2>&1
test_result "docker-compose-buggy.yml syntaxe valide" $?

docker compose -f docker-compose.yml config > /dev/null 2>&1
test_result "docker-compose.yml syntaxe valide" $?

! grep -q "^version:" docker-compose.yml
test_result "Pas de directive 'version' dans docker-compose.yml" $?

grep -q "^version:" docker-compose-buggy.yml
test_result "Directive 'version' présente dans buggy" $?

# ============================================================================
# SECTION 3 : TESTS VARIABLES ENVIRONNEMENT
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[3] Tests des Variables d'Environnement${NC}"

grep -q "^ELASTICSEARCH_PORT=" .env
test_result ".env contient ELASTICSEARCH_PORT" $?

grep -q "^ES_MEMORY=" .env
test_result ".env contient ES_MEMORY" $?

grep -q "^LOGSTASH_BEATS_PORT=" .env
test_result ".env contient LOGSTASH_BEATS_PORT" $?

grep -q "^LOGSTASH_MEMORY=" .env
test_result ".env contient LOGSTASH_MEMORY" $?

grep -q "^KIBANA_PORT=" .env
test_result ".env contient KIBANA_PORT" $?

grep -q "ELASTICSEARCH_PORT=" .env.example
test_result ".env.example contient toutes les variables" $?

grep -q "^\.env$" .gitignore
test_result ".gitignore protège .env" $?

# ============================================================================
# SECTION 4 : TESTS SERVICES
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[4] Tests des Services${NC}"

grep -q "elasticsearch:" docker-compose.yml
test_result "Service elasticsearch défini" $?

grep -q "logstash:" docker-compose.yml
test_result "Service logstash défini" $?

grep -q "kibana:" docker-compose.yml
test_result "Service kibana défini" $?

grep -q "filebeat:" docker-compose.yml
test_result "Service filebeat défini" $?

grep -q "elk-elasticsearch" docker-compose.yml
test_result "Container name elk-elasticsearch" $?

grep -q "elk-logstash" docker-compose.yml
test_result "Container name elk-logstash" $?

grep -q "elk-kibana" docker-compose.yml
test_result "Container name elk-kibana" $?

grep -q "elk-filebeat" docker-compose.yml
test_result "Container name elk-filebeat" $?

# ============================================================================
# SECTION 5 : TESTS NETWORKS
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[5] Tests des Networks${NC}"

grep -q "elk-network:" docker-compose.yml
test_result "Network elk-network défini" $?

grep -A1 "elk-network:" docker-compose.yml | grep -q "driver: bridge"
test_result "Network utilise driver bridge" $?

grep -A15 "elasticsearch:" docker-compose.yml | grep -A2 "networks:" | grep -q "elk-network"
test_result "Elasticsearch connecté au network" $?

grep -A20 "logstash:" docker-compose.yml | grep -A2 "networks:" | grep -q "elk-network"
test_result "Logstash connecté au network" $?

grep -A20 "kibana:" docker-compose.yml | grep -A2 "networks:" | grep -q "elk-network"
test_result "Kibana connecté au network" $?

grep -A20 "filebeat:" docker-compose.yml | grep -A2 "networks:" | grep -q "elk-network"
test_result "Filebeat connecté au network" $?

! grep -q "networks:" docker-compose-buggy.yml
test_result "Pas de network dans buggy (bug identifié)" $?

# ============================================================================
# SECTION 6 : TESTS HEALTH CHECKS
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[6] Tests des Health Checks${NC}"

grep -A15 "elasticsearch:" docker-compose.yml | grep -q "healthcheck:"
test_result "Health check Elasticsearch présent" $?

grep -A30 "elasticsearch:" docker-compose.yml | grep -q "_cluster/health"
test_result "Health check ES teste /_cluster/health" $?

grep -A25 "logstash:" docker-compose.yml | grep -q "healthcheck:"
test_result "Health check Logstash présent" $?

grep -A27 "logstash:" docker-compose.yml | grep -q "_node/stats"
test_result "Health check Logstash teste /_node/stats" $?

grep -A25 "kibana:" docker-compose.yml | grep -q "healthcheck:"
test_result "Health check Kibana présent" $?

grep -A27 "kibana:" docker-compose.yml | grep -q "/api/status"
test_result "Health check Kibana teste /api/status" $?

! grep -A15 "elasticsearch:" docker-compose-buggy.yml | grep -q "healthcheck:"
test_result "Pas de health check dans buggy (bug)" $?

# ============================================================================
# SECTION 7 : TESTS DEPENDS_ON
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[7] Tests des Dépendances${NC}"

grep -A25 "logstash:" docker-compose.yml | grep -A3 "depends_on:" | grep -q "condition: service_healthy"
test_result "Logstash depends_on conditionnel" $?

grep -A25 "kibana:" docker-compose.yml | grep -A3 "depends_on:" | grep -q "condition: service_healthy"
test_result "Kibana depends_on conditionnel" $?

grep -A25 "filebeat:" docker-compose.yml | grep -A5 "depends_on:" | grep -q "condition: service_healthy"
test_result "Filebeat depends_on conditionnel" $?

grep -A20 "logstash:" docker-compose-buggy.yml | grep -A2 "depends_on:" | grep -q "elasticsearch" && \
! grep -A20 "logstash:" docker-compose-buggy.yml | grep -q "condition:"
test_result "Buggy utilise depends_on simple (bug)" $?

# ============================================================================
# SECTION 8 : TESTS ELASTICSEARCH SPÉCIFIQUES
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[8] Tests Elasticsearch Spécifiques${NC}"

grep -A20 "elasticsearch:" docker-compose.yml | grep -q "\${ELASTICSEARCH_PORT}"
test_result "ES port utilise variable" $?

grep -A20 "elasticsearch:" docker-compose.yml | grep -q "\${ES_MEMORY}"
test_result "ES mémoire utilise variable" $?

grep -A20 "elasticsearch:" docker-compose.yml | grep -q "bootstrap.memory_lock=true"
test_result "bootstrap.memory_lock=true présent" $?

grep -A30 "elasticsearch:" docker-compose.yml | grep -q "ulimits:"
test_result "ulimits présents pour ES" $?

grep -A32 "elasticsearch:" docker-compose.yml | grep -q "memlock:"
test_result "ulimits memlock configuré" $?

grep -A35 "elasticsearch:" docker-compose.yml | grep -q "nofile:"
test_result "ulimits nofile configuré" $?

! grep -A20 "elasticsearch:" docker-compose-buggy.yml | grep -q "ulimits:"
test_result "Buggy n'a pas ulimits (bug CRITIQUE)" $?

! grep -A20 "elasticsearch:" docker-compose-buggy.yml | grep -q "bootstrap.memory_lock"
test_result "Buggy n'a pas memory_lock (bug)" $?

# ============================================================================
# SECTION 9 : TESTS LOGSTASH
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[9] Tests Logstash${NC}"

grep -A25 "logstash:" docker-compose.yml | grep -q "\${LOGSTASH_BEATS_PORT}"
test_result "Logstash beats port variable" $?

grep -A25 "logstash:" docker-compose.yml | grep -q "\${LOGSTASH_MEMORY}"
test_result "Logstash mémoire variable" $?

grep -A25 "logstash:" docker-compose.yml | grep "volumes:" -A3 | grep -q ":ro"
test_result "Volumes Logstash en read-only" $?

grep -A30 "logstash:" docker-compose.yml | grep -q "logstash_data:"
test_result "Volume logstash_data monté" $?

! grep -A25 "logstash:" docker-compose-buggy.yml | grep "volumes:" -A3 | grep -q ":ro"
test_result "Buggy n'a pas volumes :ro (bug)" $?

grep -A50 "^volumes:" docker-compose.yml | grep -q "logstash_data:"
test_result "Volume logstash_data déclaré" $?

! grep -A50 "^volumes:" docker-compose-buggy.yml | grep -q "logstash_data:"
test_result "Buggy n'a pas logstash_data (bug)" $?

# ============================================================================
# SECTION 10 : TESTS KIBANA
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[10] Tests Kibana${NC}"

grep -A20 "kibana:" docker-compose.yml | grep -q "\${KIBANA_PORT}"
test_result "Kibana port variable" $?

grep -A25 "kibana:" docker-compose.yml | grep -q "SERVER_NAME=kibana"
test_result "Kibana SERVER_NAME configuré" $?

grep -A25 "kibana:" docker-compose.yml | grep -q "SERVER_HOST=0.0.0.0"
test_result "Kibana SERVER_HOST configuré" $?

grep -A30 "kibana:" docker-compose.yml | grep -q "kibana_data:"
test_result "Volume kibana_data monté" $?

grep -A50 "^volumes:" docker-compose.yml | grep -q "kibana_data:"
test_result "Volume kibana_data déclaré" $?

! grep -A30 "kibana:" docker-compose-buggy.yml | grep -q "kibana_data:"
test_result "Buggy n'a pas kibana_data (bug)" $?

grep -A30 "kibana:" docker-compose.yml | grep "healthcheck:" -A5 | grep -q "start_period: 90s"
test_result "Kibana start_period 90s (long démarrage)" $?

# ============================================================================
# SECTION 11 : TESTS FILEBEAT
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[11] Tests Filebeat${NC}"

grep -A5 "filebeat:" docker-compose.yml | grep -q "user: root"
test_result "Filebeat user root (OBLIGATOIRE)" $?

grep -A20 "filebeat:" docker-compose.yml | grep -q "ELASTICSEARCH_HOSTS="
test_result "Filebeat ELASTICSEARCH_HOSTS configuré" $?

grep -A20 "filebeat:" docker-compose.yml | grep -q "LOGSTASH_HOSTS="
test_result "Filebeat LOGSTASH_HOSTS configuré" $?

grep -A25 "filebeat:" docker-compose.yml | grep "volumes:" -A3 | grep -q "filebeat.yml:ro"
test_result "Filebeat config en read-only" $?

grep -A30 "filebeat:" docker-compose.yml | grep -q "filebeat_data:"
test_result "Volume filebeat_data monté" $?

grep -A30 "filebeat:" docker-compose.yml | grep -q "command:"
test_result "Filebeat command avec -strict.perms=false" $?

! grep -A5 "filebeat:" docker-compose-buggy.yml | grep -q "user: root"
test_result "Buggy n'a pas user root (bug CRITIQUE)" $?

grep -A50 "^volumes:" docker-compose.yml | grep -q "filebeat_data:"
test_result "Volume filebeat_data déclaré" $?

# ============================================================================
# SECTION 12 : TESTS VOLUMES
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[12] Tests des Volumes${NC}"

grep -q "elasticsearch_data:" docker-compose.yml | tail -20
test_result "Volume elasticsearch_data déclaré" $?

grep -A1 "elasticsearch_data:" docker-compose.yml | tail -20 | grep -q "driver: local"
test_result "Volumes utilisent driver local" $?

volume_count=$(grep -c "driver: local" docker-compose.yml)
[ "$volume_count" -ge 4 ]
test_result "Au moins 4 volumes avec driver local" $?

# ============================================================================
# SECTION 13 : TESTS RESTART POLICIES
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[13] Tests des Restart Policies${NC}"

grep -A35 "elasticsearch:" docker-compose.yml | grep -q "restart: unless-stopped"
test_result "Elasticsearch restart policy" $?

grep -A35 "logstash:" docker-compose.yml | grep -q "restart: unless-stopped"
test_result "Logstash restart policy" $?

grep -A35 "kibana:" docker-compose.yml | grep -q "restart: unless-stopped"
test_result "Kibana restart policy" $?

grep -A25 "filebeat:" docker-compose.yml | grep -q "restart: unless-stopped"
test_result "Filebeat restart policy" $?

! grep -A20 "elasticsearch:" docker-compose-buggy.yml | grep -q "restart:"
test_result "Buggy n'a pas restart policies (bug)" $?

# ============================================================================
# SECTION 14 : TESTS PORTS
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[14] Tests des Ports${NC}"

grep -A20 "elasticsearch:" docker-compose-buggy.yml | grep "ports:" -A2 | grep -q '"9200:9200"'
test_result "Buggy a ports hardcodés (bug)" $?

! grep -A20 "elasticsearch:" docker-compose-buggy.yml | grep "ports:" -A2 | grep -q "\${ELASTICSEARCH_PORT}"
test_result "Buggy n'utilise pas variables ports (bug)" $?

grep -A20 "elasticsearch:" docker-compose.yml | grep "ports:" -A1 | grep -q "\${ELASTICSEARCH_PORT}"
test_result "Corrigé utilise variables ports" $?

! grep -A20 "elasticsearch:" docker-compose.yml | grep "ports:" -A2 | grep -q "9300"
test_result "Port 9300 supprimé (pas nécessaire single-node)" $?

# ============================================================================
# SECTION 15 : TESTS DOCUMENTATION
# ============================================================================
echo -e "\n${BOLD}${YELLOW}[15] Tests de Documentation${NC}"

bug_count=$(grep -c "^## .* Bug #" analyse.md 2>/dev/null || echo "0")
[ "$bug_count" -ge 14 ]
test_result "analyse.md contient >= 14 bugs documentés" $?

grep -q "### Symptômes" analyse.md
test_result "analyse.md contient sections Symptômes" $?

grep -q "### Solution" analyse.md
test_result "analyse.md contient sections Solution" $?

[ -s "comparaison.md" ]
test_result "comparaison.md existe et non vide" $?

[ -s "SYNTHESE.md" ]
test_result "SYNTHESE.md existe et non vide" $?

grep -qi "ulimits" analyse.md
test_result "Documentation mentionne ulimits" $?

grep -qi "bootstrap.memory_lock" analyse.md
test_result "Documentation mentionne memory_lock" $?

# ============================================================================
# RÉSUMÉ
# ============================================================================
echo -e "\n${BOLD}${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║                    RÉSUMÉ DES TESTS                        ║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "Tests totaux     : ${BOLD}$TOTAL_TESTS${NC}"
echo -e "Tests réussis    : ${GREEN}${BOLD}$PASSED_TESTS${NC}"
echo -e "Tests échoués    : ${RED}${BOLD}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}${BOLD}✓ TOUS LES TESTS SONT PASSÉS !${NC}"
    echo -e "${GREEN}${BOLD}✓ Exercice 4 (ELK Stack) validé à 100%${NC}\n"
    exit 0
else
    PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "\n${YELLOW}⚠ Taux de réussite : $PERCENTAGE%${NC}"
    echo -e "${RED}Certains tests ont échoué. Vérifiez les corrections.${NC}\n"
    exit 1
fi
