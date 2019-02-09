% A tracing utility function

function info_trace(msg, varargin)
    % write a simple message to stderr.

    persistent show_info_traces = getenv("TRACE_INFO");

    if show_info_traces
        msg = sprintf("info: [%s] %s\n", strftime('%a %b %d %H:%M:%S %Y',gmtime(time())), msg);
        fprintf(stderr(), msg, varargin{:});
    endif
endfunction

