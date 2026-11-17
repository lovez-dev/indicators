const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

fn flow_at(high: []const f64, low: []const f64, close: []const f64, volume: []const f64, index: usize) struct { positive: f64, negative: f64 } {
    const previous = (high[index - 1] + low[index - 1] + close[index - 1]) / 3.0;
    const typical = (high[index] + low[index] + close[index]) / 3.0;
    const flow = typical * volume[index];
    if (typical > previous) return .{ .positive = flow, .negative = 0 };
    if (typical < previous) return .{ .positive = 0, .negative = flow };
    return .{ .positive = 0, .negative = 0 };
}

pub fn mfi_into(high: []const f64, low: []const f64, close: []const f64, volume: []const f64, period: usize, output: []f64) Error!void {
    if (high.len != low.len or high.len != close.len or high.len != volume.len) return error.InvalidInput;
    try validation.validate_changes(period, close.len);
    try validation.require_output(output, close.len);
    @memset(output[0..close.len], 0.0);
    // Track only the values entering and leaving the period window.
    var positive: f64 = 0;
    var negative: f64 = 0;
    for (1..period + 1) |i| {
        const flow = flow_at(high, low, close, volume, i);
        positive += flow.positive;
        negative += flow.negative;
    }
    for (period..close.len) |i| {
        if (i > period) {
            const removed = flow_at(high, low, close, volume, i - period);
            positive -= removed.positive;
            negative -= removed.negative;
            const added = flow_at(high, low, close, volume, i);
            positive += added.positive;
            negative += added.negative;
        }
        output[i] = if (positive + negative == 0) 0 else 100 * positive / (positive + negative);
    }
}

pub fn mfi(allocator: std.mem.Allocator, high: []const f64, low: []const f64, close: []const f64, volume: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, close.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try mfi_into(high, low, close, volume, period, out);
    return out;
}

test "mfi reaches one hundred on uninterrupted buying flow" {
    const high = [_]f64{ 1, 2, 3, 4 };
    const low = high;
    const close = high;
    const volume = [_]f64{ 1, 1, 1, 1 };
    var output: [4]f64 = undefined;
    try mfi_into(&high, &low, &close, &volume, 2, &output);
    try std.testing.expectApproxEqAbs(@as(f64, 100), output[3], 0.000001);
    try std.testing.expectError(error.InvalidInput, mfi_into(&high, &low, &close, volume[0..3], 2, &output));
    try std.testing.expectError(error.InsufficientData, mfi_into(high[0..2], low[0..2], close[0..2], volume[0..2], 2, output[0..2]));
}
