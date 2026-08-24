%% generateCDL_3GPP_clean.m
% GENERATION VRAIS CANAUX 3GPP CDL - VERSION CORRIGEE (SANS BRUIT DANS LA CIBLE)
%
% Identique a archive\runFullCDLExperiment.m (meme physique : nrCDLChannel,
% domaine angulaire-retard via IFFT/FFT, combinaison coherente de TOUS les
% trajets multipath, profils CDL-D/CDL-A, meme numerologie 3GPP) --
% SEULE DIFFERENCE :
%
%   L'ANCIEN script ajoutait du bruit AWGN (SNR tire uniform(0,30) dB)
%   DIRECTEMENT dans X_train/X_val/X_test, qui servent ensuite de CIBLE
%   ET d'ENTREE a l'autoencodeur (trainNetwork(X_train, X_train, ...)).
%   Consequence : l'autoencodeur apprenait a reconstruire un signal DEJA
%   bruite, ce qui impose un plafond de NMSE physique arbitraire (lie au
%   tirage aleatoire du bruit), sans rapport avec la capacite reelle du
%   modele a compresser le CSI.
%
%   CE SCRIPT : le CSI reste PROPRE (pas de bruit injecte dans les donnees
%   de compression). Le SNR est toujours genere et sauvegarde en
%   METADONNEE (snr_train/snr_val/snr_test) -- il sert a piloter la
%   politique adaptative gamma(SNR, profil), pas a corrompre la tache de
%   compression elle-meme. C'est la separation standard dans la
%   litterature CsiNet : on compresse le CSI ESTIME (deja nettoye), le
%   SNR influence le CHOIX du taux de compression, pas la reconstruction.
%
% PREREQUIS : MATLAB R2024a/b, Deep Learning Toolbox, 5G Toolbox

clear; clc; close all;

%% ============================================
% 1. CONFIGURATION (identique a runFullCDLExperiment.m)
%% ============================================
fprintf('============================================\n');
fprintf('GENERATION CDL 3GPP - CSI PROPRE (SNR en metadata)\n');
fprintf('============================================\n');

cfg.fc          = 3.5e9;
cfg.B           = 100e6;
cfg.Nc          = 1024;
cfg.deltaF      = 30e3;
cfg.fs          = cfg.Nc * cfg.deltaF;
cfg.Mt          = 32;
cfg.Mr          = 1;
cfg.Na          = 32;
cfg.d_in        = 2 * cfg.Na * cfg.Mt;
cfg.Q_bits      = 8;

cfg.n_train_pool = 100000;
cfg.n_val        = 10000;
cfg.n_train      = cfg.n_train_pool - cfg.n_val;
cfg.n_test       = 20000;
cfg.n_total      = cfg.n_train_pool + cfg.n_test;

cfg.epochs        = 50;
cfg.batch_size    = 256;
cfg.learning_rate = 1e-3;

fprintf('Parametres:\n');
fprintf('  Frequence porteuse       : %.1f GHz (bande n78)\n', cfg.fc/1e9);
fprintf('  Sous-porteuses Nc        : %d\n', cfg.Nc);
fprintf('  Antennes BS Mt (UPA 4x8) : %d\n', cfg.Mt);
fprintf('  Delais conserves Na      : %d\n', cfg.Na);
fprintf('  Dimension entree d_in    : %d (= 2 x %d x %d)\n', cfg.d_in, cfg.Na, cfg.Mt);
fprintf('  Total genere             : %d (train pool %d + test %d)\n', ...
    cfg.n_total, cfg.n_train_pool, cfg.n_test);
fprintf('  Train effectif / Val     : %d / %d\n', cfg.n_train, cfg.n_val);

%% ============================================
% 2. STRUCTURE DES ANTENNES (identique, Mr=1 : cas mono-antenne UE standard)
%% ============================================
txArray = struct(...
    'Size', [4, 8, 1, 1, 1], ...
    'ElementSpacing', [0.5, 0.5, 1, 1], ...
    'PolarizationAngles', 0, ...
    'PolarizationModel', 'Model-1', ...
    'Element', '38.901' ...
);

rxArray = struct(...
    'Size', [1, 1, 1, 1, 1], ...
    'ElementSpacing', [0.5, 0.5, 1, 1], ...
    'PolarizationAngles', 0, ...
    'PolarizationModel', 'Model-1', ...
    'Element', '38.901' ...
);

assert(prod(txArray.Size(1:3)) == cfg.Mt, 'txArray ne correspond pas a Mt=%d elements', cfg.Mt);
assert(prod(rxArray.Size(1:3)) == cfg.Mr, 'rxArray ne correspond pas a Mr=%d element(s)', cfg.Mr);

