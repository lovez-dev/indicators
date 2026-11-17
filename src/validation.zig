pub const IndicatorError = error{ InvalidPeriod, InvalidInput, InsufficientData, OutputTooSmall, OutOfMemory };

pub fn validate_period(period: usize, length: usize) IndicatorError!void {
    if (period == 0) return error.InvalidPeriod;
    if (period > length) return error.InsufficientData;
}

/// A period of changes needs one additional source value as its starting point.
pub fn validate_changes(period: usize, length: usize) IndicatorError!void {
    try validate_period(period, length);
    if (period == length) return error.InsufficientData;
}

pub fn require_output(output: []f64, length: usize) IndicatorError!void {
    if (output.len < length) return error.OutputTooSmall;
}
