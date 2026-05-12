# EPIC 1 — Discovery & Assessment
## Story 1.1 : Inventaire des assets Camunda 7


---

## Contexte

Dans le cadre de ce projet, deux processus BPMN ont été analysés :

| Processus | Fichier | Complexité estimée |
|---|---|---|
| DemandeServiceIT | `demandeServiceIT.bpmn` | 🟢 Faible — Quick Win |
| CAAS Deploy Cluster | `deployCluster.bpmn` | 🔴 Élevée — Lot avancé |

---

## Processus 1 — DemandeServiceIT

### Ce que fait ce processus (en simple)

Un utilisateur fait une demande de service IT. Un manager valide ou refuse. Si c'est accepté, le service est provisionné automatiquement via une API et l'utilisateur est notifié. Si c'est refusé, l'utilisateur reçoit une notification de refus.

### Éléments BPMN

| # | Élément | Nom | Type Camunda |
|---|---|---|---|
| 1 | Start Event | StartService | Déclenchement manuel |
| 2 | User Task | Remplir demande de service IT | Formulaire utilisateur |
| 3 | User Task | Valider la demande | Formulaire manager |
| 4 | Gateway | Decision | Exclusive Gateway (XOR) |
| 5 | Service Task | Provisioning automatique (API) | Java Delegate |
| 6 | Service Task | Notifier refus | Java Delegate |
| 7 | Service Task | Notifier succès | Java Delegate |
| 8 | End Event | CloseService | Fin du processus |

### Formulaires Camunda

> Les formulaires Camunda sont des fichiers `.form` embarqués dans le processus. Chaque champ possède une propriété `key` qui correspond au nom d'une variable de processus.

| Fichier | Task associée | Ce qu'il fait |
|---|---|---|
| `demandeServiceform.form` | User Task #2 | L'utilisateur saisit sa demande IT |
| `validationform.form` | User Task #3 | Le manager approuve ou refuse |

> ⚠️ **Migration** : Ces formulaires sont au format propriétaire Camunda. Ils devront être réécrits (HTML/React ou formulaires externes) pour Kogito.

### Java Delegates

> Un Java Delegate est une classe Java qui exécute la logique métier d'une Service Task. Dans Camunda, la task appelle directement la classe Java. Dans Kogito, ce pattern n'existe pas — il faudra les remplacer par des appels REST.

| Classe Java | Interface | Service Task associée |
|---|---|---|
| `ProvisioningDelegate.java` | `JavaDelegate` | Provisioning automatique (API) |
| `NotifyRefusDelegate.java` | `JavaDelegate` | Notifier refus |
| `NotifySuccesDelegate.java` | `JavaDelegate` | Notifier succès |

> ⚠️ **Migration** : Remplacer chaque `JavaDelegate` par un appel REST (Work Item Handler Kogito).

### Variables de processus

> Les variables sont les données que le processus transporte d'une étape à l'autre. On les trouve dans les fichiers `.form` (champ `key`), dans les delegates (`getVariable` / `setVariable`), et dans le BPMN XML (`conditionExpression`).

| Variable | Type | Description | Source | Utilisée dans |
|---|---|---|---|---|
| `serviceType` | String | Type de service IT demandé | `.form` (key) | Tasks #2, #5 |
| `decision` | String | `Accepted` ou `Rejected` | `.form` (key) | Task #3, Gateway #4 |
| `userId` | String | Identifiant de l'utilisateur | `.form` (key) | Tasks #2, #6, #7 |
| `requestedBy` | String | Nom du demandeur | `.form` (key) | Task #2 |
| `provisioningResult` | String | Résultat du provisioning API | `setVariable()` delegate | Tasks #5, #7 |

> ⚠️ **Point critique** : Vérifier que les variables sont lues via `execution.getVariable("nom")` (portable) et non via Spin ou objets Java sérialisés (bloquant migration).

### Configuration moteur Camunda

> Dans Camunda 7, tout est centralisé dans un seul moteur configuré via `application.yaml`. Dans Kogito, chaque processus devient sa propre application indépendante — il n'y a pas de moteur central.

| Paramètre Camunda | Valeur actuelle | Équivalent Kogito |
|---|---|---|
| `history-level` | À vérifier dans `application.yaml` | **Data Index** (service K8s séparé) |
| `job-executor` | Configuration par défaut | **Jobs Service** (service K8s séparé) |
| `identity / IAM` | À documenter | Keycloak / OIDC dans l'app Kogito |
| `plugins moteur` | Aucun identifié | Sans objet |

> ⚠️ **Point critique** : Si `history-level: full`, le Data Index doit être déployé sur Kubernetes. Kogito n'a pas de History Service natif.

### Score de complexité

