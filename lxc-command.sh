#!/usr/bin/env bash

set -u

# ============================================================
# LXC Command Runner for Proxmox
# Exécute une commande sur les conteneurs LXC actuellement
# démarrés, avec possibilité d'exclure certains conteneurs.
#
# Aucune télémétrie.
# ============================================================

# ---------- Couleurs ----------
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"

# ---------- Vérifications ----------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en root.${NC}"
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    echo -e "${RED}La commande 'pct' est introuvable.${NC}"
    echo "Ce script doit être exécuté sur un serveur Proxmox VE."
    exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${RED}La commande 'whiptail' est introuvable.${NC}"
    echo "Installation : apt install whiptail"
    exit 1
fi


# ============================================================
# Récupération des LXC actuellement démarrés
# Une seule interrogation via "pct list"
# ============================================================

declare -A CT_NAMES
RUNNING_CTS=()
CHECKLIST=()

while read -r CTID HOSTNAME; do

    [[ -z "$CTID" ]] && continue

    [[ -z "$HOSTNAME" ]] && HOSTNAME="Sans nom"

    RUNNING_CTS+=("$CTID")
    CT_NAMES["$CTID"]="$HOSTNAME"

    CHECKLIST+=(
        "$CTID"
        "$HOSTNAME"
        "OFF"
    )

done < <(
    pct list | awk 'NR>1 && $2=="running" {print $1, $NF}'
)


if [[ ${#RUNNING_CTS[@]} -eq 0 ]]; then

    whiptail \
        --title "LXC Command Runner" \
        --msgbox \
        "Aucun conteneur LXC n'est actuellement démarré." \
        8 60

    exit 0
fi


# ============================================================
# Sélection des conteneurs à exclure
# ============================================================

EXCLUDED=$(
    whiptail \
        --title "Exclusion des conteneurs" \
        --checklist \
        "Sélectionnez les conteneurs à EXCLURE de l'exécution.

Les conteneurs non cochés recevront la commande." \
        22 78 14 \
        "${CHECKLIST[@]}" \
        3>&1 1>&2 2>&3
)

STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    echo "Opération annulée."
    exit 0
fi

# Suppression des guillemets générés par whiptail
EXCLUDED=$(echo "$EXCLUDED" | tr -d '"')


# ============================================================
# Choix de la commande
# ============================================================

COMMAND_TYPE=$(
    whiptail \
        --title "Commande à exécuter" \
        --menu \
        "Choisissez la commande à exécuter :" \
        16 78 5 \
        "1" "apt update && apt upgrade -y" \
        "2" "Commande personnalisée" \
        3>&1 1>&2 2>&3
)

STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    echo "Opération annulée."
    exit 0
fi


case "$COMMAND_TYPE" in

    1)
        CUSTOM_COMMAND='apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y'
        ;;

    2)
        CUSTOM_COMMAND=$(
            whiptail \
                --title "Commande personnalisée" \
                --inputbox \
                "Entrez la commande à exécuter dans les conteneurs :" \
                10 78 \
                3>&1 1>&2 2>&3
        )

        STATUS=$?

        if [[ $STATUS -ne 0 || -z "$CUSTOM_COMMAND" ]]; then
            echo "Opération annulée."
            exit 0
        fi
        ;;

    *)
        exit 1
        ;;

esac


# ============================================================
# Construction de la liste finale
# ============================================================

TARGET_CTS=()

for CTID in "${RUNNING_CTS[@]}"; do

    SKIP=false

    for EXCLUDED_ID in $EXCLUDED; do
        if [[ "$CTID" == "$EXCLUDED_ID" ]]; then
            SKIP=true
            break
        fi
    done

    if [[ "$SKIP" == false ]]; then
        TARGET_CTS+=("$CTID")
    fi

done


if [[ ${#TARGET_CTS[@]} -eq 0 ]]; then

    whiptail \
        --title "LXC Command Runner" \
        --msgbox \
        "Tous les conteneurs ont été exclus.

Aucune commande ne sera exécutée." \
        10 60

    exit 0
fi


# ============================================================
# Confirmation
# ============================================================

TARGET_TEXT=""

for CTID in "${TARGET_CTS[@]}"; do

    HOSTNAME="${CT_NAMES[$CTID]:-Sans nom}"

    TARGET_TEXT+="${CTID} - ${HOSTNAME}\n"

done


whiptail \
    --title "Confirmation" \
    --yesno \
    "Commande :

${CUSTOM_COMMAND}

Conteneurs concernés :

${TARGET_TEXT}
Continuer ?" \
    22 78

STATUS=$?

if [[ $STATUS -ne 0 ]]; then
    echo "Opération annulée."
    exit 0
fi


# ============================================================
# Exécution
# ============================================================

SUCCESS=()
FAILED=()

echo
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE} Exécution de la commande${NC}"
echo -e "${BLUE}============================================================${NC}"
echo
echo -e "Commande : ${YELLOW}${CUSTOM_COMMAND}${NC}"
echo


for CTID in "${TARGET_CTS[@]}"; do

    HOSTNAME="${CT_NAMES[$CTID]:-Sans nom}"

    echo
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo -e "${BLUE}CT ${CTID} - ${HOSTNAME}${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo

    # Vérifie une dernière fois que le CT est toujours démarré
    if ! pct status "$CTID" 2>/dev/null | grep -q "status: running"; then

        echo -e "${YELLOW}Le conteneur n'est plus démarré. Ignoré.${NC}"

        FAILED+=("$CTID:$HOSTNAME")
        continue
    fi


    if pct exec "$CTID" -- bash -c "$CUSTOM_COMMAND"; then

        echo
        echo -e "${GREEN}✓ CT ${CTID} : commande terminée avec succès.${NC}"

        SUCCESS+=("$CTID:$HOSTNAME")

    else

        echo
        echo -e "${RED}✗ CT ${CTID} : erreur pendant l'exécution.${NC}"

        FAILED+=("$CTID:$HOSTNAME")

    fi

done


# ============================================================
# Résumé
# ============================================================

echo
echo
echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE} Résumé${NC}"
echo -e "${BLUE}============================================================${NC}"
echo


if [[ ${#SUCCESS[@]} -gt 0 ]]; then

    echo -e "${GREEN}Succès :${NC}"

    for ITEM in "${SUCCESS[@]}"; do

        CTID="${ITEM%%:*}"
        HOSTNAME="${ITEM#*:}"

        echo -e "  ${GREEN}✓${NC} ${CTID} - ${HOSTNAME}"

    done

fi


if [[ ${#FAILED[@]} -gt 0 ]]; then

    echo
    echo -e "${RED}Échecs / ignorés :${NC}"

    for ITEM in "${FAILED[@]}"; do

        CTID="${ITEM%%:*}"
        HOSTNAME="${ITEM#*:}"

        echo -e "  ${RED}✗${NC} ${CTID} - ${HOSTNAME}"

    done

fi


echo
echo -e "${BLUE}============================================================${NC}"
echo
