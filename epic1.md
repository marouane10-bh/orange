# EPIC 1 — Discovery & Assessment
## Migration Camunda 7 → Kogito

**Date** : 14 avril 2026  
**Objectif** : Inventorier l'existant Camunda 7, qualifier les écarts avec Kogito et préparer les lots de migration.

---

## Raisons stratégiques de la migration

- ❌ Fin du support officiel de Camunda 7
- ☁️ Besoin d'une architecture cloud-native et Kubernetes-ready
- 📦 Scalabilité limitée du moteur Camunda 7 en environnement conteneurisé
- 🔄 Adoption d'une approche microservices découplés

---

## Story 1.1 — Inventorier les assets Camunda 7

### Priorité
⚠️ **HIGHEST**

### Description
Recenser tous les processus, DMN, forms, scripts, delegates, connectors, external tasks, plugins, règles de persistance et mécanismes d'historisation existants dans l'infrastructure Camunda 7.

### Acceptance Criteria
- ✅ Liste exhaustive des BPMN et DMN disponibles
- ✅ Tous les artefacts Camunda spécifiques sont identifiés (scripts, delegates, connectors, listeners)
- ✅ Les dépendances techniques sont documentées (versions, librairies, dépendances inter-processus)
- ✅ Les owners métier et techniques sont associés à chaque processus
- ✅ La matrice de dépendances entre processus est établie
- ✅ Les configurations moteur Camunda 7 (history-level, job-executor, identity) sont documentées

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

**État actuel (tiré du PDF)**
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

**État actuel (tiré du PDF)**
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

**Livrables**
```
| Élément | Type | Script | Complexité | Variables utilisées |
|---------|------|--------|------------|---------------------|
| (À remplir selon audit) | - | - | - | - |
```

---

#### 1.1.6 Recenser les connectors Camunda Connect
- [ ] Identifier tous les connecteurs utilisés (HTTP, SOAP, FTP, REST, etc.)
- [ ] Documenter leur configuration (endpoint, authentification, timeouts)
- [ ] Noter les variables d'entrée et de sortie
- [ ] Vérifier les patterns de gestion d'erreur et retry

**Livrables**
```
| Connecteur | Type | Endpoint | Auth | Input | Output | Async |
|------------|------|----------|------|-------|--------|-------|
| (À remplir selon audit) | - | - | - | - | - | - |
```

---

#### 1.1.7 Recenser les external tasks et topics associés
- [ ] Lister toutes les external tasks dans les BPMN
- [ ] Documenter les topics et leur souscription
- [ ] Identifier les worker externes (services, jobs, autres processus)
- [ ] Noter les configurations de timeout et de retry
- [ ] Vérifier les patterns de signalement (success, failure, BPMN error)

**Livrables**
```
| External Task | Topic | Worker | Timeout | Retry | Variables |
|----------------|-------|--------|---------|-------|-----------|
| (À remplir selon audit) | - | - | - | - | - |
```

---

#### 1.1.8 Recenser les variables, types et formats de sérialisation
- [ ] Documenter chaque variable de processus (nom, type, source, utilisation)
- [ ] Identifier les sources de variables (formulaires, delegates, scripts, appels REST)
- [ ] Vérifier les formats de sérialisation (primitifs, JSON, Java objects, Spin)
- [ ] Analyser les patterns d'héritage et de portée (process, task-local, transient)

**État actuel (tiré du PDF)**
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
- [ ] Identifier le `history-level` configuré (full, activity, variable, auto, none)
- [ ] Documenter les stratégies de nettoyage (cleanup tasks, archivage, rétention)
- [ ] Lister les history event handlers custom
- [ ] Vérifier les configurations de persistence (base de données, cache)
- [ ] Noter les mécanismes d'audit et de compliance (logs, traces)

