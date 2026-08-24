classdef nmseRegressionLayer < nnet.layer.RegressionLayer
    % ==========================================================
    % NMSE REGRESSION LAYER
    %
    % Loss :
    %   L = mean_b [ ||Y_b-T_b||^2 / (||T_b||^2 + eps) ]
    %
    % Cette couche minimise directement le NMSE normalise.
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

            % NMSE individuel
            nmsePerSample = ...
                errorPower ./ (targetPower + epsVal);

            % Moyenne sur le batch
            loss = mean(nmsePerSample);

        end


        function dLdY = backwardLoss(layer, Y, T)

            epsVal = 1e-8;

            % Taille du batch
            B = size(Y, 4);

            % Puissance du signal cible par echantillon
            targetPower = sum(T.^2, [1 2 3]);

            % Gradient :
            %
            % dL/dY =
            % 2(Y-T) / (targetPower + eps) / B

            denominator = ...
                targetPower + epsVal;

            denominator = reshape( ...
                denominator, ...
                1, 1, 1, B);

            dLdY = ...
                (2 * (Y - T) ./ denominator) / B;

        end

    end
end
