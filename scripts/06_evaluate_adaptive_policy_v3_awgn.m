%% ============================================================
% evaluate_adaptive_policy_test_final.m
%
% EVALUATION FINALE DE LA POLITIQUE ADAPTATIVE CSI
%
% VERSION CORRIGEE SCIENTIFIQUEMENT
%
% PRINCIPES EXPERIMENTAUX :
%
%   1) Calibration realisee UNIQUEMENT sur validation.
%   2) Les seuils de decision sont charges depuis :
%          adaptive_policy_calibration.mat
%   3) Aucun seuil n'est recalcule avec le TEST.
%   4) Le TEST est utilise uniquement pour l'evaluation finale.
%   5) Les memes realisations AWGN sont utilisees pour les
%      differentes politiques afin d'assurer une comparaison
%      equitable (common random numbers).
%   6) Le NMSE est moyenne dans le domaine lineaire puis
%      converti en dB.
%   7) L'overhead est calcule a partir de :
%
%          overhead = gamma * d_in * Q_bits
%
%   8) La contrainte NMSE est explicitement verifiee.
%
% SORTIES :
%
%   - NMSE fixe gamma = 1/4
%   - NMSE fixe gamma = 1/8
%   - NMSE fixe gamma = 1/16
%   - NMSE politique adaptative
%   - overhead moyen des politiques
%   - reduction d'overhead
%   - frequences de selection des gammas
%   - performances par profil
%   - taux de satisfaction de la contrainte NMSE
%   - fichiers CSV / MAT
%   - figures
%
% ============================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' EVALUATION FINALE POLITIQUE ADAPTATIVE - TEST UNIQUEMENT\n');
fprintf(' VERSION CORRIGEE SCIENTIFIQUEMENT\n');
fprintf('============================================================\n');

%% ============================================================
% 1. CONFIGURATION
% =============================================================

PROJECT_DIR = 'C:\AdaptiveCSICompression5G_FinaL';

RESULTS_DIR = fullfile(PROJECT_DIR, 'results');

DATA_FILE = fullfile(PROJECT_DIR, ...
    'cdl_3gpp_data_clean.mat');

CALIBRATION_FILE = fullfile(RESULTS_DIR, ...
    'adaptive_policy_calibration.mat');

MODEL_G4_FILE = fullfile(RESULTS_DIR, ...
    'net_clean_final.mat');

MODEL_G8_FILE = fullfile(RESULTS_DIR, ...
    'net_g8_final.mat');

MODEL_G16_FILE = fullfile(RESULTS_DIR, ...
    'net_g16_final.mat');

%% ------------------------------------------------------------
% Parametres experimentaux
% ------------------------------------------------------------

% Nombre de repetitions independantes AWGN
N_NOISE_REP = 10;

% Graine aleatoire pour reproductibilite
RNG_SEED = 12345;

rng(RNG_SEED, 'twister');

%% ------------------------------------------------------------
% Parametres CSI
% ------------------------------------------------------------

N_FEATURES = 2048;

Q_BITS = 8;

gamma_vals = [1/4, 1/8, 1/16];

Mc_list = [512, 256, 128];

%% ------------------------------------------------------------
% Overhead calcule theoriquement
% ------------------------------------------------------------
%
% O(gamma) = gamma * d_in * Q_bits
%
% d_in = 2048
% Q_bits = 8
%
% gamma = 1/4  -> 4096 bits
% gamma = 1/8  -> 2048 bits
% gamma = 1/16 -> 1024 bits
%

overhead_bits = gamma_vals * N_FEATURES * Q_BITS;

gamma_names = {'g4', 'g8', 'g16'};

NMSE_TARGET_DB = -12;

fprintf('\nConfiguration :\n');

fprintf('  Dimension CSI : %d\n', N_FEATURES);
fprintf('  Quantification : %d bits\n', Q_BITS);

for k = 1:3

    fprintf(['  %-4s : gamma = %.6f | Mc = %4d | ' ...
             'overhead = %4d bits\n'], ...
        gamma_names{k}, ...
        gamma_vals(k), ...
        Mc_list(k), ...
        overhead_bits(k));

end

fprintf('\nRépétitions AWGN : %d\n', N_NOISE_REP);
fprintf('Seed aléatoire   : %d\n', RNG_SEED);
fprintf('Seuil NMSE       : %.2f dB\n', NMSE_TARGET_DB);

%% ============================================================
% 2. VERIFICATION DU REPERTOIRE RESULTATS
% =============================================================

if ~isfolder(RESULTS_DIR)

    error('Le repertoire results est introuvable : %s', ...
        RESULTS_DIR);

end

%% ============================================================
% 3. VERIFICATION DES FICHIERS
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' VERIFICATION DES FICHIERS\n');
fprintf('============================================================\n');

files_to_check = {
    DATA_FILE
    CALIBRATION_FILE
    MODEL_G4_FILE
    MODEL_G8_FILE
    MODEL_G16_FILE
};

for k = 1:numel(files_to_check)

    if ~isfile(files_to_check{k})

        error('Fichier introuvable : %s', ...
            files_to_check{k});

    end

    fprintf('[OK] %s\n', files_to_check{k});

end

%% ============================================================
% 4. CHARGEMENT DU DATASET
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CHARGEMENT DU DATASET TEST\n');
fprintf('============================================================\n');

S_data = load(DATA_FILE);

if ~isfield(S_data, 'data')

    error(['La variable "data" est absente de :\n%s'], ...
        DATA_FILE);

end

data = S_data.data;

%% ------------------------------------------------------------
% Verification des variables dataset
% ------------------------------------------------------------

required_data_fields = {
    'X_test'
    'snr_test'
    'label_test'
};

