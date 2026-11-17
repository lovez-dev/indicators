const std = @import("std");
const indicators = @import("indicators");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const close = [_]f64{ 10, 11, 10.5, 12, 11.5, 13 };

    const values = try indicators.rsi.rsi(allocator, &close, 3);
    defer allocator.free(values);

    var output: [close.len]f64 = undefined;
    try indicators.ma.sma_into(&close, 3, &output);

    const bands = try indicators.bbands.bollinger_bands(allocator, &close, 3, 2, 2, .sma);
    defer bands.deinit(allocator);

    const last = close.len - 1;
    std.debug.print("RSI={d:.4}, SMA={d:.4}, upper band={d:.4}\n", .{
        values[last], output[last], bands.upper[last],
    });
}
