#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Config::Simple;
use File::Basename;

use Util qw(git_version);
use Debug;

use Trace;
use Backfilling;

use Basic;
use BestEffortContiguous;
use ForcedContiguous;
use BestEffortLocal;
use ForcedLocal;
use BestEffortPlatform qw(SMALLEST_FIRST BIGGEST_FIRST);
use ForcedPlatform;

my ($experiment_id) = @ARGV;

# I have to use the folder name to get the name of the experiment
my $config = Config::Simple->new('experiment.conf');

my $experiment_name = $config->param('parameters.experiment_name');
my $experiment_path = "$experiment_name-$experiment_id";
mkdir $experiment_path unless -d $experiment_path;

print "starting experiment: $experiment_name\n";
print "experiment version " . git_version() . "\n";
print "batch-simulator version " . git_version($config->param('paths.scheduler')) . "\n";

my @platform_levels = $config->param('parameters.platform_levels');
my @platform_latencies = $config->param('parameters.platform_latencies');
my $platform_file_name = "$experiment_path/platform.xml";

print "generating speedup data\n";
my $platform = Platform->new(\@platform_levels);
$platform->build_platform_xml(\@platform_latencies);
$platform->save_platform_xml($platform_file_name);
$platform->generate_speedup($config->param('paths.speedup_benchmark'), $platform_file_name, $config->param('paths.replay_script'));
#$platform->set_speedup(\@platform_latencies);

my $platform_string = join('-', @platform_levels);
my $platform_speedup_string = join(',', $platform->speedup());

my @variants = (
	Basic->new(),
	#BestEffortContiguous->new(),
	#ForcedContiguous->new(),
	#BestEffortLocal->new($platform),
	#ForcedLocal->new($platform),
	#BestEffortPlatform->new($platform),
	#ForcedPlatform->new($platform),
	#BestEffortPlatform->new($platform, mode => SMALLEST_FIRST),
	#ForcedPlatform->new($platform, mode => SMALLEST_FIRST),
	#BestEffortPlatform->new($platform, mode => BIGGEST_FIRST),
	#ForcedPlatform->new($platform, mode => BIGGEST_FIRST),
);

my $variant_id = 0;
my $schedule_script = $config->param('paths.schedule_script');
my $swf_file_name = $config->param('paths.swf_file');
my $jobs_number = $config->param('parameters.jobs_number');
my $results_file_name = "$experiment_path/$experiment_name-$experiment_id.csv";

my $result = `$schedule_script $swf_file_name $jobs_number $variant_id $platform_string $platform_speedup_string $experiment_path`;
#write_result();
print $result, "\n";

sub write_result {
	open(my $file, '>', $results_file_name);
	print $file $result, "\n";
	close($file);
}

