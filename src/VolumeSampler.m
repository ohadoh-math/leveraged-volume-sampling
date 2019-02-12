% This class ties together FastVolumeSampler.m and ReverseIterativeVolumeSampler.m
% into a generic volume sampler that performs as fast as possible.
% The procedure used here is proposed in "Subsampling for Ridge Regression via Regularized
% Volume Sampling".

classdef VolumeSampler < handle

    properties
        % the matrix to sample
        _X = []
        % the expected output vector
        _y = []
        % the fast volume sampler used for the first sampling
        _fast_sampler = []
        % the number of columns in X
        _d = 0
        % the number of rows to sample from X
        _s = 0
    endproperties

    methods
        % constructor - basic initialization.
        function self = VolumeSampler(X, y, s)
            d = columns(X);
            if s < d
                error("you can't sub-sample a number of rows which is less than the number of columns (s=%i, d=%i)", s, d)
            elseif d > rows(X)
                error("you can't sub-sample a wide matrix.")
            endif

            self._d = d;
            self._s = s;
            self._X = X;
            self._y = y;
            self._fast_sampler = FastVolumeSampler(X, y, max(2*d, s));
        endfunction

        % poll_rows - sub-sample `s` row indices from `X` with probability proportional to det(Xs'*Xs)
        function polled_rows = poll_rows(self)
            polled_rows = self._fast_sampler.poll_rows();

            if self._s < 2 * self._d
                sampler = ReverseIterativeVolumeSampler(self._X(polled_rows,:), self._y(polled_rows,:), self._s);
                second_polling_results = sampler.poll_rows();

                polled_rows = arrayfun(@(i) polled_rows(1, i), second_polling_results);
            endif
        endfunction

        % sub_sample - sub-sample `s` lines from `X` with probability proportional to det(Xs'*Xs)
        function [sX, sy] = sub_sample(self)
            % sometimes when polling numerical errors can cause negative probabilities to show
            % up in ReverseIterativeVolumeSampler and an error is raised so we'll just sub-sample
            % in a loop until a successful sampling is found.

            polled_rows = self.poll_rows();

            sX = self._X(polled_rows, :);
            sy = self._y(polled_rows, :);
        endfunction
    endmethods

endclassdef

% This class should basically pass 2 tests - one for when s >= 2*d and one for s < 2*d.
% These tests are taken from FastVolumeSampler.m and ReverseIterativeVolumeSampler.m pretty much as-is.

% s >= 2*d test
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
%!  sampler = VolumeSampler(X, y, s);
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

% s < 2*d test
%!test
%!  n = 8;
%!  s = 3;
%!  sampling_count = 20000;
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
%!  sampler = VolumeSampler(X, y, s);
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
