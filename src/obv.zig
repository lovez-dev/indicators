const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub fn obv_into(close: []const f64, volume: []const f64, output: []f64) Error!void {
    if (close.len != volume.len) return error.InvalidInput;
    try validation.require_output(output, close.len);
    if (close.len == 0) return;
    output[0] = 0;
    for (close[1..], 1..) |value, i| output[i] = output[i - 1] + (if (value > close[i - 1]) volume[i] else if (value < close[i - 1]) -volume[i] else 0);
}

pub fn obv(allocator: std.mem.Allocator, close: []const f64, volume: []const f64) Error![]f64 {
    const out = allocator.alloc(f64, close.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try obv_into(close, volume, out);
    return out;
}

pub const calculate = obv;

test "obv tracks direction" {
    const a = std.testing.allocator;
    const c = [_]f64{ 1, 2, 1 };
    const v = [_]f64{ 5, 6, 7 };
    const out = try obv(a, &c, &v);
    defer a.free(out);
    try std.testing.expectEqual(@as(f64, 6), out[1]);
    try std.testing.expectEqual(@as(f64, -1), out[2]);
    var output: [3]f64 = undefined;
    try std.testing.expectError(error.InvalidInput, obv_into(&c, v[0..2], &output));
}
