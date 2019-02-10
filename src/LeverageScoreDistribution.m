% This file defines a utility class that allows you to poll row indices of a matrix
% `X` in proportion to the leverage scores.

classdef LeverageScoreDistribution < handle
    properties
        % a partitioning of [0,1] that we'll use to draw a random row
        % index with proportion to leverage scores.
        _partitioning = []
        % number of members in the partitioning
        _n = 0
        % the sum of the leverage scores (i.e. number of columns)
        _d = 0
    endproperties

    methods
        % constructor - calculate the leverage scores and set the partitioning.
        %               assume X to be of full column rank.
        function self = LeverageScoreDistribution(X)
            inv_XtX = inv(X' * X);
            calc_leverage_score = @(i) X(i,:) * inv_XtX * X(i,:)';

            self._n = rows(X);
            self._d = columns(X);

            % calculate the leverage scores and use them to partition [0, 1], and add an artificial 0 in the beginning.
            % we use the fact that the leverage scores sum to the number of columns in X (assuming X is of full rank)
            % to rescale the partitioning.
            self._partitioning = [0 cumsum(arrayfun(calc_leverage_score, 1:self._n))/self._d];
            % adjust for numerical errors. the leverage scores should sum to _d so this adjustment is miniscule.
            self._partitioning(1,end) = 1;
        endfunction

        % _poll - polls a single index from the rows of X with proportion to the leverage scores.
        function index = _single_poll(self)
            % first, draw a random number uniformly from (0, 1)
            r = rand();

            % now, use the interval where it lands with regards to self._partition to determine the index.
            % since the number is uniformly drawn then:
            %       P[index = i] =
            %           P[_partitioning(1, i) <= r <= _partitioning(1, i+1)] =
            %           measure((_partitioning(1, i), _partitioning(1, i+1))) =
            %           _partitioning(1, i+1) - _partitioning(1, i) =
            %           (the i'th leverage score)/_d.
            %
            % we'll use binary search to find where r landed.
            upper_bound = self._n + 1; % the index for 1.00
            lower_bound = 1;
            index = floor((upper_bound + lower_bound)/2);

            while upper_bound - lower_bound > 1
                if self._partitioning(1, index) > r
                    upper_bound = index;
                    index = floor((upper_bound + lower_bound)/2);
                elseif self._partitioning(1, index + 1) < r
                    lower_bound = index + 1;
                    index = floor((upper_bound + lower_bound)/2);
                else
                    return;
                endif
            endwhile

            index = lower_bound;
            return;
        endfunction

        % poll - polls `k` indices i.i.d (i.e. with replacement) from the matrix rows with proprotion to the leverage scores.
        function indices = poll(self, k)
            indices = arrayfun(@(v) self._single_poll(), zeros(1, k));
        endfunction
    endmethods
endclassdef

% We'll test this distribution by polling 10000 indices from it for a specific matrix
% and check that the values distribute roughly as expected.
% The test matrix will be:
% X =
%
%   1   4
%   2   3
%   3  -1
%   2   5
% 
% And it's normalized associated leverage scores are:
% diag(X*inv(X'*X)*X')/columns(X) =
%
%   0.16137
%   0.12878
%   0.46025
%   0.24960
%

%!test
%!  sample_size = 10000;
%!  X = [1 4; 2 3; 3 -1; 2 5];
%!
%!  % make sure the test matrix is of full rank
%!  assert(rank(X), columns(X));
%!
%!  n = rows(X);
%!  leverage_score_distribution = diag(X*inv(X'*X)*X')/columns(X)
%!
%!  distribution = LeverageScoreDistribution(X);
%!  polled_indices = distribution.poll(sample_size);
%!
%!  % assert that polled_indices is a row vector:
%!  assert(rows(polled_indices), 1);
%!  assert(columns(polled_indices), sample_size);
%!
%!  % assert that all the indices are integers between 1 and rows(X)
%!  assert(columns(setdiff(polled_indices, 1:n)), 0)
%!
%!  % assert that the distribution of indices is roughly as expected.
%!  % i'm going to be lenient and allow a 2% divergence in the norm.
%!  polled_distribution = arrayfun(@(i) sum(polled_indices == i), 1:n)'/sample_size
%!  assert(norm(polled_distribution - leverage_score_distribution) < 0.02)
%

