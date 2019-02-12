% This file defines a utility class that allows you to poll a given set
% of numbers with specified probability for every number in a deterministic manner.
% The pre-processing done in the constructor is O(n) as it calculates the CDF and
% the polling is done in O(log(n)) so this is useful for when you need to poll multiple
% times from the same distribution (as in leverage score sampling).

classdef LasVegasMultinomialDistribution < handle

    properties
        % the elements to poll.
        _elements = []
        % the cumulative density vector.
        _cdf = []
        % the number of elements.
        _n = 0
    endproperties

    methods
        % constructor - perform basic sanity checks and rescale input probabilities and calculate CDF.
        %               the preparations here are O(n) (calculate the CDF).
        function self = LasVegasMultinomialDistribution(elements, probabilities)
            % make sure `elements` and `probabilities` are row vectors of the same length
            if rows(elements) != 1 || rows(probabilities) != 1
                error("`elements` and `probabilities` must be row vectors.")
            elseif columns(elements) != columns(probabilities)
                error("`elements` and `probabilities` must agree in dimensions (%i vs %i).", columns(elements), columns(probabilities))
            elseif any(probabilities < 0) || (! any(probabilities > 0))
                error("all probabilities must be non-negative and at least one must be positive.")
            endif

            % clear any 0 probability elements from the list as they can be polled by this procedure
            % if the uniformly picked number hits them.
            % delete in reverse to keep i consistent.
            for i=columns(probabilities):-1:1
                if probabilities(1, i) == 0
                    probabilities(1, i) = [];
                    elements(1,i) = [];
                endif
            endfor

            self._elements = elements;
            self._n = columns(elements);

            % calculate the cumulative density function.
            % rescaling of the probabilities is done to fit them to [0, 1].
            self._cdf = [0 cumsum(probabilities)];
            self._cdf /= self._cdf(1, end);
            % now account for numeric errors that can screw us by chance
            self._cdf(1,end) = 1;
        endfunction

        % _poll_single - poll a single element from the multinomial distribution.
        %                polling is done in O(log(n)).
        function element = _poll_single(self)
            % first, draw a random number uniformly from (0, 1)
            r = rand();

            % now, use the interval where it lands with regards to self._cdf to determine the index.
            % since the number is uniformly drawn then:
            %       P[index = i] =
            %           P[_cdf(1, i) <= r <= _cdf(1, i+1)] =
            %           measure((_cdf(1, i), _cdf(1, i+1))) =
            %           _cdf(1, i+1) - _cdf(1, i) =
            %           the normalized i'th probability.
            %
            % we'll use binary search to find where r landed.
            upper_bound = self._n + 1; % the index for 1.00
            lower_bound = 1;
            index = floor((upper_bound + lower_bound)/2);

            while upper_bound - lower_bound > 1
                if self._cdf(1, index) > r
                    upper_bound = index;
                    index = floor((upper_bound + lower_bound)/2);
                elseif self._cdf(1, index + 1) < r
                    lower_bound = index + 1;
                    index = floor((upper_bound + lower_bound)/2);
                else
                    element = self._elements(1, index);
                    return;
                endif
            endwhile

            element = self._elements(1, lower_bound);
            return;
        endfunction

        % poll - poll `k` elements i.i.d (i.e. with replacement) from the multinomial distribution.
        function elements = poll(self, k)
            elements = arrayfun(@(v) self._poll_single(), zeros(1, k));
        endfunction
    endmethods

endclassdef

% test this distribution be sampling it 10000 times with an arbitrary distribution and
% seeing that the sampled distribution is similar to the expected distribution.

%!test
%!  elements = -(1:10);
%!  probabilities = 1:10;
%!  sample_size = 10000;
%!  acceptable_error_percent = 0.03;
%!
%!  % calculate the expected distribution.
%!  expected_dist = probabilities/sum(probabilities);
%!
%!  multinomial_dist = LasVegasMultinomialDistribution(elements, probabilities);
%!
%!  % sample `sample_size` elements and calculate the distribution
%!  polled_elements = multinomial_dist.poll(sample_size);
%!  polled_dist = arrayfun(@(elem) sum(polled_elements == elem), elements)/sample_size;
%!
%!  % make sure the distributions differ in at most 3% of the expected distribution.
%!  expected_vs_polled = [expected_dist' polled_dist'; norm(expected_dist, 1) norm(polled_dist, 1)]
%!  difference = expected_dist - polled_dist
%!  difference_norm_percent = norm(difference, 1)/norm(expected_dist, 1)
%!  assert(norm(polled_dist - expected_dist, 1) <= acceptable_error_percent*norm(expected_dist, 1))


