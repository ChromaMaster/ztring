default:
	@just --list

test:
	zig build test --summary all

clean:
	rm -rf zig-out zig-cache
