#!/usr/bin/octave -fq

% this script loads a dataset, augments it with columns of the square of it's features and writes
% the results back to the same dataset file.

% let Octave know this is not a function file (just write any word other than 'function').
1;

function _main
    dataset_file = argv{1};
    M = dlmread(dataset_file);
    dlmwrite(dataset_file, [M M(:,2:end).^2], " ");
endfunction

_main

