% This file implements leverage score sampling.
% The function accepts a feature matrix `X`, expected values `y` and sample size `k`.
% The function also accepts the number of times to repeat the process with the argument `times`.
% Returns the following:
%   * The averaged least-squares optimal fitting solution for the subsampled matrix (sw).
%   * The averaged estimated values (sXw=X*sw).
%   * The averaged least-squares error (|sXw - y|^2).
%   * The standard deviation of the least-squares error (|sXw - y|^2).

function [sw, sXw, sl2error, sl2error_avg, sl2error_std]=leverage_score_sampling(X, y, k, times=1)
    n = rows(X);
    sw = zeros(columns(X), 1);
    sXw = zeros(rows(X), 1);
    sl2error = 0;
    sl2error_avg = 0;
    sl2error_std = 0;

    info_trace("initializing leverage score sampler (calculating leverage scores) for %ix%i matrix", rows(X), columns(X))
    sl2errors = [];
    leverage_score_sampler = LeverageScoreDistribution(X, y);
    info_trace("sampler initialized!")

    for t=1:times
        info_trace("sampling iteration %i", t);
        % sample a subset of the rows via leverage score sampling
        [sX, sy] = leverage_score_sampler.sub_sample(k);

        % regress
        [_sw, _sXw, _sl2error, regression_time] = linear_regression(sX, sy);

        % calculate the actual estimation (_sXw and _sl2error are irrelevant as they represent a sub-sampled problem)
        _sXw = X*_sw;
        _sl2error = (norm(_sXw - y, 2)^2)/n;

        % add data to the statistics
        sw += _sw;
        sl2errors(t,1) = _sl2error;
    endfor
    info_trace("done sampling")

    sw = sw/times;
    sXw = X*sw;
    sl2error = (norm(sXw - y, 2)^2)/n;

    sl2error_avg = mean(sl2errors);
    sl2error_std = std(sl2errors);

endfunction

