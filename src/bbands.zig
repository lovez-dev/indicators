const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;
const ma_mod = @import("ma.zig");
const statistics = @import("statistics.zig");

pub const BollingerBands = struct {
    upper: []f64,
    middle: []f64,
    lower: []f64,

    /// Free all three slices once, using the allocator passed to bollinger_bands.
    pub fn deinit(self: BollingerBands, allocator: std.mem.Allocator) void {
        allocator.free(self.upper);
        allocator.free(self.middle);
        allocator.free(self.lower);
    }
};

pub fn bollinger_bands_into(input: []const f64, period: usize, upper_dev: f64, lower_dev: f64, kind: ma_mod.MaType, upper: []f64, middle: []f64, lower: []f64) Error!void {
    try validation.require_output(upper, input.len);
    try validation.require_output(middle, input.len);
    try validation.require_output(lower, input.len);
    try ma_mod.ma_into(input, period, kind, middle);
    // `lower` temporarily holds standard deviation before becoming the lower band.
    try statistics.std_dev_into(input, period, 1.0, lower);
    for (input, 0..) |_, i| {
        const deviation = lower[i];
        upper[i] = middle[i] + deviation * upper_dev;
        lower[i] = middle[i] - deviation * lower_dev;
    }
}

pub fn bollinger_bands(allocator: std.mem.Allocator, input: []const f64, period: usize, upper_dev: f64, lower_dev: f64, kind: ma_mod.MaType) Error!BollingerBands {
    const upper = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(upper);
    const middle = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(middle);
    const lower = allocator.alloc(f64, input.len) catch return error.OutOfMemory;
    errdefer allocator.free(lower);
    try bollinger_bands_into(input, period, upper_dev, lower_dev, kind, upper, middle, lower);
    return .{ .upper = upper, .middle = middle, .lower = lower };
}

pub const calculate = bollinger_bands;

test "bollinger bands collapse for constant prices" {
    const prices = [_]f64{ 5, 5, 5, 5 };
    var upper: [4]f64 = undefined;
    var middle: [4]f64 = undefined;
    var lower: [4]f64 = undefined;
    try bollinger_bands_into(&prices, 2, 2, 2, .sma, &upper, &middle, &lower);
    try std.testing.expectEqual(@as(f64, 5), upper[3]);
    try std.testing.expectEqual(@as(f64, 5), middle[3]);
    try std.testing.expectEqual(@as(f64, 5), lower[3]);
}
