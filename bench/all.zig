const std = @import("std");
const indicators = @import("indicators");

fn counter(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).nanoseconds;
}

fn report(name: []const u8, start: i96, finish: i96, items: usize, checksum: f64) void {
    const ns_per_item = @as(f64, @floatFromInt(finish - start)) / @as(f64, @floatFromInt(items));
    std.debug.print("{s}: {d:.2} ns/item, checksum={d}\n", .{ name, ns_per_item, checksum });
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = std.heap.page_allocator;
    const n: usize = 1_000_000;
    const rounds: usize = 10;
    const alloc_rounds: usize = rounds;

    const prices = try allocator.alloc(f64, n);
    defer allocator.free(prices);
    const high = try allocator.alloc(f64, n);
    defer allocator.free(high);
    const low = try allocator.alloc(f64, n);
    defer allocator.free(low);
    const close = try allocator.alloc(f64, n);
    defer allocator.free(close);
    const volume = try allocator.alloc(f64, n);
    defer allocator.free(volume);
    for (0..n) |i| {
        prices[i] = @as(f64, @floatFromInt((i % 1000) + 1));
        high[i] = prices[i] + 2.0;
        low[i] = prices[i] - 2.0;
        close[i] = prices[i];
        volume[i] = 100.0 + @as(f64, @floatFromInt(i % 100));
    }

    const output = try allocator.alloc(f64, n);
    defer allocator.free(output);
    const output2 = try allocator.alloc(f64, n);
    defer allocator.free(output2);
    const output3 = try allocator.alloc(f64, n);
    defer allocator.free(output3);

    var start: i96 = undefined;
    var checksum: f64 = undefined;

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.ma.sma_into(prices, 14, output);
        checksum += output[n - 1];
    }
    report("SMA Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.ma.ema_into(prices, 14, output);
        checksum += output[n - 1];
    }
    report("EMA Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.macd.macd_into(prices, 12, 26, 9, output, output2, output3);
        checksum += output3[n - 1];
    }
    report("MACD Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.atr.atr_into(high, low, close, 14, output);
        checksum += output[n - 1];
    }
    report("ATR Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.bbands.bollinger_bands_into(prices, 20, 2, 2, .sma, output, output2, output3);
        checksum += output[n - 1];
    }
    report("BBands Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.rsi.rsi_into(prices, 14, output);
        checksum += output[n - 1];
    }
    report("RSI Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.er.efficiency_ratio_into(prices, 14, output);
        checksum += output[n - 1];
    }
    report("ER Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.mfi.mfi_into(high, low, close, volume, 14, output);
        checksum += output[n - 1];
    }
    report("MFI Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.obv.obv_into(close, volume, output);
        checksum += output[n - 1];
    }
    report("OBV Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..rounds) |_| {
        try indicators.correlation.correlation_into(prices, close, 20, output);
        checksum += output[n - 1];
    }
    report("Correlation Into", start, counter(io), n * rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.ma.sma(allocator, prices, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("SMA Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.ma.ema(allocator, prices, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("EMA Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.macd.macd(allocator, prices, 12, 26, 9);
        checksum += result.histogram[n - 1];
        result.deinit(allocator);
    }
    report("MACD Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.atr.atr(allocator, high, low, close, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("ATR Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.bbands.bollinger_bands(allocator, prices, 20, 2, 2, .sma);
        checksum += result.upper[n - 1];
        result.deinit(allocator);
    }
    report("BBands Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.rsi.rsi(allocator, prices, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("RSI Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.er.efficiency_ratio(allocator, prices, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("ER Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.mfi.mfi(allocator, high, low, close, volume, 14);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("MFI Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.obv.obv(allocator, close, volume);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("OBV Alloc", start, counter(io), n * alloc_rounds, checksum);

    start = counter(io);
    checksum = 0;
    for (0..alloc_rounds) |_| {
        const result = try indicators.correlation.correlation(allocator, prices, close, 20);
        checksum += result[n - 1];
        allocator.free(result);
    }
    report("Correlation Alloc", start, counter(io), n * alloc_rounds, checksum);
}
