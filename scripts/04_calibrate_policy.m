%% =========================================================
% calibrate_adaptive_policy.m
%
% CALIBRATION DE LA POLITIQUE ADAPTATIVE CSI
%
% IMPORTANT :
%   - Utilise UNIQUEMENT le jeu de validation
%   - Aucun échantillon TEST n'est utilisé
%   - Les réseaux sont déjà entraînés
%   - Les seuils obtenus seront ensuite FIGES
%
% =========================================================

clear;
clc;
close all;

rng(42,'twister');

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CALIBRATION POLITIQUE ADAPTATIVE CSI\n');
fprintf(' VALIDATION UNIQUEMENT\n');
fprintf('============================================================\n\n');

%% =========================================================
% 1. CONFIGURATION
% =========================================================

projectDir = 'C:\AdaptiveCSICompression5G_FinaL';
resultsDir = fullfile(projectDir,'results');

if ~isfolder(resultsDir)
    error('Dossier results introuvable : %s',resultsDir);
end

%% ---------------------------------------------------------
% Taux de compression
% ---------------------------------------------------------

gamma_list = {'g4','g8','g16'};
gamma_vals = [1/4 1/8 1/16];
Mc_list = [512 256 128];
Q_BITS = 8;
overhead_bits = Mc_list .* Q_BITS;

fprintf('Taux de compression :\n');
for gi = 1:3
    fprintf('  %s : gamma = %.4f | Mc = %d | overhead = %d bits\n', ...
        gamma_list{gi}, gamma_vals(gi), Mc_list(gi), overhead_bits(gi));
end
fprintf('\n');

%% =========================================================
% 2. CONTRAINTE DE QUALITE
% =========================================================

NMSE_TARGET_DB = -12;
fprintf('Contrainte qualité : NMSE <= %.2f dB\n\n', NMSE_TARGET_DB);

%% =========================================================
% 3. CHARGEMENT DES MODELES
% =========================================================

fprintf('============================================================\n');
fprintf(' CHARGEMENT DES MODELES\n');
fprintf('============================================================\n\n');

S = load(fullfile(resultsDir,'net_clean_final.mat'));
if ~isfield(S,'net_clean')
    error('net_clean absent de net_clean_final.mat');
end
net_clean = S.net_clean;

S = load(fullfile(resultsDir,'net_g8_final.mat'));
if ~isfield(S,'net_g8')
    error('net_g8 absent de net_g8_final.mat');
end
net_g8 = S.net_g8;

S = load(fullfile(resultsDir,'net_g16_final.mat'));
if ~isfield(S,'net_g16')
    error('net_g16 absent de net_g16_final.mat');
end
net_g16 = S.net_g16;

nets.g4 = net_clean;
nets.g8 = net_g8;
nets.g16 = net_g16;

fprintf('  [OK] g4\n');
fprintf('  [OK] g8\n');
fprintf('  [OK] g16\n\n');

%% =========================================================
% 4. CHARGEMENT DATASET
% =========================================================

fprintf('============================================================\n');
fprintf(' CHARGEMENT VALIDATION\n');
fprintf('============================================================\n\n');

S = load(fullfile(projectDir,'cdl_3gpp_data.mat'));

if ~isfield(S,'data')
    error('Variable data absente du dataset.');
end

data = S.data;

%% ---------------------------------------------------------
% IMPORTANT : Récupérer mean et std de l'entraînement
% Normalisation GLOBALE (une seule valeur)
% ---------------------------------------------------------

if isfield(data, 'mean_train_global') && isfield(data, 'std_train_global')
    m = double(data.mean_train_global);
    s = double(data.std_train_global);
    fprintf('Paramètres de normalisation GLOBALE (entraînement) :\n');
    fprintf('  mean = %.8f\n', m);
    fprintf('  std  = %.8f\n', s);
else
    error('mean_train_global/std_train_global introuvables dans le dataset.');
end
fprintf('\n');

%% =========================================================
% 5. DONNEES VALIDATION
% =========================================================

X_val_raw = reshape( ...
    data.X_val', ...
    32,32,2,[]);

snr_val = double(data.snr_val(:));
label_val = double(data.label_val(:));

Nval = length(snr_val);

fprintf('Nombre validation : %d\n',Nval);

