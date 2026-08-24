%% measure_latency.m
% =========================================================
% MESURE DE LA LATENCE : INFERENCE ET TRANSMISSION DU FEEDBACK
%
% Deux composantes mesurees/calculees :
%   1. Latence de calcul (inference) : temps pris par predict() pour
%      encoder+decoder un batch de CSI, sur CPU (meme materiel que
%      l'entrainement). Mesuree directement, en millisecondes par
%      echantillon.
%   2. Latence de transmission du feedback : derivee de l'overhead
%      (en bits) et d'un debit de reference du canal de retour
%      (liaison montante), en supposant un debit constant pour la
%      comparaison relative entre taux de compression.
% =========================================================

%% 0. CHARGEMENT (adapter selon les modeles disponibles)
nets.g4  = net_clean;
if exist('net_g8', 'var'),  nets.g8  = net_g8;  end
if exist('net_g16', 'var'), nets.g16 = net_g16; end

gamma_list = fieldnames(nets);
Mc_map = struct('g4', 512, 'g8', 256, 'g16', 128);
gamma_label = struct('g4', '1/4', 'g8', '1/8', 'g16', '1/16');
Q_BITS = 8;

if ~exist('X_test', 'var')
    data = load('cdl_3gpp_data_clean.mat');
    d = data.data;
    X_test = reshape(d.X_test', 32, 32, 2, []);
end

%% 1. LATENCE D'INFERENCE (encodage + decodage complet)
% Mesuree sur un batch representatif (1000 echantillons), CPU, apres
% un appel de "rechauffement" (warm-up) pour eviter de compter le
% temps de compilation JIT/optimisation interne dans la mesure.
N_BATCH = 1000;
N_REPEATS = 5;   % moyenne sur plusieurs passages pour plus de stabilite

Xb = X_test(:,:,:, 1:min(N_BATCH, size(X_test,4)));

fprintf('=== LATENCE D''INFERENCE (CPU) ===\n');
fprintf('%-8s | %-12s | %-18s | %-18s\n', 'Gamma', 'Mc', 'Latence totale (ms)', 'Latence/echant. (ms)');
fprintf('---------|--------------|--------------------|--------------------\n');

latency_results = struct();
for gi = 1:numel(gamma_list)
    net_g = nets.(gamma_list{gi});

    % Warm-up (non chronometre)
    predict(net_g, Xb(:,:,:,1:10));

    % Mesures chronometrees
    times = zeros(N_REPEATS, 1);
    for r = 1:N_REPEATS
        tic;
        predict(net_g, Xb);
        times(r) = toc;
    end
    mean_time_s = mean(times);
    mean_time_ms = mean_time_s * 1000;
    per_sample_ms = mean_time_ms / size(Xb, 4);

    latency_results.(gamma_list{gi}).total_ms = mean_time_ms;
    latency_results.(gamma_list{gi}).per_sample_ms = per_sample_ms;

    fprintf('%-8s | %-12d | %-18.2f | %-18.4f\n', ...
        gamma_label.(gamma_list{gi}), Mc_map.(gamma_list{gi}), mean_time_ms, per_sample_ms);
end

%% 2. LATENCE DE TRANSMISSION DU FEEDBACK (derive de l'overhead)
% Hypothese : debit de reference de la liaison de feedback (uplink)
% -- a ajuster selon le scenario etudie dans le memoire (ex. quelques
% Mbps pour un canal de controle typique). Valeur ici a titre
% d'illustration, A AJUSTER avec une valeur justifiee dans le texte.
UPLINK_RATE_MBPS = 1;   % Mbit/s -- HYPOTHESE A JUSTIFIER/AJUSTER
uplink_rate_bps = UPLINK_RATE_MBPS * 1e6;

fprintf('\n=== LATENCE DE TRANSMISSION DU FEEDBACK ===\n');
fprintf('(hypothese : debit liaison retour = %.1f Mbit/s)\n', UPLINK_RATE_MBPS);
fprintf('%-8s | %-12s | %-15s | %-20s\n', 'Gamma', 'Mc', 'Overhead (bits)', 'Latence feedback (ms)');
fprintf('---------|--------------|-----------------|----------------------\n');

for gi = 1:numel(gamma_list)
    overhead_bits = Mc_map.(gamma_list{gi}) * Q_BITS;
    latency_feedback_ms = (overhead_bits / uplink_rate_bps) * 1000;

    latency_results.(gamma_list{gi}).overhead_bits = overhead_bits;
    latency_results.(gamma_list{gi}).feedback_latency_ms = latency_feedback_ms;

    fprintf('%-8s | %-12d | %-15d | %-20.4f\n', ...
        gamma_label.(gamma_list{gi}), Mc_map.(gamma_list{gi}), overhead_bits, latency_feedback_ms);
end

%% 3. LATENCE TOTALE (inference + transmission) ET GAIN RELATIF vs gamma=1/4
fprintf('\n=== LATENCE TOTALE ET GAIN RELATIF (reference : gamma=1/4) ===\n');
ref_total = latency_results.g4.per_sample_ms + latency_results.g4.feedback_latency_ms;

for gi = 1:numel(gamma_list)
    total_ms = latency_results.(gamma_list{gi}).per_sample_ms + ...
               latency_results.(gamma_list{gi}).feedback_latency_ms;
    gain_pct = 100 * (ref_total - total_ms) / ref_total;

    latency_results.(gamma_list{gi}).total_latency_ms = total_ms;
    latency_results.(gamma_list{gi}).gain_vs_g4_pct = gain_pct;

    fprintf('%-8s : latence totale = %.4f ms | gain vs 1/4 = %.1f%%\n', ...
        gamma_label.(gamma_list{gi}), total_ms, gain_pct);
end

%% 4. SAUVEGARDE
save('results/latency_results.mat', 'latency_results', 'UPLINK_RATE_MBPS');
fprintf('\nResultats sauvegardes dans results/latency_results.mat\n');

%% 5. GRAPHIQUE : COMPARAISON DES LATENCES PAR TAUX DE COMPRESSION
n_g = numel(gamma_list);
inference_vals = zeros(n_g, 1);
feedback_vals  = zeros(n_g, 1);
labels = cell(n_g, 1);

for gi = 1:n_g
    inference_vals(gi) = latency_results.(gamma_list{gi}).per_sample_ms;
    feedback_vals(gi)  = latency_results.(gamma_list{gi}).feedback_latency_ms;
    labels{gi} = ['\gamma=' gamma_label.(gamma_list{gi})];
end

figure('Position', [100 100 700 450]);
bar_data = [inference_vals, feedback_vals];
b = bar(bar_data, 'stacked');
b(1).DisplayName = 'Latence d''inference (ms/echantillon)';
b(2).DisplayName = 'Latence de feedback (ms)';
set(gca, 'XTickLabel', labels);
ylabel('Latence (ms)');
title('Latence totale par taux de compression (inference + feedback)');
legend('Location', 'best'); grid on;

fprintf('\nGraphique de latence genere.\n');