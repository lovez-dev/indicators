//! Batch technical indicators. Inputs are read only during a call.
//! Each *_into function writes to separate caller-provided buffers without
//! allocating. Allocating functions return slices to free with their allocator;
//! multi-output results provide deinit. See docs/api.md for buffer constraints.
const std = @import("std");
const validation = @import("validation.zig");
pub const IndicatorError = validation.IndicatorError;
pub const validate_period = validation.validate_period;

pub const ma = @import("ma.zig");
pub const atr = @import("atr.zig");
pub const bbands = @import("bbands.zig");
pub const correlation = @import("correlation.zig");
pub const er = @import("er.zig");
pub const mfi = @import("mfi.zig");
pub const obv = @import("obv.zig");
pub const rsi = @import("rsi.zig");
pub const macd = @import("macd.zig");
pub const statistics = @import("statistics.zig");

pub const MaType = ma.MaType;
pub const MacdResult = macd.MacdResult;
pub const BollingerBands = bbands.BollingerBands;

test {
    std.testing.refAllDecls(ma);
    std.testing.refAllDecls(atr);
    std.testing.refAllDecls(bbands);
    std.testing.refAllDecls(correlation);
    std.testing.refAllDecls(er);
    std.testing.refAllDecls(mfi);
    std.testing.refAllDecls(obv);
    std.testing.refAllDecls(rsi);
    std.testing.refAllDecls(macd);
    std.testing.refAllDecls(statistics);
}

test "period validation" {
    try std.testing.expectError(error.InvalidPeriod, validate_period(0, 4));
    try std.testing.expectError(error.InsufficientData, validate_period(5, 4));
    try validate_period(4, 4);
}
