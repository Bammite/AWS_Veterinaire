# Note de Justification Architecture — Spring PetClinic sur AWS
**Projet Académique — ISI Dakar (2024-2025)**  
*M1 Virtualisation Cloud & Réseaux AWS Architecting Avancé*  
*Binôme : Déploiement de Production Spring PetClinic*

---

## 📖 Partie A — Analyse de l'application

Pour concevoir et justifier l'architecture cible sur AWS, il convient d'abord d'analyser les caractéristiques intrinsèques de l'application Spring PetClinic.

### 1. Découpage en tiers et nature du composant à exécuter
* **Caractérisation :** L'application suit un modèle classique à **3-tiers** composé d'une couche de présentation (Thymeleaf/HTML5/Bootstrap), d'une couche métier (Services Spring Boot) et d'une couche de données (Spring Data JPA / Hibernate).
* **Justification :** Bien que logiquement séparées, les couches de présentation et métier sont packagées au sein d'un unique monolithe (fichier JAR exécutable). Nous l'exécutons sous forme de **conteneur Docker** (ou JAR managé via script Systemd dans les machines) pour standardiser l'environnement d'exécution et simplifier le déploiement sur AWS.

### 2. État applicatif : stateless vs stateful
* **Caractérisation :** Le serveur d'application Spring Boot est entièrement **stateless** (sans état), tandis que la base de données relationnelle est **stateful** (conserve l'état).
* **Justification :** L'application ne stockant aucune session utilisateur sur le disque local ni aucun fichier persistant côté serveur, nous pouvons détruire et recréer les instances applicatives à la volée. Toutes les informations (propriétaires, animaux, visites) sont externalisées dans la base de données relationnelle managée pour permettre un passage à l'échelle horizontal sans perte de données.

### 3. Persistance : choix MySQL ou PostgreSQL et conséquences sur RDS
* **Caractérisation :** Le projet supporte nativement **MySQL** et **PostgreSQL** via des profils Spring Boot (`mysql` ou `postgres`). Nous avons retenu **MySQL**.
* **Justification :** Ce choix s'appuie sur **Amazon RDS for MySQL** configuré en **Multi-AZ**, ce qui offre des sauvegardes automatisées, des correctifs transparents et une réplication synchrone vers une zone de secours. L'utilisation de RDS élimine la charge d'administration du SGBD mais nécessite d'injecter dynamiquement l'URL JDBC et les identifiants via des variables d'environnement au démarrage de l'application.

### 4. Besoins de disponibilité, de montée en charge et de tolérance aux pannes
* **Caractérisation :** L'application doit être hautement disponible, capable de supporter la panne d'un centre de données (Zone de Disponibilité) et de s'adapter automatiquement aux fluctuations de charge.
* **Justification :** Pour cela, les instances applicatives sont déployées au sein d'un **Auto Scaling Group (ASG)** réparti sur **deux zones de disponibilité (us-east-1a et 1b)**, coordonnées par un **Application Load Balancer (ALB)** qui effectue des *health checks* réguliers. De même, la base de données RDS est déployée en mode Multi-AZ pour garantir un basculement automatique et transparent de l'instance principale vers l'instance secondaire en cas d'incident sur une zone.

### 5. Gestion de la configuration et des secrets
* **Caractérisation :** Les configurations (profil de production) et les données sensibles (mots de passe de base de données) doivent être externalisées et sécurisées en dehors du code et des images de conteneurs.
* **Justification :** Nous utilisons **AWS Secrets Manager** pour stocker de manière chiffrée les identifiants de la base de données RDS. Grâce à un rôle IAM attaché aux instances de calcul (EC2 ou conteneurs), l'application récupère de façon sécurisée ces informations d'identification au démarrage, éliminant ainsi toute information d'identification codée en dur dans le code source ou dans les scripts Terraform.

