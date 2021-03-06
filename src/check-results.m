#!/usr/bin/octave -fq

% this script loads the explicit results generated by main.m and calculates the average
% error, the standard deviation and the errors themselves.

% let Octave know this is not a function file (just write any word other than 'function').
1;

function process_solutions(X, y, solutions ,label)
    % sort the solutions into buckets by the sample size
    solutions_store = {};
    sample_sizes = [];

    for sample_size=sort(unique(solutions(1,:)))
        solutions_store{sample_size} = [];
        sample_sizes = [sample_sizes sample_size];
    endfor

    for i=1:columns(solutions)
        solution = solutions(:, i);
        solutions_store{solution(1,:)} = [solutions_store{solution(1,:)} solution(2:end,:)];
    endfor

    % now for each sample size calculate the losses and print their mean, std and errors
    for sample_size=sample_sizes
        solutions = solutions_store{sample_size};
        l2errors = arrayfun(@(i) (norm(X*solutions(:,i) - y, 2)^2)/rows(X), 1:columns(solutions));
        err_avg = mean(l2errors);
        err_std = std(l2errors);

        error_str = sprintf("%g ", l2errors);
        printf("%s: %i samples stats: average=%g, std=%g, errors=[ %s]\n", label, sample_size, err_avg, err_std, error_str);
    endfor

endfunction

function _main
    % read command line arguments: the dataset file and the octave state
    % file saved by the execution process
    dataset_file = argv{1};
    state_file = argv{2};

    % load the state file so we can access it's stored variables
    load(state_file);

    % load the dataset
    M = dlmread(dataset_file);
    X = M(:, 2:end);
    y = M(:, 1);

    % now process the solutions
    process_solutions(X, y, lss_solutions, "LSS");
    process_solutions(X, y, vss_solutions, "VSS");
    process_solutions(X, y, lvss_solutions, "LVSS");

endfunction

_main

