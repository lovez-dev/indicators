const std = @import("std");
const validation = @import("validation.zig");
pub const Error = validation.IndicatorError;

pub fn correlation_into(a: []const f64, b: []const f64, period: usize, output: []f64) Error!void {
    if (a.len != b.len or a.len == 0) return error.InvalidInput;
    try validation.validate_period(period, a.len);
    try validation.require_output(output, a.len);
    @memset(output[0..a.len], 0.0);
    // These rolling aggregates replace an O(period) rescan at every output point.
    var sx: f64 = 0;
    var sy: f64 = 0;
    var sxx: f64 = 0;
    var syy: f64 = 0;
    var sxy: f64 = 0;
    // Correlation is translation invariant; centering reduces cancellation.
    const origin_x = a[0];
    const origin_y = b[0];
    for (a[0..period], b[0..period]) |raw_x, raw_y| {
        const x = raw_x - origin_x;
        const y = raw_y - origin_y;
        sx += x;
        sy += y;
        sxx += x * x;
        syy += y * y;
        sxy += x * y;
    }
    const n = @as(f64, @floatFromInt(period));
    for (period - 1..a.len) |i| {
        if (i >= period) {
            const old_x = a[i - period] - origin_x;
            const old_y = b[i - period] - origin_y;
            const new_x = a[i] - origin_x;
            const new_y = b[i] - origin_y;
            sx += new_x - old_x;
            sy += new_y - old_y;
            sxx += new_x * new_x - old_x * old_x;
            syy += new_y * new_y - old_y * old_y;
            sxy += new_x * new_y - old_x * old_y;
        }
        const variance_x = @max(0, n * sxx - sx * sx);
        const variance_y = @max(0, n * syy - sy * sy);
        const denom = @sqrt(variance_x) * @sqrt(variance_y);
        output[i] = if (denom == 0) 0 else std.math.clamp((n * sxy - sx * sy) / denom, -1, 1);
    }
}

pub fn correlation(allocator: std.mem.Allocator, a: []const f64, b: []const f64, period: usize) Error![]f64 {
    const out = allocator.alloc(f64, a.len) catch return error.OutOfMemory;
    errdefer allocator.free(out);
    try correlation_into(a, b, period, out);
    return out;
}

test "correlation detects perfect inverse" {
    const a = std.testing.allocator;
    const x = [_]f64{ 1, 2, 3 };
    const y = [_]f64{ 3, 2, 1 };
    const out = try correlation(a, &x, &y, 3);
    defer a.free(out);
    try std.testing.expectApproxEqAbs(@as(f64, -1), out[2], 0.000001);
}

test "correlation handles zero variance and invalid input" {
    const values = [_]f64{ 2, 2, 2 };
    var output: [3]f64 = undefined;
    try correlation_into(&values, &values, 2, &output);
    try std.testing.expectEqual(@as(f64, 0), output[2]);
    try std.testing.expectError(error.InvalidInput, correlation_into(&values, values[0..2], 2, &output));
    try std.testing.expectError(error.OutputTooSmall, correlation_into(&values, &values, 2, output[0..2]));
}
