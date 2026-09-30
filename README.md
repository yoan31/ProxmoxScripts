# ProxmoxScripts

Scripts simples pour faciliter l'administration de **Proxmox VE**.

## LXC Command Runner

`lxc-command.sh` permet d'exécuter une commande sur plusieurs conteneurs LXC actuellement démarrés.

### Fonctionnalités

- Liste uniquement les LXC allumés
- Permet d'exclure certains conteneurs
- Propose une mise à jour APT prédéfinie
- Accepte une commande personnalisée
- Demande une confirmation avant exécution
- Affiche un résumé final
- Ne démarre aucun conteneur arrêté
- Aucune télémétrie

### Lancer directement depuis GitHub

```bash
curl -fsSL https://raw.githubusercontent.com/yoan31/ProxmoxScripts/main/lxc-command.sh | bash
```

Le script doit être exécuté en `root`.

### Commande APT prédéfinie

```bash
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y
```

### Prérequis

- Proxmox VE
- Bash
- `pct`
- `whiptail`

### Installation locale

```bash
wget https://raw.githubusercontent.com/yoan31/ProxmoxScripts/main/lxc-command.sh
chmod +x lxc-command.sh
./lxc-command.sh
```

## Aperçu

Le script :

```text
LXC allumés
    ↓
Sélection des exclusions
    ↓
Choix de la commande
    ↓
Confirmation
    ↓
Exécution
    ↓
Résumé
```

## Avertissement

Les commandes sont exécutées avec les privilèges `root` dans les conteneurs sélectionnés.

Vérifiez toujours la commande et la liste des conteneurs avant validation.
