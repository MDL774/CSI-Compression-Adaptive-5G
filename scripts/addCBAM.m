function [lgraph, outputName] = addCBAM(lgraph, inputName, outputName, numChannels, blockName)
    % ==========================================================
    % CBAM (Channel Attention) - Version corrigee
    % ==========================================================
    if nargin < 5
        blockName = 'cbam';
    end
    if nargin < 4
        numChannels = 64;
    end
    fprintf('   Ajout CBAM : %s\n', blockName);

    %% ===== CHANNEL ATTENTION =====
    gapName  = sprintf('%s_gap', blockName);
    fc1Name  = sprintf('%s_fc1', blockName);
    reluName = sprintf('%s_relu', blockName);
    fc2Name  = sprintf('%s_fc2', blockName);
    sigName  = sprintf('%s_sig', blockName);
    mulName  = sprintf('%s_scale', blockName);

    lgraph = addLayers(lgraph, globalAveragePooling2dLayer('Name', gapName));
    lgraph = addLayers(lgraph, fullyConnectedLayer(max(1, floor(numChannels/4)), 'Name', fc1Name));
    lgraph = addLayers(lgraph, reluLayer('Name', reluName));
    lgraph = addLayers(lgraph, fullyConnectedLayer(numChannels, 'Name', fc2Name));
    lgraph = addLayers(lgraph, sigmoidLayer('Name', sigName));
    lgraph = addLayers(lgraph, multiplicationLayer(2, 'Name', mulName));

    lgraph = connectLayers(lgraph, inputName, gapName);
    lgraph = connectLayers(lgraph, gapName, fc1Name);
    lgraph = connectLayers(lgraph, fc1Name, reluName);
    lgraph = connectLayers(lgraph, reluName, fc2Name);
    lgraph = connectLayers(lgraph, fc2Name, sigName);

    lgraph = connectLayers(lgraph, inputName, [mulName '/in1']);
    lgraph = connectLayers(lgraph, sigName,   [mulName '/in2']);

    %% ===== SORTIE =====
    outputName = mulName;
    fprintf('   CBAM ajoute : %s\n', blockName);
end