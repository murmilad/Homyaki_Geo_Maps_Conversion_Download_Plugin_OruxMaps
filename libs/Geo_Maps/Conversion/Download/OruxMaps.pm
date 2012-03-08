package Homyaki::Geo_Maps::Conversion::Download::OruxMaps;

use strict;

use File::Copy;
use Math::Complex;

use Homyaki::Geo_Maps::Conversion::Download::Constants;
use Homyaki::Geo_Maps::Conversion::Map::Ozi_To_Flat;
 
use Data::Dumper;

use base 'Homyaki::Geo_Maps::Conversion';

use constant CHUNK_SIZE_X => 512;
use constant CHUNK_SIZE_Y => 512;

sub convert {
	my $self = shift;
	my %h = @_;

	my $maps = $h{maps};

	my $geo_data  = $self->{params}->{geo_data};
	my $maps_path = $self->{params}->{maps_path};
	my $www_path  = &MAPS_DESTANTION;

	Homyaki::Geo_Maps::Conversion::Map::Ozi_To_Flat->convert(
		maps       => $maps,
		size       => {
			x => &CHUNK_SIZE_X,
			y => &CHUNK_SIZE_Y,
		},
		geo_data  => $geo_data,
		maps_path => $maps_path,
		map_data_save_method => sub {
			my %h = @_;

			my $chunks = $h{chunks};
			my $chunks_data = $h{chunks_data};

			open MAP_KOORD, ">$chunks_data->{path}/map_koord.txt";
			my $geo_chunk_scale = sprintf("%d", $chunks_data->{scale_calculated_abs} * 2817.947378);

			my $max_x = 0;
			my $max_y = 0;
			my $calibration_points_xml = '';

			foreach my $chunk (@{$chunks}){

				my $chunk_map_file_name = "top_$chunks_data->{type}_$chunks_data->{scale}_$chunk->{move}->{x}_$chunk->{move}->{y}";
				
				my $error = $chunk->{image}->Write("$www_path/$maps_path/$chunks_data->{path}/$chunk_map_file_name.jpg");
				Homyaki::Logger::print_log("Download::GpsDrive Error: creation $www_path/$maps_path/$chunks_data->{path}/$chunk_map_file_name.jpg : $error");

				move(
					"$www_path/$maps_path/$chunks_data->{path}/$chunk_map_file_name.jpg",
					"$www_path/$maps_path/$chunks_data->{path}/$chunk_map_file_name.omc2"
				);

				$max_x = $chunk->{move}->{x}
					if ($chunk->{move}->{x} > $max_x);

				$max_y = $chunk->{move}->{y}
					if ($chunk->{move}->{y} > $max_y);
			}

			$max_x++;
			$max_y++;

			my $dim_x = &CHUNK_SIZE_X * $max_x;
			my $dim_y = &CHUNK_SIZE_Y * $max_y;

			my $geo_chunk_lon_l = 
				$geo_data->{selected_square}->[0]
				+ &CHUNK_SIZE_X * $max_x
				* $chunks_data->{scale_calculated}->[0];

			my $geo_chunk_lat_t = 
				$geo_data->{selected_square}->[3]
				- &CHUNK_SIZE_Y * $max_y
				* $chunks_data->{scale_calculated}->[1];


			my $geo_chunk_lon_r = 
				$geo_data->{selected_square}->[0]
				+ &CHUNK_SIZE_X * ($max_x+1)
				* $chunks_data->{scale_calculated}->[0];

			my $geo_chunk_lat_b = 
				$geo_data->{selected_square}->[3]
				- &CHUNK_SIZE_Y * ($max_y+1)
				* $chunks_data->{scale_calculated}->[1];

			$calibration_points_xml .= qq|
				<OruxTracker xmlns="http://oruxtracker.com/app/res/calibration" versionCode="2.1"> 
				<MapCalibration layers="false" layerLevel="13">
				<MapName><![CDATA[top_$chunks_data->{type}_$chunks_data->{scale}]]></MapName>
				<MapChunks xMax="$max_x" yMax="$max_y" datum="WGS84" projection="Mercator" img_height="512" img_width="512" file_name="top_$chunks_data->{type}_$chunks_data->{scale}" />
				<MapDimensions height="$dim_y" width="$dim_x" />
				<MapBounds minLat="$geo_chunk_lat_b" maxLat="$geo_chunk_lat_t" minLon="$geo_chunk_lon_l" maxLon="$geo_chunk_lon_r" />
				<CalibrationPoints>
					<CalibrationPoint corner="TL" lon="$geo_chunk_lon_l" lat="$geo_chunk_lat_t" />
					<CalibrationPoint corner="BR" lon="$geo_chunk_lon_r" lat="$geo_chunk_lat_b" />
					<CalibrationPoint corner="TR" lon="$geo_chunk_lon_r" lat="$geo_chunk_lat_t" />
					<CalibrationPoint corner="BL" lon="$geo_chunk_lon_l" lat="$geo_chunk_lat_b" />
				</CalibrationPoints>
				</MapCalibration>
				</OruxTracker>
			|;

			open MAP_KOORD, ">$www_path/$maps_path/$chunks_data->{path}/top_$chunks_data->{type}_$chunks_data->{scale}.otrk2.xml";
			print MAP_KOORD '<?xml version="1.0" encoding="UTF-8"?>';
			print MAP_KOORD $calibration_points_xml;
			close MAP_KOORD;
		}
	);
	
}

1;