**État actuel (tiré du PDF)**
```
| Paramètre | Valeur actuelle | Description |
|-----------|-----------------|-------------|
| history-level | À vérifier | full / auto / activity / none |
| job-executor | Actif (défaut) | Gère les timers et événements asynchrones |
| History handlers | À identifier | Custom event listeners |
```

**Point critique — History Level** : Si `history-level: full` est utilisé dans Camunda, l'historique complet des instances (variables, activités, durées) est stocké en base. **Kogito ne reproduit pas ce comportement nativement**. Le Data Index doit être déployé et configuré explicitement sur Kubernetes.

---

#### 1.1.10 Recenser les plugins moteur, identity integrations et job executor settings
- [ ] Lister tous les plugins moteur Camunda deployés
- [ ] Documenter les intégrations d'identité (LDAP, Keycloak, basic auth, OAuth2)
- [ ] Vérifier les configurations du job executor (core threads, max threads, queue size, retry)
- [ ] Identifier les process engine plugins et process application plugins
- [ ] Noter les éventuels parsers ou validators custom

**État actuel (tiré du PDF)**
```
| Paramètre | Camunda 7 | Équivalent Kogito |
|-----------|-----------|-------------------|
| history-level | À vérifier | Data Index (service K8s séparé) + PostgreSQL |
| job-executor | Configuration défaut | Jobs Service (service K8s séparé) |
| Identity / IAM | À documenter | Keycloak ou OIDC configuré dans l'app Kogito |
| Plugins moteur | À identifier | Sans objet / À évaluer |
```

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
| DMN | À compléter | ? |
| Scripts JSR-223 | À compléter | ? |

---

---

## Story 1.2 — Évaluer la complexité de migration par processus

### Priorité
⚠️ **HIGHEST**

### Description
Classer les processus par complexité de migration sur la base d'une grille de scoring standardisée. Identifier les processus candidats au pilote (quick wins) et ceux nécessitant une refonte partielle ou complète.

### Acceptance Criteria
- ✅ Grille de scoring de complexité définie et validée
- ✅ Chaque processus a un score de migration
- ✅ Heatmap de complexité produite (matrice visualisable)
- ✅ Blockers majeurs identifiés et listés
- ✅ Quick wins listés et priorisés
- ✅ Processus incompatibles avec un simple portage sont flaggés

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

**Modèle de rapport**

```
| Processus | Score | Points d'effort | Refonte requise | Dépendances | Priorité |
|-----------|-------|-----------------|-----------------|-------------|----------|
| (À remplir selon audit) | - | - | - | - | - |
```

---

#### 1.2.5 Identifier les processus incompatibles avec un simple portage
- [ ] Lister les processus avec un score > 40 (ÉLEVÉ)
- [ ] Documenter les bloquants (Spin, custom plugins, patterns non supportés)
- [ ] Évaluer les options (refonte, rejet, décommissionnement)
- [ ] Définir un plan de mitigation par processus
- [ ] Préparer une justification métier/technique pour chaque bloquant

**Modèle de rapport**

```
| Processus | Score | Bloquants | Options | Impact | Plan mitigation |
|-----------|-------|-----------|---------|--------|-----------------|
| (À remplir selon audit) | - | - | - | - | - |
```

---

### Heatmap de complexité

| Critère | Niveau | Exemple |
|---------|--------|---------|
| Flux BPMN (tâches, gateway) | 🟢 Faible | DemandeServiceIT : 5 tâches, 1 XOR |
| Java Delegates | 🟡 Moyen | 3 delegates à porter en REST |
| Formulaires Camunda | 🟡 Moyen | 2 forms à réécrire en HTML/React |
| Variables de processus | 🟢 Faible | Types simples (String) |
| Timers et boundary events | 🟢 Faible | Aucun identifié |
| Scripts JSR-223 | 🔴 À confirmer | À documenter lors de l'audit complet |
| External tasks | 🟢 Faible | Aucun identifié |
| Sous-processus | 🟢 Faible | Aucun identifié |
| History / Audit | 🟡 À confirmer | History level à vérifier |
| Identity / Plugins | 🟢 Faible | Aucun plugin custom |

