function bits = computeFeedback(gamma, Q)

if nargin < 2
    Q = 8;
end

d_in = 2048;

Mc = round(d_in*gamma);

bits = Mc*Q;

end