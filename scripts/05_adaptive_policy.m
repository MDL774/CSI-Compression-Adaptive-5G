function [gamma, reason] = adaptivePolicy(snr_db, channelType, prev_nmse_db)

%==========================================================
% channelType
%
% 0 = CDL-A (NLOS)
% 1 = CDL-D (LOS)
%==========================================================

if channelType==1

    %========================
    % LOS
    %========================

    if snr_db >= 20 && prev_nmse_db <= -18

        gamma = 1/16;
        reason = "Excellent LOS";

    elseif snr_db >=10 && prev_nmse_db <= -15

        gamma = 1/8;
        reason = "Bon LOS";

    else

        gamma = 1/4;
        reason = "LOS difficile";

    end

else

    %========================
    % NLOS
    %========================

    if snr_db>=20 && prev_nmse_db<=-16

        gamma = 1/8;
        reason = "Bon NLOS";

    else

        gamma = 1/4;
        reason = "NLOS difficile";

    end

end

end