%% ============================================
% 3. GENERATION DES CANAUX CDL 3GPP (CSI PROPRE, pas de bruit injecte)
%% ============================================
fprintf('\n============================================\n');
fprintf('GENERATION DES CANAUX CDL 3GPP (CSI propre)\n');
fprintf('============================================\n');

profiles     = {'CDL-D', 'CDL-A'};
profileNames = {'LOS (CDL-D)', 'NLOS (CDL-A)'};
n_per_profile = floor(cfg.n_total / 2);

X_all     = [];
snr_all   = [];   % <-- conserve comme METADATA uniquement, jamais injecte dans X_all
label_all = [];

tic;
for p = 1:length(profiles)
    profile = profiles{p};
    fprintf('\n  Profil %s (%d canaux)...\n', profileNames{p}, n_per_profile);

    % Le SNR est genere ici (representera les conditions de reception
    % pour la politique adaptative), mais n'est PLUS transmis a la
    % fonction de generation du canal -- voir signature ci-dessous.
    snr = 30 * rand(n_per_profile, 1);

    try
        H = generateCDL_3GPP_noNoise(n_per_profile, profile, cfg, txArray, rxArray);
        X_all     = [X_all; H];
        snr_all   = [snr_all; snr];
        label_all = [label_all; repmat(p, n_per_profile, 1)];
        fprintf('  OK: %d canaux CDL generes pour %s (CSI propre)\n', size(H, 1), profile);
    catch ME
        fprintf('  ERREUR: %s\n', ME.message);
        rethrow(ME);
    end
end
temps_gen = toc;
fprintf('\n  Temps de generation: %.2f secondes\n', temps_gen);
fprintf('  Total: %d canaux CDL 3GPP\n', size(X_all, 1));

%% ============================================
% 4. SPLIT TRAIN/VAL/TEST
%% ============================================
fprintf('\n============================================\n');
fprintf('SPLIT DES DONNEES\n');
fprintf('============================================\n');

idx = randperm(size(X_all, 1));
X_all     = X_all(idx, :);
snr_all   = snr_all(idx);
label_all = label_all(idx);

X_train     = X_all(1:cfg.n_train, :);
snr_train   = snr_all(1:cfg.n_train);
label_train = label_all(1:cfg.n_train);

X_val     = X_all(cfg.n_train+1 : cfg.n_train+cfg.n_val, :);
snr_val   = snr_all(cfg.n_train+1 : cfg.n_train+cfg.n_val);
label_val = label_all(cfg.n_train+1 : cfg.n_train+cfg.n_val);

X_test     = X_all(cfg.n_train+cfg.n_val+1 : end, :);
snr_test   = snr_all(cfg.n_train+cfg.n_val+1 : end);
label_test = label_all(cfg.n_train+cfg.n_val+1 : end);

fprintf('  Train: %d echantillons\n', size(X_train, 1));
fprintf('  Val:   %d echantillons\n', size(X_val, 1));
fprintf('  Test:  %d echantillons\n', size(X_test, 1));

