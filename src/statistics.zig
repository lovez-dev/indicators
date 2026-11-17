const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub fn variance_into(input: []const f64, period: usize, output: []f64) Error!void {
    try validation.validate_period(period, input.len);
    try validation.require_output(output, input.len);
    @memset(output[0..input.len], 0.0);
    var sum: f64 = 0;
    var squares: f64 = 0;
    // Center values to reduce cancellation when prices have a large baseline.
    const origin = input[0];
    for (input, 0..) |v, i| {
        const value = v - origin;
        sum += value;
        squares += value * value;
        if (i >= period) {
            const old = input[i - period] - origin;
            sum -= old;
            squares -= old * old;
        }
        if (i + 1 >= period) {
            const mean = sum / @as(f64, @floatFromInt(period));
            output[i] = @max(0.0, squares / @as(f64, @floatFromInt(period)) - mean * mean);
        }
    }
}

pub fn variance(allocator: std.mem.Allocator, input: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try variance_into(input, period, out);
    return out;
}

pub fn std_dev_into(input: []const f64, period: usize, deviations: f64, output: []f64) Error!void {
    try variance_into(input, period, output);
    for (output[0..input.len]) |*v| v.* = @sqrt(v.*) * deviations;
}

pub fn std_dev(allocator: std.mem.Allocator, input: []const f64, period: usize, deviations: f64) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try std_dev_into(input, period, deviations, out);
    return out;
}
