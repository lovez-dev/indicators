# indicators

Technical indicators with allocating and allocation-free batch APIs: moving averages, MACD, ATR, Bollinger Bands, RSI, efficiency ratio, MFI, OBV, and rolling statistics.

## Install

```sh
zig fetch --save "git+https://github.com/lovez-dev/indicators#main"
```

```zig
const dep = b.dependency("indicators", .{
    .target = target,
    .optimize = optimize,
});
root_module.addImport("indicators", dep.module("indicators"));
```

## Use

```zig
const std = @import("std");
const indicators = @import("indicators");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const close = [_]f64{ 10, 11, 10.5, 12, 11.5, 13 };

    const values = try indicators.rsi.rsi(allocator, &close, 3);
    defer allocator.free(values);

    var output: [close.len]f64 = undefined;
    try indicators.ma.sma_into(&close, 3, &output);
}
```

Inputs remain valid for the duration of the call. Output buffers must not overlap inputs or each other. Warm-up positions are zero. Allocating results must be released with the same allocator; multi-output results provide `deinit(allocator)`.

Run the complete example with `zig build example`.

## Build

```sh
zig build test
zig build test --release=safe
zig build check
zig build example
zig build bench --release=fast
```

## License

[MIT](LICENSE)
