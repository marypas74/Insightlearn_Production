#!/bin/bash

# Script per configurare l'accesso a InsightLearn su 192.168.1.103
# Password sudo: SS1-Temp1234

echo "Configurazione accesso InsightLearn su 192.168.1.103..."

# Verifica se l'utente è root o ha privilegi sudo
if [ "$EUID" -ne 0 ]; then
   echo "Eseguire con sudo o come root"
   echo "Uso: echo 'SS1-Temp1234' | sudo -S bash configure-access.sh"
   exit 1
fi

# IP di Minikube
MINIKUBE_IP="192.168.49.2"
TARGET_IP="192.168.1.103"

echo "1. Configurazione port forwarding con iptables..."

# Rimuovi regole esistenti se presenti
iptables -t nat -D PREROUTING -d $TARGET_IP -p tcp --dport 443 -j DNAT --to-destination $MINIKUBE_IP:31443 2>/dev/null
iptables -t nat -D PREROUTING -d $TARGET_IP -p tcp --dport 80 -j DNAT --to-destination $MINIKUBE_IP:31080 2>/dev/null
iptables -t nat -D POSTROUTING -d $MINIKUBE_IP -p tcp --dport 31443 -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -d $MINIKUBE_IP -p tcp --dport 31080 -j MASQUERADE 2>/dev/null

# Aggiungi nuove regole
iptables -t nat -A PREROUTING -d $TARGET_IP -p tcp --dport 443 -j DNAT --to-destination $MINIKUBE_IP:31443
iptables -t nat -A PREROUTING -d $TARGET_IP -p tcp --dport 80 -j DNAT --to-destination $MINIKUBE_IP:31080
iptables -t nat -A POSTROUTING -d $MINIKUBE_IP -p tcp --dport 31443 -j MASQUERADE
iptables -t nat -A POSTROUTING -d $MINIKUBE_IP -p tcp --dport 31080 -j MASQUERADE

echo "2. Abilitazione IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Rendi persistente
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

echo "3. Configurazione interfaccia virtuale per 192.168.1.103..."
# Aggiungi IP alias se non esiste
if ! ip addr show | grep -q "$TARGET_IP"; then
    # Trova l'interfaccia di rete principale
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$INTERFACE" ]; then
        INTERFACE="eth0"
    fi

    ip addr add $TARGET_IP/32 dev $INTERFACE
    echo "IP $TARGET_IP aggiunto all'interfaccia $INTERFACE"
fi

echo ""
echo "=== CONFIGURAZIONE COMPLETATA ==="
echo ""
echo "L'applicazione InsightLearn è ora accessibile su:"
echo "  HTTP:  http://$TARGET_IP"
echo "  HTTPS: https://$TARGET_IP (certificato auto-firmato)"
echo ""
echo "Da qualsiasi dispositivo nella rete intranet, accedi a:"
echo "  https://$TARGET_IP"
echo ""
echo "Per rendere le modifiche permanenti al riavvio, aggiungi questo script a /etc/rc.local"
echo ""

# Test di connettività
echo "Test di connettività..."
if curl -k -s -o /dev/null -w "%{http_code}" https://$MINIKUBE_IP:31443/health | grep -q "200"; then
    echo "✅ Backend InsightLearn risponde correttamente"
else
    echo "⚠️  Attenzione: Il backend potrebbe non essere completamente avviato"
fi

echo ""
echo "Per verificare lo stato dei pod:"
echo "  kubectl get pods -n insightlearn"