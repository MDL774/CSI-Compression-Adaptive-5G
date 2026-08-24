classdef nmseRegressionLayer < nnet.layer.RegressionLayer
    % ==========================================================
    % NMSE REGRESSION LAYER
    % Minimise directement la NMSE moyenne sur le batch
    % ==========================================================

    methods

        function layer = nmseRegressionLayer(varargin)

            layer.Name = 'output';

            layer.Description = ...
                'NMSE Regression Layer';

        end


        function loss = forwardLoss(layer, Y, T)

            epsVal = 1e-8;

            % Erreur quadratique par echantillon
            errorPower = sum((Y - T).^2, [1 2 3]);

            % Puissance du signal cible par echantillon
            targetPower = sum(T.^2, [1 2 3]);

            % NMSE par echantillon
            nmsePerSample = ...
                errorPower ./ (targetPower + epsVal);

            % Moyenne de la NMSE sur le batch
            loss = mean(nmsePerSample);

        end


        function dLdY = backwardLoss(layer, Y, T)

            epsVal = 1e-8;

            % Taille du batch
            B = size(Y, 4);

            % Puissance du signal cible par echantillon
            targetPower = sum(T.^2, [1 2 3]);

            % Gradient de la NMSE moyenne
            dLdY = ...
                2 .* (Y - T) ./ ...
                (targetPower + epsVal) ./ B;

        end

    end

end
