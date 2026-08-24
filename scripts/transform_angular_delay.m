function H_ad = transform_angular_delay(H)
    % ==========================================================
    % Transformation vers le domaine Angle-Retard (Angular-Delay)
    % via FFT2D, normalisee.
    %
    % CORRECTIF : la version precedente faisait
    %   H_complex = squeeze(H_complex);
    % sur un tableau de taille [Na, Mt, 1, N]. squeeze() le reduit
    % a [Na, Mt, N] -- une matrice 3D ou la 3e dimension est deja
    % les echantillons, pas un axe libre. Le cat(3, real(...), imag(...))
    % qui suivait concatenait alors les ECHANTILLONS entre eux
    % (taille [Na, Mt, 2N]), et le reshape final vers [Na, Mt, 2, N]
    % re-interpretait cet ordre en melangeant la partie reelle d'un
    % echantillon avec la partie imaginaire d'un AUTRE echantillon.
    %
    % Ce correctif construit explicitement le tableau de sortie
    % [Na, Mt, 2, N] par assignation directe, sans jamais passer par
    % un squeeze/cat ambigu sur la dimension batch.
    % ==========================================================
    [Na, Mt, ~, N] = size(H);

    H_complex = complex(H(:,:,1,:), H(:,:,2,:));   % [Na, Mt, 1, N], reste en 4D
    H_complex = reshape(H_complex, Na, Mt, N);       % squeeze explicite, seulement dim 3 (singleton)

    H_ad_complex = fft2(H_complex) / sqrt(Na * Mt);  % FFT2D par echantillon, [Na, Mt, N]

    H_ad = zeros(Na, Mt, 2, N, 'like', real(H_ad_complex));
    H_ad(:,:,1,:) = reshape(real(H_ad_complex), Na, Mt, 1, N);
    H_ad(:,:,2,:) = reshape(imag(H_ad_complex), Na, Mt, 1, N);
end
