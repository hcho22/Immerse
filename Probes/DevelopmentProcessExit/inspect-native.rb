require 'json'

def check(value, message)
  raise message unless value
end

paths = Dir.glob(File.join(ARGV.fetch(0), 'histories', '*'))
check(paths.length == 4, 'Expected four newly executed histories')
seen = []
paths.each do |directory|
  manifest = JSON.parse(File.read(File.join(directory, 'scenario.json')))
  camera = manifest.fetch('camera')
  seen << camera
  snapshots = %w[prepare at-exit recover resume repeat].map do |name|
    value = JSON.parse(File.read(File.join(directory, "#{name}.json")))
    value['run']['completedSequences'].sort! if value['run']
    value
  end
  prepared, stopped, recovered, resumed, repeated = snapshots
  check(prepared.fetch('process') == stopped.fetch('process'), 'Exit snapshot not from original process')
  check(stopped.fetch('process') != recovered.fetch('process'), 'No process re-entry')
  %w[film run assets].each { |key| check(recovered[key] == stopped[key], "Recovery changed #{key} before explicit resume") }
  check(recovered.fetch('privateFiles').none? { |p| p.start_with?('Work/') }, 'Abandoned Work survived recovery')
  snapshots.each do |s|
    check(s.fetch('film').fetch('id') == manifest.fetch('filmID'), 'Film identity changed')
    check(s.fetch('film').fetch('camera') == prepared.fetch('film').fetch('camera'), 'Camera changed')
    check(s.fetch('film')['movieOrientation'] == prepared.fetch('film')['movieOrientation'], 'Movie orientation changed')
    check(s.fetch('film').fetch('completionState') == prepared.fetch('film').fetch('completionState'), 'Completion or spent capacity changed')
    # Capture identity, saved timestamps, duration and placeholders cannot refund/reorder.
    metadata = s.fetch('film').fetch('captures').map { |c| c.reject { |k,_| k == 'revealState' } }
    initial = prepared.fetch('film').fetch('captures').map { |c| c.reject { |k,_| k == 'revealState' } }
    check(metadata == initial, 'Capture identity/accounting/order changed')
  end
  if stopped['run']
    %w[assignments treatmentVersion printProcess].each do |key|
      check(resumed.fetch('run')[key] == stopped.fetch('run')[key], "Resume changed #{key}")
    end
  end
  stopped.fetch('assets').each do |key, hash|
    next unless key.start_with?('master-', 'clip-')
    check(resumed.fetch('assets')[key] == hash, "Resume changed #{key} bytes")
  end
  check(resumed.fetch('assets').keys.none? { |k| k.start_with?('source-') }, 'Declined sources not cleaned after verified resume')
  check(resumed.fetch('privateFiles').none? { |p| p.start_with?('Work/') }, 'Finished Work remains')
  check(repeated.fetch('film') == resumed.fetch('film'), 'Repeated resume changed Film')
  check(repeated.fetch('run') == resumed.fetch('run'), 'Repeated resume changed Development')
  retained = ->(s) { s.fetch('assets').reject { |k,_| k.start_with?('movie-') } }
  check(retained.call(repeated) == retained.call(resumed), 'Repeated resume changed masters/clips')
  if manifest.fetch('label').end_with?('discard-true')
    check(stopped.fetch('assets')['movie-0'].nil?, 'Stale Movie available after Discard')
    check(stopped.fetch('assets')['clip-1'].nil?, 'Discarded clip available')
    check(resumed.fetch('assets')['clip-1'].nil?, 'Discarded clip resurrected')
    check(resumed.fetch('assets')['clip-2'] == prepared.fetch('assets')['clip-2'], 'Surviving clip changed')
    check(resumed.fetch('assets')['movie-0'], 'Surviving Movie not reassembled')
    check(resumed.fetch('film').fetch('captures').first.fetch('revealState') == 'discardedPlaceholder', 'Discard placeholder lost')
  elsif camera == 'instant1970s'
    check(stopped.fetch('film').fetch('captures').map { |c| c.fetch('revealState') } == %w[revealed sealed], 'Instant second revealed before exit')
    check(resumed.fetch('film').fetch('completionState') == {'open'=>{}}, 'Instant pack closed')
    check(resumed.fetch('assets')['master-1'] == prepared.fetch('assets')['master-1'], 'First print changed')
  elsif camera == 'disposable1990s'
    check(stopped.fetch('assets')['master-1'].nil?, 'Photo master persisted before selected after-render exit')
    check(stopped.fetch('assets')['source-1'], 'Pending source lost')
    check(stopped.fetch('film').fetch('captures').first.fetch('revealState') == 'sealed', 'Photo revealed before persistence')
  elsif camera == 'cinema16mm'
    check(stopped.fetch('assets')['clip-1'], 'Clip missing at after-persistence exit')
    check(stopped.fetch('assets')['movie-0'].nil?, 'Movie assembled before selected clip-persistence exit')
    check(stopped.fetch('film').fetch('captures').first.fetch('revealState') == 'sealed', 'Movie revealed before assembly')
  end
  check(resumed.fetch('film').fetch('captures').reject { |c| c.fetch('revealState') == 'discardedPlaceholder' }.all? { |c| c.fetch('revealState') == 'revealed' }, 'Resume left surviving capture sealed')
  puts "PASS #{camera} #{manifest.fetch('label')} #{File.basename(directory)}"
end
check(seen.sort == %w[cinema16mm disposable1990s instant1970s super8HomeMovie], 'Missing or duplicate native case')
puts 'Four ordinary iOS simulator exits with native synthetic media; no power-loss, Photos, capture or hardware proof.'
