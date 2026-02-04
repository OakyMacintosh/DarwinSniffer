import argparse
import subprocess as sb
import sys


def build_darwin_sniffer(configuration: str, output_path: str | None) -> int:
    build_command = [
        "xcodebuild",
        "-project", "DarwinSniffer.xcodeproj",
        "-scheme", "DarwinSniffer",
        "-configuration", configuration,
        "clean", "build",
    ]
    if output_path:
        build_command.append(f"CONFIGURATION_BUILD_DIR={output_path}")

    try:
        sb.run(build_command, check=True)
        print(f"Build completed successfully ({configuration}).")
        return 0
    except sb.CalledProcessError as e:
        print(f"Build failed ({configuration}) with error: {e}")
        return e.returncode or 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build DarwinSniffer via xcodebuild."
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--release",
        action="store_true",
        help="Build using Release configuration (default).",
    )
    group.add_argument(
        "--debug",
        action="store_true",
        help="Build using Debug configuration.",
    )
    parser.add_argument(
        "--output",
        help="Override the build output directory (CONFIGURATION_BUILD_DIR).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    configuration = "Debug" if args.debug else "Release"
    return build_darwin_sniffer(configuration, args.output)


if __name__ == "__main__":
    sys.exit(main())
