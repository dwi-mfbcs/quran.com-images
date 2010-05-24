package Quran::Image::Page;

use strict;
use warnings;

use base qw/Quran Quran::Image/;

sub generate {
	my ($self, %opt) = @_;

	my $page = ($self->{_page} = $opt{page}) || 'all';
	my $path = ($self->{_path} = $opt{path}) || Quran::ROOT_DIR .'/images';
	my $width = ($self->{_width} = $opt{width}) || 800;
	my $height = ($self->{_height} = $width * Quran::Image::PHI);
	my $font_size = ($self->{_font_size} = $width / 20);

	if ($page eq 'all') {
		for my $page (1..604) {
			my $image = $self->_create_image($page);
			$self->_write_image($path, $page, $image);
		}
	}
	else {
		my $image = $self->_create_image($page);
		$self->_write_image($path, $page, $image);
	}

	return;
}

sub _create_image {
	my ($self, $page_number) = @_;
	my $page_lines = $self->db->_get_page_lines($page_number);
	my $image = ($self->{_image} = GD::Image->new($self->{_width},
		$self->{_height}));
	my $colors = ($self->{_color} = {
		white => $image->colorAllocateAlpha(255,255,255,127),
		black => $image->colorAllocate(0,0,0),
		red   => $image->colorAllocate(255,0,0)
	});
	my $line_coord_y = 0;

	print "Generating page $page_number...\n";

	$image->transparent( $colors->{white} );
	$image->interlaced('false');

	while (my $page_line = shift @{ $page_lines }) {
		my $font_file = Quran::Image::FONTS_DIR .'/'. $page_line->{font_file};
		my $line_type = $page_line->{line_type};
		my $line_text = $page_line->{line_text};
		my $gd_text = GD::Text->new(
			font => $font_file,
			ptsize => $self->{_font_size}
		) or die GD::Text::error();
	
		$gd_text->set_text($line_text);

		my ($lw, $lh, $ls, $lu, $ld) = $gd_text->get('width', 'height', 'space',
			'char_up', 'char_down');

		# set x to the pixel coordinate of the beginning of the left margin
		my $line_coord_x = ($self->{_width} - $lw - $ls) / 2;

		# grab bounding box @bb for this line's text
		my @bb = GD::Image->stringFT($colors->{black}, $font_file,
			$self->{_font_size}, 0, $line_coord_x, $line_coord_y, $line_text);

		if ($bb[7] < 0 || $bb[5] < 0) { # if line's top y coord is in negative space
			$line_coord_y += -1 * List::Util::min($bb[7], $bb[5]); # fix it
		}

		# create the string of char codes for the line, e.g. "&#64432;&#64365"
		my @char_codes = split /;/, $line_text;
		$_ .= ';' for @char_codes;

		my ($word_coord_x, $previous_w);

		for my $char_code (@char_codes) {
			$gd_text->set_text($char_code);

			my ($ww, $wh, $ws, $wu, $wd) = $gd_text->get('width', 'height', 'space',
				'char_up', 'char_down');

			#print "ww = $ww, wh = $wh, ws = $ws, wu = $wu, wd = $wd\n";

			if (!defined $word_coord_x) {
				$word_coord_x = $line_coord_x;
			}
			else {
				$word_coord_x += $previous_w;
			}

			# here we use GD::Text::Align to get the bounding box of the word
			my $align = GD::Text::Align->new($self->{_image});
			$align->set_font($font_file, $self->{_font_size});
			$align->set_text($char_code);

			# here we grab the bounding box for the word
			@bb = $align->bounding_box(0, $line_coord_y, 0);

			# here we make use of the word's bounding box
			$previous_w = $bb[4] - ($ws / 2);

			# assign color to the word
			my $color = $self->_is_mention_of_Allah($char_code, $page_number,
				$line_type)? $colors->{red} : $colors->{black};

			# this line actually draws the word unto the image
			@bb = $self->{_image}->stringFT($color, $font_file, $self->{_font_size},
				0, $word_coord_x, $line_coord_y, $char_code);
		}

		if ($page_number == 1 || $page_number == 2) {
			$line_coord_y += Quran::Image::PHI * $lu;
		}
		else {
			$line_coord_y += 2 * $lu;
		}
	}

	return $image;
}

1;
__END__
