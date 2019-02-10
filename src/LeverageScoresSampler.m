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
            sX = [];
            sy = [];

            % generating the sampling Q as specified in the paper, which is `n`-by-`n`, can take a lot of memory
            % (more than i can spare on the laptop i'm using when it comes to the MSD dataset where `n` is about 433k).
            % therefor we'll first see how many times each index in `polled_rows` is repeated and we'll sub-sample and
            % rescale accordingly.
            % admittedly, this may end up costing O(k^2) steps but that's better than holding a 433k-by-433k matrix.

            % get the number of uniquely polled indices
            uniq_polled_rows = unique([polled_rows' polled_scores'], "rows")
            % use hist() as a shortcut to getting the number of times each row was polled
            poll_counts = hist(polled_rows, uniq_polled_rows(:,1))

            % now compound the polled indices, polled scores and repeatition count into a single matrix and sub-sample X
            sub_sampling_info = [uniq_polled_rows poll_counts']
            for i = 1:rows(sub_sampling_info)
                sampled_row = sub_sampling_info(i,1);
                sampled_score = sub_sampling_info(i,2);
                count = sub_sampling_info(i, 3);

                rescale = count*(1/sqrt(sampled_score));
                sX(i,:) = rescale * self._X(sampled_row,:);
                sy(i,:) = rescale * self._y(sampled_row,:);
            endfor
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
% So `1` is repeated 3 times, `3` and `5` twice and `4` once.
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
%!  expected_sX = [X(1,:)*3*coefficients(1,1)
%!                 X(3,:)*2*coefficients(1,2)
%!                 X(4,:)*1*coefficients(1,end)
%!                 X(5,:)*2*coefficients(1,3)]
%!
%!  expected_sy = [y(1,:)*3*coefficients(1,1)
%!                 y(3,:)*2*coefficients(1,2)
%!                 y(4,:)*1*coefficients(1,end)
%!                 y(5,:)*2*coefficients(1,3)]
%!
%!   % now create the sampler and do the sampling.
%!   sampler = LeverageScoresSampler(X, y);
%!   [sX, sy] = sampler.sample(polled_indices, polled_scores)
%!
%!   % now check that we got what we expect, but tolerate small numerical errors (in the Frobenius norm).
%!   % tolerate at most 2% difference (picked this number out of thin air).
%!   assert(norm(expected_sX - sX, "fro") < 0.02*norm(expected_sX, "fro"));
%!   assert(norm(expected_sy - sy, 2) < 0.02*norm(expected_sy, 2));