for k = 1:numel(required_data_fields)

    if ~isfield(data, required_data_fields{k})

        error(['Variable "%s" absente du dataset TEST.'], ...
            required_data_fields{k});

    end

end

X_test = data.X_test;

snr_test = double(data.snr_test(:));

label_test = double(data.label_test(:));

%% ------------------------------------------------------------
% Nombre de samples
% ------------------------------------------------------------

N_test = size(X_test, 1);

if N_test ~= numel(snr_test)

    error(['Incoherence : N_test = %d alors que snr_test contient %d ' ...
           'valeurs.'], ...
        N_test, numel(snr_test));

end

if N_test ~= numel(label_test)

    error(['Incoherence : N_test = %d alors que label_test contient %d ' ...
           'valeurs.'], ...
        N_test, numel(label_test));

end

%% ------------------------------------------------------------
% Verification NaN / Inf
% ------------------------------------------------------------

if any(~isfinite(snr_test))

    error('snr_test contient des valeurs NaN ou Inf.');

end

if any(~isfinite(label_test))

    error('label_test contient des valeurs NaN ou Inf.');

end

fprintf('Nombre de samples TEST : %d\n', N_test);

fprintf('Dimensions X_test : ');
disp(size(X_test));

fprintf('SNR TEST : %.2f à %.2f dB\n', ...
    min(snr_test), max(snr_test));

fprintf('SNR moyen : %.2f dB\n', ...
    mean(snr_test));

%% ============================================================
% 5. VERIFICATION DES PROFILS
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' VERIFICATION DES PROFILS TEST\n');
fprintf('============================================================\n');

labels_unique = unique(label_test);

