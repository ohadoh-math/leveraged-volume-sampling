% This file implements a utility class that, given polled indices and normalized leverages,
% returns a sub-sampled matrix as described in the leverage score sampling algorithm.

classdef LeverageScoresSampler < handle

    properties
        % the matrix to sub-sample
        _X = []
        % the expected output vector to sub-sample
        _y = []
    endproperties

    methods

        % constructor - cache the matrices in question.
        function self = LeverageScoresSampler(X, y)
            self._X = X;
            self._y = y;
        endfunction

        % sample - sample the rows of X and y according to a given list of indices and rescale accordingly.
        %          no validation of the input row indices or leverage scores is done.
        %          `polled_rows` and `polled_scores` are assumed to be row vectors.
        function [sX, sy]=sample(self, polled_rows, polled_scores)
            rescaling_matrix = diag(1./sqrt(polled_scores));

            sX = rescaling_matrix * self._X(polled_rows, :);
            sy = rescaling_matrix * self._y(polled_rows, :);
        endfunction

    endmethods

endclassdef

% Test the sampling procedure by passing a hard coded test matrix through it.
% The input `X` matrix is:
%
% X =
%
%    1    1
%    1    2
%    1    3
%    1    4
%    1    5
%    1    6
%    1    7
%    1    8
%    1    9
%    1   10
%
% The input `y` vector:
%
% y =
%
%   11
%   12
%   13
%   14
%   15
%   16
%   17
%   18
%   19
%   20
%
% The input polled inidices will be:
%
% polled_indices =
%
%    1   3   5   1   3   5   1   4
%
% And the polled leverage scores will be (arbitrarily chosen as the following):
%
% polled_indices/sum(polled_indices) =
%
%    0.043478   0.130435   0.217391   0.043478   0.130435   0.217391   0.043478   0.173913
%

%!test
%!   X = [ones(10,1) (1:10)']
%!   y = (11:20)'
%!   polled_indices = [1   3   5   1   3   5   1   4]
%!
%!   polled_scores = polled_indices/sum(polled_indices)
%!
%!   % calculate the expected output first.
%!   coefficients = 1./sqrt(polled_scores)
%!
%!  expected_sX = [X(1,:)*coefficients(1,1)
%!                 X(3,:)*coefficients(1,2)
%!                 X(5,:)*coefficients(1,3)
%!                 X(1,:)*coefficients(1,1)
%!                 X(3,:)*coefficients(1,2)
%!                 X(5,:)*coefficients(1,3)
%!                 X(1,:)*coefficients(1,1)
%!                 X(4,:)*coefficients(1,end)]
%!
%!  expected_sy = [y(1,:)*coefficients(1,1)
%!                 y(3,:)*coefficients(1,2)
%!                 y(5,:)*coefficients(1,3)
%!                 y(1,:)*coefficients(1,1)
%!                 y(3,:)*coefficients(1,2)
%!                 y(5,:)*coefficients(1,3)
%!                 y(1,:)*coefficients(1,1)
%!                 y(4,:)*coefficients(1,end)]
%!
%!   % now create the sampler and do the sampling.
%!   sampler = LeverageScoresSampler(X, y);
%!   [sX, sy] = sampler.sample(polled_indices, polled_scores)
%!
%!   % now check that we got what we expect, but tolerate small numerical errors (in the Frobenius norm).
%!   % tolerate at most 2% difference (picked this number out of thin air).
%!   assert(norm(expected_sX - sX, "fro") < 0.02*norm(expected_sX, "fro"));
%!   assert(norm(expected_sy - sy, 2) < 0.02*norm(expected_sy, 2));

