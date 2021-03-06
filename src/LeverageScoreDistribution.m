% This file defines a utility class that allows you to poll row indices of a matrix
% `X` in proportion to the leverage scores.

classdef LeverageScoreDistribution < handle
    properties
        % the matrix to sub-sample
        _X = []
        % the labels vector to sub-sample
        _y = []
        % the raw re-scaled leverage scores
        _leverage_scores_pdf = []
        % number of members in the partitioning
        _n = 0
        % the sum of the leverage scores (i.e. number of columns)
        _d = 0
        % a multinomial distribution sampler
        _sampler = []
    endproperties

    methods
        % constructor - calculate the leverage scores and set the partitioning.
        %               assume X to be of full column rank.
        function self = LeverageScoreDistribution(X, y)
            self._X = X;
            self._y = y;

            inv_XtX = inv(X' * X);
            calc_leverage_score = @(i) X(i,:) * inv_XtX * X(i,:)';

            self._n = rows(X);
            self._d = columns(X);

            % calculate the scaled leverage scores.
            self._leverage_scores_pdf = arrayfun(calc_leverage_score, 1:self._n)/self._d;

            % create a multinomial sampler based on the leverage scores
            self._sampler = LasVegasMultinomialDistribution(1:self._n, self._leverage_scores_pdf);
        endfunction

        % leverage_scores - returns a copy of the calculated leverage scores distribution.
        function scores = leverage_scores_distribution(self)
            scores = self._leverage_scores_pdf;
        endfunction

        % poll - polls `k` indices i.i.d (i.e. with replacement) from the matrix rows with proprotion to the leverage scores.
        %        returns the associated levarage scores as well as the indices.
        function [indices, scores] = poll(self, k)
            indices = self._sampler.poll(k);
            scores = arrayfun(@(i) self._leverage_scores_pdf(1, i), indices);
        endfunction

        % sub_sample - sample the rows of X and y according to a given list of indices and rescale accordingly.
        %              no validation of the input row indices or leverage scores is done.
        %              `polled_rows` and `polled_scores` are assumed to be row vectors.
        function [sX, sy] = sub_sample(self, k)
            [polled_rows, polled_scores] = self.poll(k);

            rescaling_matrix = diag(1./sqrt(polled_scores));

            sX = rescaling_matrix * self._X(polled_rows, :);
            sy = rescaling_matrix * self._y(polled_rows, :);
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
%!  y = ones(rows(X), 1); % no real use
%!
%!  % make sure the test matrix is of full rank
%!  assert(rank(X), columns(X));
%!
%!  n = rows(X);
%!  leverage_score_distribution = diag(X*inv(X'*X)*X')/columns(X)
%!
%!  distribution = LeverageScoreDistribution(X, y);
%!
%!  % assert that the calculated leverage scores are as expected.
%!  % tolerate some numerical error.
%!  calculated_leverage_scores_dist = distribution.leverage_scores_distribution()'
%!  assert(norm(calculated_leverage_scores_dist - leverage_score_distribution) < 0.000001);
%!
%!  [polled_indices, polled_scores] = distribution.poll(sample_size);
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
%!  assert(norm(polled_distribution - leverage_score_distribution) < 0.02);
%!
%!  % assert that the returned scores vector is as expected
%!  expected_polled_scores = arrayfun(@(i) calculated_leverage_scores_dist(i,1), polled_indices);
%!  assert(expected_polled_scores, polled_scores);