fprintf('Labels présents dans TEST : ');
disp(labels_unique.');

if ~all(ismember(labels_unique, [1 2]))

    error(['Les labels de profil doivent etre 1 ou 2. ' ...
           'Labels trouves : %s'], ...
        mat2str(labels_unique.'));

end

if ~all(ismember([1 2], labels_unique))

    error(['Les deux profils 1 et 2 doivent etre presents ' ...
           'dans le jeu TEST.']);

end

fprintf('\nDistribution des profils TEST :\n');

for p = 1:2

    idx = label_test == p;

    fprintf('  Profil %d : %d samples (%6.2f %%)\n', ...
        p, ...
        sum(idx), ...
        100 * mean(idx));

end

%% ============================================================
% 6. CHARGEMENT DE LA POLITIQUE CALIBREE
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CHARGEMENT DE LA POLITIQUE CALIBREE\n');
fprintf('============================================================\n');

S_cal = load(CALIBRATION_FILE);

required_fields = {
    'decision_gamma'
    'decision_nmse'
    'decision_overhead'
    'snr_centers'
    'snr_edges'
    'profile_names'
    'gamma_vals'
    'overhead_bits'
    'NMSE_TARGET_DB'
};

for k = 1:numel(required_fields)

    if ~isfield(S_cal, required_fields{k})

        error(['Variable absente du fichier de calibration : %s'], ...
            required_fields{k});

    end

end

%% ------------------------------------------------------------
% Recuperation des variables calibrees
% ------------------------------------------------------------

decision_gamma = double(S_cal.decision_gamma);

decision_nmse = double(S_cal.decision_nmse);

decision_overhead = double(S_cal.decision_overhead);

snr_centers = double(S_cal.snr_centers(:)');

snr_edges = double(S_cal.snr_edges(:)');

profile_names = S_cal.profile_names;

cal_gamma_vals = double(S_cal.gamma_vals(:)');

cal_overhead_bits = double(S_cal.overhead_bits(:)');

cal_target_db = double(S_cal.NMSE_TARGET_DB);

%% ============================================================
% 7. VERIFICATION DE COHERENCE CALIBRATION / TEST
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' VERIFICATION COHERENCE CALIBRATION / TEST\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------
% Gamma
% ------------------------------------------------------------

if numel(cal_gamma_vals) ~= numel(gamma_vals)

    error(['Nombre de gamma different entre calibration et TEST.']);

end

if any(abs(cal_gamma_vals - gamma_vals) > 1e-12)

    error(['Incoherence des valeurs gamma entre calibration et TEST.\n' ...
           'Calibration : %s\n' ...
           'TEST        : %s'], ...
        mat2str(cal_gamma_vals), ...
        mat2str(gamma_vals));

end

fprintf('[OK] Valeurs gamma cohérentes.\n');

%% ------------------------------------------------------------
% Overhead
% ------------------------------------------------------------

if numel(cal_overhead_bits) ~= numel(overhead_bits)

    error(['Nombre d''overheads different entre calibration et TEST.']);

end

if any(abs(cal_overhead_bits - overhead_bits) > 1e-9)

    error(['Incoherence des overheads entre calibration et TEST.\n' ...
           'Calibration : %s\n' ...
           'TEST        : %s'], ...
        mat2str(cal_overhead_bits), ...
        mat2str(overhead_bits));

end

fprintf('[OK] Overheads cohérents.\n');

%% ------------------------------------------------------------
% Seuil NMSE
% ------------------------------------------------------------

if abs(cal_target_db - NMSE_TARGET_DB) > 1e-9

    error(['Incoherence du seuil NMSE.\n' ...
           'Calibration : %.6f dB\n' ...
           'TEST        : %.6f dB'], ...
        cal_target_db, ...
        NMSE_TARGET_DB);

end

fprintf('[OK] Seuil NMSE cohérent : %.2f dB.\n', ...
    NMSE_TARGET_DB);

%% ============================================================
% 8. VERIFICATION DES DIMENSIONS DE LA POLITIQUE
% =============================================================

if size(decision_gamma, 1) ~= numel(snr_centers)

    error(['decision_gamma contient %d lignes alors que ' ...
           'snr_centers contient %d valeurs.'], ...
        size(decision_gamma,1), ...
        numel(snr_centers));

end

if size(decision_gamma, 2) ~= numel(profile_names)

    error(['decision_gamma contient %d profils alors que ' ...
           'profile_names contient %d profils.'], ...
        size(decision_gamma,2), ...
        numel(profile_names));

end

if numel(snr_edges) ~= numel(snr_centers) + 1

    error(['snr_edges doit contenir numel(snr_centers)+1 valeurs.']);

end

if any(~isfinite(decision_gamma(:)))

    error('decision_gamma contient des valeurs NaN ou Inf.');

end

fprintf('[OK] Dimensions de la politique cohérentes.\n');

fprintf('\nNombre de bandes SNR : %d\n', ...
    numel(snr_centers));

fprintf('Nombre de profils : %d\n', ...
    numel(profile_names));

%% ============================================================
% 9. AFFICHAGE DE LA POLITIQUE FIGEE
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' POLITIQUE ADAPTATIVE FIGEE\n');
fprintf('============================================================\n');

for p = 1:size(decision_gamma, 2)

    fprintf('\nProfil : %s\n', profile_names{p});

    for b = 1:size(decision_gamma, 1)

        fprintf(['  SNR centre = %5.1f dB -> gamma = %.6f | ' ...
                 'overhead = %4d bits | NMSE = %8.3f dB\n'], ...
            snr_centers(b), ...
            decision_gamma(b,p), ...
            round(decision_overhead(b,p)), ...
            decision_nmse(b,p));

    end

end

%% ============================================================
% 10. CHARGEMENT DES MODELES
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CHARGEMENT DES MODELES\n');
fprintf('============================================================\n');

S_g4 = load(MODEL_G4_FILE);

S_g8 = load(MODEL_G8_FILE);

S_g16 = load(MODEL_G16_FILE);

net_g4 = extractNetwork(S_g4, 'g4');

net_g8 = extractNetwork(S_g8, 'g8');

net_g16 = extractNetwork(S_g16, 'g16');

fprintf('[OK] gamma = 1/4\n');
fprintf('[OK] gamma = 1/8\n');
fprintf('[OK] gamma = 1/16\n');

%% ============================================================
% 11. PREPARATION DE X_TEST
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' PREPARATION DES DONNEES TEST\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------
% Cas attendu :
%
% X_test = N x 2048
%
% Les reseaux attendent :
%
% 32 x 32 x 2 x N
% ------------------------------------------------------------

if ndims(X_test) == 2

    if size(X_test,2) ~= N_FEATURES

        error(['X_test doit avoir %d colonnes. ' ...
               'Dimensions actuelles : %s'], ...
            N_FEATURES, ...
            mat2str(size(X_test)));

    end

    X_test_img = reshape( ...
        X_test.', ...
        [32, 32, 2, N_test]);

elseif ndims(X_test) == 4

    if size(X_test,1) ~= 32 || ...
       size(X_test,2) ~= 32 || ...
       size(X_test,3) ~= 2 || ...
       size(X_test,4) ~= N_test

        error(['Dimensions X_test incompatibles avec ' ...
               '[32 32 2 N_test].']);

    end

    X_test_img = X_test;

else

    error(['Format X_test non supporte. Dimensions : %s'], ...
        mat2str(size(X_test)));

end

fprintf('Dimensions utilisées par les réseaux : ');

disp(size(X_test_img));

%% ============================================================
% 12. VERIFICATION DE LA POLITIQUE SNR
% =============================================================

if any(snr_test < min(snr_centers)) || ...
   any(snr_test > max(snr_centers))

    warning(['Certains SNR TEST sont en dehors de la plage des ' ...
             'centres de calibration. Le centre le plus proche ' ...
             'sera utilisé.']);

end

%% ============================================================
% 13. DETERMINATION DE LA DECISION POUR CHAQUE TEST
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' APPLICATION DE LA POLITIQUE CALIBREE\n');
fprintf('============================================================\n');

decision_idx = zeros(N_test,1);

%% ------------------------------------------------------------
% Attribution de chaque SNR au centre de calibration le plus
% proche.
% ------------------------------------------------------------

for i = 1:N_test

    [~, decision_idx(i)] = ...
        min(abs(snr_centers - snr_test(i)));

end

%% ------------------------------------------------------------
% Verification des indices
% ------------------------------------------------------------

if any(decision_idx < 1) || ...
   any(decision_idx > numel(snr_centers))

    error('Indice de decision SNR invalide.');

end

%% ============================================================
% 14. SELECTION DU GAMMA POUR CHAQUE SAMPLE
% =============================================================

selected_gamma = zeros(N_test,1);

selected_overhead = zeros(N_test,1);

selected_gamma_index = zeros(N_test,1);

for i = 1:N_test

    p = label_test(i);

    if p < 1 || ...
       p > size(decision_gamma,2)

        error('Label de profil inattendu : %d', p);

    end

    b = decision_idx(i);

    selected_gamma(i) = ...
        decision_gamma(b,p);

    %% Identification du gamma correspondant

    [distance, gidx] = ...
        min(abs(gamma_vals - selected_gamma(i)));

    if distance > 1e-12

        error(['Gamma de decision %.12f non reconnu.'], ...
            selected_gamma(i));

    end

    selected_gamma_index(i) = gidx;

    selected_overhead(i) = ...
        overhead_bits(gidx);

end

fprintf('Politique appliquée à %d samples TEST.\n', ...
    N_test);

%% ============================================================
% 15. DISTRIBUTION DES DECISIONS
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' DISTRIBUTION DES DECISIONS TEST\n');
fprintf('============================================================\n');

for k = 1:3

    idx = selected_gamma_index == k;

    fprintf(['gamma = %-4s : %5d samples (%6.2f %%)\n'], ...
        gamma_names{k}, ...
        sum(idx), ...
        100 * mean(idx));

end

%% ============================================================
% 16. DISTRIBUTION PAR PROFIL
% =============================================================

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf(' DISTRIBUTION DES DECISIONS PAR PROFIL\n');
fprintf('------------------------------------------------------------\n');

for p = 1:2

    idx_profile = label_test == p;

    fprintf('\nProfil %d : %s\n', ...
        p, profile_names{p});

    Np = sum(idx_profile);

    for k = 1:3

        idx = idx_profile & ...
            selected_gamma_index == k;

        fprintf(['  gamma = %-4s : %5d samples (%6.2f %%)\n'], ...
            gamma_names{k}, ...
            sum(idx), ...
            100 * sum(idx) / Np);

    end

end

%% ============================================================
% 17. GENERATION DES REALISATIONS AWGN
% =============================================================
%
% IMPORTANT :
%
% Les memes realisations AWGN seront utilisees pour :
%
%   - politique fixe g4
%   - politique fixe g8
%   - politique fixe g16
%   - politique adaptative
%
% Cela permet une comparaison equitable.
%
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' PREPARATION DES REALISATIONS AWGN\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------
% Calcul de la puissance signal
% ------------------------------------------------------------

signal_power = zeros(N_test,1);

for i = 1:N_test

    x = double(X_test_img(:,:,:,i));

    signal_power(i) = mean(x(:).^2);

end

if any(~isfinite(signal_power))

    error('Puissance signal contenant NaN ou Inf.');

end

if any(signal_power <= 0)

    error('Au moins un sample possède une puissance nulle.');

end

%% ------------------------------------------------------------
% Stockage des bruits
%
% AWGN_REP{r} contient :
%
% 32 x 32 x 2 x N_test
% ------------------------------------------------------------

AWGN_REP = cell(N_NOISE_REP,1);

fprintf('Generation de %d realisations AWGN...\n', ...
    N_NOISE_REP);

for r = 1:N_NOISE_REP

    noise = zeros(size(X_test_img), ...
        'like', X_test_img);

    for i = 1:N_test

        noise_power = ...
            signal_power(i) / ...
            (10^(snr_test(i)/10));

        noise(:,:,:,i) = ...
            sqrt(noise_power) .* ...
            randn(32,32,2,'like',X_test_img);

    end

    AWGN_REP{r} = noise;

end

fprintf('[OK] Realisations AWGN generees.\n');

%% ============================================================
% 18. INITIALISATION NMSE
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' INITIALISATION EVALUATION NMSE\n');
fprintf('============================================================\n');

nmse_linear_adaptive = NaN(N_test,1);

nmse_linear_g4 = NaN(N_test,1);

nmse_linear_g8 = NaN(N_test,1);

nmse_linear_g16 = NaN(N_test,1);

%% ============================================================
% 19. EVALUATION DES POLITIQUES FIXES
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' EVALUATION DES POLITIQUES FIXES\n');
fprintf('============================================================\n');

fixed_nets = {
    net_g4
    net_g8
    net_g16
};

fixed_names = {
    'g4'
    'g8'
    'g16'
};

fixed_nmse_linear = NaN(3,1);

for k = 1:3

    fprintf('\nPolitique fixe %s...\n', ...
        fixed_names{k});

    net = fixed_nets{k};

    nmse_rep = NaN(N_test, N_NOISE_REP);

    for r = 1:N_NOISE_REP

        fprintf('  Realisation AWGN %d/%d\n', ...
            r, N_NOISE_REP);

        X_noisy = X_test_img + AWGN_REP{r};

        X_hat = predict(net, X_noisy);

        %% Verification sortie

        X_hat = standardizeNetworkOutput( ...
            X_hat, ...
            N_test);

        nmse_rep(:,r) = ...
            computeNMSEPerSample( ...
                X_test_img, ...
                X_hat);

    end

    %% Moyenne sur les repetitions AWGN

    nmse_linear = mean(nmse_rep,2,'omitnan');

    if any(~isfinite(nmse_linear))

        error(['NMSE contenant NaN/Inf pour la politique %s.'], ...
            fixed_names{k});

    end

    fixed_nmse_linear(k) = ...
        mean(nmse_linear,'omitnan');

    switch k

        case 1

            nmse_linear_g4 = nmse_linear;

        case 2

            nmse_linear_g8 = nmse_linear;

        case 3

            nmse_linear_g16 = nmse_linear;

    end

    fprintf('[OK] %s termine.\n', ...
        fixed_names{k});

end

%% ============================================================
% 20. EVALUATION DE LA POLITIQUE ADAPTATIVE
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' EVALUATION POLITIQUE ADAPTATIVE\n');
fprintf('============================================================\n');

for k = 1:3

    idx = selected_gamma_index == k;

    if ~any(idx)

        fprintf('  %s : aucun sample selectionne.\n', ...
            gamma_names{k});

        continue;

    end

    fprintf('\n');
    fprintf('Gamma %s : %d samples\n', ...
        gamma_names{k}, ...
        sum(idx));

    switch k

        case 1

            net = net_g4;

        case 2

            net = net_g8;

        case 3

            net = net_g16;

    end

    X_group = X_test_img(:,:,:,idx);

    nmse_rep = NaN(sum(idx), N_NOISE_REP);

    for r = 1:N_NOISE_REP

        fprintf('  Realisation AWGN %d/%d\n', ...
            r, N_NOISE_REP);

        noise_group = AWGN_REP{r}(:,:,:,idx);

        X_noisy = X_group + noise_group;

        X_hat = predict(net, X_noisy);

        X_hat = standardizeNetworkOutput( ...
            X_hat, ...
            sum(idx));

        nmse_rep(:,r) = ...
            computeNMSEPerSample( ...
                X_group, ...
                X_hat);

    end

    nmse_group = mean(nmse_rep,2,'omitnan');

    nmse_linear_adaptive(idx) = ...
        nmse_group;

end

if any(~isfinite(nmse_linear_adaptive))

    error(['Le NMSE adaptatif contient des valeurs NaN/Inf. ' ...
           'Tous les samples doivent avoir ete evalues.']);

end

fprintf('\n[OK] NMSE adaptatif calcule.\n');

%% ============================================================
% 21. NMSE MOYEN FINAL
% =============================================================
%
% IMPORTANT :
%
% La moyenne est realisee dans le domaine lineaire.
%
% Ensuite :
%
%       NMSE_dB = 10 log10(NMSE_linear)
%
% =============================================================

NMSE_adaptive_linear = ...
    mean(nmse_linear_adaptive,'omitnan');

NMSE_g4_linear = ...
    mean(nmse_linear_g4,'omitnan');

NMSE_g8_linear = ...
    mean(nmse_linear_g8,'omitnan');

NMSE_g16_linear = ...
    mean(nmse_linear_g16,'omitnan');

NMSE_adaptive_dB = ...
    10 * log10(NMSE_adaptive_linear);

NMSE_g4_dB = ...
    10 * log10(NMSE_g4_linear);

NMSE_g8_dB = ...
    10 * log10(NMSE_g8_linear);

NMSE_g16_dB = ...
    10 * log10(NMSE_g16_linear);

%% ============================================================
% 22. TAUX DE SATISFACTION DE LA CONTRAINTE NMSE
% =============================================================
%
% Contrainte :
%
%       NMSE_dB <= NMSE_TARGET_DB
%
% Equivalent en lineaire :
%
%       NMSE <= 10^(NMSE_TARGET_DB/10)
%
% =============================================================

NMSE_TARGET_LINEAR = ...
    10^(NMSE_TARGET_DB/10);

constraint_satisfied_adaptive = ...
    nmse_linear_adaptive <= NMSE_TARGET_LINEAR;

constraint_rate_adaptive = ...
    100 * mean(constraint_satisfied_adaptive);

fprintf('\n');
fprintf('Contrainte NMSE : %.2f dB\n', ...
    NMSE_TARGET_DB);

fprintf('Taux de satisfaction adaptatif : %.2f %%\n', ...
    constraint_rate_adaptive);

%% ============================================================
% 23. TAUX DE SATISFACTION PAR PROFIL
% =============================================================

constraint_rate_profile = NaN(2,1);

for p = 1:2

    idx = label_test == p;

    constraint_rate_profile(p) = ...
        100 * mean( ...
        constraint_satisfied_adaptive(idx));

end

%% ============================================================
% 24. OVERHEAD MOYEN
% =============================================================

Overhead_adaptive = ...
    mean(selected_overhead);

Overhead_g4 = ...
    overhead_bits(1);

Overhead_g8 = ...
    overhead_bits(2);

Overhead_g16 = ...
    overhead_bits(3);

%% ------------------------------------------------------------
% Reduction par rapport a gamma = 1/4
% ------------------------------------------------------------

Reduction_overhead = ...
    (1 - Overhead_adaptive / Overhead_g4) * 100;

%% ============================================================
% 25. RESULTATS FINAUX
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' RESULTATS FINAUX TEST\n');
fprintf('============================================================\n');

