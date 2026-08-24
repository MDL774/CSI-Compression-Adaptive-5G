function lgraph = build_csinet_pp_g16()

fprintf("\n=====================================\n");
fprintf(" CsiNet++ 3 RefineNet + CBAM\n");
fprintf(" 64 filtres - Compression 1/16\n");
fprintf("=====================================\n\n");


%% PARAMETRES
Na = 32;
Mt = 32;
inputSize = [Na Mt 2];
numFilters = 64;
Mc = 128;


%% ENCODEUR
layers = [
    imageInputLayer(inputSize, "Normalization","none", "Name","input")
    convolution2dLayer(3,numFilters, "Padding","same", "Name","encoder_conv1")
    batchNormalizationLayer("Name","encoder_bn1")
    reluLayer("Name","encoder_relu1")
    convolution2dLayer(3,numFilters, "Padding","same", "Name","encoder_conv2")
    batchNormalizationLayer("Name","encoder_bn2")
    reluLayer("Name","encoder_relu2")
];

lgraph = layerGraph(layers);


%% BOTTLENECK
bottleneck = [
    flattenLayer("Name","flatten")
    fullyConnectedLayer(Mc, "Name","encoder_fc")
];

lgraph = addLayers(lgraph,bottleneck);
lgraph = connectLayers(lgraph, "encoder_relu2", "flatten");


%% DECODEUR
decoder_fc = fullyConnectedLayer(Na*Mt*numFilters, "Name","decoder_fc");

% ---------------------------------------------------------------
% CORRECTIF : le reshape() MATLAB sur un dlarray formate renvoie un
% tableau SANS format (les labels S/S/C/B sont perdus). C'est
% exactement ce qui provoquait l'erreur :
%   "Input data must have two spatial dimensions... Instead, it
%    has 0 spatial dimensions and 0 temporal dimensions"
% au niveau de decoder_conv1. On reetiquette explicitement la
% sortie en 'SSCB' (Spatial, Spatial, Channel, Batch) : ceci ne
% casse PAS la retropropagation, ca ne fait qu'ajouter les labels
% de format sur le meme dlarray trace.
% ---------------------------------------------------------------
decoder_reshape = functionLayer( ...
    @(x) dlarray(reshape(x, Na, Mt, numFilters, []), 'SSCB'), ...
    'Name', 'decoder_reshape', ...
    'Formattable', true, ...
    'Acceleratable', true);

decoder_conv1 = convolution2dLayer(3, numFilters, 'Padding', 'same', 'Name', 'decoder_conv1');
decoder_bn1 = batchNormalizationLayer('Name', 'decoder_bn1');
decoder_relu1 = reluLayer('Name', 'decoder_relu1');

lgraph = addLayers(lgraph, decoder_fc);
lgraph = addLayers(lgraph, decoder_reshape);
lgraph = addLayers(lgraph, decoder_conv1);
lgraph = addLayers(lgraph, decoder_bn1);
lgraph = addLayers(lgraph, decoder_relu1);

lgraph = connectLayers(lgraph, "encoder_fc", "decoder_fc");
lgraph = connectLayers(lgraph, "decoder_fc", "decoder_reshape");
lgraph = connectLayers(lgraph, "decoder_reshape", "decoder_conv1");
lgraph = connectLayers(lgraph, "decoder_conv1", "decoder_bn1");
lgraph = connectLayers(lgraph, "decoder_bn1", "decoder_relu1");


%% REFINE BLOCK 1 - UNIQUEMENT LES CONNEXIONS EXTERNES
lgraph = addLayers(lgraph,[
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine1_conv1")
    batchNormalizationLayer("Name","refine1_bn1")
    reluLayer("Name","refine1_relu1")
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine1_conv2")
    batchNormalizationLayer("Name","refine1_bn2")
]);

lgraph = addLayers(lgraph, additionLayer(2,"Name","refine1_add"));
lgraph = addLayers(lgraph, reluLayer("Name","refine1_out"));

lgraph = connectLayers(lgraph, "decoder_relu1", "refine1_conv1");      % Entree du bloc
lgraph = connectLayers(lgraph, "decoder_relu1", "refine1_add/in2");    % Skip connection
lgraph = connectLayers(lgraph, "refine1_bn2", "refine1_add/in1");      % Connexion vers addition
lgraph = connectLayers(lgraph, "refine1_add", "refine1_out");          % Sortie du bloc


%% CBAM 1
[lgraph, cbam1_out] = addCBAM(lgraph, "refine1_out", "refine1_cbam_output", numFilters, "cbam_1");


%% REFINE BLOCK 2
lgraph = addLayers(lgraph,[
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine2_conv1")
    batchNormalizationLayer("Name","refine2_bn1")
    reluLayer("Name","refine2_relu1")
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine2_conv2")
    batchNormalizationLayer("Name","refine2_bn2")
]);

lgraph = addLayers(lgraph, additionLayer(2,"Name","refine2_add"));
lgraph = addLayers(lgraph, reluLayer("Name","refine2_out"));

lgraph = connectLayers(lgraph, cbam1_out, "refine2_conv1");
lgraph = connectLayers(lgraph, cbam1_out, "refine2_add/in2");
lgraph = connectLayers(lgraph, "refine2_bn2", "refine2_add/in1");
lgraph = connectLayers(lgraph, "refine2_add", "refine2_out");


%% CBAM 2
[lgraph, cbam2_out] = addCBAM(lgraph, "refine2_out", "refine2_cbam_output", numFilters, "cbam_2");


%% REFINE BLOCK 3
lgraph = addLayers(lgraph,[
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine3_conv1")
    batchNormalizationLayer("Name","refine3_bn1")
    reluLayer("Name","refine3_relu1")
    convolution2dLayer(3,numFilters, "Padding","same", "Name","refine3_conv2")
    batchNormalizationLayer("Name","refine3_bn2")
]);

lgraph = addLayers(lgraph, additionLayer(2,"Name","refine3_add"));
lgraph = addLayers(lgraph, reluLayer("Name","refine3_out"));

lgraph = connectLayers(lgraph, cbam2_out, "refine3_conv1");
lgraph = connectLayers(lgraph, cbam2_out, "refine3_add/in2");
lgraph = connectLayers(lgraph, "refine3_bn2", "refine3_add/in1");
lgraph = connectLayers(lgraph, "refine3_add", "refine3_out");


%% CBAM 3
[lgraph, cbam3_out] = addCBAM(lgraph, "refine3_out", "refine3_cbam_output", numFilters, "cbam_3");


%% SORTIE
lgraph = addLayers(lgraph, convolution2dLayer(3, 2, "Padding","same", "Name","final_conv"));
lgraph = connectLayers(lgraph, cbam3_out, "final_conv");

lgraph = addLayers(lgraph, regressionLayer("Name","output"));
lgraph = connectLayers(lgraph, "final_conv", "output");


%% VERIFICATION
fprintf("=====================================\n");
fprintf("Reseau CsiNet++ construit avec succes\n");
fprintf("   - Filtres : %d\n",numFilters);
fprintf("   - Compression : %d (gamma=1/4)\n",Mc);
fprintf("   - RefineNet : 3 blocs\n");
fprintf("   - CBAM : 3 modules\n");
fprintf("   - Sortie : Regression\n");
fprintf("=====================================\n");

if isempty(lgraph.OutputNames)
    fprintf("Attention : aucune sortie detectee\n");
else
    fprintf("Couche de sortie : %s\n", lgraph.OutputNames{1});
end

end