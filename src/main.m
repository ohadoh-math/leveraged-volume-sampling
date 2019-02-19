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
    for sample_sz = [30] % sample_sizes
        info_trace("\t%s: LSS(k=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X))
        [sw, sXw, sl2error, sl2error_avg, sl2error_std, total_time] = naive_leverage_score_sampling(X, y, sample_sz, sampling_count);

        printf("%s: LSS(k=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f], time=%i secs\n",
               dataset_name, sample_sz, sampling_count, rows(X), columns(X),
               sl2error, optimal_l2error, sl2error_avg, sl2error_std,
               floor(total_time));

        info_trace("\t%s: VSS(s=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X));
        [sw, sXw, sl2error, sl2error_avg, sl2error_std] = volume_sampling(X, y, sample_sz, sampling_count);
        printf("%s: VSS(s=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f]\n",
               dataset_name, sample_sz, sampling_count, rows(X), columns(X),
               sl2error, optimal_l2error, sl2error_avg, sl2error_std);

        info_trace("\t%s: LVSS(k=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X));
        [sw, sXw, sl2error, sl2error_avg, sl2error_std] = leveraged_volume_sampling(X, y, sample_sz, sampling_count);
        printf("%s: LVSS(s=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f]\n",
               dataset_name, sample_sz, sampling_count, rows(X), columns(X),
               sl2error, optimal_l2error, sl2error_avg, sl2error_std);
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

    % sadly, that's the most convenient way i know to pass arguments to an Octave script.
    % there doesn't seem to be something like python's `argparse` or `getopts`.
    sampling_count = str2double(getenv("SAMPLING_COUNT"));
    if isnan(sampling_count) || sampling_count <= 0
        sampling_count = 100;
    endif

    % handle each dataset separately
    for dataset_file = datasets
        % extract just the file name from the data set file (that's the data set's name)
        [s, e, te, matches, t, nm, sp] = regexp(dataset_file{1}, "([^/])+$");
        dataset_name = matches{1};

        [optimal_l2error, regression_time] = handle_dataset(dataset_name, dataset_file{1}, sampling_count, [30 40 50 60 70]);

        printf ("%s\t%e\t%f\n", dataset_name, optimal_l2error, regression_time)
    endfor

endfunction

% execute `main()` on entry
_main