%% ============================================
% 5. NORMALISATION (feature-wise, identique a l'original)
%% ============================================
fprintf('\n============================================\n');
fprintf('NORMALISATION\n');
fprintf('============================================\n');

mean_X = mean(X_train, 1);
std_X  = std(X_train, 0, 1);
std_X(std_X == 0) = 1;

X_train_norm = (X_train - mean_X) ./ std_X;
X_val_norm   = (X_val   - mean_X) ./ std_X;
X_test_norm  = (X_test  - mean_X) ./ std_X;

fprintf('  OK: Normalisation terminee (CSI propre, aucun bruit)\n');

%% ============================================
% 6. VERIFICATION DE LA CORRELATION SPATIALE
%% ============================================
Na = cfg.Na; Mt = cfg.Mt;
x1 = reshape(X_train_norm(1,:).', Na, Mt, 2);
corr_h = mean(diag(corr(x1(:,1:31,1), x1(:,2:32,1))));
fprintf('  Correlation horizontale (canal reel, echantillon 1) : %.4f\n', corr_h);
fprintf('  (Reference precedente avec bruit AWGN dans la cible : ~0.12)\n');

%% ============================================
% 7. SAUVEGARDE
%% ============================================
fprintf('\n============================================\n');
fprintf('SAUVEGARDE\n');
fprintf('============================================\n');

data.X_train     = single(X_train_norm);
data.X_val       = single(X_val_norm);
data.X_test      = single(X_test_norm);
data.snr_train   = snr_train;   % metadata uniquement -- utiliser pour la politique adaptative
data.snr_val     = snr_val;
data.snr_test    = snr_test;
data.label_train = label_train; % 1 = CDL-D (LOS), 2 = CDL-A (NLOS)
data.label_val   = label_val;
data.label_test  = label_test;
data.mean        = mean_X;
data.std         = std_X;
data.cfg         = cfg;
data.note        = 'CSI propre, SNR en metadata uniquement (pas de bruit injecte dans X)';

save('cdl_3gpp_data_clean.mat', 'data', '-v7.3');
fprintf('  OK: Donnees sauvegardees dans cdl_3gpp_data_clean.mat\n');

fprintf('\n============================================\n');
fprintf('TERMINE\n');
fprintf('============================================\n');


%% ============================================
% FONCTION DE GENERATION (identique a runFullCDLExperiment.m,
% simplement debarrassee de l'ajout de bruit AWGN en fin de fonction)
%% ============================================

function H = generateCDL_3GPP_noNoise(n, profileType, cfg, txArray, rxArray)
% GENERATION CDL 3GPP - Domaine angulaire-retard (convention CsiNet)
% Meme physique que l'original : combinaison COHERENTE de tous les
% trajets multipath (avec la bonne phase liee au delai), TOUTES les
% Mt=32 antennes, troncature Na dans le domaine angulaire-retard.
% DIFFERENCE : aucun bruit AWGN ajoute a la fin -- H est le CSI propre.

    Nsc    = cfg.Nc;
    deltaF = cfg.deltaF;

    cdl = nrCDLChannel;
    cdl.DelayProfile        = profileType;
    cdl.CarrierFrequency    = cfg.fc;
    cdl.SampleRate          = cfg.fs;
    cdl.ChannelFiltering    = false;
    cdl.NormalizePathGains  = true;
    cdl.NumTimeSamples      = 1;
    cdl.TransmitAntennaArray = txArray;
    cdl.ReceiveAntennaArray  = rxArray;

    chInfo     = info(cdl);
    pathDelays = chInfo.PathDelays;
    Np = numel(pathDelays);

    k = (0:Nsc-1)';
    PhaseMatrix = exp(-1j*2*pi*k*deltaF*pathDelays(:)');

    H = zeros(n, 2*cfg.Na*cfg.Mt);
    printEvery = max(1, floor(n/20));

    for i = 1:n
        reset(cdl);
        [pg, ~] = cdl();

        % ---------------------------------------------------------------
        % CORRECTIF (v2, confirme par mesure directe) : avec Mr=1, la
        % sortie pg de nrCDLChannel est en realite 3D [NumTimeSamples=1,
        % Np, Nt] -- le toolbox retire deja la dimension Nr=1 en amont,
        % il n'y a jamais eu de 4e dimension a extraire. Le premier
        % correctif supposait a tort une structure 4D [Ns,Np,Nr,Nt] et
        % reproduisait le meme bug (une seule antenne Tx selectionnee)
        % en indexant accidentellement l'axe Nt avec l'indice suppose
        % etre Nr.
        %
        % Extraction correcte, confirmee par size(pg)=[1,14,32] mesure
        % directement en session :
        % ---------------------------------------------------------------
        pgRx1 = reshape(pg(1, :, :), Np, []);   % [Np x Nt], toutes les Nt antennes Tx
        Nt_actual = size(pgRx1, 2);        % doit valoir cfg.Mt = 32

        Hfreq = PhaseMatrix * pgRx1;

        Hdelay   = ifft(Hfreq, Nsc, 1);
        Hangular = fft(Hdelay, Nt_actual, 2);

        Ha = Hangular(1:cfg.Na, :);

        if Nt_actual < cfg.Mt
            Ha_full = zeros(cfg.Na, cfg.Mt);
            Ha_full(:, 1:Nt_actual) = Ha;
            Ha = Ha_full;
        else
            Ha = Ha(:, 1:cfg.Mt);
        end

        p_energy = mean(abs(Ha(:)).^2);
        if p_energy > 0
            Ha = Ha / sqrt(p_energy);
        end

        H(i,:) = [real(Ha(:)); imag(Ha(:))]';

        if mod(i, printEvery) == 0 || i == n
            fprintf('    ... %d / %d canaux (%s)\n', i, n, profileType);
        end
    end
    % PAS de bloc d'ajout de bruit AWGN ici -- H reste le CSI propre.
end
