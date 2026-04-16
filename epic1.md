# EPIC 1 — Discovery & Assessment
## Migration Camunda 7 → Kogito
 
**Objectif** : Inventorier l'existant Camunda 7, qualifier les écarts avec Kogito et préparer les lots de migration.

---

## Raisons stratégiques de la migration

- ❌ Fin du support officiel de Camunda 7
- ☁️ Besoin d'une architecture cloud-native et Kubernetes-ready
- 📦 Scalabilité limitée du moteur Camunda 7 en environnement conteneurisé
- 🔄 Adoption d'une approche microservices découplés

---

## Story 1.1 — Inventorier les assets Camunda 7
Recenser tous les processus BPMN, DMN, forms, scripts, delegates, connectors, external tasks, plugins, règles de persistance et mécanismes d'historisation existants dans l'infrastructure Camunda 7.

### Tasks

#### 1.1.1 Recenser les fichiers BPMN et leurs versions
- [ ] Identifier tous les fichiers `.bpmn` / `.bpmn2` dans le projet
- [ ] Noter le chemin, la version et la date de dernière modification
- [ ] Vérifier les versions déployées vs fichiers sources
- [ ] Documenter le format de versioning utilisé (git tags, Maven, autre)
- [ ] Générer la liste exhaustive avec matrice processus × environnements (DEV, TEST, PROD)

**Livrables**
```
| Processus | Fichier | Version | Chemin | Dernière maj | Environnements |
|-----------|---------|---------|--------|--------------|-----------------|
| DemandeServiceIT | demandeServiceIT.bpmn | 1.2.0 | /processes | 2026-03-15 | DEV, TEST, PROD |
```

---

#### 1.1.2 Recenser les modèles DMN et leurs points d'appel
- [ ] Identifier tous les fichiers `.dmn` dans le projet
- [ ] Lister les règles métier par DMN
- [ ] Documenter comment chaque DMN est appelé (depuis quel processus BPMN, via quel service)
- [ ] Vérifier la complexité (nombre de règles, tables, conditions)
- [ ] Noter les dépendances (variables en entrée, résultats attendus)

**Livrables**
```
| DMN | Fichier | Règles | Appelé par | Points d'intégration | Complexité |
|-----|---------|--------|-----------|----------------------|------------|
| DecisionTable | approval.dmn | 5 | DemandeServiceIT | Task #4 | Basse |
```

---

#### 1.1.3 Recenser les user forms Camunda / forms externes
- [ ] Lister tous les fichiers `.form` (Camunda Embedded Forms)
- [ ] Lister les formulaires externes intégrés (URL, iframes, services externes)
- [ ] Documenter la structure de chaque formulaire (champs, types, validations)
- [ ] Identifier les dépendances entre formulaires
- [ ] Noter l'usage des propriétés spéciales Camunda (key, defaultValue, readonly, etc.)
- [ ] Vérifier la présence de logique JavaScript embarquée

**État actuel **
```
| Formulaire | Fichier | Task associée | Type | Champs |
|------------|---------|---------------|------|--------|
| Saisie demande IT | demandeServiceform.form | Task #2 | Camunda Embedded | serviceType, userId, requestedBy |
| Validation demande | validationform.form | Task #3 | Camunda Embedded | decision |
```

**Point critique** : Ces formulaires utilisent le format propriétaire Camunda Embedded Forms. Ils doivent être réécrits en HTML/React pour Kogito ou portés vers un système de formulaires externe (ex. SWF, Automatiko Forms).

---

#### 1.1.4 Recenser les Java Delegates, listeners et delegateExpressions
- [ ] Identifier tous les `.java` qui implémentent `JavaDelegate`, `TaskListener`, `ExecutionListener`
- [ ] Lister les classes et leurs points d'appel (service task, boundary events, etc.)
- [ ] Documenter la signature et les paramètres attendus
- [ ] Analyser les accès à l'objet `execution` (getVariable, setVariable, etc.)
- [ ] Vérifier les patterns de gestion d'erreur (try/catch, fault handlers)
- [ ] Noter les dépendances vers les services métier appelés

**État actuel ()**
```
| Delegate | Classe | Service Task | Interface |
|----------|--------|--------------|-----------|
| Provisioning | ProvisioningDelegate | Task #5 | JavaDelegate |
| Notifier refus | NotifyRefusDelegate | Task #6 | JavaDelegate |
| Notifier succès | NotifySuccesDelegate | Task #7 | JavaDelegate |
```