### 6. Surface de sécurité : exposition réseau, accès d'administration et chiffrement
* **Caractérisation :** La surface d'attaque doit être minimale : aucun port d'administration ne doit être exposé directement sur Internet, et les flux doivent être chiffrés.
* **Justification :** Seul l'ALB est exposé dans les sous-réseaux publics, tandis que les serveurs d'application et la base de données sont confinés dans des sous-réseaux privés dotés de groupes de sécurité chaînés (Internet $\rightarrow$ ALB $\rightarrow$ Instances App $\rightarrow$ RDS DB). Le chiffrement est appliqué globalement : en transit via TLS (HTTPS) sur l'ALB et au repos via des clés de chiffrement gérées par **AWS KMS** pour les volumes EBS de calcul, le stockage S3 et l'instance RDS.

---

## 🗺️ Schéma d'Architecture Logique (3-Tiers)

```mermaid
graph TD
    %% Styling
    classDef client fill:#f9f9f9,stroke:#333,stroke-width:2px;
    classDef pres fill:#d4ebf2,stroke:#006699,stroke-width:2px;
    classDef business fill:#e2f0d9,stroke:#385723,stroke-width:2px;
    classDef data fill:#fff2cc,stroke:#b25900,stroke-width:2px;
    
    %% Nodes
    Client["Navigateur Client (HTTPS)"]:::client
    
    subgraph PresentationTier ["Tiers Présentation (Exposition & UI)"]
        UI["Interface Thymeleaf / Webjars<br/>(HTML / CSS / JS statiques)"]:::pres
        Controller["Spring MVC Controllers<br/>(Routage & Data Binding)"]:::pres
    end
    
    subgraph BusinessTier ["Tiers Métier (Logique Application)"]
        Service["Services Spring Boot<br/>(Logique métier : Owners, Vets, Pets, Visits)"]:::business
        Domain["Modèle de Domaine<br/>(Entités JPA : Owner, Vet, Pet, Visit)"]:::business
    end
    
    subgraph DataTier ["Tiers Données (Persistance)"]
        Repository["Spring Data JPA Repositories<br/>(Abstraction Data Access / Hibernate)"]:::data
        Database[("Amazon RDS MySQL<br/>(Base Relationnelle Multi-AZ)")]:::data
    end

    %% Flows
    Client -->|Requêtes HTTPS (port 443)| UI
    UI --> Controller
    Controller --> Service
    Service --> Domain
    Service --> Repository
    Repository -->|Connexion JDBC (port 3306)| Database
```

---

## 📊 Partie C — Justification & Défense des Choix Techniques

Pour le choix de la solution de calcul (*Compute*), nous avons comparé trois options d'architecture AWS répondant aux critères Well-Architected.

### 1. Tableau Comparatif des Options de Calcul

| Critère | Option 1 : EC2 + Auto Scaling + ALB (Retenu) | Option 2 : ECS Fargate + ALB | Option 3 : AWS App Runner |
| :--- | :--- | :--- | :--- |
| **Coût de mise en place et d'exploitation** | **Modéré à Faible (Free Tier)**. Les instances `t3.micro` sont éligibles à l'offre gratuite ou très peu coûteuses. | **Modéré**. Pas d'instances à gérer, mais Fargate facture à la seconde (CPU/RAM), ce qui est plus coûteux hors Free Tier. | **Plus Élevé**. Tarification fixe par instance active + tarification à la requête, sans support du Free Tier. |
| **Résilience / Haute Disponibilité** | **Excellente**. Géré par l'Auto Scaling Group (ASG) réparti sur plusieurs zones de disponibilité (Multi-AZ). | **Excellente**. Remplacement automatique des conteneurs en cas de panne physique, natif Multi-AZ. | **Excellente**. Géré entièrement par AWS sur plusieurs AZ de manière transparente. |
| **Scalabilité et Performance** | **Bonne**. Scaling horizontal automatique basé sur les métriques CPU/Mémoire, mais démarrage d'instances prend 1 à 2 min. | **Excellente**. Mise à l'échelle horizontale très rapide des conteneurs (en quelques secondes). | **Très Bonne**. Auto-scaling intégré et automatique basé sur le nombre de requêtes simultanées. |
| **Complexité opérationnelle** | **Plus Élevée**. Nécessite de configurer les scripts de démarrage (`user_data.sh`), OS (Ubuntu), et agents CloudWatch. | **Modérée**. Pas de serveurs à maintenir, mais nécessite de gérer les définitions de tâches ECS et registres ECR. | **Minimale**. Entièrement serverless, aucune infrastructure réseau ou serveur à configurer. |
| **Sécurité** | **Excellente**. Contrôle total sur les groupes de sécurité, le chiffrement KMS des volumes EBS, et IAM. | **Excellente**. Isolation native au niveau conteneur, aucun OS partagé à sécuriser. | **Très Bonne**. Géré par AWS, mais moins de contrôle fin sur l'architecture réseau sous-jacente. |
| **Rapidité de mise en œuvre (Time-to-market)** | **Moyenne**. Demande l'écriture de scripts de configuration d'OS et de gestion d'AMI. | **Bonne**. Nécessite uniquement la création d'un Dockerfile et d'un dépôt d'images ECR. | **Excellente**. Déploiement direct depuis un dépôt Git ou ECR en quelques clics. |
| **Adéquation aux compétences du binôme** | **Parfaite**. Repose sur des concepts AWS classiques (VPC, EC2, ALB, Systemd) acquis durant le cours. | **Moyenne**. Requiert la maîtrise de Docker et des configurations de conteneurs ECS/Fargate. | **Faible**. Solution très automatisée mais moins instructive pour comprendre l'architecture réseau sous-jacente (VPC/Routing). |