fprintf('\n');

fprintf('Fixe gamma = 1/4 :\n');
fprintf('  NMSE     = %8.3f dB\n', NMSE_g4_dB);
fprintf('  Overhead = %8d bits\n', Overhead_g4);

fprintf('\n');

fprintf('Fixe gamma = 1/8 :\n');
fprintf('  NMSE     = %8.3f dB\n', NMSE_g8_dB);
fprintf('  Overhead = %8d bits\n', Overhead_g8);

fprintf('\n');

fprintf('Fixe gamma = 1/16 :\n');
fprintf('  NMSE     = %8.3f dB\n', NMSE_g16_dB);
fprintf('  Overhead = %8d bits\n', Overhead_g16);

fprintf('\n');

fprintf('ADAPTATIF CALIBRE :\n');
fprintf('  NMSE     = %8.3f dB\n', NMSE_adaptive_dB);
fprintf('  Overhead = %8.1f bits\n', Overhead_adaptive);
fprintf('  Reduction overhead = %7.2f %%\n', ...
    Reduction_overhead);

fprintf('\n');

fprintf('Taux satisfaction contrainte NMSE = %.2f %%\n', ...
    constraint_rate_adaptive);

%% ============================================================
% 26. FREQUENCES FINALES DE SELECTION
% =============================================================

