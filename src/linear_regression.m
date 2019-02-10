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

% a simple test to make sure everything is in order.
% the test is mostly here to make sure the dimensions of the returned values are correct
% (the code is simple enought to not need a test for now).

%!test
%!   X=[1  1  1
%!      2  3  4
%!      11 17 13
%!      18 3  5]
%!
%!   y = [3
%!        5
%!        20
%!        9]
%!
%!   % make sure it's a valid regression problem.
%!   assert(rank(X), columns(X));
%!
%!   % calculate the expected estimator, estimation and error
%!   expected_w = pinv(X)*y
%!   expected_Xw = X*expected_w
%!   expected_l2error = norm(expected_Xw - y, 2)^2
%!
%!   % run the utility function
%!   [w, Xw, l2error] = linear_regression(X, y)
%!
%!   % test vs expectation while allow small numerical errors.
%!   assert(norm(w - expected_w) < 0.001)
%!   assert(norm(Xw - expected_Xw) < 0.001)
%!   assert(abs(l2error - expected_l2error) < 0.001)

