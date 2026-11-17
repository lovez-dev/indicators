const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub fn rsi_into(input: []const f64, period: usize, output: []f64) Error!void {
    if (period < 2) return error.InvalidPeriod;
    try validation.validate_changes(period, input.len);
    try validation.require_output(output, input.len);
    @memset(output[0..input.len], 0.0);
    var gain: f64 = 0;
    var loss: f64 = 0;
    for (input[1 .. period + 1], 1..) |value, i| {
        const delta = value - input[i - 1];
        if (delta >= 0) gain += delta else loss -= delta;
    }
    gain /= @as(f64, @floatFromInt(period));
    loss /= @as(f64, @floatFromInt(period));
    output[period] = if (gain + loss == 0) 0 else 100 * gain / (gain + loss);
    for (input[period + 1 ..], period + 1..) |value, i| {
        const delta = value - input[i - 1];
        const g = if (delta > 0) delta else 0;
        const l = if (delta < 0) -delta else 0;
        gain = (gain * @as(f64, @floatFromInt(period - 1)) + g) / @as(f64, @floatFromInt(period));
        loss = (loss * @as(f64, @floatFromInt(period - 1)) + l) / @as(f64, @floatFromInt(period));
        output[i] = if (gain + loss == 0) 0 else 100 * gain / (gain + loss);
    }
}

pub fn rsi(allocator: std.mem.Allocator, input: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try rsi_into(input, period, out);
    return out;
}

test "rsi responds to rising prices" {
    const a = std.testing.allocator;
    const v = [_]f64{ 1, 2, 3, 4, 5 };
    const out = try rsi(a, &v, 2);
    defer a.free(out);
    try std.testing.expect(out[2] > 90);
}

test "rsi validates period and buffer" {
    const values = [_]f64{ 1, 2, 3 };
    var output: [3]f64 = undefined;
    try std.testing.expectError(error.InvalidPeriod, rsi_into(&values, 1, &output));
    try std.testing.expectError(error.OutputTooSmall, rsi_into(&values, 2, output[0..2]));
    try std.testing.expectError(error.InsufficientData, rsi_into(values[0..2], 2, &output));
}