selection_count_test = zeros(2,3);

selection_frequency_test = zeros(2,3);

for p = 1:2

    idx_profile = label_test == p;

    Np = sum(idx_profile);

    for k = 1:3

        idx = idx_profile & ...
            selected_gamma_index == k;

        selection_count_test(p,k) = ...
            sum(idx);

        selection_frequency_test(p,k) = ...
            100 * sum(idx) / Np;

    end

end

%% ------------------------------------------------------------
% Global
% ------------------------------------------------------------

selection_count_global = zeros(3,1);

selection_frequency_global = zeros(3,1);

for k = 1:3

    idx = selected_gamma_index == k;

    selection_count_global(k) = ...
        sum(idx);

    selection_frequency_global(k) = ...
        100 * mean(idx);

end

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FREQUENCES DE SELECTION TEST\n');
fprintf('============================================================\n');

fprintf('\nGLOBAL :\n');

for k = 1:3

    fprintf(['  gamma = %-4s : %5d samples (%6.2f %%)\n'], ...
        gamma_names{k}, ...
        selection_count_global(k), ...
        selection_frequency_global(k));

end

fprintf('\nPROFIL 1 (%s) :\n', ...
    profile_names{1});

for k = 1:3

    fprintf(['  gamma = %-4s : %5d samples (%6.2f %%)\n'], ...
        gamma_names{k}, ...
        selection_count_test(1,k), ...
        selection_frequency_test(1,k));