**Point critique** : Les JavaDelegate Camunda n'existent pas dans Kogito. Ils devront être portés en :
- Appels REST (REST nodes Kogito)
- Work Item Handlers
- Services Quarkus injectés

---

#### 1.1.5 Recenser les scripts JSR-223
- [ ] Identifier tous les scripts (Groovy, JavaScript, Python) présents dans les processus
- [ ] Lister les éléments contenant des scripts (service tasks, gateways, input/output mappings)
- [ ] Documenter le contenu et la complexité de chaque script
- [ ] Analyser les accesses à `execution`, `task`, variables de processus
- [ ] Vérifier les imports et dépendances externes


---

#### 1.1.6 Recenser les connectors Camunda Connect
- [ ] Identifier tous les connecteurs utilisés (HTTP, SOAP, FTP, REST, etc.)
- [ ] Documenter leur configuration (endpoint, authentification, timeouts)
- [ ] Noter les variables d'entrée et de sortie
- [ ] Vérifier les patterns de gestion d'erreur et retry


---

#### 1.1.7 Recenser les external tasks et topics associés
- [ ] Lister toutes les external tasks dans les BPMN
- [ ] Documenter les topics et leur souscription
- [ ] Identifier les worker externes (services, jobs, autres processus)
- [ ] Noter les configurations de timeout et de retry
- [ ] Vérifier les patterns de signalement (success, failure, BPMN error)


---

#### 1.1.8 Recenser les variables, types et formats de sérialisation
- [ ] Documenter chaque variable de processus (nom, type, source, utilisation)
- [ ] Identifier les sources de variables (formulaires, delegates, scripts, appels REST)
- [ ] Vérifier les formats de sérialisation (primitifs, JSON, Java objects, Spin)
- [ ] Analyser les patterns d'héritage et de portée (process, task-local, transient)

**État actuel ()**
```
| Variable | Type | Source | Utilisée dans | Sérialisation |
|----------|------|--------|---|---|
| serviceType | String | .form (key) | Tasks #2, #5 | JSON |
| decision | String | .form (key) | Task #3, Gateway #4 | JSON |
| userId | String | .form (key) | Tasks #2, #6, #7 | JSON |
| requestedBy | String | .form (key) | Task #2 | JSON |
| provisioningResult | String | setVariable() delegate | Task #5, #7 | JSON |
```

**Point critique** : 
- Vérifier que les variables sont lues via `execution.getVariable("nom")` (portable vers Kogito) 
- Identifier et documenter tout usage de **Spin** ou objets Java sérialisés — ces patterns sont spécifiques à Camunda et constituent un **bloquant de migration**

---

#### 1.1.9 Recenser l'usage de l'history level, cleanup et handlers custom
- [ ] Identifier le `history-level` 
- [ ] Lister les history event handlers custom
- [ ] Vérifier les configurations de persistence (base de données, cache)
- [ ] Noter les mécanismes d'audit et de compliance (logs, traces)


**Point critique — History Level** : Si `history-level: full` est utilisé dans Camunda, l'historique complet des instances (variables, activités, durées) est stocké en base. **Kogito ne reproduit pas ce comportement nativement**. Le Data Index doit être déployé et configuré explicitement sur Kubernetes.

---

#### 1.1.10 Recenser les plugins moteur, identity integrations et job executor settings
- [ ] Lister tous les plugins moteur Camunda deployés(pas de plugins deployés)
- [ ] Identifier les process engine plugins et process application plugins
- [ ] Noter les éventuels parsers ou validators custom


---

### Résumé de l'inventaire

**État actuel (processus DemandeServiceIT)**

| Type d'asset | Détail | Quantité |
|--------------|--------|----------|
| Processus BPMN | DemandeServiceIT | 1 |
| Formulaires Camunda | demandeServiceform, validationform | 2 |
| Java Delegates | Provisioning, NotifyRefus, NotifySucces | 3 |
| Variables de processus | serviceType, decision, userId, requestedBy, provisioningResult | 5 |
| Gateways | Exclusive Gateway (XOR) | 1 |
| Timers / Boundary events | Aucun identifié | 0 |
| Sous-processus / Call activities | Aucun identifié | 0 |
| External tasks | Aucun identifié | 0 |


