% This file defines a utility class that allows you to poll a given set
% of numbers with specified probability for every number in a non-deterministic manner.
% The pre-processing done in the constructor is O(1) as it calculates the CDF but
% the polling is done with expectation n so this is useful for when you need to poll once
% from a distribution (as in volume sampling where the distribution changes with each iteration).

classdef MonteCarloMultinomialDistribution

    properties
        % the elements to poll.
        _elements = []
        % the probabilities vector.
        _probabilities = []
        % the number of elements.
        _n = 0
    endproperties

    methods
        % constructor - sanity checks and basic setup. done in O(1).
        function self = MonteCarloMultinomialDistribution(elements, probabilities)
            % make sure `elements` and `probabilities` are row vectors of the same length
            if rows(elements) != 1 || rows(probabilities) != 1
                error("`elements` and `probabilities` must be row vectors.")
            elseif columns(elements) != columns(probabilities)
                error("`elements` and `probabilities` must agree in dimensions (%i vs %i).", columns(elements), columns(probabilities))
            elseif any(probabilities < 0) || (! any(probabilities > 0))
                error("all probabilities must be non-negative and at least one must be positive.")
            endif

            self._elements = elements;
            self._probabilities = probabilities/sum(probabilities);
            self._n = columns(elements);
        endfunction

        % _poll_single - poll a single element from the multinomial distribution.
        %                polling is done with expectation n.
        function element = _poll_single(self)
            do
                index = randi(self._n);
            until rand() <= self._probabilities(1, index)

            element = self._elements(1, index);
        endfunction

        % poll - poll `k` elements i.i.d (i.e. with replacement) from the multinomial distribution.
        function elements = poll(self, k)
            elements = arrayfun(@(v) self._poll_single(), zeros(1, k));
        endfunction
    endmethods
endclassdef

% this test is takend as-is from LasVegasMultinomialDistribution.m
% with a simple substitution of the poller.
% since this polling method is slower when polling repeating elements we'll use
% a smaller sample size and a more graceful error of 5% for the test.

%!test
%!  elements = -(1:10);
%!  probabilities = 1:10;
%!  sample_size = 5000;
%!  acceptable_error_percent = 0.05;
%!
%!  % calculate the expected distribution.
%!  expected_dist = probabilities/sum(probabilities);
%!
%!  multinomial_dist = MonteCarloMultinomialDistribution(elements, probabilities);
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