end

fprintf('\nPROFIL 2 (%s) :\n', ...
    profile_names{2});

for k = 1:3

    fprintf(['  gamma = %-4s : %5d samples (%6.2f %%)\n'], ...
        gamma_names{k}, ...
        selection_count_test(2,k), ...
        selection_frequency_test(2,k));

end

%% ============================================================
% 27. RESULTATS PAR PROFIL
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' PERFORMANCE PAR PROFIL\n');
fprintf('============================================================\n');

profile_nmse_adaptive = NaN(2,1);

profile_overhead_adaptive = NaN(2,1);

for p = 1:2

    idx = label_test == p;

    profile_nmse_linear = ...
        mean(nmse_linear_adaptive(idx), ...
        'omitnan');

    profile_nmse_adaptive(p) = ...
        10 * log10(profile_nmse_linear);

    profile_overhead_adaptive(p) = ...
        mean(selected_overhead(idx));

    fprintf('\n%s :\n', ...
        profile_names{p});

    fprintf('  NMSE adaptatif     = %8.3f dB\n', ...
        profile_nmse_adaptive(p));

    fprintf('  Overhead adaptatif = %8.1f bits\n', ...
        profile_overhead_adaptive(p));

    fprintf('  Satisfaction NMSE  = %8.2f %%\n', ...
        constraint_rate_profile(p));

end

%% ============================================================
% 28. RESULTATS NMSE PAR PROFIL POUR POLITIQUES FIXES
% =============================================================

profile_nmse_fixed = NaN(2,3);

for p = 1:2

    idx = label_test == p;

    profile_nmse_fixed(p,1) = ...
        10*log10(mean( ...
        nmse_linear_g4(idx),'omitnan'));

    profile_nmse_fixed(p,2) = ...
        10*log10(mean( ...
        nmse_linear_g8(idx),'omitnan'));

    profile_nmse_fixed(p,3) = ...
        10*log10(mean( ...
        nmse_linear_g16(idx),'omitnan'));

end

%% ============================================================
% 29. TABLEAU PRINCIPAL RESULTATS
% =============================================================

results_table = table( ...
    {'Fixe 1/4'; ...
     'Fixe 1/8'; ...
     'Fixe 1/16'; ...
     'Adaptatif'}, ...
    [NMSE_g4_dB; ...
     NMSE_g8_dB; ...
     NMSE_g16_dB; ...
     NMSE_adaptive_dB], ...
    [Overhead_g4; ...
     Overhead_g8; ...
     Overhead_g16; ...
     Overhead_adaptive], ...
    'VariableNames', ...
    {'Politique', ...
     'NMSE_dB', ...
     'Overhead_bits'});

fprintf('\n');
disp(results_table);

%% ============================================================
% 30. TABLEAU CONTRAINTE NMSE
% =============================================================

constraint_table = table( ...
    {'Adaptatif'}, ...
    NMSE_adaptive_dB, ...
    NMSE_TARGET_DB, ...
    constraint_rate_adaptive, ...
    'VariableNames', ...
    {'Politique', ...
     'NMSE_moyen_dB', ...
     'Seuil_NMSE_dB', ...
     'Taux_satisfaction_percent'});

fprintf('\nTableau contrainte NMSE :\n');

disp(constraint_table);

%% ============================================================
% 31. TABLEAU FREQUENCES
% =============================================================

frequency_table = table( ...
    gamma_names(:), ...
    Mc_list(:), ...
    overhead_bits(:), ...
    selection_count_global(:), ...
    selection_frequency_global(:), ...
    'VariableNames', ...
    {'Gamma', ...
     'Mc', ...
     'Overhead_bits', ...
     'Count', ...
     'Frequency_percent'});

fprintf('\nTableau fréquences :\n');

disp(frequency_table);

%% ============================================================
% 32. EXPORT CSV RESULTATS
% =============================================================

RESULTS_CSV = fullfile( ...
    RESULTS_DIR, ...
    'adaptive_policy_test_final.csv');

writetable( ...
    results_table, ...
    RESULTS_CSV);

fprintf('\nTableau principal sauvegarde :\n%s\n', ...
    RESULTS_CSV);

%% ============================================================
% 33. EXPORT CSV CONTRAINTE
% =============================================================

CONSTRAINT_CSV = fullfile( ...
    RESULTS_DIR, ...
    'adaptive_policy_test_constraint.csv');

writetable( ...
    constraint_table, ...
    CONSTRAINT_CSV);

fprintf('Tableau contrainte sauvegarde :\n%s\n', ...
    CONSTRAINT_CSV);

%% ============================================================
% 34. EXPORT CSV FREQUENCES
% =============================================================

FREQ_CSV = fullfile( ...
    RESULTS_DIR, ...
    'adaptive_policy_test_frequencies.csv');

writetable( ...
    frequency_table, ...
    FREQ_CSV);

fprintf('Fréquences sauvegardées :\n%s\n', ...
    FREQ_CSV);

%% ============================================================
% 35. EXPORT CSV PAR PROFIL
% =============================================================

