#!/usr/bin/env ruby
require 'json'
require 'digest'

root = ARGV.fetch(0)
read = ->(path) { JSON.parse(File.read(path)) }
check = ->(condition, message) { raise message unless condition }
summary = read.call(File.join(root, 'summary.json'))
check.call(summary['passedTests'] == 7 && summary['failedTests'] == 0 && summary['skippedTests'] == 0,
           'Require seven executed passing hosted observer tests')
check.call(File.read(File.join(root, 'exit.txt')).strip == '0', 'Native command did not succeed')
histories = Dir.glob(File.join(root, 'development-scenarios', '*', 'scenario.json'))
check.call(histories.size == 49, 'Expected 49 separately identified native histories')
counts = Hash.new(0)
observations = histories.sort.map do |manifest_path|
  manifest = read.call(manifest_path)
  directory = File.dirname(manifest_path)
  label = manifest.fetch('label')
  category = label.split('-').first
  counts[category] += 1
  snapshots = Dir.glob(File.join(directory, '*.json')).to_h { |p| [File.basename(p, '.json'), read.call(p)] }
  final = snapshots['finished'] || snapshots['instant-second-revealed'] || snapshots['movie-reassembled']
  live_files = Dir.glob(File.join(directory, 'App', '{Media,Staging,Work}', '**', '*')).select { |p| File.file?(p) }
  if category == 'delete'
    check.call(snapshots.fetch('deleted') == {'privateFilms' => 0, 'privateMediaFiles' => 0}, "#{label}: missing observed deletion")
    check.call(live_files.empty?, "#{label}: remaining private media/work")
  else
    check.call(!final.nil?, "#{label}: no final snapshot")
    hashes = live_files.map { |p| Digest::SHA256.file(p).hexdigest }
    final.fetch('assets').each { |key, hash| check.call(hashes.include?(hash), "#{label}: final #{key} bytes absent") }
    check.call(final.fetch('workFiles').empty?, "#{label}: residual Work")
  end
  if category == 'cancel'
    held = snapshots.fetch('held')
    cancelled = snapshots.fetch('cancelled')
    %w[film assets].each { |key| check.call(held[key] == cancelled[key], "#{label}: #{key} changed after cancellation") }
    normalize_run = lambda do |value|
      next nil if value.nil?
      value.merge('completedSequences' => value.fetch('completedSequences').sort)
    end
    check.call(normalize_run.call(held['run']) == normalize_run.call(cancelled['run']), "#{label}: run changed after cancellation")
    check.call(cancelled.fetch('workFiles').empty?, "#{label}: cancelled Work retained")
  end
  if final
    earlier = snapshots['observer-threw'] || snapshots['cancelled'] || snapshots['held-for-release'] || snapshots['default-completed']
    if earlier
      if earlier['run']
        %w[filmID treatmentVersion printProcess assignments].each do |key|
          check.call(final.fetch('run')[key] == earlier.fetch('run')[key], "#{label}: #{key} changed on resume")
        end
      end
      earlier.fetch('assets').select { |key, _| key.start_with?('master-', 'clip-') }.each do |key, hash|
        check.call(final.fetch('assets')[key] == hash, "#{label}: persisted #{key} changed")
      end
    end
  end
  {id: File.basename(directory), label: label, camera: manifest.fetch('camera'), film: manifest.fetch('film'),
   createdUTC: manifest.fetch('createdUTC'), snapshots: snapshots.keys.sort, finalHashes: final && final['assets']}
end
check.call(counts == {'default'=>5, 'throw'=>18, 'cancel'=>10, 'delete'=>8, 'instant'=>1, 'movie'=>1, 'release'=>6},
           "Incorrect scenario groups: #{counts}")
puts JSON.pretty_generate({result: 'passed offline retained-state checks', histories: histories.size, groups: counts,
                           integerParsing: 'Ruby JSON exact integers', physicalAcceptance: false, observations: observations})
