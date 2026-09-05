% train_model.m
% Script d'entraînement des trois modèles de compression CSI
%
% IMPORTANT :
%   - Les données sont chargées depuis : data/cdl_3gpp_data_clean.mat
%   - Les données doivent être transformées au format [32 32 2 N]
%   - Les modèles sont sauvegardés dans : trained_models/

clear; clc; close all;

% Récupérer le dossier du projet
script_dir = fileparts(mfilename('fullpath'));
PROJECT_DIR = fileparts(script_dir);
addpath(genpath(PROJECT_DIR));

fprintf('=== Démarrage de l''entraînement ===\n');

% ------------------------------------------------------------
% 1. Charger les données
% ------------------------------------------------------------
data = load(fullfile(PROJECT_DIR, 'data', 'cdl_3gpp_data_clean.mat'));
X_train = data.data.X_train;
X_val = data.data.X_val;

fprintf('Données chargées : X_train (%d samples), X_val (%d samples)\n', ...
    size(X_train,1), size(X_val,1));

% ------------------------------------------------------------
% 2. Reshaper les données au format 4D [32 32 2 N]
% ------------------------------------------------------------
% Supposons que X_train est de taille N x 2048
% On transforme en 32 x 32 x 2 x N
N_train = size(X_train, 1);
X_train_4D = reshape(X_train', 32, 32, 2, N_train);

N_val = size(X_val, 1);
X_val_4D = reshape(X_val', 32, 32, 2, N_val);

fprintf('Données reshapeées au format 4D :\n');
fprintf('  X_train_4D : %s\n', mat2str(size(X_train_4D)));
fprintf('  X_val_4D   : %s\n', mat2str(size(X_val_4D)));

% ------------------------------------------------------------
% 3. Définir les options d'entraînement
% ------------------------------------------------------------
options = trainingOptions('adam', ...
    'MaxEpochs', 15, ...
    'MiniBatchSize', 64, ...
    'ValidationData', {X_val_4D, X_val_4D}, ...
    'ValidationFrequency', 30, ...
    'Verbose', true, ...
    'Plots', 'training-progress');

% ------------------------------------------------------------
% 4. Entraîner le modèle g4 (gamma = 1/4)
% ------------------------------------------------------------
fprintf('\nEntraînement du modèle g4 (gamma = 1/4)...\n');
lgraph_g4 = build_csinet_pp();
net_g4 = trainNetwork(X_train_4D, X_train_4D, lgraph_g4, options);

% Sauvegarder le modèle
save(fullfile(PROJECT_DIR, 'trained_models', 'net_clean_final.mat'), 'net_g4');
fprintf('Modèle g4 sauvegardé.\n');

% ------------------------------------------------------------
% 5. Entraîner le modèle g8 (gamma = 1/8)
% ------------------------------------------------------------
fprintf('\nEntraînement du modèle g8 (gamma = 1/8)...\n');
lgraph_g8 = build_csinet_pp_g8();
net_g8 = trainNetwork(X_train_4D, X_train_4D, lgraph_g8, options);

% Sauvegarder le modèle
save(fullfile(PROJECT_DIR, 'trained_models', 'net_g8_final.mat'), 'net_g8');
fprintf('Modèle g8 sauvegardé.\n');

% ------------------------------------------------------------
% 6. Entraîner le modèle g16 (gamma = 1/16)
% ------------------------------------------------------------
fprintf('\nEntraînement du modèle g16 (gamma = 1/16)...\n');
lgraph_g16 = build_csinet_pp_g16();
net_g16 = trainNetwork(X_train_4D, X_train_4D, lgraph_g16, options);

% Sauvegarder le modèle
save(fullfile(PROJECT_DIR, 'trained_models', 'net_g16_final.mat'), 'net_g16');
fprintf('Modèle g16 sauvegardé.\n');

fprintf('\n=== Entraînement terminé avec succès ===\n');
