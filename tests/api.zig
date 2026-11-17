const std = @import("std");
const indicators = @import("indicators");
const testing = std.testing;

fn expect_values(expected: []const f64, actual: []const f64) !void {
    try testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |want, got| try testing.expectApproxEqAbs(want, got, 1e-9);
}

test "moving averages include their first complete window" {
    const input = [_]f64{ 1, 2, 4, 8, 7 };
    var output: [6]f64 = @splat(-123);
    try indicators.ma.sma_into(&input, 3, &output);
    try expect_values(&.{ 0, 0, 7.0 / 3.0, 14.0 / 3.0, 19.0 / 3.0 }, output[0..input.len]);
    try testing.expectEqual(@as(f64, -123), output[input.len]);
    try indicators.ma.ema_into(&input, 3, &output);
    try expect_values(&.{ 0, 0, 7.0 / 3.0, 31.0 / 6.0, 73.0 / 12.0 }, output[0..input.len]);
    inline for (.{ indicators.MaType.sma, indicators.MaType.ema }) |kind| {
        try indicators.ma.ma_into(&input, 1, kind, &output);
        try expect_values(&input, output[0..input.len]);
        try testing.expectError(error.InsufficientData, indicators.ma.ma_into(&.{}, 1, kind, &output));
    }
}

test "ATR and efficiency ratio require a starting point plus period changes" {
    const high = [_]f64{ 10, 12, 14, 16 };
    const low = [_]f64{ 8, 10, 12, 14 };
    const close = [_]f64{ 9, 11, 13, 15 };
    var output: [4]f64 = @splat(-123);
    try testing.expectError(error.InsufficientData, indicators.atr.atr_into(&high, &low, &close, 4, &output));
    try testing.expectError(error.InsufficientData, indicators.er.efficiency_ratio_into(&close, 4, &output));
    try expect_values(&.{ -123, -123, -123, -123 }, &output);
    try indicators.atr.atr_into(&high, &low, &close, 3, &output);
    try expect_values(&.{ 0, 0, 0, 3 }, &output);
    try indicators.er.efficiency_ratio_into(&close, 3, &output);
    try expect_values(&.{ 0, 0, 0, 1 }, &output);
    try indicators.atr.atr_into(&high, &low, &close, 1, &output);
    try expect_values(&.{ 0, 3, 3, 3 }, &output);
    try indicators.er.efficiency_ratio_into(&close, 1, &output);
    try expect_values(&.{ 0, 1, 1, 1 }, &output);
}

test "ATR smooths changing ranges and efficiency ratio accounts for reversals" {
    const high = [_]f64{ 10, 13, 12, 17, 16 };
    const low = [_]f64{ 8, 10, 9, 12, 11 };
    const close = [_]f64{ 9, 12, 10, 16, 12 };
    var output: [5]f64 = undefined;
    try indicators.atr.atr_into(&high, &low, &close, 2, &output);
    try expect_values(&.{ 0, 0, 3.5, 5.25, 5.125 }, &output);
    try indicators.er.efficiency_ratio_into(&.{ 1, 3, 2, 5, 4 }, 2, &output);
    try expect_values(&.{ 0, 0, 1.0 / 3.0, 0.5, 0.5 }, &output);
    try indicators.er.efficiency_ratio_into(&.{ 1, 1, 1, 1, 1 }, 2, &output);
    try expect_values(&.{ 0, 0, 0, 0, 0 }, &output);
}

test "MACD signal is seeded from valid MACD values and uses EMA smoothing" {
    const input = [_]f64{ 1, 2, 4, 8, 7, 12, 9 };
    const result = try indicators.macd.macd(testing.allocator, &input, 2, 3, 2);
    defer result.deinit(testing.allocator);
    try expect_values(&.{ 0, 0, 5.0 / 6.0, 11.0 / 9.0, 77.0 / 108.0, 793.0 / 648.0, 1559.0 / 3888.0 }, result.macd);
    try expect_values(&.{ 0, 0, 0, 37.0 / 36.0, 265.0 / 324.0, 529.0 / 486.0, 1225.0 / 1944.0 }, result.signal);
    try expect_values(&.{ 0, 0, 0, 7.0 / 36.0, -17.0 / 162.0, 263.0 / 1944.0, -11.0 / 48.0 }, result.histogram);
}