profile_table = table( ...
    profile_names(:), ...
    profile_nmse_adaptive, ...
    profile_overhead_adaptive, ...
    constraint_rate_profile, ...
    'VariableNames', ...
    {'Profil', ...
     'NMSE_adaptatif_dB', ...
     'Overhead_adaptatif_bits', ...
     'Satisfaction_NMSE_percent'});

PROFILE_CSV = fullfile( ...
    RESULTS_DIR, ...
    'adaptive_policy_test_profiles.csv');

writetable( ...
    profile_table, ...
    PROFILE_CSV);

fprintf('Résultats par profil sauvegardés :\n%s\n', ...
    PROFILE_CSV);

%% ============================================================
% 36. EXPORT COMPLET MAT
% =============================================================

TEST_MAT = fullfile( ...
    RESULTS_DIR, ...
    'adaptive_policy_test_final.mat');

save(TEST_MAT, ...
    'NMSE_adaptive_dB', ...
    'NMSE_g4_dB', ...
    'NMSE_g8_dB', ...
    'NMSE_g16_dB', ...
    'NMSE_adaptive_linear', ...
    'NMSE_g4_linear', ...
    'NMSE_g8_linear', ...
    'NMSE_g16_linear', ...
    'Overhead_adaptive', ...
    'Overhead_g4', ...
    'Overhead_g8', ...
    'Overhead_g16', ...
    'Reduction_overhead', ...
    'NMSE_TARGET_DB', ...
    'NMSE_TARGET_LINEAR', ...
    'constraint_rate_adaptive', ...
    'constraint_rate_profile', ...
    'selection_count_test', ...
    'selection_frequency_test', ...
    'selection_count_global', ...
    'selection_frequency_global', ...
    'profile_nmse_adaptive', ...
    'profile_overhead_adaptive', ...
    'profile_nmse_fixed', ...
    'selected_gamma', ...
    'selected_gamma_index', ...
    'selected_overhead', ...
    'decision_idx', ...
    'snr_test', ...
    'label_test', ...
    'RNG_SEED', ...
    'N_NOISE_REP', ...
    'gamma_vals', ...
    'Mc_list', ...
    'overhead_bits', ...
    'Q_BITS', ...
    'N_FEATURES');

fprintf('\nRésultats MAT sauvegardés :\n%s\n', ...
    TEST_MAT);

%% ============================================================
% 37. FIGURE : DISTRIBUTION DES GAMMAS
% =============================================================

figure( ...
    'Name', ...
    'Decision gamma TEST', ...
    'Color', ...
    'w');

bar(selection_count_global);

set(gca, ...
    'XTick', 1:3, ...
    'XTickLabel', {'1/4','1/8','1/16'});

ylabel('Nombre de samples');

xlabel('\gamma');

title( ...
    'Distribution des décisions adaptatives - TEST');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
    RESULTS_DIR, ...
    'decision_gamma_test_final.png'));

%% ============================================================
% 38. FIGURE : OVERHEAD
% =============================================================

figure( ...
    'Name', ...
    'Overhead TEST', ...
    'Color', ...
    'w');

bar([ ...
    Overhead_g4, ...
    Overhead_g8, ...
    Overhead_g16, ...
    Overhead_adaptive]);

set(gca, ...
    'XTick', 1:4, ...
    'XTickLabel', ...
    {'Fixe 1/4', ...
     'Fixe 1/8', ...
     'Fixe 1/16', ...
     'Adaptatif'});

ylabel('Overhead moyen (bits)');

xlabel('Politique');

title( ...
    'Comparaison de l''overhead moyen - TEST');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
    RESULTS_DIR, ...
    'overhead_test_final.png'));

%% ============================================================
% 39. FIGURE : NMSE
% =============================================================

figure( ...
    'Name', ...
    'NMSE TEST', ...
    'Color', ...
    'w');

bar([ ...
    NMSE_g4_dB, ...
    NMSE_g8_dB, ...
    NMSE_g16_dB, ...
    NMSE_adaptive_dB]);

hold on;

yline( ...
    NMSE_TARGET_DB, ...
    '--', ...
    'Seuil NMSE');

hold off;

set(gca, ...
    'XTick', 1:4, ...
    'XTickLabel', ...
    {'Fixe 1/4', ...
     'Fixe 1/8', ...
     'Fixe 1/16', ...
     'Adaptatif'});

ylabel('NMSE (dB)');

xlabel('Politique');

title( ...
    'Comparaison NMSE - TEST');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
    RESULTS_DIR, ...
    'nmse_test_final.png'));

%% ============================================================
% 40. FIGURE : SATISFACTION DE LA CONTRAINTE
% =============================================================

figure( ...
    'Name', ...
    'Satisfaction contrainte NMSE', ...
    'Color', ...
    'w');

bar(constraint_rate_adaptive);

set(gca, ...
    'XTick', 1, ...
    'XTickLabel', {'Adaptatif'});

ylabel('Samples satisfaisant la contrainte (%)');

xlabel('Politique');

title( ...
    sprintf( ...
    'Satisfaction de la contrainte NMSE \\leq %.1f dB', ...
    NMSE_TARGET_DB));

ylim([0 100]);

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
    RESULTS_DIR, ...
    'nmse_constraint_test_final.png'));

%% ============================================================
% 41. FIGURE : FREQUENCES PAR PROFIL
% =============================================================

figure( ...
    'Name', ...
    'Selection gamma par profil', ...
    'Color', ...
    'w');

bar(selection_frequency_test);

set(gca, ...
    'XTick', 1:2, ...
    'XTickLabel', profile_names);

ylabel('Fréquence de sélection (%)');

xlabel('Profil');

