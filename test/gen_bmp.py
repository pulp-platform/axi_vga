import struct
import sys
from PIL import Image

def write_bmp_header(f, width, height):
	row_pad = (4 - (width * 3) % 4) % 4
	image_size = (width * 3 + row_pad) * height
	filesize = 54 + image_size

	# BMP file header (14 bytes)
	f.write(b'BM')                                  # Signature
	f.write(struct.pack('<I', filesize))            # File size
	f.write(struct.pack('<HH', 0, 0))               # Reserved
	f.write(struct.pack('<I', 54))                  # Pixel data offset

	# DIB header (40 bytes)
	f.write(struct.pack('<I', 40))                  # Header size
	f.write(struct.pack('<i', width))               # Image width
	f.write(struct.pack('<i', height))              # Image height (bottom-up)
	f.write(struct.pack('<H', 1))                   # Planes
	f.write(struct.pack('<H', 24))                  # Bits per pixel
	f.write(struct.pack('<I', 0))                   # Compression (none)
	f.write(struct.pack('<I', image_size))          # Image size
	f.write(struct.pack('<I', 1000))                # X pixels/meter
	f.write(struct.pack('<I', 1000))                # Y pixels/meter
	f.write(struct.pack('<I', 0))                   # Colors used
	f.write(struct.pack('<I', 0))                   # Important colors

	return row_pad


def generate_bmp(filename, width, height, rgb_format):
	red_bits, green_bits, blue_bits = rgb_format
	red_levels = 1 << red_bits
	green_levels = 1 << green_bits
	blue_levels = 1 << blue_bits

	red_step = max(1, width // red_levels)
	green_step = max(1, width // green_levels)
	blue_step = max(1, height // blue_levels)

	with open(filename, 'wb') as f:
		row_pad = write_bmp_header(f, width, height)

		for y in range(height):
			blue = (y // blue_step) % blue_levels
			for x in range(width):
				red = (x // red_step) % red_levels
				green = (x // green_step) % green_levels

				r8 = (red << (8 - red_bits)) & 0xFF
				g8 = (green << (8 - green_bits)) & 0xFF
				b8 = (blue << (8 - blue_bits)) & 0xFF

				f.write(struct.pack('BBB', b8, g8, r8))
			f.write(b'\x00' * row_pad)

	print(f"[INFO] Wrote {width}x{height} BMP to '{filename}' with RGB format {rgb_format}")



def convert_image_to_bmp(input_file, output_file, rgb_format):
	red_bits, green_bits, blue_bits = rgb_format
	img = Image.open(input_file).convert("RGB")
	width, height = img.size
	pixels = list(img.getdata())

	with open(output_file, 'wb') as f:
		row_pad = write_bmp_header(f, width, height)

		# BMP is bottom-up: write rows in reverse
		for y in range(height - 1, -1, -1):
			for x in range(width):
				idx = y * width + x
				r, g, b = pixels[idx]
				r8 = (r >> (8 - red_bits)) << (8 - red_bits)
				g8 = (g >> (8 - green_bits)) << (8 - green_bits)
				b8 = (b >> (8 - blue_bits)) << (8 - blue_bits)
				f.write(struct.pack('BBB', b8, g8, r8))
			f.write(b'\x00' * row_pad)

	print(f"[INFO] Converted '{input_file}' -> '{output_file}' with RGB format {rgb_format}")


if __name__ == "__main__":
	import argparse
	import sys

	parser = argparse.ArgumentParser()
	parser.add_argument("output", help="Output BMP filename")
	parser.add_argument("--input", help="Input image file (if provided, converts image to BMP)")
	parser.add_argument("--width", type=int, default=64, help="Width (only used if generating)")
	parser.add_argument("--height", type=int, default=64, help="Height (only used if generating)")
	parser.add_argument("--rgb", default="5,6,5", help="RGB bit-widths, comma-separated (e.g., 5,6,5)")
	args = parser.parse_args()

	try:
		rgb_bits = tuple(map(int, args.rgb.split(',')))
		if len(rgb_bits) != 3:
			raise ValueError
	except ValueError:
		print("[ERROR] RGB format must be 3 comma-separated integers like 5,6,5")
		sys.exit(1)

	if args.input:
		convert_image_to_bmp(args.input, args.output, rgb_bits)
	else:
		generate_bmp(args.output, args.width, args.height, rgb_bits)

