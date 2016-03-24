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

print "saving speedup data\n";
my @platform_levels = $config->param('parameters.platform_levels');
my @platform_speedup = $config->param('parameters.platform_speedup');
my $platform = Platform->new(\@platform_levels);
$platform->set_speedup(\@platform_speedup);

my $platform_string = join('-', @platform_levels);
my $platform_speedup_string = join(',', $platform->speedup());

my $variant = Basic->new();
my $schedule_script = $config->param('paths.schedule_script');
my $swf_file_name = $config->param('paths.swf_file');
my $jobs_number = $config->param('parameters.jobs_number');
my $results_file_name = "$experiment_path/$experiment_name-$experiment_id.csv";

my $trace = Trace->new_from_swf($swf_file_name);
$trace->remove_large_jobs($platform->processors_number());
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
$trace->keep_first_jobs($jobs_number);
$trace->write_to_file('output.swf');

my $schedule = Backfilling->new($variant, $platform, $trace);
$schedule->run();
write_results();

sub write_results {
	my $jobs = $trace->jobs();

	open(my $file, '>', $results_file_name);

	print $file join(' ', (
			"JOB_NUMBER",
			"CPUS_NUMBER",
			"SUBMIT_TIME",
			"WAIT_TIME",
			"RUN_TIME",
			"REQUESTED_TIME",
			"BSLD",
			"AVG_BSLD",
	)) . "\n";

	my $total_bounded_stretch = 0;
	my $processed_jobs = 0;
	my $stretch_bound = $config->param('parameters.stretch_bound');

	for my $job (@{$jobs}) {
		$total_bounded_stretch += $job->bounded_stretch($stretch_bound);
		$processed_jobs++;

		print $file join(' ', (
			$job->job_number(),
			$job->requested_cpus(),
			$job->submit_time(),
			$job->wait_time(),
			$job->run_time(),
			$job->requested_time(),
			$job->bounded_stretch($stretch_bound),
			$total_bounded_stretch/$processed_jobs,
		)) . "\n";
	}

	close($file);
	return;
}