| Critère | Score (1-3) | Justification |
|---|---|---|
| Nombre de tâches | 1 | 5 tâches, flux simple |
| Java Delegates | 2 | 3 delegates à porter en REST |
| Gateways | 1 | 1 XOR simple |
| Formulaires Camunda | 2 | 2 forms à réécrire |
| Variables sérialisées | 1 | Types String simples |
| Timers / Boundary events | 1 | Aucun |
| Sous-processus | 1 | Aucun |
| External tasks | 1 | Aucune |

**🟢 Score global : FAIBLE → Candidat pilote prioritaire (Quick Win)**

---

## Processus 2 — CAAS Deploy Cluster

### Ce que fait ce processus (en simple)

Une équipe de développeurs demande un nouveau cluster Kubernetes pour déployer leurs applications. Ce processus automatise tout : enregistrement de la demande, attente de la date programmée, validation par 3 équipes, configuration du réseau virtuel (NSX-T), création du cluster (Rancher), configuration du stockage, tests de résilience, et notification finale. La seule action humaine est la création du bucket S3.

### Vue d'ensemble des phases

```
[Start]
   ↓
Phase 1 — Planification     : Portail PLANNED + attente date/annulation
   ↓
Phase 2 — CAR Validations   : 3 équipes valident (retry 15min chacune)
   ↓
Phase 3 — NSX-T             : Configuration réseau virtuel (3 boucles)
   ↓
Phase 4 — Rancher           : Création du cluster K8s (5 étapes + 1 humain)
   ↓
Phase 5 — Post-déploiement  : Stockage + backup + tests résilience
   ↓
Phase 6 — Finalisation      : Email + Portail COMPLETED
   ↓
[End]
```

---

### Phase 1 — Planification & décision

#### Ce qui se passe simplement
Le processus démarre et prévient le portail que la demande est enregistrée (`PLANNED`). Ensuite il se met en attente devant 3 possibilités : la date programmée arrive (on démarre), quelqu'un annule (on arrête), ou quelqu'un reporte (on attend une nouvelle date).

#### Inventaire

| Élément | Type | Topic / Détail | Variable |
|---|---|---|---|
| Inform Portal PLANNED | Service Task External | `update-status-portal-topic` | statut = `PLANNED` |
| Event-Based Gateway | Gateway | Attend : timer OU message annulation OU message reprise | — |
| Timer démarrage | Timer Event | `requestedDate` | `requestedDate` (lue) |
| Message annulation | Message Catch | `cancelMessage` | → branche annulation |
| Message reprise | Message Catch | `resumeMessage` | → retour attente |
| Inform Portal CANCELLED | Service Task External | `update-status-portal-topic` | statut = `CANCELLED` |

> ⚠️ **Migration** : L'Event-Based Gateway est complexe dans Kogito. Le timer basé sur une variable (`requestedDate`) nécessite le Jobs Service Kogito.

---

### Phase 2 — CAR Validations

#### Ce qui se passe simplement
CAR est le système de gestion des changements IT de l'entreprise. Avant de toucher à l'infrastructure, 3 équipes doivent approuver la demande. Le processus interroge chaque équipe toutes les 15 minutes jusqu'à validation.

| Équipe | Rôle | Ce qu'elle vérifie |
|---|---|---|
| **SO** (Service Owner) | Responsable métier | La demande est légitime et le budget validé |
| **NTSS** (Network & Telecom Security) | Équipe sécurité réseau | La demande respecte la politique de sécurité |
| **NSD** (Network Services Delivery) | Équipe réseau | Les ressources réseau sont disponibles |

#### Inventaire

| Élément | Type | Topic | Timer retry | Variable |
|---|---|---|---|---|
| Inform Portal PROCESSING | Service Task External | `update-status-portal-topic` | — | statut = `PROCESSING` |
| CAR SO Validation | Service Task External | `car-so-validation-topic` | `PT15M` | `isAvailable` |
| CAR NTSS Validation | Service Task External | `car-ntss-validation-topic` | `PT15M` | `isAvailable` |
| CAR NSD Validation | Service Task External | `car-nsd-validation-topic` | `PT15M` | `isAvailable` |

> ⚠️ **Migration** : Les timers de retry (`PT15M`) nécessitent le Jobs Service Kogito. Les External Tasks deviennent des appels REST avec callback.

---

### Phase 3 — Configuration réseau NSX-T

#### Ce qui se passe simplement
NSX-T crée un réseau virtuel isolé pour le cluster par-dessus le réseau physique de l'entreprise. Cela évite que le trafic du cluster se mélange avec le reste du réseau de l'entreprise.