fprintf('Dimensions X_val_raw : [%s]\n', ...
    num2str(size(X_val_raw)));

%% =========================================================
% PRETRAITEMENT IDENTIQUE A L'ENTRAINEMENT
% =========================================================

fprintf('\nPrétraitement validation...\n');

% Transformation Angular-Delay
X_val_AD = transform_angular_delay(X_val_raw);

fprintf('  Angular-Delay : OK\n');

% IMPORTANT :
% Utiliser EXACTEMENT mean/std calculés sur TRAIN.
%
% NE PAS recalculer m et s sur validation.

if isfield(data,'mean_train') && isfield(data,'std_train')

    m = double(data.mean_train);
    s = double(data.std_train);

else

    % Si les paramètres ne sont pas sauvegardés dans le dataset,
    % les charger depuis le fichier contenant le modèle/résultats.

    if isfield(S,'meanVal')
        m = double(S.meanVal);
    elseif isfield(S,'mean')
        m = double(S.mean);
    else
        error(['Impossible de retrouver la moyenne de normalisation ', ...
               'utilisée pendant l''entraînement.']);
    end

    if isfield(S,'stdVal')
        s = double(S.stdVal);
    elseif isfield(S,'std')
        s = double(S.std);
    else
        error(['Impossible de retrouver l''écart-type de normalisation ', ...
               'utilisé pendant l''entraînement.']);
    end

end

fprintf('  mean train = %.8f\n',m);
fprintf('  std train  = %.8f\n',s);

X_val = (X_val_AD - m) ./ s;

fprintf('  Normalisation : OK\n');

fprintf('Dimensions X_val : [%s]\n', ...
    num2str(size(X_val)));
%% =========================================================
% 6. PROFILS
% =========================================================

profiles = [1 2];
profile_names = {'LOS (CDL-D)', 'NLOS (CDL-A)'};

%% =========================================================
% 7. BANDES SNR
% =========================================================

snr_edges = 0:2:30;
snr_centers = snr_edges(1:end-1) + 1;
Nsnr = length(snr_centers);
MIN_SAMPLES = 20;
N_REPEATS_NOISE = 10;

%% =========================================================
% 8. TABLE NMSE
% =========================================================

nmse_table = nan(Nsnr, 2, 3);

fprintf('============================================================\n');
fprintf(' CALCUL NMSE SUR VALIDATION\n');
fprintf('============================================================\n\n');

fprintf('Répétitions AWGN : %d\n', N_REPEATS_NOISE);
fprintf('Contrainte : NMSE <= %.2f dB\n\n', NMSE_TARGET_DB);

%% =========================================================
% 9. CALCUL
% =========================================================

for gi = 1:3

    fprintf('--------------------------------------------\n');
    fprintf('Gamma = %s\n', gamma_list{gi});
    fprintf('--------------------------------------------\n');

    net = nets.(gamma_list{gi});

    for pi = 1:2

        fprintf('Profil : %s\n', profile_names{pi});

        for si = 1:Nsnr

            idx = find(label_val == profiles(pi) & ...
                       snr_val >= snr_edges(si) & ...
                       snr_val < snr_edges(si+1));

            if length(idx) < MIN_SAMPLES
                fprintf('  SNR %2d : insuffisant (%d)\n', snr_centers(si), length(idx));
                continue;
            end

            % -------------------------------------------------
            % DONNEES BRUTES
            % -------------------------------------------------
            X_raw = X_val_raw(:,:,:,idx);

            % Nombre d'échantillons dans ce batch
            N_batch = size(X_raw, 4);

            % -------------------------------------------------
            % AJOUT AWGN SUR DONNEES BRUTES
            % -------------------------------------------------
            nmse_reps = zeros(N_REPEATS_NOISE,1);

            for rep = 1:N_REPEATS_NOISE

                % Calcul de la puissance du signal sur les données brutes
                signal_power = mean(X_raw(:).^2);
                snr_linear = 10^(snr_centers(si)/10);
                noise_power = signal_power / snr_linear;
                noise = sqrt(noise_power) .* randn(size(X_raw), 'like', X_raw);
                X_noisy_raw = X_raw + noise;

                % -------------------------------------------------
                % APPLIQUER ANGULAR-DELAY SUR BRUITÉ ET PROPRE
                % -------------------------------------------------
                X_clean_AD = transform_angular_delay(X_raw);
                X_noisy_AD = transform_angular_delay(X_noisy_raw);

                % -------------------------------------------------
                % NORMALISATION GLOBALE AVEC mean/std DE L'ENTRAÎNEMENT
                % -------------------------------------------------
                X_clean = (X_clean_AD - m) ./ s;
                X_noisy = (X_noisy_AD - m) ./ s;

                % -------------------------------------------------
                % INFERENCE
                % -------------------------------------------------
                Y_rec = predict(net, X_noisy);

                % -------------------------------------------------
                % NMSE
                % -------------------------------------------------
                nSamples = size(X_clean,4);
                nmse_each = zeros(nSamples,1);

                for kk = 1:nSamples
                    Xc = X_clean(:,:,:,kk);
                    Yr = Y_rec(:,:,:,kk);
                    num = sum((Yr(:)-Xc(:)).^2);
                    den = sum(Xc(:).^2) + 1e-12;
                    nmse_each(kk) = num / den;
                end

                nmse_reps(rep) = mean(nmse_each);

            end

            nmse_table(si,pi,gi) = 10 * log10(mean(nmse_reps));

        end

    end

