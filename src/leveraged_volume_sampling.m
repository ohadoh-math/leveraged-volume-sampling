% this function implements leveraged volume sampling regression.
% it utilizes the functionality implemented in LeveragedVolumeSampler.m.
% the function takes a matrix `X`, an expected output vector `y`, a sample size `k` and the number
% of times the algorithm should be run and averaged.
% The function then returns:
%   * The solution to a volume sub-sampled problem, averaged after `times` times.
%   * The estimator of the average solution.
%   * The l2 error of the average estimator.
%   * The average l2 error for each of the `times` runs.
%   * The standard deviation of the l2 error for each of the `times` runs.

function [sw, sXw, sl2error, sl2error_avg, sl2error_std] = leveraged_volume_sampling(X, y, k, times)
    info_trace("initializing leveraged volume sampler for %ix%i matrix", rows(X), columns(X))

    n = rows(X);
    sampler = LeveragedVolumeSampler(X, y, k);
    info_trace("sampler initialized")

    sw = zeros(columns(X), 1);
    sXw = zeros(rows(X), 1);
    sl2error = 0;
    sl2error_avg = 0;
    sl2error_std = 0;
    total_time = 0;
    sl2errors = [];

    for t = 1:times
        info_trace("LVSS iteration #%i", t);

        info_trace("\tsampling...");
        sampled_successfully = false;
        do
            try
                [_sX, _sy] = sampler.sub_sample();
                sampled_successfully = true;
            catch err
                fprintf(stderr(), "error while sub-sampling: %s\n", err.message)
            end_try_catch
        until sampled_successfully

        info_trace("\tregressing...");
        _sw = linear_regression(_sX, _sy);

        sw += _sw;

        _sl2error = (norm(X*_sw - y, 2)^2)/n;
        info_trace("\tsampled error for iteration %i: %f", t, _sl2error);
        sl2errors(1, t) = _sl2error;
    endfor

    info_trace("statistics...")
    sw /= times;
    sXw = X*sw;
    sl2error = (norm(sXw - y, 2)^2)/n;
    sl2error_avg = mean(sl2errors);
    sl2error_std = std(sl2errors);

    info_trace("done!")
endfunction