---

---

## Story 1.3 — Définir la stratégie de coexistence Camunda/Kogito

### Priorité
⚠️ **HIGHEST**

### Description
Concevoir et valider la stratégie de transition entre le moteur source (Camunda 7) et le moteur cible (Kogito) pour assurer une migration fluide, sans coupure de service et avec possibilité de rollback.

### Acceptance Criteria
- ✅ Stratégie "new instances on Kogito / old instances on Camunda" **validée ou rejetée explicitement**
- ✅ Scénario de cutover détaillé (date, versioning, communications)
- ✅ Plan de rollback complet et testé (RTO, RPO définis)
- ✅ Règles de routage documentées (feature flag, API Gateway, etc.)
- ✅ Rôles et responsabilités clairs (tech lead, DBA, DevOps, métier)
- ✅ Métriques de succès et critères de basculement définies
- ✅ Points de synchronisation identifiés (historique, données, état)

### Tasks

#### 1.3.1 Définir le mode coexistence

**Mode retenu : New instances on Kogito / Old instances on Camunda 7**

Cette stratégie est la **seule viable** pour éviter une coupure de service. Elle repose sur les principes suivants :

1. **Instances en cours de Camunda** → Continuent à s'exécuter sur Camunda 7 jusqu'à leur **fin naturelle**
2. **Nouvelles instances post-cutover** → Sont **routées vers Kogito**
3. **Coexistence transitoire** → Les deux moteurs tournent en parallèle pendant une **période définie** (ex. 2–6 mois)
4. **Décommissionnement progressif** → Camunda 7 est éteint une fois le parc d'instances actives à zéro

**Avantages**
- ✅ Zéro interruption de service
- ✅ Risque de régression minimisé (instances critiques restent sur Camunda)
- ✅ Possibilité de tester Kogito en environnement réel
- ✅ Rollback trivial (switch du feature flag)

**Inconvénients**
- ⚠️ Exploitation de deux moteurs pendant 2–6 mois
- ⚠️ Synchronisation des données entre moteurs (historique, audit)
- ⚠️ Risque de dépendances non documentées entre instances

**Alternatives rejetées**
- ❌ **Big bang cutover** : Trop risqué, coupure de service garantie
- ❌ **Processus par processus** : Trop complexe à orchestrer, dépendances inter-processus
- ❌ **Shadow mode** (test passif) : Kogito tournant en parallèle sans traiter réellement — overkill pour ce cas

---

#### 1.3.2 Définir le mode de routage des nouvelles instances

**Option 1 : Feature flag applicatif** ✅ RECOMMANDÉE

- **Description** : Variable de configuration dans le service appelant
- **Implémentation** : `engine=kogito|camunda` dans `application.properties`
- **Complexité** : Faible
- **Code exemple** :
  ```java
  String engine = env.getProperty("workflow.engine", "camunda");
  if ("kogito".equals(engine)) {
    return kogitoProcessStarter.start(request);
  } else {
    return camundaProcessStarter.start(request);
  }
  ```

**Avantages**
- ✅ Activable/désactivable en 2 min (redéploiement du service appelant)
- ✅ Pas d'impact sur l'infrastructure
- ✅ Rollback instantané
- ✅ Testable localement

**Inconvénients**
- ⚠️ Requiert un redéploiement du service appelant

---

**Option 2 : API Gateway routing**

- **Description** : L'API Gateway redirige `/process/start` selon la cible (Camunda vs Kogito)
- **Implémentation** : Règles de routage niveau Kong, Nginx, AWS API Gateway
- **Complexité** : Moyenne
- **Config exemple (Kong)** :
  ```yaml
  routes:
    - name: process-camunda
      paths: ["/process/start/camunda"]
      upstream_url: http://camunda:8080
    - name: process-kogito
      paths: ["/process/start/kogito"]
      upstream_url: http://kogito:8080
  ```

