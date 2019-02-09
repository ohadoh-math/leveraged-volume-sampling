% This file defines the `linear_regression()` function that recieves a dataset feature
% matrix `X`, and the expected output `y` and returns:
%   * The least-squares optimal fitting solution (w).
%   * The estimated values (Xw).
%   * The least-squares error (|Xw - y|^2).

function [w, Xw, l2error] = linear_regression(X, y)
    w = X \ y;
    Xw = X*w;
    l2error = norm(Xw-y, 2)^2;
    return;
endfunction