---

### 2. Argumentaire et Compromis de l'Option Retenue

#### Pourquoi l'Option 1 (EC2 + ASG + ALB) est la meilleure pour ce cas d'usage ?
L'architecture reposant sur **Amazon EC2 dans un groupe d'Auto Scaling (ASG)** associé à un **Application Load Balancer (ALB)** a été choisie pour les raisons suivantes :

1. **Maîtrise Pédagogique et Académique :** Ce modèle permet de configurer explicitement l'ensemble des couches d'infrastructure (VPC, tables de routage, NAT Gateways, sous-réseaux publics et privés). Utiliser une solution trop managée comme App Runner masquerait cette complexité réseau et priverait le binôme de la compréhension pratique du routage IP et des groupes de sécurité.
2. **Optimisation FinOps stricte (Zéro Coût résiduel sur Free Tier) :** L'utilisation de machines virtuelles `t3.micro` entre pleinement dans l'offre d'évaluation gratuite d'AWS (*AWS Free Tier*). Contrairement à Fargate ou App Runner, nous n'avons aucun coût de calcul facturé hors forfait pendant la durée du TP.
3. **Contrôle et Personnalisation :** Nous maîtrisons entièrement le système d'exploitation (Ubuntu 22.04 LTS), ce qui nous permet d'installer les dépendances spécifiques (ex: OpenJDK 17) et d'ajuster finement les agents de logs et de métriques CloudWatch pour l'observabilité.

#### Les Compromis Assumés
Tout choix d'architecture impose des compromis (*trade-offs*). Voici ceux que nous assumons pour ce déploiement :

* **Charge opérationnelle accrue (Operational Overhead) :** Nous devons gérer la configuration de l'OS, les mises à jour de sécurité des packages système (via `apt update`) et le cycle de vie de la machine virtuelle (gestion du script `user_data.sh`). En production réelle, une équipe préférerait **ECS Fargate** pour éliminer cette gestion d'OS.
* **Vitesse de mise à l'échelle (Scaling latency) :** Le démarrage d'une nouvelle instance EC2 et l'installation de Java/téléchargement du JAR prend environ **90 à 120 secondes**, ce qui est plus lent que le démarrage d'un conteneur ECS (quelques secondes). C'est un compromis acceptable au vu de la nature peu fluctuante de la charge sur cette application de démonstration.
* **Coût des NAT Gateways :** Pour respecter la tolérance aux pannes Multi-AZ, nous avons déployé 2 NAT Gateways (une dans chaque AZ publique). En production, c'est indispensable pour la résilience, mais pour un environnement de test, cela représente un coût fixe non négligeable de ~$0.09/heure.

---

## 🎤 Préparation à la Soutenance Orale : Questions de Défense

Pour préparer l'évaluation devant le jury (Section 8 de l'énoncé), voici les réponses aux questions clés de défense d'architecture :

