const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub const MaType = enum { sma, ema };

pub fn sma_into(input: []const f64, period: usize, output: []f64) Error!void {
    try validation.validate_period(period, input.len);
    try validation.require_output(output, input.len);
    @memset(output[0..input.len], 0.0);
    // Maintain the current window total instead of summing each period again.
    var sum: f64 = 0;
    for (input, 0..) |value, i| {
        sum += value;
        if (i >= period) sum -= input[i - period];
        if (i + 1 >= period) output[i] = sum / @as(f64, @floatFromInt(period));
    }
}

pub fn sma(allocator: std.mem.Allocator, input: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try sma_into(input, period, out);
    return out;
}

pub fn ema_into(input: []const f64, period: usize, output: []f64) Error!void {
    try validation.validate_period(period, input.len);
    try validation.require_output(output, input.len);
    @memset(output[0..input.len], 0.0);
    var sum: f64 = 0;
    for (input[0..period]) |value| sum += value;
    output[period - 1] = sum / @as(f64, @floatFromInt(period));
    const multiplier = 2.0 / (@as(f64, @floatFromInt(period)) + 1.0);
    for (input[period..], period..) |value, i| output[i] = (value - output[i - 1]) * multiplier + output[i - 1];
}

pub fn ema(allocator: std.mem.Allocator, input: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try ema_into(input, period, out);
    return out;
}

pub fn ma_into(input: []const f64, period: usize, kind: MaType, output: []f64) Error!void {
    switch (kind) {
        .sma => try sma_into(input, period, output),
        .ema => try ema_into(input, period, output),
    }
}

pub fn ma(allocator: std.mem.Allocator, input: []const f64, period: usize, kind: MaType) Error![]f64 {
    const out = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try ma_into(input, period, kind, out);
    return out;
}

test "sma and ema produce warmup zeroes" {
    const a = std.testing.allocator;
    const input = [_]f64{ 1, 2, 3, 4 };
    const s = try sma(a, &input, 2);
    defer a.free(s);
    try std.testing.expectEqual(@as(f64, 0), s[0]);
    const e = try ema(a, &input, 2);
    defer a.free(e);
    try std.testing.expectApproxEqAbs(@as(f64, 3.5), e[3], 0.000001);
    var output: [4]f64 = undefined;
    try std.testing.expectError(error.OutputTooSmall, sma_into(&input, 2, output[0..1]));
}
