#!/bin/bash

echo "🚀 Quick Start - InsightLearn"
echo "============================="

# Port forwarding semplice
echo "⚡ Avvio port forwarding..."

kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 443:443 &
HTTPS_PID=$!

kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 80:80 &
HTTP_PID=$!

echo ""
echo "✅ InsightLearn è accessibile su:"
echo ""
echo "🔐 HTTPS: https://localhost (certificato self-signed)"
echo "🌐 HTTP:  http://localhost"
echo ""
echo "⚠️  Per l'accesso HTTPS, accetta il certificato self-signed nel browser"
echo ""
echo "🛑 Premi Ctrl+C per fermare"

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Fermando servizi..."
    kill $HTTPS_PID $HTTP_PID 2>/dev/null
    echo "✅ Fatto!"
    exit 0
}

trap cleanup INT

# Keep running
while true; do
    sleep 1
done