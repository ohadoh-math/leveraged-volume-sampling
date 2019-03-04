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
          ] = handle_dataset(dataset_name, dataset_file, output_file, sampling_count, sample_sizes)
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

    lss_sl2errors = [];
    lss_sl2errors_avg = [];
    lss_sl2errors_std = [];
    lss_solutions = [];

    vss_sl2errors = [];
    vss_sl2errors_avg = [];
    vss_sl2errors_std = [];
    vss_solutions = [];

    lvss_sl2errors = [];
    lvss_sl2errors_avg = [];
    lvss_sl2errors_std = [];
    lvss_solutions = [];

    optimal_error = optimal_l2error * ones(size(sample_sizes));

    info_trace ("proceeding to sample via LSS, VSS and LVSS for %i tries each", sampling_count)
    for sample_sz = sample_sizes
        info_trace("\t%s: LSS(k=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X))
        [sw, sXw, sl2error, sl2error_avg, sl2error_std, solutions] = leverage_score_sampling(X, y, sample_sz, sampling_count);

        info_trace("%s: LSS(k=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f]\n",
                   dataset_name, sample_sz, sampling_count, rows(X), columns(X),
                   sl2error, optimal_l2error, sl2error_avg, sl2error_std);
        lss_sl2errors = [lss_sl2errors sl2error];
        lss_sl2errors_avg = [lss_sl2errors_avg sl2error_avg];
        lss_sl2errors_std = [lss_sl2errors_std sl2error_std];
        solutions = [sample_sz*ones(1, columns(solutions)); solutions];
        lss_solutions = [lss_solutions solutions];

        info_trace("\t%s: VSS(s=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X));
        [sw, sXw, sl2error, sl2error_avg, sl2error_std, solutions] = volume_sampling(X, y, sample_sz, sampling_count);
        info_trace("%s: VSS(s=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f]\n",
                   dataset_name, sample_sz, sampling_count, rows(X), columns(X),
                   sl2error, optimal_l2error, sl2error_avg, sl2error_std);
        vss_sl2errors = [vss_sl2errors sl2error];
        vss_sl2errors_avg = [vss_sl2errors_avg sl2error_avg];
        vss_sl2errors_std = [vss_sl2errors_std sl2error_std];
        solutions = [sample_sz*ones(1, columns(solutions)); solutions];
        vss_solutions = [vss_solutions solutions];

        info_trace("\t%s: LVSS(k=%i, times=%i, n=%i, d=%i)", dataset_name, sample_sz, sampling_count, rows(X), columns(X));
        [sw, sXw, sl2error, sl2error_avg, sl2error_std, solutions] = leveraged_volume_sampling(X, y, sample_sz, sampling_count);
        info_trace("%s: LVSS(s=%i, times=%i, n=%i, d=%i): sl2error=%f, ol2error=%f, sl2error_avg=%f[%f]\n",
                   dataset_name, sample_sz, sampling_count, rows(X), columns(X),
                   sl2error, optimal_l2error, sl2error_avg, sl2error_std);
        lvss_sl2errors = [lvss_sl2errors sl2error];
        lvss_sl2errors_avg = [lvss_sl2errors_avg sl2error_avg];
        lvss_sl2errors_std = [lvss_sl2errors_std sl2error_std];
        solutions = [sample_sz*ones(1, columns(solutions)); solutions];
        lvss_solutions = [lvss_solutions solutions];
    end

    info_trace("finished regressions - plotting results to %s", output_file);

    graph_handle = figure();

    min_x = min(sample_sizes);
    max_x = max(sample_sizes);
    min_y = 0.98*min([lss_sl2errors_avg vss_sl2errors_avg lvss_sl2errors_avg optimal_error]);
    max_y = 1.02*max([lss_sl2errors_avg vss_sl2errors_avg lvss_sl2errors_avg optimal_error]);
    axis([min_x max_x min_y max_y]);

    plot (sample_sizes, lss_sl2errors_avg, "-.xr;Leverage Scores Sampling;",
          sample_sizes, vss_sl2errors_avg, "--xb;Volume Sampling;",
          sample_sizes, lvss_sl2errors_avg, "-xg;Leveraged Volume Sampling;",
          sample_sizes, optimal_error, "-.k;Full Regression;")

    print(graph_handle, output_file, "-dpng");

    save(strcat(output_file, ".octave"), "sample_sizes", "lss_sl2errors", "vss_sl2errors", "lvss_sl2errors", "optimal_error", "lss_solutions", "vss_solutions", "lvss_solutions");

    info_trace("done plotting!");

endfunction

function _main
    datasets = argv()'; % transpose argv for convenience during iterations.
    argc = length(datasets);

    global script_file;

    % check that there's at least:
    %   1. dataset file
    %   2. output file
    %   3. at least one sample size
    if argc < 3
        printf (["usage: %s DATASET-FILE OUTPUT-FILE SAMPLE-SIZE[...]\n" ...
                 "       Performs linear regression on a dataset via multiple sampling algorithms.\n" ...
                 "       Generates a graph and saves it in PNG format.\n" ...
                 "       * DATASET-FILE - the file holding the dataset. first column is assumed to be labels\n" ...
                 "                        and the remaining columns are assumed to be features." ...
                 "       * OUTPUT-FILE - the file to save the graph to." ...
                 "       * SAMPLE-SIZE - a list of integers or comma-separated integers that indicate how many" ...
                 "                       lines to sub-sample from the regression problem when using the various algorithms."],
                    script_file);

        exit (0);
    endif

    dataset_file = argv{1};
    output_file = argv{2};

    % parse the sample sizes
    sample_sizes = [];
    for i=3:argc
        separated_arg = strsplit(argv{i}, ",");
        for j=1:length(separated_arg)
            size_arg = separated_arg{j};

            if length(findstr(size_arg, ":")) > 0
                range_args = strsplit(size_arg, ":");

                if length(range_args) > 3
                    error("invalid range argument '%s'", size_arg)
                endif

                range_start = floor(str2double(range_args{1}));
                range_end = floor(str2double(range_args{end}));
                if length(range_args) == 3
                    step = floor(str2double(range_args{2}));
                else
                    step = 1;
                endif

                sample_sizes = [sample_sizes range_start:step:range_end];
            else
                _sample_size = str2double(size_arg);
                if isnan(_sample_size)
                    error("invalid size '%s'", size_arg)
                else
                    sample_sizes = [sample_sizes floor(_sample_size)];
                endif
            endif
        endfor
    endfor

    sample_sizes = sort(unique(sample_sizes));

    % sadly, that's the most convenient way i know to pass arguments to an Octave script.
    % there doesn't seem to be something like python's `argparse` or `getopts`.
    sampling_count = str2double(getenv("SAMPLING_COUNT"));
    if isnan(sampling_count) || sampling_count <= 0
        sampling_count = 100;
    endif

    % extract just the file name from the data set file (that's the data set's name)
    [s, e, te, matches, t, nm, sp] = regexp(dataset_file, "([^/])+$");
    dataset_name = matches{1};

    handle_dataset(dataset_name, dataset_file, output_file, sampling_count, sample_sizes);
endfunction

% execute `main()` on entry
_main