| Composant NSX-T | Analogie simple | Variable liste |
|---|---|---|
| **Inventory Groups** | Étiquettes qui regroupent les machines sous un nom commun | `igList` |
| **Server Pools** | Standard téléphonique qui répartit les requêtes entre les serveurs | `taintsWithVip` |
| **Virtual Servers** | Porte d'entrée publique du cluster (adresse IP + port) | `taintsWithVip` |

#### Inventaire

| Élément | Type | Topic | Boucle sur | Variable |
|---|---|---|---|---|
| Fill NSX-T Informations | Service Task External | `fill-nsxt-information-topic` | — | Prépare `igList`, `taintsWithVip` |
| Create Inventory Groups | Sous-processus multi-instance | `create-inventory-group-topic` | `igList` | `igList` |
| Create Server Pools | Sous-processus multi-instance | `create-server-pool-topic` | `taintsWithVip` | `taintsWithVip` |
| Create Virtual Servers | Sous-processus multi-instance | `create-virtual-server-topic` | `taintsWithVip` | `taintsWithVip` |

> ⚠️ **Migration** : Les sous-processus multi-instance sont complexes dans Kogito — comportement différent de Camunda.

---

### Phase 4 — Création du cluster Rancher

#### Ce qui se passe simplement
Rancher est l'outil qui crée et gère les clusters Kubernetes. Le processus crée le cluster en plusieurs étapes dans l'ordre : d'abord les moules (templates), ensuite la coquille vide (empty cluster), ensuite les machines (node pools), puis on attend que tout soit prêt.

| Étape | Analogie |
|---|---|
| Node Templates | Les plans de chaque type de machine (CPU, RAM, disque) |
| RKE Template | Le règlement commun du cluster (version K8s, plugins réseau) |
| Empty Cluster | La coquille vide — le cluster existe mais sans machines |
| Node Pools | Les vraies machines rattachées au cluster |
| Polling statut | On vérifie toutes les 15min si le cluster est prêt |
| Create S3 Bucket | Le coffre-fort de sauvegarde — action humaine |

#### Inventaire

| Élément | Type | Topic | Boucle / Timer | Variable |
|---|---|---|---|---|
| Fill Rancher Informations | Service Task External | `fill-rancher-information-topic` | — | Prépare `nodes` |
| Create Node Templates | Sous-processus multi-instance | `create-node-template-topic` | `nodes` | `nodes` |
| Create RKE Template | Service Task External | `create-rke-template-topic` | — | — |
| Create Empty Cluster | Service Task External | `create-cluster-topic` | — | ID cluster |
| Create Node Pools | Sous-processus multi-instance | `create-node-pool-topic` | `nodes` | `nodes` |
| Get Cluster Status | Service Task External | `get-cluster-status-topic` | `PT15M` | `isClusterReady` |
| Get Nodes Status | Service Task External | `get-nodes-status-topic` | `PT15M` | — |
| **Create S3 Bucket** | **User Task (humain)** | — | — | Config S3 |
| Update Cluster with S3 | User Task (humain) | — | — | Config S3 |

> ⚠️ **Migration** : 2 sous-processus multi-instance + 2 timers de polling + 1 Event-Based Gateway = complexité très élevée.

---

### Phase 5 — Post-déploiement

#### Ce qui se passe simplement
Le cluster tourne. On le configure pour qu'il soit vraiment utilisable : on définit comment stocker les données, on réserve des espaces disque, on connecte les sauvegardes automatiques, et on teste que le cluster résiste aux pannes.

| Étape | Analogie |
|---|---|
| Storage Class | Le type de rangement disponible (SSD rapide, HDD lent) |
| Volume Creation | Ton casier personnel de 50GB réservé |
| S3 Snapshot config | Sauvegarde automatique nocturne connectée au coffre-fort S3 |
| Resilience Tests | Test incendie — on simule une panne pour vérifier que ça tient |
| Create / Update Project | Ton étage réservé dans l'immeuble (espace de travail équipe) |

#### Inventaire

| Élément | Type | Topic | Timer retry | Variable |
|---|---|---|---|---|
| Storage Class Creation | Service Task External | `create-storage-class-topic` | — | — |
| Volume Creation | Service Task External | — | — | — |
| S3 Snapshot config | Service Task External | — | — | Config S3 |
| Resilience Tests | Service Task External | — | `PT2M` | `isResiliencyTestsOk` |
| Create Project | Service Task External | `create-project-topic` | — | — |
| Update Project | Service Task External | `update-project-topic` | — | — |

---

### Phase 6 — Finalisation

#### Ce qui se passe simplement
Le processus ferme tous les dossiers : il marque le changement CAR comme implémenté, envoie un email à l'équipe avec les infos de connexion, et met le portail en COMPLETED.

#### Inventaire

