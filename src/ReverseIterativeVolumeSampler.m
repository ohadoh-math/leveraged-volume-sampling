% This class implements reverse iterative volume sampling of a matrix `X`.
% The algorithm is taken from "Unbiased estimates for linear regression via volume sampling" (page 8).
% Note that in the paper `X` is a wide matrix (d-by-n) and in this program it is n-by-d so we should
% switch the terminology between `X` and `X'` in the paper.

classdef ReverseIterativeVolumeSampler < handle

    properties
        % the matrix to poll
        _X = []
        % the number of rows in _X
        _n = 0
        % the matrix specified as `Z` in the algorithm.
        _Z = []
        % the number of lines to poll
        _s = 0
        % the inital probabilities for polling
        _initial_p = []
    endproperties

    methods
        % constructor - do basic sanity checks and calculate `Z` and the inital sampling probabilities and.
        function self = ReverseIterativeVolumeSampler(X, s)
            if columns(X) > rows(X)
                error ("X must be a long matrix (more rows than columns)")
            elseif s < columns(X)
                error ("volume sampling requires sampling at least the number of columns from a long matrix (s=%i < %i=columns)", s, columns(X))
            endif

            self._X = X;
            self._s = s;
            self._n = rows(X);

            % `Z` and the inital probabilities are given in a straight-forward manner in the algorithm
            self._Z = inv(X'*X);
            self._initial_p = arrayfun(@(i) 1 - X(i,:)*self._Z*(X(i,:)'), 1:rows(X));
        endfunction

        % poll - poll `s` rows from `X` with probability proportional to det(Xs'*Xs).
        function polled_rows = poll_rows(self)
            polled_rows = 1:self._n;

            % recurringly remove rows from X
            probabilities = self._initial_p;
            Z = self._Z;

            while columns(polled_rows) > self._s
                % pick a row to remove
                multinomial_sampler = MultinomialDistribution(1:columns(polled_rows), probabilities);
                removed_row_index = multinomial_sampler.poll(1);

                % remove the row and adjust the probabilities set
                p = probabilities(1, removed_row_index);
                removed_row = polled_rows(1, removed_row_index); % the row in X corresponding to the polled index

                polled_rows(removed_row_index) = [];
                probabilities(removed_row_index) = [];

                x = self._X(removed_row,:)';
                v = Z*x/sqrt(p);

                for j=1:columns(probabilities)
                    row_index = polled_rows(1, j);
                    probabilities(1, j) -= (self._X(row_index, :) * v)^2;
                endfor

                Z += v*v';
            endwhile
        endfunction

        % sub_sample - sub-samples `s` lines from `X` with probability proportional to det(Xs'*Xs)
        function sX = sub_sample(self)
            sX = self._X(self.poll_rows(), :);
        endfunction
    endmethods

endclassdef

% we'll test this class be sampling a hard coded matrix 1000 times and making sure the
% probability distribution of the polled matrices roughly approximates their volumes.

%!test
%!  n = 8;
%!  s = 3;
%!  sampling_count = 50000;
%!
%!  % since this sampling requires a lot of tries (as there are many sub-matrices)
%!  % and i've empirically seen that the l1/l2 norms seem to slowly decrease with
%!  % sampling count i'm going to set the acceptable loss at around 7% of the l1 norm
%!  % for this test.
%!  % all in all the sampling seems fine but since there are many possible sub matrices
%!  % convergence to the expected distribution seems slow.
%!  acceptable_loss_percent = 0.07;
%!
%!  X = [ones(n, 1) (1:n)'];
%!
%!  % we'll generate all possible `s` line selections from `X` using nchoosek() and store them in a matrix.
%!  sub_matrices = nchoosek(1:n, s);
%!
%!  % now, we can calculate the index of a sub matrix sample in sub_matrices but the formula is ugly.
%!  % we'll just cache everything in a really big wasteful vector.
%!  index_cache = zeros(1, (n+1)^s); % s+1 is wasteful but screw it, this is a test
%!  index_cache_factor = (n+1).^(0:(s-1))';
%!  for i=1:rows(sub_matrices)
%!      row = sort(sub_matrices(i, :));
%!      index_cache(1, row * index_cache_factor) = i;
%!  endfor
%!  get_sample_row = @(sample) index_cache(1, sort(sample) * index_cache_factor);
%!
%!  % calculate the expected probability of every line combination.
%!  volume = @(A) det(A'*A);
%!  sub_volume = @(rows) volume(X(rows,:));
%!  expected_dist = zeros(1, rows(sub_matrices));
%!  expected_dist = arrayfun(@(row) sub_volume(sub_matrices(row, :)), 1:rows(sub_matrices));
%!  expected_dist /= sum(expected_dist);
%!
%!  % now poll the bastard
%!  sampler = ReverseIterativeVolumeSampler(X, s);
%!  polled_dist = zeros(1, rows(sub_matrices));
%!
%!  printf("sampled 0 (0%%) times...");
%!  fflush(stdout());
%!  for i=1:sampling_count
%!      sample = sampler.poll_rows();
%!      polled_dist(1, get_sample_row(sample)) += 1;
%!
%!      % this takes some time so print the progress
%!      if mod(i, 10) == 0
%!          printf("\rsampled %i (%i%%) times...", i, floor((100*i)/sampling_count));
%!          fflush(stdout());
%!      endif
%!  endfor
%!
%!  % finish with that progress statement
%!  printf("\n");
%!
%!  % now normalize everything
%!  polled_dist /= sum(polled_dist);
%!
%!  % l1 norm makes more sense to me when talking about distribution vectors.
%!  [expected_dist' polled_dist']
%!  polled_dist_norm1 = norm(polled_dist, 1)
%!  expected_dist_norm1 = norm(expected_dist, 1)
%!  difference_norm = norm(polled_dist - expected_dist, 1)
%!  maximum_allowed_deviation = acceptable_loss_percent * norm(expected_dist, 1)
%!  assert(difference_norm <= maximum_allowed_deviation);
%!