---

---

## Story 1.2 — Évaluer la complexité de migration par processus
Classer les processus par complexité de migration sur la base d'une grille de scoring standardisée. Identifier les processus candidats au pilote (quick wins) et ceux nécessitant une refonte partielle ou complète.


### Tasks

#### 1.2.1 Définir une grille de scoring de complexité
- [ ] Établir la liste des critères d'évaluation
- [ ] Définir l'échelle de scoring (1–3 : faible → bloquant)
- [ ] Attribuer des poids à chaque critère (importance relative)
- [ ] Définir les seuils d'interprétation (FAIBLE, MOYEN, ÉLEVÉ)
- [ ] Valider la grille avec l'équipe technique et métier

**Grille validée**

| # | Critère | Poids | Score (1–3) | Justification | Notes |
|---|---------|-------|-------------|---------------|-------|
| 1 | Nombre de tâches | 1 | - | Simple si <10, complexe si >30 | Flux parallèles multiplent le score |
| 2 | Java Delegates | 3 | - | 3 = portage REST requis, 1 = aucun | Bloquant majeur |
| 3 | Gateways (XOR/AND) | 1 | - | AND = plus complexe que XOR | Parallélisme à gérer |
| 4 | Formulaires embedded | 2 | - | 3 = logique JS complexe, 2 = simple réécriture, 1 = aucun | Réécriture HTML/React |
| 5 | Variables sérialisées | 3 | - | 3 = objets Java / Spin, 1 = types simples | Bloquant critique si Spin |
| 6 | Timers / Boundary events | 2 | - | 2+ timers = complexe | Data Index requis pour async |
| 7 | Sous-processus / Call activities | 2 | - | Chaque sous-processus ajoute 1 point | Dépendances inter-processus |
| 8 | External tasks | 2 | - | 2+ = complexité async élevée | Requiert Work Item Handlers |
| 9 | History level (audit) | 3 | - | 3 si full, 1 si none | Data Index à déployer |
| 10 | Identity / plugins | 2 | - | 3 si custom plugins, 1 si natif | Requalification requise |

**Score maximum possible** : 63 points (tous critères à 3)

---

#### 1.2.2 Évaluer l'usage de scripts, async boundaries, external tasks, forms, connectors
- [ ] Évaluer la présence et la complexité des scripts JSR-223
- [ ] Analyser les patterns asynchrones (async service tasks, timers)
- [ ] Vérifier la présence et l'usage des boundary events
- [ ] Documenter la complexité des formulaires (champs, validations, logique)
- [ ] Valider les connecteurs utilisés et leur équivalent Kogito

**Appliquer la grille au processus DemandeServiceIT**

| Critère | Score | Justification |
|---------|-------|--------------|
| Nombre de tâches | 1 | 5 tâches, flux linéaire simple |
| Java Delegates | 2 | 3 delegates, portage REST requis |
| Gateways (XOR/AND) | 1 | 1 gateway XOR simple |
| Formulaires embedded | 2 | 2 forms Camunda, réécriture nécessaire |
| Variables sérialisées | 1 | Types simples String (à confirmer) |
| Timers / Boundary events | 1 | Aucun identifié |
| Sous-processus / Call activities | 1 | Aucun identifié |
| External tasks | 1 | Aucun identifié |
| History level (audit) | ? | À vérifier dans `application.yaml` |
| Identity / plugins | 1 | Pas de plugin custom identifié |
| **Score pondéré total** | **11/63** | Faible à Moyen (hors history level non confirmé) |

---

#### 1.2.3 Identifier les processus candidats au pilote
- [ ] Filtrer les processus avec un score < 15 (FAIBLE)
- [ ] Vérifier l'absence de blockers critiques
- [ ] Valider l'impact métier (couverture, dépendances)
- [ ] Prioriser par ordre de déploiement
- [ ] Documenter les dépendances entre candidats pilote

**Résultat pour DemandeServiceIT**

| Paramètre | Valeur |
|-----------|--------|
| **Score de migration** | FAIBLE (11/63 estimé) |
| **Classification** | ✅ **Quick Win — Candidat pilote prioritaire** |
| **Blockers identifiés** | Aucun bloquant majeur à ce stade |
| **Points de vigilance** | Portage des 3 Java Delegates + réécriture des 2 formulaires |
| **Incompatibilités** | Formulaires Camunda embedded (non supportés nativement dans Kogito) |

