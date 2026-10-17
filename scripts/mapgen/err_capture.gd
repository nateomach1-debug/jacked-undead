extends Logger
## TEMPORARY helper for map_gen_report.gd: collects engine error messages.

var lines: Array = []


func _log_error(function, file, line, code, rationale, editor_notify, error_type, script_backtraces) -> void:
    lines.append("%s:%s %s %s" % [str(file).get_file(), str(line), str(code), str(rationale)])


func _log_message(message, error) -> void:
    if error:
        lines.append(str(message))

# END OF FILE
