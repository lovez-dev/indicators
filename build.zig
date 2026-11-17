const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const module = b.addModule("indicators", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const unit_tests = b.addTest(.{ .root_module = module });
    const api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/api.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "indicators", .module = module }},
        }),
    });
    const test_step = b.step("test", "Run unit and public API tests");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
    test_step.dependOn(&b.addRunArtifact(api_tests).step);

    const example = b.addExecutable(.{
        .name = "indicators-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "indicators", .module = module }},
        }),
    });
    const example_step = b.step("example", "Run the basic usage example");
    example_step.dependOn(&b.addRunArtifact(example).step);

    const benchmark_module = b.createModule(.{
        .root_source_file = b.path("bench/all.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "indicators", .module = module }},
    });
    const benchmark = b.addExecutable(.{
        .name = "indicators-bench",
        .root_module = benchmark_module,
    });
    const run_benchmark = b.addRunArtifact(benchmark);
    const benchmark_step = b.step("bench", "Run indicator benchmarks (use --release=fast)");
    benchmark_step.dependOn(&run_benchmark.step);

    const check_step = b.step("check", "Compile tests, example, and benchmark without running");
    check_step.dependOn(&unit_tests.step);
    check_step.dependOn(&api_tests.step);
    check_step.dependOn(&example.step);
    check_step.dependOn(&benchmark.step);
    b.default_step = check_step;
}
