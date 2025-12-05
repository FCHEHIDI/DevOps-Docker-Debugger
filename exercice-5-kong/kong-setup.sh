#!/bin/bash

# Script de configuration automatique de Kong Gateway
# Ce script configure les services, routes et plugins via l'API Admin de Kong

KONG_ADMIN_URL="http://localhost:8001"

echo "🚀 Configuration de Kong Gateway..."
echo ""

# Attendre que Kong soit prêt
echo "⏳ Attente de Kong..."
until curl -s "${KONG_ADMIN_URL}/status" > /dev/null; do
    sleep 2
done
echo "✅ Kong est prêt!"
echo ""

# Configuration du service User
echo "📦 Configuration du service User..."
curl -i -X POST ${KONG_ADMIN_URL}/services/ \
  --data name=user-service \
  --data url='http://user-service:80'

curl -i -X POST ${KONG_ADMIN_URL}/services/user-service/routes \
  --data 'paths[]=/users' \
  --data name=user-route

echo ""
echo "✅ Service User configuré!"
echo ""

# Configuration du service Product
echo "📦 Configuration du service Product..."
curl -i -X POST ${KONG_ADMIN_URL}/services/ \
  --data name=product-service \
  --data url='http://product-service:80'

curl -i -X POST ${KONG_ADMIN_URL}/services/product-service/routes \
  --data 'paths[]=/products' \
  --data name=product-route

echo ""
echo "✅ Service Product configuré!"
echo ""

# Configuration du service Order
echo "📦 Configuration du service Order..."
curl -i -X POST ${KONG_ADMIN_URL}/services/ \
  --data name=order-service \
  --data url='http://order-service:80'

curl -i -X POST ${KONG_ADMIN_URL}/services/order-service/routes \
  --data 'paths[]=/orders' \
  --data name=order-route

echo ""
echo "✅ Service Order configuré!"
echo ""

# Activer le plugin Rate Limiting
echo "🔌 Activation du plugin Rate Limiting..."
curl -i -X POST ${KONG_ADMIN_URL}/plugins/ \
  --data name=rate-limiting \
  --data config.minute=100 \
  --data config.policy=local

echo ""
echo "✅ Plugin Rate Limiting activé!"
echo ""

# Activer le plugin CORS
echo "🔌 Activation du plugin CORS..."
curl -i -X POST ${KONG_ADMIN_URL}/plugins/ \
  --data name=cors \
  --data config.origins='*' \
  --data config.methods=GET,POST,PUT,DELETE \
  --data config.headers=Accept,Content-Type \
  --data config.credentials=true \
  --data config.max_age=3600

echo ""
echo "✅ Plugin CORS activé!"
echo ""

echo "🎉 Configuration terminée!"
echo ""
echo "🔗 URLs disponibles:"
echo "   - Kong Proxy: http://localhost:8000"
echo "   - Kong Admin: http://localhost:8001"
echo ""
echo "📝 Routes configurées:"
echo "   - http://localhost:8000/users/api/users"
echo "   - http://localhost:8000/products/api/products"
echo "   - http://localhost:8000/orders/api/orders"
