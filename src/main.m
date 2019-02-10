#!/usr/bin/octave -fq

% The main program.
% Take a list of datasets, solve their associated regression problem with:
%   * Full linear regression.
%
% And print in tab-separated CSV format the results.

% let Octave know this is not a function file (just write any word other than 'function').
1;

% cache this script's file (should be outside of any function
% otherwise the function name is fetched).
global script_file = [mfilename("fullpathext")];

function [optimal_l2error, regression_time, ...
          lss_l2error, lss_l2error_std, lss_total_time ...
          ] = handle_dataset(dataset_name, dataset_file, sampling_count, sample_sizes)
    % this function processes a single dataset file.

    % load the dataset into Octave.
    % a dataset is a CSV file with a whitespace separator where the first column is the expected
    % regression output and the rest of the columns are the coefficient matrix.
    dataset = dlmread(dataset_file);
    y = dataset(:, 1);
    X = dataset(:, 2:end);

    % discard the reference to the loaded data as it can be huge and I have
    % no idea how Octave manages it's memory.
    dataset = NaN;

    % perform regression
    info_trace("performing full regression for %s ...", dataset_file);
    [optimal_w, optimal_Xw, optimal_l2error, regression_time] = linear_regression(X, y);

    info_trace("\tfinished full regression in %.4f seconds. optimal error is %f.",
               regression_time,
               optimal_l2error);

    % perform leverage score sampling (abbreviated "lss")
    info_trace("performing %d repetitions of leverage score sampling for %d sample sizes...", sampling_count, columns(sample_sizes));
    for sample_sz = sample_sizes
        info_trace("\t%s: LSS(k=%i, times=%i)", dataset_name, sample_sz, sampling_count)
        [sw, sXw, sl2error, sl2error_std, total_time] = naive_leverage_score_sampling(X, y, sample_sz, sampling_count);

        lss_error = norm(sw - optimal_w, 2);
        lss_error_p = 100*lss_error/norm(optimal_w, 2);
        lss_estimation_error = norm(sXw - optimal_Xw, 2);
        lss_estimation_error_p = 100*lss_estimation_error/norm(optimal_Xw, 2);

        printf("%s: LSS(k=%i, times=%i): sl2error=%f[%f], error=%f(%.5f%%), estimation error=%f(%.5f%%), time=%i secs\n",
               dataset_name, sample_sz, sampling_count,
               sl2error, sl2error_std,
               lss_error, lss_error_p, lss_estimation_error, lss_estimation_error_p,
               floor(total_time));
    end

endfunction

function _main
    datasets = argv()'; % transpose argv for convenience during iterations.
    argc = length(datasets);

    global script_file;

    % check that there's exactly at least one argument
    if argc == 0
        printf (["usage: %s DATASET-FILE[...]\n" ...
                 "       Performs linear regression on a dataset file and print the error and time information."],
                    script_file);

        exit (0);
    endif

    % handle each dataset separately
    for dataset_file = datasets
        % extract just the file name from the data set file (that's the data set's name)
        [s, e, te, matches, t, nm, sp] = regexp(dataset_file{1}, "([^/])+$");
        dataset_name = matches{1};

        [optimal_l2error, regression_time] = handle_dataset(dataset_name, dataset_file{1}, 100, [30 40 50 60 70]);

        printf ("%s\t%e\t%f\n", dataset_name, optimal_l2error, regression_time)
    endfor

endfunction

% execute `main()` on entry
_main

