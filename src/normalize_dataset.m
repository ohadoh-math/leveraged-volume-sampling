% Turns out the huge datasets fail to converge when using this implementation
% of LVSS because for their case det(X'*X) = Inf and that causes comparisons like:
% rand() < NaN and rand() < 0 and that will always fail, thus the algorithm fails
% to converge.
% To compensate for such an event we'll normalize X such that det(X'*X) is always 1.
%
% The transformation we want to apply is scaling of X and y by det(X'*X)^(1/(2*d)).
%
% Since directly normalizing the large datasets won't work (because det(X'*X) = Inf)
% we first calculate the eigenvalues of X'*X (which for our datasets are fine),
% raise each of them by 1/(2*d) and this lowers them enough so that we can take
% their product and use it to normalize X.
%
% Note that we drop any eigenvalues that are diminished to 0 (which means either
% they were 0 or there was some floating point error.

function [nX, ny, scaling_factor] = normalize_dataset(X, y)
    d = columns(X);
    Z = X'*X;

    factor = prod(
        arrayfun(
            @ (v) v + (v == 0),
            abs(eig(Z)).^(1/(2*d))
        )
    );

    nX = X/factor;
    ny = y/factor;
    scaling_factor = factor;
endfunction