---

#### 1.2.4 Identifier les processus à refonte partielle
- [ ] Lister les processus avec un score 15–40 (MOYEN)
- [ ] Documenter les sections à refondre (formulaires, delegates, gateways)
- [ ] Identifier les dépendances intra-processus
- [ ] Estimer l'effort (jours/hommes)
- [ ] Grouper par thème métier



---

#### 1.2.5 Identifier les processus incompatibles avec un simple portage
- [ ] Lister les processus avec un score > 40 (ÉLEVÉ)
- [ ] Documenter les bloquants (Spin, custom plugins, patterns non supportés)
- [ ] Évaluer les options (refonte, rejet, décommissionnement)
- [ ] Définir un plan de mitigation par processus
- [ ] Préparer une justification métier/technique pour chaque bloquant


---

### Heatmap de complexité

| Critère | Niveau | Exemple |
|---------|--------|---------|
| Flux BPMN (tâches, gateway) | 🟢 Faible | DemandeServiceIT : 5 tâches, 1 XOR |
| Java Delegates | 🟡 Moyen | 3 delegates à porter en REST |
| Formulaires Camunda | 🟡 Moyen | 2 forms à réécrire en HTML/React |
| Variables de processus | 🟢 Faible | Types simples (String) |
| Timers et boundary events | 🟢 Faible | Aucun identifié |
| External tasks | 🟢 Faible | Aucun identifié |
| Sous-processus | 🟢 Faible | Aucun identifié |
| History / Audit | 🟡 À confirmer | History level à vérifier |
| Identity / Plugins | 🟢 Faible | Aucun plugin custom |

---

---

# Story 1.3 — Stratégie de coexistence Camunda / Kogito
Faire tourner Camunda et Kogito en parallèle pendant la migration, sans jamais couper le service.

---

## Principe : New instances on Kogito / Old instances on Camunda

- Les **instances en cours** → continuent sur **Camunda 7** jusqu'à leur fin naturelle
- Les **nouvelles instances** → partent directement sur **Kogito**
- Les deux moteurs tournent en parallèle pendant **2 à 6 mois**
- Camunda est éteint une fois qu'il n'a plus aucune instance active

---
### Tasks
## Comment router les instances ? — Le feature flag

Une simple ligne de configuration dans le service appelant :

```properties
workflow.engine=kogito   # ou camunda
```

- Activation en 30 secondes
- Rollback instantané sans impact sur les instances en cours
- Pas de changement d'infrastructure

---

## Plan de cutover 

| Étape | Quand | Action |
|-------|-------|--------|
| Freeze du code | J-5 | Plus de changement de code |
| Backup Camunda | J-3 | Sauvegarde complète de la base |
| Communication | J-1 | Mail à tous les stakeholders |
| Activation | J0 à 14h | Feature flag `engine=kogito` activé |
| Surveillance | J0 → J+1 | War room ouverte, monitoring continu |
| Débrief | J+1 | Bilan technique et stabilisation |

---

## Plan de rollback (si ça bug)

**Objectif : revenir à Camunda en moins de 2 minutes**

Déclencher le rollback si :
- Kogito est DOWN plus de 5 minutes
- Taux d'erreurs dépasse 5%
- Variables de processus corrompues
- Processus ne se terminent plus normalement

**Procédure :**
1. Décision collective en war room (Tech Lead + métier)
2. Remettre `engine=camunda` dans la config
3. Redémarrer le service (`kubectl rollout restart`)
4. Vérifier que les nouvelles instances vont bien sur Camunda
5. Communiquer aux stakeholders

---

## Quand éteindre Camunda définitivement ?

Les 3 conditions à réunir :

1. **Zéro instance active** sur Camunda
2. **Zéro incident critique** sur Kogito depuis le cutover
3. **Historique Camunda archivé** et sauvegardé (export SQL vers S3)

Une fois ces conditions validées → arrêt Camunda + libération de l'infrastructure.



---

## Annexes

### A. Références et documentation

- [Camunda 7 Process Engine](https://docs.camunda.org/manual/7.20/)
- [Kogito User Guide](https://kogito.kie.org/guides/)
- [Kogito on Kubernetes](https://github.com/kiegroup/kogito-examples)
- [Data Index Service](https://kogito.kie.org/guides/data-index-service/)



