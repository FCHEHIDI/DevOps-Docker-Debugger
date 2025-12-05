#!/bin/bash
echo "=== VALIDATION RAPIDE EXERCICE 5 : KONG GATEWAY ==="
echo ""
PASS=0
FAIL=0

# Fichiers
[ -f docker-compose.yml ] && ((PASS++)) || ((FAIL++))
[ -f .env ] && ((PASS++)) || ((FAIL++))
[ -f .env.example ] && ((PASS++)) || ((FAIL++))
[ -f .gitignore ] && ((PASS++)) || ((FAIL++))
[ -f analyse.md ] && ((PASS++)) || ((FAIL++))
[ -f comparaison.md ] && ((PASS++)) || ((FAIL++))
[ -f SYNTHESE.md ] && ((PASS++)) || ((FAIL++))
[ -f test.sh ] && ((PASS++)) || ((FAIL++))
echo "✓ Structure fichiers: 8/8"

# YAML valide
docker compose -f docker-compose.yml config > /dev/null 2>&1 && ((PASS++)) || ((FAIL++))
! grep -q "^version:" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "networks:" docker-compose.yml && ((PASS++)) || ((FAIL++))
echo "✓ YAML valide: 3/3"

# Variables .env
grep -q "POSTGRES_USER" .env && ((PASS++)) || ((FAIL++))
grep -q "POSTGRES_PASSWORD" .env && ((PASS++)) || ((FAIL++))
grep -q "KONG_PROXY_PORT" .env && ((PASS++)) || ((FAIL++))
grep -q "REDIS_PASSWORD" .env && ((PASS++)) || ((FAIL++))
echo "✓ Variables .env: 4/4"

# Pas hardcodé
! grep -q "POSTGRES_PASSWORD=kong" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "\${POSTGRES_PASSWORD}" docker-compose.yml && ((PASS++)) || ((FAIL++))
echo "✓ Pas de credentials hardcodés: 2/2"

# Services
grep -q "kong-database:" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "kong-migration:" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "kong:" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "user-service:" docker-compose.yml && ((PASS++)) || ((FAIL++))
grep -q "redis:" docker-compose.yml && ((PASS++)) || ((FAIL++))
echo "✓ 7 services définis: 5/5"

# Health checks
grep -c "healthcheck:" docker-compose.yml | grep -q "6" && ((PASS++)) || ((FAIL++))
grep -A 20 "kong-database:" docker-compose.yml | grep -q "pg_isready" && ((PASS++)) || ((FAIL++))
grep -A 50 "kong:" docker-compose.yml | grep -q "kong health" && ((PASS++)) || ((FAIL++))
echo "✓ Health checks: 3/3"

# depends_on avancé
grep -A 50 "kong:" docker-compose.yml | grep -q "service_completed_successfully" && ((PASS++)) || ((FAIL++))
grep -A 30 "kong-migration:" docker-compose.yml | grep -q "condition: service_healthy" && ((PASS++)) || ((FAIL++))
echo "✓ Orchestration avancée: 2/2"

# Architecture API Gateway (pas de ports microservices)
! grep -A 20 "user-service:" docker-compose.yml | grep -q "ports:" && ((PASS++)) || ((FAIL++))
! grep -A 20 "product-service:" docker-compose.yml | grep -q "ports:" && ((PASS++)) || ((FAIL++))
! grep -A 20 "order-service:" docker-compose.yml | grep -q "ports:" && ((PASS++)) || ((FAIL++))
echo "✓ Architecture API Gateway: 3/3"

# Redis sécurisé
grep -A 20 "redis:" docker-compose.yml | grep -q "requirepass" && ((PASS++)) || ((FAIL++))
! grep -A 20 "redis:" docker-compose.yml | grep -q "ports:" && ((PASS++)) || ((FAIL++))
echo "✓ Redis sécurisé: 2/2"

# Restart policies
grep -c "restart:" docker-compose.yml | grep -qE "[7-9]" && ((PASS++)) || ((FAIL++))
echo "✓ Restart policies: 1/1"

# Documentation
grep -q "16" analyse.md && ((PASS++)) || ((FAIL++))
[ -s SYNTHESE.md ] && ((PASS++)) || ((FAIL++))
echo "✓ Documentation: 2/2"

# Sécurité
grep -q "^.env$" .gitignore && ((PASS++)) || ((FAIL++))
echo "✓ Sécurité: 1/1"

echo ""
echo "======================================"
echo "RÉSULTATS: $PASS tests réussis / $((PASS+FAIL)) total"
echo "======================================"
[ $FAIL -eq 0 ] && echo "✅ TOUS LES TESTS PASSÉS !" || echo "⚠️  $FAIL tests échoués"