test "MACD validates combined lookback without integer overflow" {
    const input = [_]f64{ 1, 2, 3 };
    var line: [3]f64 = @splat(-123);
    var signal: [3]f64 = @splat(-123);
    var histogram: [3]f64 = @splat(-123);
    try testing.expectError(error.InsufficientData, indicators.macd.macd_into(&input, 2, 3, 2, &line, &signal, &histogram));
    try testing.expectError(error.InsufficientData, indicators.macd.macd_into(&input, 1, 1, std.math.maxInt(usize), &line, &signal, &histogram));
    try testing.expectError(error.InvalidPeriod, indicators.macd.macd_into(&input, 3, 2, 1, &line, &signal, &histogram));
    try expect_values(&.{ -123, -123, -123 }, &line);
    try expect_values(&.{ -123, -123, -123 }, &signal);
    try expect_values(&.{ -123, -123, -123 }, &histogram);
    try indicators.macd.macd_into(&input, 2, 3, 1, &line, &signal, &histogram);
    try expect_values(&.{ 0, 0, 0.5 }, &line);
    try expect_values(&.{ 0, 0, 0.5 }, &signal);
    try expect_values(&.{ 0, 0, 0 }, &histogram);
}

test "multi-output APIs validate every buffer and preserve output tails" {
    const prices = [_]f64{ 1, 2, 4, 8 };
    var first: [5]f64 = @splat(-123);
    var second: [5]f64 = @splat(-123);
    var third: [5]f64 = @splat(-123);
    try testing.expectError(error.OutputTooSmall, indicators.macd.macd_into(&prices, 2, 3, 2, &first, second[0..3], &third));
    try testing.expectError(error.OutputTooSmall, indicators.macd.macd_into(&prices, 2, 3, 2, &first, &second, third[0..3]));
    try testing.expectError(error.OutputTooSmall, indicators.bbands.bollinger_bands_into(&prices, 2, 2, 2, .sma, &first, &second, third[0..3]));
    for ([_][5]f64{ first, second, third }) |output| try expect_values(&.{ -123, -123, -123, -123, -123 }, &output);
    try indicators.macd.macd_into(&prices, 2, 3, 2, &first, &second, &third);
    try testing.expectEqual(@as(f64, -123), first[4]);
    try testing.expectEqual(@as(f64, -123), second[4]);
    try testing.expectEqual(@as(f64, -123), third[4]);
    try indicators.bbands.bollinger_bands_into(&prices, 2, 2, 2, .sma, &first, &second, &third);
    try testing.expectEqual(@as(f64, -123), first[4]);
    try testing.expectEqual(@as(f64, -123), second[4]);
    try testing.expectEqual(@as(f64, -123), third[4]);
}

test "population variance and bands handle prices with a large baseline" {
    const prices = [_]f64{ 1e12 + 1, 1e12 + 2, 1e12 + 3, 1e12 + 4 };
    var output: [4]f64 = undefined;
    try indicators.statistics.variance_into(&prices, 2, &output);
    try expect_values(&.{ 0, 0.25, 0.25, 0.25 }, &output);
    try indicators.statistics.std_dev_into(&prices, 2, 2, &output);
    try expect_values(&.{ 0, 1, 1, 1 }, &output);
    const bands = try indicators.bbands.bollinger_bands(testing.allocator, &prices, 2, 2, 2, .sma);
    defer bands.deinit(testing.allocator);
    try expect_values(&.{ 0, 1e12 + 2.5, 1e12 + 3.5, 1e12 + 4.5 }, bands.upper);
    try expect_values(&.{ 0, 1e12 + 1.5, 1e12 + 2.5, 1e12 + 3.5 }, bands.middle);
    try expect_values(&.{ 0, 1e12 + 0.5, 1e12 + 1.5, 1e12 + 2.5 }, bands.lower);
}

test "correlation is stable for large offsets and zero variance" {
    const a = [_]f64{ 1e12 + 1, 1e12 + 2, 1e12 + 3, 1e12 + 4 };
    const b = [_]f64{ 1e12 + 8, 1e12 + 6, 1e12 + 4, 1e12 + 2 };
    var output: [4]f64 = undefined;
    try indicators.correlation.correlation_into(&a, &b, 3, &output);
    try expect_values(&.{ 0, 0, -1, -1 }, &output);
    try indicators.correlation.correlation_into(&a, &a, 3, &output);
    try expect_values(&.{ 0, 0, 1, 1 }, &output);
    try indicators.correlation.correlation_into(&a, &b, 1, &output);
    try expect_values(&.{ 0, 0, 0, 0 }, &output);
}