### Q1. Que se passe-t-il si une zone de disponibilité (AZ) tombe ? Démontrez la continuité de service.
* **Réponse :** Si la zone `us-east-1a` subit une panne majeure, l'ALB détecte instantanément que l'instance EC2 située dans cette zone est défectueuse ou injoignable grâce aux contrôles de santé (*health checks* sur `/actuator/health`). L'ALB coupe immédiatement le routage vers cette instance et redirige 100 % du trafic utilisateur vers l'instance saine située dans la zone `us-east-1b`. Côté base de données, l'instance RDS principale (si elle était dans la zone en panne) bascule automatiquement et de manière transparente vers l'instance secondaire répliquée en synchrone dans la zone saine, maintenant l'application en ligne sans perte de données.

### Q2. Où est stocké le mot de passe de la base de données, et comment l'application y accède-t-elle sans clé en dur ?
* **Réponse :** Le mot de passe de la base de données est généré aléatoirement par Terraform et immédiatement stocké dans **AWS Secrets Manager**, chiffré par une clé KMS personnalisée. Au démarrage d'une instance EC2, le script de démarrage `user_data.sh` exécute une requête sécurisée vers l'API de Secrets Manager (via l'AWS CLI) pour extraire ce mot de passe. Cette requête est autorisée uniquement grâce au **Rôle IAM d'Instance** (Instance Profile) attaché à la machine virtuelle, qui utilise des identifiants temporaires générés par AWS Security Token Service (STS) ; aucune clé d'accès ou mot de passe statique n'est présent dans le code source ou dans les fichiers Terraform.

### Q3. Pourquoi avoir choisi cette option de calcul plutôt qu'une autre ? Quel est le compromis principal ?
* **Réponse :** Nous avons choisi les instances EC2 dans un Auto Scaling Group pour maximiser l'éligibilité au *Free Tier* de calcul et conserver un contrôle total sur l'infrastructure réseau (indispensable pour l'évaluation académique). Le compromis principal est l'**effort d'exploitation (operational overhead)** : nous devons maintenir l'OS de l'instance et sa configuration de démarrage, contrairement à une approche Serverless (ECS Fargate) qui éliminerait totalement cette gestion de serveurs au prix d'une tarification plus stricte.

### Q4. Comment l'application monte-t-elle en charge ? Quel signal déclenche le scaling ?
* **Réponse :** L'élasticité est pilotée par des politiques d'Auto Scaling associées à notre ASG. Nous surveillons l'utilisation moyenne du CPU des instances actives via **Amazon CloudWatch**. Si la charge moyenne dépasse le seuil de **70% de CPU pendant 2 minutes consécutives**, une alarme CloudWatch se déclenche et ordonne à l'ASG d'ajouter une nouvelle instance EC2 dans les sous-réseaux privés pour répartir la charge. À l'inverse, si l'utilisation descend en dessous de 30% pendant 5 minutes, une politique de *scale-in* détruit progressivement les instances excédentaires pour économiser les coûts.

### Q5. Quel est le coût mensuel estimé de cette architecture, et comment le réduiriez-vous en environnement réel ?
* **Réponse :** 
  * **Coût estimé (hors Free Tier) :**
    - 2 instances EC2 `t3.micro` : ~$15/mois.
    - 1 base RDS MySQL `db.t3.micro` Multi-AZ : ~$32/mois.
    - 2 NAT Gateways : ~$65/mois (coût fixe majeur pour le trafic réseau sortant).
    - 1 ALB : ~$22/mois.
    - *Total estimé : ~$134/mois.*
  * **Pistes d'optimisation en production réelle :**
    1. **Supprimer une NAT Gateway en environnement de non-prod :** N'utiliser qu'une seule NAT Gateway partagée entre les AZs pour diviser par deux le coût réseau fixe.
    2. **Instances Spot :** Utiliser des instances EC2 Spot pour l'ASG de l'application (économie de près de 70% par rapport au tarif à la demande).
    3. **RDS Single-AZ en dév :** Désactiver le Multi-AZ de la base RDS en environnement de développement ou test pour réduire la facture de moitié.
    4. **Passer sur Graviton :** Utiliser des instances de calcul et de base de données de type `t4g` (processeurs ARM Graviton d'AWS) qui offrent un meilleur rapport performance/prix de 20% par rapport aux instances Intel/AMD classiques.
