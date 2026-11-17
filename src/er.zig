const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub fn efficiency_ratio_into(input: []const f64, period: usize, output: []f64) Error!void {
    try validation.validate_changes(period, input.len);
    try validation.require_output(output, input.len);
    @memset(output[0..input.len], 0.0);
    // Keep the sum of absolute changes for the active period window.
    var movement: f64 = 0;
    for (input[1 .. period + 1], 1..) |value, i| movement += @abs(value - input[i - 1]);
    for (period..input.len) |i| {
        if (i > period) {
            movement -= @abs(input[i - period] - input[i - period - 1]);
            movement += @abs(input[i] - input[i - 1]);
        }
        const change = @abs(input[i] - input[i - period]);
        output[i] = if (movement == 0) 0 else change / movement;
    }
}

pub fn efficiency_ratio(allocator: std.mem.Allocator, input: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try efficiency_ratio_into(input, period, out);
    return out;
}

pub const calculate = efficiency_ratio;

test "efficiency ratio is one for monotonic movement" {
    const values = [_]f64{ 1, 2, 3, 4 };
    var output: [4]f64 = undefined;
    try efficiency_ratio_into(&values, 2, &output);
    try std.testing.expectApproxEqAbs(@as(f64, 1), output[3], 0.000001);
    try std.testing.expectError(error.InvalidPeriod, efficiency_ratio_into(&values, 0, &output));
}
