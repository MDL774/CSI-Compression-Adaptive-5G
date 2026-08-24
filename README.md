# Adaptation du taux de compression du CSI selon les conditions
# du canal dans les systèmes Massive MIMO 5G

## Auteur
LOMPO Abdrahamane

## Encadrement
- Dr Désiré GUEL (Encadrant)
- Dr Boureima ZERBO (Superviseur)

## Université
Université Joseph KI-ZERBO (UJKZ)

## Description
Ce dépôt contient l'ensemble des scripts, modèles, données et résultats
associés au mémoire de Master 2 intitulé :
"Adaptation du taux de compression du CSI selon les conditions du canal
dans les systèmes Massive MIMO 5G"

## Structure du dépôt
```
projet_CSI_adaptatif/
├── data/          # Jeux de données
├── models/        # Modèles entraînés
├── scripts/       # Scripts MATLAB
├── results/       # Résultats expérimentaux
│   └── figures/   # Figures générées
├── checkpoints/   # Points de contrôle d'entraînement
├── README.md
└── REPRODUCIBILITY_MANIFEST.txt
```

## Prérequis
- MATLAB R2024a ou supérieur
- 5G Toolbox
- Deep Learning Toolbox
- Communications Toolbox
- Signal Processing Toolbox

## Procédure de reproduction
1. Ajouter le dossier `scripts/` au path MATLAB
2. Exécuter `01_generateCDL_3GPP_clean.m` pour générer les données
3. Exécuter `02_build_models.m` pour construire les architectures
4. Exécuter `03_train_csinet_pp.m` pour entraîner les modèles
5. Exécuter `04_calibrate_policy.m` pour calibrer la politique
6. Exécuter `06_evaluate_adaptive_policy_v3_awgn.m` pour l'évaluation finale

## Résultats principaux
- Overhead moyen adaptatif : **3206,14 bits**
- NMSE adaptatif : **-13,4826 dB**
- Réduction d'overhead : **21,73%**

## Licence
Ce projet est distribué sous licence MIT.

## Contact
[LOMPO Abdrahamane]