| Élément | Type | Topic | Variable |
|---|---|---|---|
| CAR OpcTech Implementation | Service Task External | `car-opctech-topic` | — |
| Email Notification | Service Task External | `email-notification-topic` | — |
| Inform Portal COMPLETED | Service Task External | `update-status-portal-topic` | statut = `COMPLETED` |

---

### Variables de processus — Deploy Cluster

| Variable | Type | Description | Utilisée dans |
|---|---|---|---|
| `requestedDate` | Date | Date à laquelle démarrer le déploiement | Timer Phase 1 |
| `isAvailable` | Boolean | Est-ce que la validation est faite ? | Gateways Phase 2 |
| `isClusterReady` | Boolean | Est-ce que le cluster est prêt ? | Gateway Phase 4 polling |
| `isResiliencyTestsOk` | Boolean | Les tests de résilience sont OK ? | Gateway Phase 5 |
| `igList` | List | Liste des groupes réseau à créer | Boucle Phase 3 |
| `taintsWithVip` | List | Liste des VIP réseau à configurer | Boucles Phase 3 |
| `nodes` | List | Liste des machines du cluster | Boucles Phase 4 |

### Score de complexité

| Critère | Score (1-3) | Justification |
|---|---|---|
| Nombre de tâches | 2 | ~20 service tasks |
| External Tasks | 3 | Toutes les tasks sont external — portage REST requis |
| Gateways | 3 | Event-Based Gateway complexe |
| Sous-processus multi-instance | 3 | 5 boucles sur des listes |
| Timers | 3 | PT15M + PT2M — Jobs Service requis |
| Message events | 2 | cancelMessage + resumeMessage |
| User Tasks | 1 | 2 seulement |
| Variables sérialisées | 2 | Listes (igList, nodes, taintsWithVip) |

**🔴 Score global : ÉLEVÉ → Lot 3 (processus complexe, pas un quick win)**

---

## Comparaison des complexités

| Critère | DemandeServiceIT | Deploy Cluster |
|---|---|---|
| Nb de Service Tasks | 3 | ~17 |
| Type Service Tasks | Java Delegates | External Tasks (topics) |
| User Tasks | 2 | 2 |
| Gateways | 1 XOR simple | Event-Based Gateway |
| Sous-processus | 0 | 5 multi-instance |
| Timers | 0 | PT15M + PT2M |
| Message Events | 0 | 2 (cancel + resume) |
| Formulaires Camunda | 2 | 0 |
| **Score migration** | 🟢 **FAIBLE** | 🔴 **ÉLEVÉ** |
| **Lot migration** | **Pilote (Epic 3)** | **Lot 3 (Epic 4)** |

---

## Glossaire

| Terme | Définition simple |
|---|---|
| **Service Task** | Étape automatique exécutée par du code, sans intervention humaine |
| **User Task** | Étape qui attend qu'un humain fasse quelque chose |
| **External Task** | Service Task qui délègue son travail à un programme externe via un "topic" |
| **Topic** | Le nom du guichet où la task dépose son travail pour qu'un worker externe le traite |
| **Java Delegate** | Classe Java qui contient la logique d'une Service Task dans Camunda 7 |
| **Gateway XOR** | Carrefour qui choisit UNE seule route selon une condition |
| **Event-Based Gateway** | Carrefour qui attend un événement (timer ou message) pour choisir sa route |
| **Multi-instance SubProcess** | Bloc qui se répète automatiquement pour chaque élément d'une liste (comme un `for`) |
| **Timer Event** | Le processus s'arrête et attend un délai (ex : `PT15M` = 15 minutes) |
| **Message Event** | Le processus attend qu'un système externe lui envoie un signal pour continuer |
| **Variable de processus** | Donnée transportée par le processus d'une étape à l'autre |
| **Kubernetes (K8s)** | Système qui gère et orchestre les containers applicatifs |
| **Rancher** | Interface de gestion de clusters Kubernetes |
| **NSX-T** | Système de réseau virtuel VMware — crée des réseaux isolés par-dessus le réseau physique |
| **CAR** | Système de gestion des changements IT — chaque modification d'infra doit être approuvée |
| **S3 Bucket** | Espace de stockage cloud pour les fichiers et sauvegardes |
| **Data Index** | Service Kogito (sur K8s) qui stocke l'historique des instances — remplace le History Service Camunda |
| **Jobs Service** | Service Kogito (sur K8s) qui gère les timers et tâches asynchrones — remplace le Job Executor Camunda |
| **Node** | Une machine (serveur) dans un cluster Kubernetes |
| **Node Pool** | Groupe de machines identiques dans un cluster |
| **Storage Class** | Définit le type de stockage disponible (SSD, HDD, réseau) |
| **Volume** | Espace disque réservé pour une application dans le cluster |
