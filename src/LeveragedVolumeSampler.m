% This class samples rows from a matrix according to "determinantal rejection sampling" as
% specified in "Leveraged volume sampling for linear regression".

classdef LeveragedVolumeSampler < handle

    properties
        % the matrix to sample
        _X = []
        % the expected output vector
        _y = []
        % the fast volume sampler used for the first sampling
        _leverage_scores_distribution = []
        _leverage_scores_sampler = []
        % the number of columns of X
        _d = 0
        % the number of rows of X
        _n = 0
        % the number of rows to sample from X
        _k = 0
        % the number of rows to sample with leverage score sampling
        _s = 0
        % det(X'*X)
        _total_volume = 0
    endproperties

    methods
        % constructor - basic setup and preliminary calculations.
        function self = LeveragedVolumeSampler(X, y, k)
            % make sure all the dimensions add up
            d = columns(X);
            if k < d
                error("you can't sub-sample a number of rows which is less than the number of columns (s=%i, d=%i)", s, d)
            elseif d > rows(X)
                error("you can't sub-sample a wide matrix.")
            endif

            self._X = X;
            self._y = y;
            self._d = columns(X);
            self._n = rows(X);
            self._k = k;

            self._s = max(k, 4*(d^2));
            self._total_volume = det(X'*X);

            self._leverage_scores_distribution = LeverageScoreDistribution(X);
            self._leverage_scores_sampler = LeverageScoresSampler(X, y);
        endfunction

        % poll_rows - sample `k` row incidices from X with probability proportional to rescaled volume.
        function polled_rows = poll_rows(self)
            % first, poll `s` rows according to volume sampling and accept them in proportion
            % to their volume change.

            do
                [polled_rows, scores] = self._leverage_scores_distribution.poll(self._s);

                Q = diag(1./sqrt(scores));
                _sX = Q*self._X(polled_rows, :);
                _sy = Q*self._y(polled_rows, :);
            until rand() < det((_sX'*_sX)/self._s)/self._total_volume

            % now do regular volume sampling on the polled rows
            if self._k < self._s
                volume_sampler = VolumeSampler(_sX, _sy, self._k);
                volume_polled_rows = volume_sampler.poll_rows();

                % adjust to the original matrix row indices
                polled_rows = arrayfun(@(vol_polled_i) polled_rows(1, vol_polled_i), volume_polled_rows);
            endif
        endfunction

        % sub_sample - sample `k` rows from X with probability proportional to rescaled volume.
        function [sX, sy] = sub_sample(self)
            polled_rows = self.poll_rows();
            sX = self._X(polled_rows, :);
            sy = self._y(polled_rows, :);
        endfunction
    endmethods

endclassdef

% these tests are adjusted from VolumeSampler.
% they calculate the expected probabilities for all sub-matrices and then sample X via
% LeverageScoresSampler() a large number of times and compares the distribution.

% k < 4*d^2 test
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
%!  d = columns(X);
%!  k = 2*d;
%!  assert (k < 4*d^2); % make sure this test is valid
%!
%!  % we'll generate all possible `k` line selections from `X` using nchoosek() and store them in a matrix.
%!  sub_matrices = nchoosek(1:n, k);
%!
%!  % now, we can calculate the index of a sub matrix sample in sub_matrices but the formula is ugly.
%!  % we'll just cache everything in a really big wasteful vector.
%!  index_cache = zeros(1, (n+1)^k); % k+1 is wasteful but screw it, this is a test
%!  index_cache_factor = (n+1).^(0:(k-1))'
%!  for i=1:rows(sub_matrices)
%!      row = sort(sub_matrices(i, :));
%!      index_cache(1, row * index_cache_factor) = i;
%!  endfor
%!  get_sample_row = @(sample) index_cache(1, sort(sample) * index_cache_factor);
%!
%!  % calculate the expected probability of every line combination.
%!  inv_XtX = inv(X'*X);
%!  leverage_scores_dist = arrayfun(@(i) X(i,:)*inv_XtX*(X(i,:)')/d, 1:rows(X));
%!  leverage_scores_q = 1./sqrt(leverage_scores_dist);
%!  volume = @(A) det(A'*A);
%!  sub_leveraged_volume = @(rows) volume(diag(leverage_scores_q(1, rows))*X(rows,:)) * prod(leverage_scores_dist(1, rows));
%!  expected_dist = zeros(1, rows(sub_matrices));
%!  expected_dist = arrayfun(@(row) sub_leveraged_volume(sub_matrices(row, :)), 1:rows(sub_matrices));
%!  expected_dist /= sum(expected_dist);
%!
%!  % now poll the bastard
%!  sampler = LeveragedVolumeSampler(X, y, k);
%!  polled_dist = zeros(1, rows(sub_matrices));
%!
%!  printf("sampled 0 (0%%) times (0 seconds)...");
%!  begin = time();
%!  fflush(stdout());
%!  for i=1:sampling_count
%!      before = columns(index_cache)
%!      sample = sampler.poll_rows()
%!      supposed_place = sort(sample) * index_cache_factor
%!      _row_index = get_sample_row(sample)
%!      after = columns(index_cache)
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

% k >= 4*d^2 test
%test
%  n = 18; % so n > s = 4*d^2 + 1
%  sampling_count = 50000;
%
%  % since this sampling requires a lot of tries (as there are many sub-matrices)
%  % and i've empirically seen that the l1/l2 norms seem to slowly decrease with
%  % sampling count i'm going to set the acceptable loss at around 7% of the l1 norm
%  % for this test.
%  % all in all the sampling seems fine but since there are many possible sub matrices
%  % convergence to the expected distribution seems slow.
%  acceptable_loss_percent = 0.07;
%
%  X = [ones(n, 1) (1:n)'];
%  y = (1337:(1337+n-1))'; % meaningless for this test
%  d = columns(X);
%  k = 4*(d^2) + 1;
%  assert (k < n); % make sure this test is valid
%
%  % we'll generate all possible `k` line selections from `X` using nchoosek() and store them in a matrix.
%  sub_matrices = nchoosek(1:n, k);
%
%  % now, we can calculate the index of a sub matrix sample in sub_matrices but the formula is ugly.
%  % we'll just cache everything in a really big wasteful vector.
%  index_cache = zeros(1, (n+1)^k); % k+1 is wasteful but screw it, this is a test
%  index_cache_factor = (n+1).^(0:(k-1))';
%  for i=1:rows(sub_matrices)
%      row = sort(sub_matrices(i, :));
%      index_cache(1, row * index_cache_factor) = i;
%  endfor
%  get_sample_row = @(sample) index_cache(1, sort(sample) * index_cache_factor);
%
%  % calculate the expected probability of every line combination.
%  inv_XtX = inv(X'*X);
%  leverage_scores_dist = arrayfun(@(i) X(i,:)*inv_XtX*(X(i,:)')/d, 1:rows(X));
%  leverage_scores_q = 1./sqrt(leverage_scores_dist);
%  volume = @(A) det(A'*A);
%  sub_leveraged_volume = @(rows) volume(diag(leverage_scores_q(1, rows))*X(rows,:)) * prod(leverage_scores_dist(1, rows));
%  expected_dist = zeros(1, rows(sub_matrices));
%  expected_dist = arrayfun(@(row) sub_leveraged_volume(sub_matrices(row, :)), 1:rows(sub_matrices));
%  expected_dist /= sum(expected_dist);
%
%  % now poll the bastard
%  sampler = LeveragedVolumeSampler(X, y, k);
%  polled_dist = zeros(1, rows(sub_matrices));
%
%  printf("sampled 0 (0%%) times (0 seconds)...");
%  begin = time();
%  fflush(stdout());
%  for i=1:sampling_count
%      sample = sampler.poll_rows();
%      polled_dist(1, get_sample_row(sample)) += 1;
%
%      % this takes some time so print the progress
%      if mod(i, 10) == 0
%          printf("\rsampled %i (%i%%) times (%i seconds)...", i, floor((100*i)/sampling_count), floor(time()-begin));
%          fflush(stdout());
%      endif
%  endfor
%
%  % finish with that progress statement
%  printf("\n");
%
%  % now normalize everything
%  polled_dist /= sum(polled_dist);
%
%  % l1 norm makes more sense to me when talking about distribution vectors.
%  [expected_dist' polled_dist']
%  polled_dist_norm1 = norm(polled_dist, 1)
%  expected_dist_norm1 = norm(expected_dist, 1)
%  difference_norm = norm(polled_dist - expected_dist, 1)
%  maximum_allowed_deviation = acceptable_loss_percent * norm(expected_dist, 1)
%  assert(difference_norm <= maximum_allowed_deviation);
%