test "RSI uses Wilder smoothing and MFI rolls signed money flow" {
    const prices = [_]f64{ 1, 2, 1, 3, 2 };
    const volume = [_]f64{ 1, 1, 1, 1, 1 };
    var output: [5]f64 = undefined;
    try indicators.rsi.rsi_into(&prices, 2, &output);
    try expect_values(&.{ 0, 0, 50, 250.0 / 3.0, 50 }, &output);
    try indicators.mfi.mfi_into(&prices, &prices, &prices, &volume, 2, &output);
    try expect_values(&.{ 0, 0, 200.0 / 3.0, 75, 60 }, &output);
    const flat = [_]f64{ 2, 2, 2, 2, 2 };
    try indicators.rsi.rsi_into(&flat, 2, &output);
    try expect_values(&.{ 0, 0, 0, 0, 0 }, &output);
    try indicators.mfi.mfi_into(&flat, &flat, &flat, &volume, 2, &output);
    try expect_values(&.{ 0, 0, 0, 0, 0 }, &output);
}

test "empty nonperiodic inputs and output tails are preserved" {
    var output = [_]f64{ -123, -123, -123, -123 };
    try indicators.obv.obv_into(&.{}, &.{}, &output);
    try indicators.atr.true_range_into(&.{}, &.{}, &.{}, &output);
    try expect_values(&.{ -123, -123, -123, -123 }, &output);
    try indicators.obv.obv_into(&.{ 1, 2, 1 }, &.{ 5, 6, 7 }, &output);
    try expect_values(&.{ 0, 6, -1, -123 }, &output);
    try indicators.atr.true_range_into(&.{ 2, 4, 3 }, &.{ 0, 2, 1 }, &.{ 1, 3, 2 }, &output);
    try expect_values(&.{ 0, 3, 2, -123 }, &output);
}

test "invalid periods and undersized buffers fail before writing" {
    const prices = [_]f64{ 1, 2, 3 };
    var output = [_]f64{ -123, -123, -123 };
    inline for (.{ indicators.ma.sma_into, indicators.ma.ema_into, indicators.er.efficiency_ratio_into, indicators.rsi.rsi_into, indicators.statistics.variance_into }) |calculate| {
        try testing.expectError(error.InvalidPeriod, calculate(&prices, 0, &output));
        try testing.expectError(error.InsufficientData, calculate(&prices, 4, &output));
        try testing.expectError(error.OutputTooSmall, calculate(&prices, 2, output[0..2]));
    }
    try testing.expectError(error.OutputTooSmall, indicators.atr.atr_into(&prices, &prices, &prices, 2, output[0..2]));
    try testing.expectError(error.OutputTooSmall, indicators.atr.true_range_into(&prices, &prices, &prices, output[0..2]));
    try testing.expectError(error.OutputTooSmall, indicators.obv.obv_into(&prices, &prices, output[0..2]));
    try testing.expectError(error.OutputTooSmall, indicators.mfi.mfi_into(&prices, &prices, &prices, &prices, 2, output[0..2]));
    try testing.expectError(error.OutputTooSmall, indicators.correlation.correlation_into(&prices, &prices, 2, output[0..2]));
    try expect_values(&.{ -123, -123, -123 }, &output);
}

fn allocate_all(allocator: std.mem.Allocator) !void {
    const prices = [_]f64{ 2, 3, 4, 2, 5, 4 };
    inline for (.{ indicators.ma.sma, indicators.ma.ema, indicators.rsi.rsi, indicators.er.efficiency_ratio, indicators.statistics.variance }) |calculate| {
        const result = try calculate(allocator, &prices, 2);
        defer allocator.free(result);
        try testing.expectEqual(prices.len, result.len);
    }
    const moving_average = try indicators.ma.ma(allocator, &prices, 2, .sma);
    defer allocator.free(moving_average);
    const tr = try indicators.atr.true_range(allocator, &prices, &prices, &prices);
    defer allocator.free(tr);
    const atr = try indicators.atr.atr(allocator, &prices, &prices, &prices, 2);
    defer allocator.free(atr);
    const deviation = try indicators.statistics.std_dev(allocator, &prices, 2, 2);
    defer allocator.free(deviation);
    const mfi = try indicators.mfi.mfi(allocator, &prices, &prices, &prices, &prices, 2);
    defer allocator.free(mfi);
    const obv = try indicators.obv.obv(allocator, &prices, &prices);
    defer allocator.free(obv);
    const correlation = try indicators.correlation.correlation(allocator, &prices, &prices, 2);
    defer allocator.free(correlation);
    const macd = try indicators.macd.macd(allocator, &prices, 2, 3, 2);
    defer macd.deinit(allocator);
    const bands = try indicators.bbands.bollinger_bands(allocator, &prices, 2, 2, 2, .ema);
    defer bands.deinit(allocator);
}

test "allocation failures free every partial result" {
    try testing.checkAllAllocationFailures(testing.allocator, allocate_all, .{});
}
