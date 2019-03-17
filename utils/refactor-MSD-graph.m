% the MSD graph was generated after rescaling X and y - which cause the error to be greatly reduced.
% this script loads the MSD saved state and generates a correct graph.

1;

function _main
    fprintf(stderr(), "loading dataset\n");
    M=dlmread("downloaded-datasets/YearPredictionMSD" );
    fprintf(stderr(), "dataset loaded\n");
    y=M(:,1);
    X=M(:,2:end);

    load("graphs/YearPredictionMSD.png.octave");

    errorfunc = @(v) (norm(y - X*v, 2)^2)/rows(X);

    lvss_errors = {};
    vss_errors = {};
    lss_errors = {};

    for sz=sample_sizes
        lvss_errors{sz} = [];
        vss_errors{sz} = [];
        lss_errors{sz} = [];
    endfor
    
    for i=1:columns(lvss_solutions)
        compound_solution = lvss_solutions(:,i);
        sample_size = compound_solution(1,1);
        solution = compound_solution(2:end,1);

        fprintf(stderr(), "evaluating solution of size %i\n", sample_size);

        lvss_errors{sample_size} = [lvss_errors{sample_size} errorfunc(solution)];

        compound_solution = vss_solutions(:,i);
        sample_size = compound_solution(1,1);
        solution = compound_solution(2:end,1);
        vss_errors{sample_size} = [vss_errors{sample_size} errorfunc(solution)];

        compound_solution = lss_solutions(:,i);
        sample_size = compound_solution(1,1);
        solution = compound_solution(2:end,1);
        lss_errors{sample_size} = [lss_errors{sample_size} errorfunc(solution)];
    endfor

    optimal_error = errorfunc(X\y)*ones(size(sample_sizes));

    fprintf(stderr(), "calculating mean LVSS errors\n");
    lvss_sl2errors_avg = arrayfun(@(sz) mean(lvss_errors{sz}), sample_sizes);
    fprintf(stderr(), "calculating mean VSS errors\n");
    vss_sl2errors_avg = arrayfun(@(sz) mean(vss_errors{sz}), sample_sizes);
    fprintf(stderr(), "calculating mean LSS errors\n");
    lss_sl2errors_avg = arrayfun(@(sz) mean(lss_errors{sz}), sample_sizes);
    
    fprintf(stderr(), "plotting\n");
    graph_handle = figure();

    min_x = min(sample_sizes);
    max_x = max(sample_sizes);
    min_y = 0.98*min([lss_sl2errors_avg vss_sl2errors_avg lvss_sl2errors_avg optimal_error]);
    max_y = 1.02*max([lss_sl2errors_avg vss_sl2errors_avg lvss_sl2errors_avg optimal_error]);
    axis([min_x max_x min_y max_y]);

    plot (sample_sizes, lss_sl2errors_avg, "-.xr;Leverage Scores Sampling;",
          sample_sizes, vss_sl2errors_avg, "--xb;Volume Sampling;",
          sample_sizes, lvss_sl2errors_avg, "-xg;Leveraged Volume Sampling;",
          sample_sizes, optimal_error, "-.k;Full Regression;")

    print(graph_handle, "graphs/YearPredictionMSD.fixed.png", "-dpng");

endfunction

_main