legend( ...
    {'\gamma = 1/4', ...
     '\gamma = 1/8', ...
     '\gamma = 1/16'}, ...
    'Location', ...
    'best');

title( ...
    'Distribution des décisions par profil - TEST');

grid on;

saveas( ...
    gcf, ...
    fullfile( ...
    RESULTS_DIR, ...
    'decision_gamma_profile_test_final.png'));

%% ============================================================
% 42. RESUME FINAL
% =============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' RESUME FINAL\n');
fprintf('============================================================\n');

fprintf('\n');

fprintf('Jeu de test       : %d samples\n', ...
    N_test);

fprintf('Répétitions AWGN  : %d\n', ...
    N_NOISE_REP);

fprintf('Dimension CSI     : %d\n', ...
    N_FEATURES);

fprintf('Quantification    : %d bits\n', ...
    Q_BITS);

fprintf('\n');

fprintf(['Fixe 1/4  : NMSE = %8.3f dB | ' ...
         'Overhead = %8d bits\n'], ...
    NMSE_g4_dB, ...
    Overhead_g4);

fprintf(['Fixe 1/8  : NMSE = %8.3f dB | ' ...
         'Overhead = %8d bits\n'], ...
    NMSE_g8_dB, ...
    Overhead_g8);

fprintf(['Fixe 1/16 : NMSE = %8.3f dB | ' ...
         'Overhead = %8d bits\n'], ...
    NMSE_g16_dB, ...
    Overhead_g16);

fprintf(['Adaptatif : NMSE = %8.3f dB | ' ...
         'Overhead = %8.1f bits\n'], ...
    NMSE_adaptive_dB, ...
    Overhead_adaptive);

fprintf('\n');

fprintf('Réduction overhead : %.2f %%\n', ...
    Reduction_overhead);

fprintf('Satisfaction NMSE  : %.2f %%\n', ...
    constraint_rate_adaptive);

fprintf('\n');

fprintf('Fichiers générés :\n');

fprintf('  adaptive_policy_test_final.csv\n');
fprintf('  adaptive_policy_test_constraint.csv\n');
fprintf('  adaptive_policy_test_frequencies.csv\n');
fprintf('  adaptive_policy_test_profiles.csv\n');
fprintf('  adaptive_policy_test_final.mat\n');
fprintf('  decision_gamma_test_final.png\n');
fprintf('  decision_gamma_profile_test_final.png\n');
fprintf('  overhead_test_final.png\n');
fprintf('  nmse_test_final.png\n');
fprintf('  nmse_constraint_test_final.png\n');

fprintf('\n');

fprintf('============================================================\n');
fprintf(' EVALUATION TEST TERMINEE AVEC SUCCES\n');
fprintf('============================================================\n');


%% ============================================================
% FONCTION : EXTRACTION DU RESEAU
% =============================================================

function net = extractNetwork(S, name)

    fields = fieldnames(S);

    net = [];

    for i = 1:numel(fields)

        candidate = S.(fields{i});

        if isa(candidate, 'DAGNetwork') || ...
           isa(candidate, 'SeriesNetwork') || ...
           isa(candidate, 'dlnetwork')

            net = candidate;

            return;

        end

    end

    error([ ...
        'Impossible de trouver le réseau %s dans le fichier MAT. ' ...
        'Variables présentes : %s'], ...
        name, ...
        strjoin(fields, ', '));

end


%% ============================================================
% FONCTION : STANDARDISATION DE LA SORTIE DU RESEAU
% ============================================================

function X_hat = standardizeNetworkOutput(X_hat, N)

    %% ---------------------------------------------------------
    % Cas 1 :
    %
    % 32 x 32 x 2 x N
    % ----------------------------------------------------------

    if ndims(X_hat) == 4

        if size(X_hat,1) ~= 32 || ...
           size(X_hat,2) ~= 32 || ...
           size(X_hat,3) ~= 2 || ...
           size(X_hat,4) ~= N

            error([ ...
                'Sortie réseau 4D incompatible. ' ...
                'Dimensions obtenues : %s'], ...
                mat2str(size(X_hat)));

        end

        return;

    end

    %% ---------------------------------------------------------
    % Cas 2 :
    %
    % N x 2048
    % ----------------------------------------------------------

    if ismatrix(X_hat)

        if size(X_hat,1) == N && ...
           size(X_hat,2) == 2048

            X_hat = reshape( ...
                X_hat.', ...
                [32,32,2,N]);

            return;

        end

    end

    %% ---------------------------------------------------------
    % Si aucun format reconnu
    % ----------------------------------------------------------

    error([ ...
        'Format de sortie réseau non supporte. ' ...
        'Dimensions : %s'], ...
        mat2str(size(X_hat)));

end


%% ============================================================
% FONCTION : NMSE PAR SAMPLE
% =============================================================

function nmse = computeNMSEPerSample(X, X_hat)

    if ndims(X) ~= 4 || ...
       ndims(X_hat) ~= 4

        error('X et X_hat doivent etre des tenseurs 4D.');

    end

    if ~isequal(size(X), size(X_hat))

        error([ ...
            'X et X_hat doivent avoir les memes dimensions.\n' ...
            'X     : %s\n' ...
            'X_hat : %s'], ...
            mat2str(size(X)), ...
            mat2str(size(X_hat)));

    end

    N = size(X,4);

    nmse = NaN(N,1);

    for i = 1:N

        x = double(X(:,:,:,i));

        xhat = double(X_hat(:,:,:,i));

        numerator = ...
            sum((x(:) - xhat(:)).^2);

        denominator = ...
            sum(x(:).^2);

        if denominator > 0

            nmse(i) = ...
                numerator / denominator;

        else

            nmse(i) = NaN;

        end

    end

end