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
        % a volume sampler for the case where n < 4*d^2
        _default_volume_sampler = []
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

            if self._s >= self._n
                % diag returns a sparse matrix so we're fine with a large `n`
                Q = diag(1./sqrt(self._leverage_scores_distribution.leverage_scores_distribution()));
                self._default_volume_sampler = VolumeSampler(Q*X, Q*y, k);
            endif
        endfunction

        % poll_rows - sample `k` row incidices from X with probability proportional to rescaled volume.
        function [polled_rows, scores] = poll_rows(self)
            % make sure we can perform leveraged volume samling.
            % if s >= n there's no point in doing the rejection sampling.
            if self._n <= self._s
                polled_rows = self._default_volume_sampler.poll_rows();
                scores = self._leverage_scores_distribution.leverage_scores_distribution()(polled_rows, :);
                return;
            endif

            % first, poll `s` rows according to volume sampling and accept them in proportion
            % to their volume change.

            do
                [polled_rows, scores] = self._leverage_scores_distribution.poll(self._s);

                Q = diag(1./sqrt(scores));
                _sX = Q*self._X(polled_rows, :);
            until rand() < det((_sX'*_sX)/self._s)/self._total_volume

            % now do regular volume sampling on the polled rows
            if self._k < self._s
                _sy = Q*self._y(polled_rows, :);
                volume_sampler = VolumeSampler(_sX, _sy, self._k);
                volume_polled_rows = volume_sampler.poll_rows();

                % adjust to the original matrix row indices
                polled_rows = arrayfun(@(vol_polled_i) polled_rows(1, vol_polled_i), volume_polled_rows);
                leverage_scores = self._leverage_scores_distribution.leverage_scores_distribution();
                scores = arrayfun(@(row) leverage_scores(1, row), polled_rows);
            endif
        endfunction

        % sub_sample - sample `k` rows from X with probability proportional to rescaled volume.
        function [sX, sy] = sub_sample(self)
            [polled_rows, scores] = self.poll_rows();
            Q = 1./sqrt(diag(scores));
            sX = Q*self._X(polled_rows, :);
            sy = Q*self._y(polled_rows, :);
        endfunction
    endmethods

endclassdef

% testing this class is a bit tricky because usually i just generate all possible samples and
% calculate their expected probability, but for the case where k >= 4*d^2 even for the most
% benign value d=2 this means there are 16 features and therefor n >= 17.
% since leveraged volume sampling can choose with repetition this means pre-calculating the
% probabilities requires pre-calculating n^s/factorial(s) determinants (which can only be
% estimated even for 17). that's a bit unreasonable.
% for that reason the tests use d=1.
% it seems the error decreases *very* slowly and requires a huge number of trials to converge
% to the theoretical probabilities (probably due to the large number of sub-matrices).
% e.g. for the case where k >= 4*d^2 with d=1 and n=10, k=5 the error for 5000000 samples
% was about 11% (where it consistently decreased when i increased the samples count ten folds
% from 5K to 50K, 500K and 5M).
% finally, for 50M samples the error was 4.3% which is reasonable, but took (given no optimization)
% more than 9 hours to run.
% run these tests only if you have enough time, otherwise you'll not get to see the results.

%! k < 4*d^2, d=1
%!test
%!  n = 18;
%!  sampling_count = 50000;
%!
%!  acceptable_loss_percent = 0.07;
%!
%!  X = (1:n)';
%!  y = (1337:(1337+n-1))'; % meaningless for this test
%!  d = columns(X);
%!  k = 2*d;
%!  assert (d == 1); % make sure it's the test we want
%!  assert (k < 4*d^2); % make sure this test is valid
%!  assert (4*d^2 < n); % make sure we can even do the sampling
%!
%!  % calculate the expected probability of every line combination.
%!  % since n and d are small we can calculate all n^d submatrices and their expected distributions
%!  inv_XtX = inv(X'*X);
%!  leverage_scores_dist = arrayfun(@(i) X(i,:)*inv_XtX*(X(i,:)')/d, 1:rows(X));
%!  leverage_scores_q = 1./sqrt(leverage_scores_dist);
%!  volume = @(A) det(A'*A);
%!  sub_leveraged_volume = @(rows) volume(diag(leverage_scores_q(1, rows))*X(rows,:)) * prod(leverage_scores_dist(1, rows));
%!
%!  expected_dist = zeros((n+1)^k, 1); % there are redundant spots in this vector
%!  polled_dist = zeros((n+1)^k, 1); % there are redundant spots in this vector as well
%!  index_cache_factor = (n+1).^(0:(k-1))';
%!  get_sample_row = @(sample) sample * index_cache_factor;
%!
%!  % now go through all n^k sub-samples
%!  sub_matrices = (1:n)';
%!  for dimension=1:(k-1)
%!      basic_block = sub_matrices;
%!      size = rows(sub_matrices);
%!
%!      sub_matrices = [];
%!      for i=1:n
%!          sub_matrices = [sub_matrices; i*ones(size, 1) basic_block];
%!      endfor
%!  endfor
%!
%!  % and calculate the expected probability
%!  for row_index=1:rows(sub_matrices)
%!      row = sub_matrices(row_index, :);
%!      dist_row_index = get_sample_row(row);
%!      expected_dist(dist_row_index, 1) = sub_leveraged_volume(row);
%!  endfor
%!  expected_dist /= sum(expected_dist);
%!
%!  % now poll the bastard
%!  sampler = LeveragedVolumeSampler(X, y, k);
%!
%!  printf("sampled 0 (0%%)/%i times (0 seconds)...", sampling_count);
%!  begin = time();
%!  fflush(stdout());
%!  for i=1:sampling_count
%!      sample = sampler.poll_rows();
%!      sample_index = get_sample_row(sample);
%!      polled_dist(sample_index, 1) += 1;
%!
%!      % this takes some time so print the progress
%!      if mod(i, 10) == 0
%!          printf("\rsampled %i/%i (%i%%) times (%i seconds)...", i, sampling_count, floor((100*i)/sampling_count), floor(time()-begin));
%!          fflush(stdout());
%!      endif
%!  endfor
%!
%!  % finish with that progress statement
%!  printf("\n");
%!  printf("sampled %i matrices in %i seconds\n", sampling_count, floor(time() - begin));
%!
%!  % now normalize everything
%!  polled_dist /= sum(polled_dist)
%!
%!  % l1 norm makes more sense to me when talking about distribution vectors.
%!  expected_vs_polled = [expected_dist polled_dist]
%!  polled_dist_norm1 = norm(polled_dist, 1)
%!  expected_dist_norm1 = norm(expected_dist, 1)
%!  difference_norm = norm(polled_dist - expected_dist, 1)
%!  maximum_allowed_deviation = acceptable_loss_percent * norm(expected_dist, 1)
%!  assert(difference_norm <= maximum_allowed_deviation);
%!

% k >= 4*d^2, d=1
%!test
%!  n = 10;
%!  sampling_count = 10000000;
%!
%!  acceptable_loss_percent = 0.07;
%!
%!  X = (1:n)';
%!  y = (1337:(1337+n-1))'; % meaningless for this test
%!  d = columns(X);
%!  k = 4*d^2 + 1;
%!  assert (d == 1); % make sure it's the test we want
%!  assert (k >= 4*d^2); % make sure this test is valid
%!  assert (4*d^2 < n); % make sure we can even do the sampling
%!
%!  % calculate the expected probability of every line combination.
%!  % since n and d are small we can calculate all n^d submatrices and their expected distributions
%!  inv_XtX = inv(X'*X);
%!  leverage_scores_dist = arrayfun(@(i) X(i,:)*inv_XtX*(X(i,:)')/d, 1:rows(X));
%!  leverage_scores_q = 1./sqrt(leverage_scores_dist);
%!  volume = @(A) det(A'*A);
%!  sub_leveraged_volume = @(rows) volume(diag(leverage_scores_q(1, rows))*X(rows,:)) * prod(leverage_scores_dist(1, rows));
%!
%!  polled_dist = zeros((n+1)^k, 1); % there are redundant spots in this vector as well
%!  index_cache_factor = (n+1).^(0:(k-1))';
%!  get_sample_row = @(sample) sample * index_cache_factor;
%!
%!  % now go through all n^k sub-samples
%!  printf("generating all sub-matrices...\n");
%!  sub_matrices = (1:n)';
%!  for dimension=1:(k-1)
%!      basic_block = sub_matrices;
%!      size = rows(sub_matrices);
%!
%!      sub_matrices = [];
%!      for i=1:n
%!          sub_matrices = [sub_matrices; i*ones(size, 1) basic_block];
%!      endfor
%!  endfor
%!
%!  % since calculating things here suck and takes a lot of time we'll cache this one
%!  % so we can save a few minutes when running this test
%!  sub_matrices_cached=false;
%!  cache_file="/tmp/leveraged-volume-sampler-test-sub-matrices-cache";
%!  [info err msg] = stat(cache_file);
%!  if err == 0 && S_ISREG(info.mode)
%!      load(cache_file);
%!      sub_matrices_cached = exist("expected_dist");
%!  endif
%!
%!  % if the sub matrices probabilities aren't cached we should calculate them and
%!  % store them in the cache file
%!  if sub_matrices_cached
%!      printf("loaded sub-matrices from cache file %s\n", cache_file);
%!  else
%!      % and calculate the expected probability
%!      probabilities_calculated = 0;
%!      num_of_sub_matrices = rows(sub_matrices);
%!      begin = time();
%!      printf("calculated probabilities for 0/%i (0%%) matrices (0 seconds)", num_of_sub_matrices);
%!      fflush(stdout());
%!      expected_dist = zeros((n+1)^k, 1); % there are redundant spots in this vector
%!      for row_index=1:rows(sub_matrices)
%!          row = sub_matrices(row_index, :);
%!          dist_row_index = get_sample_row(row);
%!          expected_dist(dist_row_index, 1) = sub_leveraged_volume(row);
%!
%!          probabilities_calculated += 1;
%!          if mod(probabilities_calculated, 10) == 0
%!              printf("\rcalculated probabilities for %i/%i (%i%%) matrices (%i seconds)",
%!                     probabilities_calculated,
%!                     num_of_sub_matrices,
%!                     floor(100*probabilities_calculated/num_of_sub_matrices),
%!                     floor(time() - begin));
%!              fflush(stdout());
%!          endif
%!      endfor
%!      printf("\n");
%!
%!      expected_dist /= sum(expected_dist);
%!
%!      % save the calculated dist to a cache file
%!      printf("caching sub-matrices in %s\n", cache_file);
%!      save(cache_file, "expected_dist");
%!  endif
%!
%!
%!  % now poll the bastard
%!  sampler = LeveragedVolumeSampler(X, y, k);
%!
%!  printf("sampled 0 (0%%)/%i times (0 seconds)...", sampling_count);
%!  begin = time();
%!  fflush(stdout());
%!  for i=1:sampling_count
%!      sample = sampler.poll_rows();
%!      sample_index = get_sample_row(sample);
%!      polled_dist(sample_index, 1) += 1;
%!
%!      % this takes some time so print the progress
%!      if mod(i, 10) == 0
%!          printf("\rsampled %i/%i (%i%%) times (%i seconds)...", i, sampling_count, floor((100*i)/sampling_count), floor(time()-begin));
%!          fflush(stdout());
%!      endif
%!  endfor
%!
%!  % finish with that progress statement
%!  printf("\n");
%!  printf("sampled %i matrices in %i seconds\n", sampling_count, floor(time() - begin));
%!
%!  % now normalize everything
%!  polled_dist /= sum(polled_dist)
%!
%!  % l1 norm makes more sense to me when talking about distribution vectors.
%!  expected_vs_polled = [expected_dist polled_dist]
%!  polled_dist_norm1 = norm(polled_dist, 1)
%!  expected_dist_norm1 = norm(expected_dist, 1)
%!  difference_norm = norm(polled_dist - expected_dist, 1)
%!  maximum_allowed_deviation = acceptable_loss_percent * norm(expected_dist, 1)
%!  assert(difference_norm <= maximum_allowed_deviation);
%!

