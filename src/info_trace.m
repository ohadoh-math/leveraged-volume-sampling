% A tracing utility function

function info_trace(msg, varargin)
    % write a simple message to stderr.

    persistent show_info_traces = getenv("TRACE_INFO");
    persistent prefix = getenv("TRACE_PREFIX");

    if show_info_traces
        func_name = dbstack()(2).name;
        msg = sprintf("info: %s [%s] %s: %s\n", prefix, strftime('%a %b %d %H:%M:%S %Y',gmtime(time())), func_name, msg);
        fprintf(stderr(), msg, varargin{:});
    endif
endfunction

