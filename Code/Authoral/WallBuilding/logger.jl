using Logging

logging_allowed = false
default_logger = global_logger()
hb_logger = ConsoleLogger(stdout, Logging.Info, meta_formatter=(level, _module, group, id, file, line) -> (:light_cyan, "Hummingbird: ", ""), show_limited=false)

function logging_on()
    global_logger(hb_logger)
    global logging_allowed = true
end

function logging_off()
    global_logger(default_logger)
    global logging_allowed = false
end

function log(message::String)
    if logging_allowed
        @info message
    end
end

function log(message::String; vars...)
    if logging_allowed
        if length(vars) > 0
            @info message vars...
        else
            @info message
        end
    end
end