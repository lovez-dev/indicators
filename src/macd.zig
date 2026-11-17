const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;
const ma_mod = @import("ma.zig");

pub const MacdResult = struct {
    macd: []f64,
    signal: []f64,
    histogram: []f64,

    /// Free all three slices once, using the allocator passed to macd.
    pub fn deinit(self: MacdResult, allocator: std.mem.Allocator) void {
        allocator.free(self.macd);
        allocator.free(self.signal);
        allocator.free(self.histogram);
    }
};

pub fn macd_into(input: []const f64, fast: usize, slow: usize, signal: usize, output_macd: []f64, output_signal: []f64, output_histogram: []f64) Error!void {
    if (fast == 0 or slow == 0 or signal == 0 or fast > slow) return error.InvalidPeriod;
    try validation.validate_period(slow, input.len);
    // Subtract after validating slow to avoid overflow in slow + signal - 1.
    if (signal > input.len - slow + 1) return error.InsufficientData;
    try validation.require_output(output_macd, input.len);
    try validation.require_output(output_signal, input.len);
    try validation.require_output(output_histogram, input.len);
    @memset(output_macd[0..input.len], 0);
    @memset(output_signal[0..input.len], 0);
    @memset(output_histogram[0..input.len], 0);
    // Reuse output buffers as temporary fast and slow EMA storage.
    try ma_mod.ema_into(input, fast, output_histogram);
    try ma_mod.ema_into(input, slow, output_signal);
    for (slow - 1..input.len) |i| output_macd[i] = output_histogram[i] - output_signal[i];
    // The signal EMA is seeded only from valid MACD values, excluding warm-up.
    try ma_mod.ema_into(output_macd[slow - 1 .. input.len], signal, output_signal[slow - 1 .. input.len]);
    @memset(output_signal[0 .. slow - 1], 0);
    const first_signal = slow + (signal - 1) - 1;
    @memset(output_histogram[0..first_signal], 0);
    for (first_signal..input.len) |i| output_histogram[i] = output_macd[i] - output_signal[i];
}

pub fn macd(allocator: std.mem.Allocator, input: []const f64, fast: usize, slow: usize, signal: usize) Error!MacdResult {
    const output_macd = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(output_macd);
    const output_signal = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(output_signal);
    const output_histogram = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(output_histogram);
    try macd_into(input, fast, slow, signal, output_macd, output_signal, output_histogram);
    return .{ .macd = output_macd, .signal = output_signal, .histogram = output_histogram };
}

pub const calculate = macd;