**Avantages**
- ✅ Zéro code change dans l'applicatif
- ✅ Routage centralisé et monitarisable

**Inconvénients**
- ⚠️ Configuration complexe au niveau infrastructure
- ⚠️ Clients doivent connaître l'endpoint correct
- ⚠️ Risque d'erreurs de configuration

---

**Recommandation finale** : **Feature flag applicatif**
- Simple à implémenter et à tester
- Pas de dépendance infra complexe
- Contrôle fin au niveau de chaque service appelant

---

#### 1.3.3 Définir le plan de cutover

**Phases et timeline**

| Phase | Étape | Durée | Responsable | Condition de succès |
|-------|-------|-------|------------|-------------------|
| **Préparation** | Déployer Kogito sur K8s avec processus porté (EPIC 3) | 2–3 semaines | Tech Lead + DevOps | DemandeServiceIT déployé et fonctionnel |
| **Validation** | Tester fonctionnellement et en non-régression sur Kogito | 1–2 semaines | QA + métier | Tous les scénarios validés, zéro défauts bloquants |
| **Activation** | Activer feature flag `engine=kogito` pour nouvelles instances | 1 jour | Tech Lead | Feature flag déployé, monitoring actif |
| **Observation** | Laisser instances Camunda en cours se terminer naturellement | 2–6 mois | Support + Ops | Zéro instance active sur Camunda |
| **Archivage** | Exporter et archiver historique Camunda | 1 semaine | DBA | Historique complètement sauvegardé |
| **Décommissionnement** | Arrêter Camunda 7 et libérer ressources | 1 jour | DevOps | Services de monitoring arrêtés |

**Plan détaillé pré-cutover (J-5 à J0)**

```
J-5 : Freeze du code applicatif (stable branch)
      Validation complète de la chaîne Kogito en prod-like
      
J-3 : Backup complet de la base Camunda 7 (PROD)
      Vérification des procédures de rollback
      
J-2 : Communication à tous les stakeholders (métier, users)
      Validation des plans d'escalade et support 24/7
      
J-1 : Reprise en charge des instances "anciennes" sur Camunda
      Préparation des dashboards de monitoring dual-moteur
      
J0  : Activation du feature flag engine=kogito à H+X (ex. 14h00)
      Monitoring continu : Kogito + Camunda
      Surveillance des logs et des erreurs applicatives
      
J+1 : Débrief technique — prise en compte des incidents
      Validation de la stabilité
      Communication aux stakeholders
```

**Communication pré-cutover**

