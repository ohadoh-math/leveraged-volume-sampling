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

% should informational logs be printed?
global show_info_traces = getenv("TRACE_INFO");

function info_trace(msg, varargin)
    % write a simple message to stderr.

    global show_info_traces

    if show_info_traces
        msg = sprintf("info: [%s] %s\n", strftime('%a %b %d %H:%M:%S %Y',gmtime(time())), msg);
        fprintf(stderr(), msg, varargin{:});
    endif
endfunction

function [optimal_l2error, regression_time] = handle_dataset(dataset_file)
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

        [optimal_l2error, regression_time] = handle_dataset(dataset_file{1});

        printf ("%s\t%e\t%f\n", dataset_name, optimal_l2error, regression_time)
    endfor

endfunction

% execute `main()` on entry
_main

