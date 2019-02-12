% This class implements volume sampling of a matrix `X` via the FastRegVol as suggested by
% "Subsampling for Ridge Regression via Regularized Volume Sampling", though we're not going to
% regularize the sampling in any way.
% Note that as inReverseIterativeVolumeSampler.m, the paper's notation is that `X` is wide
% and so we change the roles of `X` and `X'`.

classdef FastVolumeSampler < handle

    properties
        % the matrix to poll
        _X = []
        % the expected output vector
        _y = []
        % the number of rows in _X
        _n = 0
        % the matrix specified as `Z` in the algorithm.
        _Z = []
        % the number of lines to poll
        _s = 0
    endproperties

    methods
        % constructor - do basic sanity checks and calculate `Z` as it appears in the paper.
        function self = FastVolumeSampler(X, y, s)
            if columns(X) > rows(X)
                error ("X must be a long matrix (more rows than columns)")
            elseif s < 2*columns(X)
                error ("fast volume sampling requires sampling at least double the number of columns from a long matrix (s=%i < %i=columns)", s, columns(X))
            endif
            
            self._X = X;
            self._y = y;
            self._s = s;
            self._n = rows(X);

            self._Z = inv(X'*X);
        endfunction

        % poll_rows - poll `s` rows from `X` with probability proportional to det(Xs'*Xs).
        function polled_rows = poll_rows(self)
            polled_rows = 1:self._n;
            Z = self._Z;

            % recurringly remove rows from X
            while columns(polled_rows) > self._s
                % pick a row uniformly and accept it with probability 1-X(i,:)*Z*X(i,:)'
                s = columns(polled_rows);
                index = 0;
                h = 0;
                row = [];
                do
                    index = randi(s);
                    row = self._X(polled_rows(1, index), :);
                    h = 1 - row*Z*(row');
                until rand() < h

                % remove the row and adjust the probabilities set
                polled_rows(index) = [];
                
                v = Z*(row');
                Z += (v*(v'))/h;
            endwhile
        endfunction

        % sub_sample - sub-samples `s` lines from `X` with probability proportional to det(Xs'*Xs)
        function [sX, sy] = sub_sample(self)
            polled_rows = self.poll_rows();
            sX = self._X(polled_rows, :);
            sy = self._y(polled_rows, :);
        endfunction
    endmethods

endclassdef

% this test is taken directly from ReverseIterativeVolumeSampler.m and only had
% it's `s` and `n` adjusted for fast volume sampling as `s` needs to be at least 2*`columns(X)`.

%!test
%!  n = 8;
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
%!  y = (1337:(1337+n-1))'; % meaningless for this test
%!  s = columns(X)*2 + 1;
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
%!  sampler = FastVolumeSampler(X, y, s);
%!  polled_dist = zeros(1, rows(sub_matrices));
%!
%!  printf("sampled 0 (0%%) times (0 seconds)...");
%!  begin = time();
%!  fflush(stdout());
%!  for i=1:sampling_count
%!      sample = sampler.poll_rows();
%!      polled_dist(1, get_sample_row(sample)) += 1;
%!
%!      % this takes some time so print the progress
%!      if mod(i, 10) == 0
%!          printf("\rsampled %i (%i%%) times (%i seconds)...", i, floor((100*i)/sampling_count), floor(time()-begin));
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
