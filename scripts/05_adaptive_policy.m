function [gamma, Mc] = adaptive_policy(snr_dB, profile_label, thresholds)
% ADAPTIVE_POLICY
% Sélection adaptative du taux de compression gamma selon :
%   - le SNR estimé ;
%   - le profil de canal.
%
% Profils :
%   1 = CDL-D / LOS
%   2 = CDL-A / NLOS
%
% Taux disponibles :
%   gamma = 1/4  -> Mc = 512 -> 4096 bits
%   gamma = 1/8  -> Mc = 256 -> 2048 bits
%   gamma = 1/16 -> Mc = 128 -> 1024 bits
%
% Politique retenue :
%
% CDL-D / LOS :
%   SNR < 5 dB       -> gamma = 1/4
%   5 <= SNR < 15 dB -> gamma = 1/8
%   SNR >= 15 dB     -> gamma = 1/16
%
% CDL-A / NLOS :
%   SNR < 21 dB      -> gamma = 1/4
%   SNR >= 21 dB     -> gamma = 1/8
%
% Pour CDL-A/NLOS, le taux 1/16 n'est pas sélectionné par la
% politique finale, car les résultats disponibles ne justifient
% pas l'utilisation de ce taux sous la contrainte de qualité retenue.
%
% ENTREES :
%   snr_dB        : SNR en dB, scalaire ou vecteur
%   profile_label : 1 = CDL-D/LOS, 2 = CDL-A/NLOS
%   thresholds    : structure optionnelle contenant les seuils
%
% SORTIES :
%   gamma : taux de compression sélectionné
%   Mc    : dimension du code latent correspondante

    % ---------------------------------------------------------------
    % Vérification des entrées
    % ---------------------------------------------------------------

    if nargin < 2
        error('adaptive_policy:MissingInput', ...
              'snr_dB et profile_label sont requis.');
    end

    if numel(snr_dB) ~= numel(profile_label)
        error('adaptive_policy:SizeMismatch', ...
              'snr_dB et profile_label doivent avoir la meme taille.');
    end

    % Conversion en vecteurs colonnes
    snr_dB = snr_dB(:);
    profile_label = profile_label(:);

    % ---------------------------------------------------------------
    % Seuils de la politique finale
    % ---------------------------------------------------------------

    if nargin < 3 || isempty(thresholds)

        % CDL-D / LOS
        thresholds.LOS.low  = 5;
        thresholds.LOS.high = 15;

        % CDL-A / NLOS
        thresholds.NLOS.low  = 21;

        % Aucun seuil high NLOS n'est utilisé dans la politique finale.
        thresholds.NLOS.high = Inf;
    end

    % ---------------------------------------------------------------
    % Allocation
    % ---------------------------------------------------------------

    N = numel(snr_dB);

    gamma = zeros(N,1);
    Mc    = zeros(N,1);

    % ---------------------------------------------------------------
    % Sélection adaptative
    % ---------------------------------------------------------------

    for i = 1:N

        s = snr_dB(i);
        p = profile_label(i);

        switch p

            % =======================================================
            % CDL-D / LOS
            % =======================================================
            case 1

                low_thr  = thresholds.LOS.low;
                high_thr = thresholds.LOS.high;

                if s < low_thr

                    % Faible SNR : taux de compression faible
                    gamma(i) = 1/4;
                    Mc(i)    = 512;

                elseif s < high_thr

                    % SNR intermédiaire
                    gamma(i) = 1/8;
                    Mc(i)    = 256;

                else

                    % SNR élevé : compression maximale
                    gamma(i) = 1/16;
                    Mc(i)    = 128;
                end

            % =======================================================
            % CDL-A / NLOS
            % =======================================================
            case 2

                low_thr = thresholds.NLOS.low;

                if s < low_thr

                    % Jusqu'à 20 dB inclus :
                    % conservation du taux 1/4
                    gamma(i) = 1/4;
                    Mc(i)    = 512;

                else

                    % À partir de 21 dB :
                    % passage au taux 1/8
                    gamma(i) = 1/8;
                    Mc(i)    = 256;
                end

            otherwise

                error('adaptive_policy:InvalidProfile', ...
                      'profile_label doit etre 1 (CDL-D/LOS) ou 2 (CDL-A/NLOS).');
        end
    end
end
