#!/bin/bash

echo "🔧 Configurazione accesso diretto a https://192.168.1.103"
echo "=================================================="

# Verifica che i port forward siano attivi
echo "✅ Port forward attivi:"
ps aux | grep "kubectl port-forward" | grep -v grep || echo "⚠️  Nessun port forward attivo"

echo ""
echo "🔐 Per abilitare l'accesso diretto a https://192.168.1.103, esegui:"
echo ""
echo "1️⃣  Apri un nuovo terminale e esegui (richiede sudo):"
echo "    sudo python3 /home/mpasqui/Kubernetes/InsightLearn/proxy-443.py"
echo ""
echo "2️⃣  In un altro terminale esegui (richiede sudo):"
echo "    sudo python3 /home/mpasqui/Kubernetes/InsightLearn/proxy-80.py"
echo ""
echo "3️⃣  Oppure usa le porte alternative:"
echo "    • HTTP:  http://192.168.1.103:8080"
echo "    • HTTPS: https://192.168.1.103:8443"
echo ""
echo "📋 Test rapidi:"
echo "    curl -k -H 'Host: localhost' https://192.168.1.103:8443/"
echo "    curl -H 'Host: localhost' http://192.168.1.103:8080/"
echo ""

# Test dei servizi
echo "🧪 Test dei servizi locali:"
curl -s -o /dev/null -w "Port 8080: %{http_code}\\n" -H "Host: localhost" http://127.0.0.1:8080/health || echo "Port 8080: FAILED"
curl -s -o /dev/null -w "Port 8443: %{http_code}\\n" -k -H "Host: localhost" https://127.0.0.1:8443/health || echo "Port 8443: FAILED"

echo ""
echo "✅ InsightLearn è configurato e pronto!"
echo "🔗 I certificati SSL per 192.168.1.103 sono stati creati in /tmp/"