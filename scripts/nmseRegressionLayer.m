classdef nmseRegressionLayer < nnet.layer.RegressionLayer
    % ==========================================================
    % NMSE REGRESSION LAYER
    % Minimise directement le NMSE
    % ==========================================================
    methods
        function layer = nmseRegressionLayer(varargin)
            % Constructeur
            layer.Name = 'output';
            layer.Description = 'NMSE Regression Layer';
        end

        function loss = forwardLoss(layer, Y, T)
            % Calcul du NMSE
            eps = 1e-8;
            % Erreur quadratique par echantillon
            error = sum((Y - T).^2, [1, 2, 3]); % [1, 1, 1, B]
            % Puissance du signal par echantillon
            power = sum(T.^2, [1, 2, 3]); % [1, 1, 1, B]
            % NMSE par echantillon
            nmse_per_sample = error ./ (power + eps);
            % Moyenne sur le batch
            loss = mean(nmse_per_sample);
        end

        function dLdY = backwardLoss(layer, Y, T)
            % Gradient pour la retropropagation
            % ---------------------------------------------------------------
            % CORRECTIF : forwardLoss fait mean(nmse_per_sample), donc divise
            % par B (la taille du batch). L'ancienne version de backwardLoss
            % ne divisait PAS par B, ce qui rendait le gradient retourne B
            % fois trop grand par rapport a la loss reellement utilisee par
            % forwardLoss -- incoherent avec la convention attendue par
            % trainNetwork pour une couche de regression personnalisee.
            % ---------------------------------------------------------------
            eps = 1e-8;
            power = sum(T.^2, [1, 2, 3]);
            B = size(Y, 4);
            power_expanded = repmat(power ./ B, size(Y,1), size(Y,2), size(Y,3));
            dLdY = 2 * (Y - T) ./ (power_expanded + eps) ./ B;
        end
    end
end
