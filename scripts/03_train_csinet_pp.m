function [net, results] = train_csinet_pp_enhanced()

fprintf('\n============================================\n');
fprintf('   CSINET++ ENHANCED\n');
fprintf('   128 filtres - 15 RefineNet - NMSE Loss\n');
fprintf('============================================\n\n');

%% CHARGEMENT + TRANSFORMÉE ANGULAR-DELAY
fprintf('📂 Chargement et transformation...\n');
data = load('data/cdl_3gpp_data.mat');
d = data.data;

X_train_raw = reshape(d.X_train', 32, 32, 2, []);
X_val_raw = reshape(d.X_val', 32, 32, 2, []);
X_test_raw = reshape(d.X_test', 32, 32, 2, []);

fprintf('   Angular-Delay transform...\n');
X_train = transform_angular_delay(X_train_raw);
X_val = transform_angular_delay(X_val_raw);
X_test = transform_angular_delay(X_test_raw);

fprintf('   Train: %d, Val: %d, Test: %d\n', size(X_train,4), size(X_val,4), size(X_test,4));

%% NORMALISATION GLOBALE
fprintf('\n🔄 Normalisation globale...\n');
m = mean(X_train(:));
s = std(X_train(:));
X_train = (X_train - m) / s;
X_val = (X_val - m) / s;
X_test = (X_test - m) / s;
fprintf('  mean = %.6f, std = %.6f\n', m, s);

%% MODELE
fprintf('\n🏗️ Construction du modele...\n');
addpath(genpath(pwd));
lgraph = build_csinet_pp_enhanced();

%% OPTIONS
fprintf('\n⚙️ Configuration...\n');
options = trainingOptions('adam', ...
    'InitialLearnRate', 1e-4, ...
    'MaxEpochs', 200, ...
    'MiniBatchSize', 256, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', {X_val, X_val}, ...
    'ValidationFrequency', 50, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 50, ...
    'ValidationPatience', 30, ...
    'GradientThreshold', 1, ...
    'Verbose', true, ...
    'Plots', 'training-progress', ...
    'ExecutionEnvironment', 'auto');

%% ENTRAINEMENT
fprintf('\n🚀 DEBUT ENTRAINEMENT...\n\n');
tic;
net = trainNetwork(X_train, X_train, lgraph, options);
temps = toc;

%% EVALUATION
fprintf('\n🧪 Evaluation sur test...\n');
Y_pred = predict(net, X_test);
erreur = (Y_pred - X_test).^2;
puissance = X_test.^2;
nmse = mean(sum(erreur, [1,2,3]) ./ (sum(puissance, [1,2,3]) + 1e-8));
nmse_db = 10 * log10(nmse);
fprintf('  NMSE: %.6f (%.2f dB)\n', nmse, nmse_db);

%% SAUVEGARDE
if ~exist('results', 'dir'), mkdir('results'); end
results.net = net;
results.nmse = nmse;
results.nmse_db = nmse_db;
results.temps = temps;
results.mean = m;
results.std = s;
save('results/csinet_pp_enhanced_results.mat', '-struct', 'results');
fprintf('✅ Resultats sauvegardes\n');

fprintf('\n============================================\n');
fprintf('📊 RESULTATS CSINET++ ENHANCED\n');
fprintf('============================================\n');
fprintf('NMSE: %.6f (%.2f dB)\n', nmse, nmse_db);
fprintf('Temps: %.2f heures\n', temps/3600);
fprintf('============================================\n');

end