end

%% =========================================================
% 10. AFFICHAGE NMSE
% =========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' NMSE VALIDATION\n');
fprintf('============================================================\n\n');

for pi = 1:2
    fprintf('--- %s ---\n', profile_names{pi});
    for si = 1:Nsnr
        fprintf('SNR %2d dB : ', snr_centers(si));
        for gi = 1:3
            fprintf('g%d = %7.3f dB', round(1/gamma_vals(gi)), nmse_table(si,pi,gi));
            if gi < 3, fprintf(' | '); end
        end
        fprintf('\n');
    end
    fprintf('\n');
end

%% =========================================================
% 11. DECISION PAR SNR
% =========================================================

decision_gamma = zeros(Nsnr,2);
decision_nmse = nan(Nsnr,2);
decision_overhead = zeros(Nsnr,2);

for pi = 1:2
    for si = 1:Nsnr
        chosen = 0;
        % On teste d'abord le plus faible overhead : g16 -> g8 -> g4
        for gi = 3:-1:1
            current_nmse = nmse_table(si,pi,gi);
            if ~isnan(current_nmse) && current_nmse <= NMSE_TARGET_DB
                chosen = gi;
                break;
            end
        end
        % Si aucun taux ne satisfait la contrainte, on prend g4
        if chosen == 0
            chosen = 1;
        end
        decision_gamma(si,pi) = gamma_vals(chosen);
        decision_nmse(si,pi) = nmse_table(si,pi,chosen);
        decision_overhead(si,pi) = overhead_bits(chosen);
    end
end

%% =========================================================
% 12. AFFICHAGE POLITIQUE
% =========================================================

fprintf('============================================================\n');
fprintf(' POLITIQUE CALIBREE\n');
fprintf('============================================================\n\n');

for pi = 1:2
    fprintf('--- %s ---\n', profile_names{pi});
    for si = 1:Nsnr
        fprintf('SNR = %2d dB -> gamma = 1/%d | overhead = %d bits | NMSE = %.3f dB\n', ...
            snr_centers(si), round(1/decision_gamma(si,pi)), ...
            decision_overhead(si,pi), decision_nmse(si,pi));
    end
    fprintf('\n');
end

%% =========================================================
% 13. SAUVEGARDE
% =========================================================

save(fullfile(resultsDir,'adaptive_policy_calibration.mat'), ...
    'NMSE_TARGET_DB', 'nmse_table', 'snr_centers', 'snr_edges', ...
    'decision_gamma', 'decision_nmse', 'decision_overhead', ...
    'gamma_vals', 'Mc_list', 'overhead_bits', 'profile_names', 'm', 's');

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CALIBRATION TERMINEE\n');
fprintf('============================================================\n\n');

fprintf('Aucun échantillon TEST n''a été utilisé.\n\n');
fprintf('Les seuils/paliers sont maintenant figés.\n');
fprintf('Ils pourront être appliqués au jeu TEST.\n\n');

fprintf('============================================================\n');