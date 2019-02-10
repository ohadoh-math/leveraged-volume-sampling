% This file defines the `linear_regression()` function that recieves a dataset feature
% matrix `X`, and the expected output `y` and returns:
%   * The least-squares optimal fitting solution (w).
%   * The estimated values (Xw).
%   * The least-squares error (|Xw - y|^2).
%   * The time it took Octave to solve the regression problem (time_delta)

function [w, Xw, l2error, time_delta] = linear_regression(X, y)
    before = time();
    w = X \ y;
    time_delta = time() - before;

    Xw = X*w;
    l2error = norm(Xw-y, 2)^2;

    return;
endfunction