- **J-10** : Notification stratégique (direction, support)
- **J-5** : Notification opérationnelle (ops, support, métier)
- **J-1** : Mail de confirmation cutover (tous stakeholders)
- **Pendant** : War room en direct (Slack #incident, calls toutes les 30 min)
- **J+1** : Débrief et bilan de santé

---

#### 1.3.4 Définir le plan de rollback

**Objectif** : En cas de dysfonctionnement sur Kogito après le cutover, revenir instantanément à Camunda 7 **sans impact sur les instances en cours**.

**Trigger de rollback**

Activer le rollback si l'une des conditions est réalisée :
- 🔴 **Disponibilité** : Kogito DOWN > 5 min (SLA : 99.9%)
- 🔴 **Erreur métier** : Taux d'erreurs > 5% (vs baseline < 0.5%)
- 🔴 **Perte de données** : Variables de processus corrompues
- 🔴 **Régression fonctionnelle** : Processus ne se terminent plus normalement
- 🟡 **Dégradation** : Latence > 3× baseline (timeout utilisateurs)

**Procédure de rollback (RTO = 2 minutes)**

| # | Étape | Durée | Commande / Action |
|---|-------|-------|-------------------|
| 1 | Validation de la décision rollback | 2 min | War room : décision collective Tech Lead + responsable métier |
| 2 | Désactivation feature flag | 30 sec | `engine=camunda` dans config, `kubectl rollout restart` service |
| 3 | Vérification base Camunda | 30 sec | Health check : `/engine-rest/metrics` en 200 OK |
| 4 | Monitoring dual-moteur | 2 min | Vérifier : nouvelles instances → Camunda, anciennes → Kogito |
| 5 | Communication | 1 min | Mail/Slack : rollback complété, ETA retour Kogito |

**État post-rollback**

```
Instances créées avant cutover → S'exécutent sur Camunda 7 (pas de changement)
Instances créées pendant Kogito → Restent sur Kogito jusqu'à leur fin
Nouvelles instances (après rollback) → Routées vers Camunda 7
```

**Point fort** : Grâce au feature flag, le rollback est **immédiat et sans impact** sur les instances en cours. Les instances Kogito continuent de s'exécuter normalement.

**Métriques de succès rollback**
- ✅ Feature flag désactivé < 1 min
- ✅ RTO réalisé ≤ 2 min
- ✅ Zéro nouvelle erreur post-rollback
- ✅ Instances Kogito restantes se terminent correctement

---

#### 1.3.5 Définir la stratégie de fin de vie Camunda 7

**Règles de décommissionnement**

| Condition | Action | Responsable | Délai |
|-----------|--------|------------|-------|
| **Zéro instance active sur Camunda** | Déclencher la procédure de décommissionnement | Tech Lead | Immédiat |
| **Historique Camunda à archiver** | Export et archivage en base externe ou S3 | DBA / Ops | Avant arrêt |
| **Infra Camunda (DB, server)** | Suppression après validation archivage | DevOps | 1 jour après archivage |

**Procédure d'archivage historique (pré-shutdown)**

**Point critique** : Kogito ne dispose **pas** d'un équivalent natif au History Service de Camunda 7. L'historique des instances Camunda doit être archivé avant le décommissionnement.

| # | Étape | Outil | Cible |
|---|-------|------|-------|
| 1 | Export table ACT_HI_* (historique Camunda) | `mysqldump` / `pg_dump` | SQL dump |
| 2 | Export des variables historiques | Requête SQL `SELECT * FROM ACT_HI_VARINST` | CSV / Parquet |
| 3 | Compression et chiffrement | `gzip + GPG` | Archive |
| 4 | Upload en stockage long terme | S3 / Azure Blob / archive DB | Immuable |
| 5 | Validation de l'intégrité (checksum) | `sha256sum` | Logs |
| 6 | Suppression des tables source | `DROP TABLE` | Audit trail |

**Exemple SQL pour export**
```sql
-- Backup complet ACT_HI_*
mysqldump --single-transaction --set-gtid-purged=OFF \
  camunda_db ACT_HI_PROCINST ACT_HI_ACTINST ACT_HI_VARINST \
  > camunda_history_$(date +%Y%m%d).sql

-- Vérification export
mysql -u user -p camunda_db < camunda_history_*.sql
```

**Stockage d'archive recommandé**
- ✅ **S3 Glacier** : Faible coût, conservation long terme (7 ans+)
- ✅ **PostgreSQL archiving** : Table `audit_camunda_history` séparée avec TTL
- ✅ **Elasticsearch** : Pour requêtes d'audit, analyse d'impact

---

#### 1.3.6 Définir les critères de bascule complète

**Définition** : Moment où passer de "coexistence transitoire" à "Kogito seul".

**Critères de bascule**

| Critère | Seuil | Mesure | Status |
|---------|-------|--------|--------|
| **Instances actives Camunda** | = 0 | Requête : `SELECT COUNT(*) FROM ACT_RU_EXECUTION WHERE END_TIME IS NULL;` | À atteindre |
| **Incidents Kogito en prod** | = 0 | Incidents critiques (P1) depuis cutover | À valider |
| **Taux d'erreur Kogito** | < 0.5% | `(500 errors + timeouts) / total requests` | À respecter |
| **Performance Kogito** | > 95e centile baseline | Latence p95 vs Camunda historique | À confirmer |
| **Archivage historique Camunda** | 100% | Vérification des dumps SQL en S3 | À accomplir |
| **Validation métier** | Approuvé | Sign-off responsable métier | À obtenir |

**Process de validation bascule**

```
Jour N (instances = 0) :
  ✓ Décision de bascule complète validée par steering committee
  ✓ Sign-off métier, tech, support
  ✓ Historique Camunda archivé et vérifié
  ✓ War room : monitoring Kogito 24/7 pendant 48h
  
Jour N+2 :
  ✓ Arrêt officiel Camunda 7 (après monitoring stable)
  ✓ Decommissioning infrastructure
  ✓ Documentation de clôture EPIC 1
  
Jour N+7 :
  ✓ Leçons apprises (retro)
  ✓ Archivage des données de migration
```

---

### Schéma de la stratégie de coexistence

```
┌─────────────────────────────────────────────────────────────┐
│ TIMELINE DE MIGRATION CAMUNDA 7 → KOGITO                   │
└─────────────────────────────────────────────────────────────┘

      PHASE 1                  PHASE 2              PHASE 3
   (Avant cutover)        (Coexistence)       (Décommissionnement)
   ─────────────────      ─────────────────    ─────────────────
       2–3 sem                 2–6 mois             1 sem

Développement       Cutover (J0)               Archivage
& Test         ──────────────→               ─────────→
  Kogito                │              Instances = 0
                        │
     ├─ BPMN porté      │                  ├─ Export ACT_HI_*
     ├─ Delegates       │                  ├─ Upload S3
     ├─ Forms          │                  ├─ Validation
     └─ Data Index     │                  └─ Vérification


       ↓                ↓                      ↓
    Camunda 7      Camunda 7 (OLD)          ARRÊT
    EXISTANT       ├─ Instances en cours    Camunda 7
                   │  se terminent
                   │  naturellement
                   │
                   └─ Zéro impact


                   Kogito (NEW)
                   ├─ Nouvelles instances
                   │  (feature flag = on)
                   │
                   └─ Monitoring 24/7


                   ↓                          ↓
             COEXISTENCE               Kogito SEUL
             2 moteurs en              (Cloud-native)
             parallèle

```

---

### Rôles et responsabilités

| Rôle | Responsabilités | Lors du cutover |
|-----|-----------------|-----------------|
| **Tech Lead** | Validation technique, décision rollback, sign-off | War room, flag activation, rollback decision |
| **DevOps / SRE** | Déploiements, infra K8s, monitoring | Activation, escalade monitoring |
| **DBA** | Archivage données, backup Camunda | Backup pré-cutover, export historique |
| **QA** | Tests fonctionnels, régression | Validation pré-cutover, suivi incidents |
| **Métier** | Acceptation, communication users | Sign-off, validation métier |
| **Support** | Escalade incidents, hotline | Support 24/7 pendant coexistence |
| **Architecture** | Validation stratégie, design cutover | Validation plan de rollback |

---

### Checklist pré-cutover

- [ ] EPIC 3 complète : Kogito déployé et fonctionnel
- [ ] Tests fonctionnels et régression : ✅ Passed
- [ ] Feature flag implémenté et testé localement
- [ ] Backup complet Camunda 7 (DEV, TEST, PROD)
- [ ] War room : calendrier 24h post-cutover bloqué
- [ ] Communication stakeholders : Notification J-5, J-1
- [ ] Monitoring dual-moteur : Dashboards Prometheus/Grafana prêts
- [ ] Plan rollback : Testé en stage
- [ ] Procédure archivage : SQL scripts validés
- [ ] SLA définis : RTO ≤ 2 min, RPO ≤ 5 min
- [ ] Escalade : Points de contact 24/7 nommés
- [ ] Sign-off métier + architecture + DevOps

---

---

## Résumé exécutif EPIC 1

### Objectif réalisé
L'EPIC 1 établit les **fondations** de la migration Camunda 7 → Kogito par un inventaire exhaustif, une évaluation de complexité et une stratégie de coexistence robuste.

### Livrables clés

| Livrable | Status | Propriétaire |
|----------|--------|--------------|
| Inventaire assets Camunda 7 | ⏳ En cours (Story 1.1) | Tech Lead |
| Grille de scoring & heatmap complexité | ⏳ En cours (Story 1.2) | Architecture |
| Stratégie coexistence validée | ⏳ En cours (Story 1.3) | Architecture + Tech Lead |
| Plan de cutover détaillé | 📋 À produire | DevOps |
| Plan de rollback testé | 📋 À produire | SRE |
| Processus candidat pilote identifié | ✅ DemandeServiceIT | Architecture |

### Points critiques à valider

1. **History Level Camunda** : Si `full`, le Data Index Kogito doit être déployé explicitement
2. **Patterns Spin / Java objects** : Bloquant critique — à confirmer absent
3. **Formulaires Camunda embedded** : Réécriture HTML/React obligatoire
4. **Portage Java Delegates** : 3 delegates → REST nodes ou Work Item Handlers

### Prochaines étapes (EPIC 2–3)

- **EPIC 2** : Détail des processus, schéma mapping, documentation
- **EPIC 3** : Développement et déploiement Kogito
- **EPIC 4** : Cutover et monitoring
- **EPIC 5** : Décommissionnement Camunda 7

---

## Annexes

### A. Références et documentation

- [Camunda 7 Process Engine](https://docs.camunda.org/manual/7.20/)
- [Kogito User Guide](https://kogito.kie.org/guides/)
- [Kogito on Kubernetes](https://github.com/kiegroup/kogito-examples)
- [Data Index Service](https://kogito.kie.org/guides/data-index-service/)

### B. Glossaire

| Terme | Définition |
|-------|-----------|
| **BPMN** | Business Process Model and Notation — standard de modélisation de processus |
| **DMN** | Decision Model and Notation — standard pour les règles métier |
| **JavaDelegate** | Classe Camunda implémentant la logique métier d'une service task |
| **History Level** | Niveau de détail de l'historique des instances (full, activity, variable, none) |
| **Work Item Handler** | Équivalent Kogito des JavaDelegate Camunda |
| **Data Index** | Service Kogito qui remplace le History Service de Camunda 7 |
| **Jobs Service** | Service Kogito qui remplace le Job Executor de Camunda 7 |
| **Cutover** | Basculement des nouvelles instances de Camunda vers Kogito |
| **RTO** | Recovery Time Objective — durée pour revenir à la normale après incident |
| **RPO** | Recovery Point Objective — quantité de données acceptable à perdre |

### C. Modèles de templates

#### Matrice des processus inventoriés
```markdown
| # | Processus | Score | Classification | Dépendances | Notes |
|---|-----------|-------|-----------------|-------------|-------|
| 1 | DemandeServiceIT | 11/63 | Quick Win | Aucune | Processus pilote |
| 2 | (À compléter) | ? | ? | ? | ? |
```

#### Fiche de migration par processus
```markdown
## Processus : [NOM]
- **Score** : X/63
- **Classification** : FAIBLE | MOYEN | ÉLEVÉ
- **Blockers** : Aucun | (liste)
- **Assets à migrer** : BPMN, forms, delegates, etc.
- **Responsable** : (Tech Lead)
- **Timeline estimée** : (jours)
- **Risques** : (liste)
- **Plan mitigation** : (description)
```

---

**Document édité le 14 avril 2026**  
**Version 1.0 — DRAFT**