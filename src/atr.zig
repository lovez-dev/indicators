const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

// Retain the original public statistics entry points.
const statistics = @import("statistics.zig");
pub const variance = statistics.variance;
pub const variance_into = statistics.variance_into;
pub const std_dev = statistics.std_dev;
pub const std_dev_into = statistics.std_dev_into;

pub fn true_range_into(high: []const f64, low: []const f64, close: []const f64, output: []f64) Error!void {
    if (high.len != low.len or high.len != close.len) return error.InvalidInput;
    try validation.require_output(output, close.len);
    if (close.len == 0) return;
    output[0] = 0.0;
    for (close[1..], 1..) |_, i| {
        const hl = high[i] - low[i];
        const hc = @abs(high[i] - close[i - 1]);
        const lc = @abs(low[i] - close[i - 1]);
        output[i] = @max(hl, @max(hc, lc));
    }
}

pub fn true_range(allocator: std.mem.Allocator, high: []const f64, low: []const f64, close: []const f64) Error![]f64 {
    const out = allocator.alloc(f64, close.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try true_range_into(high, low, close, out);
    return out;
}

pub fn atr_into(high: []const f64, low: []const f64, close: []const f64, period: usize, output: []f64) Error!void {
    if (high.len != low.len or high.len != close.len) return error.InvalidInput;
    try validation.validate_changes(period, close.len);
    try validation.require_output(output, close.len);
    @memset(output[0..close.len], 0.0);
    var sum: f64 = 0;
    for (close[1 .. period + 1], 1..) |_, i| {
        const v = @max(high[i] - low[i], @max(@abs(high[i] - close[i - 1]), @abs(low[i] - close[i - 1])));
        sum += v;
    }
    output[period] = sum / @as(f64, @floatFromInt(period));
    // Wilder's smoothing carries the prior ATR forward one point at a time.
    var previous = output[period];
    for (close[period + 1 ..], period + 1..) |_, i| {
        const v = @max(high[i] - low[i], @max(@abs(high[i] - close[i - 1]), @abs(low[i] - close[i - 1])));
        previous = (previous * @as(f64, @floatFromInt(period - 1)) + v) / @as(f64, @floatFromInt(period));
        output[i] = previous;
    }
}

pub fn atr(allocator: std.mem.Allocator, high: []const f64, low: []const f64, close: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, close.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try atr_into(high, low, close, period, out);
    return out;
}

test "true range uses the preceding close" {
    const a = std.testing.allocator;
    const high = [_]f64{ 10, 12 };
    const low = [_]f64{ 8, 9 };
    const close = [_]f64{ 9, 11 };
    const tr = try true_range(a, &high, &low, &close);
    defer a.free(tr);
    try std.testing.expectEqual(@as(f64, 3), tr[1]);
}

test "atr calculates constant ranges" {
    const high = [_]f64{ 10, 12, 14, 16 };
    const low = [_]f64{ 8, 10, 12, 14 };
    const close = [_]f64{ 9, 11, 13, 15 };
    var output: [4]f64 = undefined;
    try atr_into(&high, &low, &close, 2, &output);
    try std.testing.expectApproxEqAbs(@as(f64, 0), output[1], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 3), output[2], 0.000001);
    try std.testing.expectApproxEqAbs(@as(f64, 3), output[3], 0.000001);
    try std.testing.expectError(error.InvalidInput, atr_into(&high, &low, close[0..3], 2, &output));
    try std.testing.expectError(error.OutputTooSmall, atr_into(&high, &low, &close, 2, output[0..2]));
}
